#!/usr/bin/env python3
"""
统一的实时算法任务服务程序
整合缓流器、抽帧器、推帧器功能，支持追踪和告警
参照test_services_pipeline.py和test_services_pipeline_tracking.py

@author 翱翔的雄库鲁
@email andywebjava@163.com
@wechat EasyAIoT2025
"""
import os
import sys
import time
import threading
import logging
import subprocess
import signal
import queue
import cv2
import numpy as np
import requests
import json
import socket
from datetime import datetime, timezone
import pytz
from pathlib import Path
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, scoped_session
import concurrent.futures

# 添加VIDEO模块路径
video_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, video_root)

# 导入VIDEO模块的模型
from models import db, AlgorithmTask, Device


def get_device():
    """根据环境变量动态选择设备"""
    use_gpu = os.environ.get('USE_GPU', 'False').lower() == 'true'
    if not use_gpu:
        return 'cpu'

    try:
        import torch
        if torch.cuda.is_available():
            device_id = os.environ.get('CUDA_VISIBLE_DEVICES', '0').split(',')[0]
            return f'cuda:{device_id}' if device_id else 'cuda'
        else:
            logging.warning('USE_GPU设置为True但CUDA不可用，回退到CPU')
            return 'cpu'
    except Exception:
        return 'cpu'


# Flask应用实例（延迟创建，避免导入run模块时的副作用）
_flask_app = None


def get_flask_app():
    """获取Flask应用实例（延迟创建，避免导入run模块时的副作用）"""
    global _flask_app
    if _flask_app is None:
        from flask import Flask
        app = Flask(__name__)
        # 从环境变量获取数据库URL
        database_url = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/iot-edge-video20')
        database_url = database_url.replace("postgres://", "postgresql://", 1)
        app.config['SQLALCHEMY_DATABASE_URI'] = database_url
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        app.config['SQLALCHEMY_ENGINE_OPTIONS'] = {
            'pool_pre_ping': True,
            'pool_recycle': 3600,
            'pool_size': 10,
            'max_overflow': 20,
            'connect_args': {
                'connect_timeout': 10,
            }
        }

        # 初始化数据库
        db.init_app(app)
        _flask_app = app
    return _flask_app


# 导入追踪器（使用相对导入）
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'app', 'utils'))
from tracker import SimpleTracker

# 加载环境变量
load_dotenv()

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# 时区设置（使用Asia/Shanghai，与Java端保持一致）
BEIJING_TZ = pytz.timezone('Asia/Shanghai')

# 全局变量
TASK_ID = int(os.getenv('TASK_ID', '0'))
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/iot-edge-video20')
VIDEO_SERVICE_PORT = os.getenv('VIDEO_SERVICE_PORT', '6000')
# 网关地址（用于构建完整的告警hook URL）
GATEWAY_URL = os.getenv('GATEWAY_URL', 'http://localhost:48080')
# 告警hook URL：优先使用GATEWAY_URL，如果GATEWAY_URL包含端口则使用，否则使用VIDEO_SERVICE_PORT
if GATEWAY_URL and GATEWAY_URL != 'http://localhost:48080':
    # 使用网关地址构建hook URL
    ALERT_HOOK_URL = f"{GATEWAY_URL}/video/alert/hook"
else:
    # 回退到使用VIDEO_SERVICE_PORT（本地开发环境）
    ALERT_HOOK_URL = f"http://localhost:{VIDEO_SERVICE_PORT}/video/alert/hook"

# 数据库会话
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
db_session = scoped_session(SessionLocal)

# 全局变量
stop_event = threading.Event()
task_config = None
yolo_models = {}
# 为每个摄像头创建独立的追踪器
trackers = {}  # {device_id: SimpleTracker}
# 为每个摄像头创建独立的帧缓存队列
frame_buffers = {}  # {device_id: {frame_number: frame_data}}
buffer_locks = {}  # {device_id: threading.Lock()}
# 为每个摄像头创建独立的帧索引计数器
frame_counts = {}  # {device_id: int}
# 为每个摄像头创建独立的队列
extract_queues = {}  # {device_id: queue.Queue}
detection_queues = {}  # {device_id: queue.Queue}
push_queues = {}  # {device_id: queue.Queue}
# 摄像头流连接（VideoCapture对象）
device_caps = {}  # {device_id: cv2.VideoCapture}
# 摄像头推送进程（FFmpeg进程）
device_pushers = {}  # {device_id: subprocess.Popen}
# FFmpeg进程的stderr读取线程和错误信息
device_pusher_stderr_threads = {}  # {device_id: threading.Thread}
device_pusher_stderr_buffers = {}  # {device_id: list} 存储stderr输出
device_pusher_stderr_locks = {}  # {device_id: threading.Lock}
# 设备编码器状态：记录每个设备实际使用的编码器（用于硬件编码失败时自动回退）
device_codec_status = {}  # {device_id: 'h264_nvenc' | 'libx264'}
device_codec_locks = {}  # {device_id: threading.Lock} 保护编码器状态
# 告警抑制：记录每个设备上次告警推送时间
last_alert_time = {}  # {device_id: timestamp}
alert_suppression_interval = 5.0  # 告警抑制间隔：5秒
alert_time_lock = threading.Lock()  # 告警时间戳锁，确保线程安全

# 配置参数（从数据库读取，支持环境变量覆盖以降低CPU占用）
# 帧率：降低可减少CPU占用和推流速度
SOURCE_FPS = int(os.getenv('SOURCE_FPS', '15'))  # 默认15fps（原25fps）
# 分辨率：降低可大幅减少CPU占用和推流速度
TARGET_WIDTH = int(os.getenv('TARGET_WIDTH', '640'))  # 默认640（原1280）
TARGET_HEIGHT = int(os.getenv('TARGET_HEIGHT', '360'))  # 默认360（原720）
TARGET_RESOLUTION = (TARGET_WIDTH, TARGET_HEIGHT)
EXTRACT_INTERVAL = int(os.getenv('EXTRACT_INTERVAL', '5'))
BUFFER_SIZE = int(os.getenv('BUFFER_SIZE', '70'))
MIN_BUFFER_FRAMES = int(os.getenv('MIN_BUFFER_FRAMES', '15'))
MAX_WAIT_TIME = float(os.getenv('MAX_WAIT_TIME', '0.08'))
# FFmpeg编码参数（优化以降低CPU占用）
# FFmpeg编码参数（优化以降低CPU占用）
# 处理空字符串的情况，确保参数有效
FFMPEG_PRESET_ENV = os.getenv('FFMPEG_PRESET', 'ultrafast')
FFMPEG_PRESET = FFMPEG_PRESET_ENV.strip() if FFMPEG_PRESET_ENV and FFMPEG_PRESET_ENV.strip() else 'ultrafast'  # 编码预设：ultrafast最快，CPU占用最低

FFMPEG_VIDEO_BITRATE_ENV = os.getenv('FFMPEG_VIDEO_BITRATE', '500k')
FFMPEG_VIDEO_BITRATE = FFMPEG_VIDEO_BITRATE_ENV.strip() if FFMPEG_VIDEO_BITRATE_ENV and FFMPEG_VIDEO_BITRATE_ENV.strip() else '500k'  # 视频比特率：降低可减少推流速度（原1500k）

# 编码线程数：None表示自动，可设置为较小值降低CPU
# 处理空字符串的情况，确保只有有效的数字字符串才会被使用
FFMPEG_THREADS_ENV = os.getenv('FFMPEG_THREADS', None)
FFMPEG_THREADS = None if not FFMPEG_THREADS_ENV or FFMPEG_THREADS_ENV.strip() == '' else FFMPEG_THREADS_ENV.strip()
# GOP大小：2秒一个关键帧（在SOURCE_FPS定义后计算）
FFMPEG_GOP_SIZE_ENV = os.getenv('FFMPEG_GOP_SIZE', None)
FFMPEG_GOP_SIZE = int(FFMPEG_GOP_SIZE_ENV) if FFMPEG_GOP_SIZE_ENV else (SOURCE_FPS * 2)

# 硬件加速配置
FFMPEG_HWACCEL_ENV = os.getenv('FFMPEG_HWACCEL', 'auto').strip().lower()
FFMPEG_HWACCEL = FFMPEG_HWACCEL_ENV if FFMPEG_HWACCEL_ENV in ['auto', 'nvenc', 'cuvid', 'none'] else 'auto'

# YOLO检测参数（优化以降低CPU占用）
YOLO_IMG_SIZE = int(os.getenv('YOLO_IMG_SIZE', '416'))  # 检测分辨率：降低可减少CPU占用（原640）
# 队列大小配置（优化以处理高负载）
DETECTION_QUEUE_SIZE = int(os.getenv('DETECTION_QUEUE_SIZE', '100'))  # 检测队列大小（默认100，原50）
PUSH_QUEUE_SIZE = int(os.getenv('PUSH_QUEUE_SIZE', '100'))  # 推帧队列大小（默认100，原50）
EXTRACT_QUEUE_SIZE = int(os.getenv('EXTRACT_QUEUE_SIZE', '50'))  # 抽帧队列大小（默认50）
# 检测工作线程数量（优化以提升处理能力）
YOLO_WORKER_THREADS = int(os.getenv('YOLO_WORKER_THREADS', '2'))  # YOLO检测线程数（默认2，原1）


def _is_valid_model_file(path: str) -> bool:
    """检查模型文件是否真实存在且非空（避免 0 字节无效文件）"""
    try:
        if not path:
            return False
        if not os.path.exists(path):
            return False
        return os.path.getsize(path) > 0
    except Exception:
        return False


def _edge_video_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _resolve_edge_local_model_weights(model_id: int) -> Optional[str]:
    """
    边缘版：仅在 VIDEO/data/models/<model_id>/ 下查找 .pt / .pth / .onnx。
    不调用 AI 服务、不直连 MinIO、不发 HTTP。多文件时优先 .pt，其次 .pth、.onnx，再按文件名排序。
    """
    model_dir = os.path.join(_edge_video_root(), 'data', 'models', str(model_id))
    if not os.path.isdir(model_dir):
        return None
    candidates = []
    for fn in os.listdir(model_dir):
        low = fn.lower()
        p = os.path.join(model_dir, fn)
        if not os.path.isfile(p) or not _is_valid_model_file(p):
            continue
        if low.endswith('.pt'):
            pri = 0
        elif low.endswith('.pth'):
            pri = 1
        elif low.endswith('.onnx'):
            pri = 2
        else:
            continue
        candidates.append((pri, fn, p))
    if not candidates:
        return None
    candidates.sort(key=lambda x: (x[0], x[1]))
    chosen = candidates[0][2]
    logger.info(f"边缘本地模型: model_id={model_id} -> {chosen}")
    return chosen


def load_yolo_models(model_ids: List[int]) -> Dict[int, Any]:
    """加载YOLO模型列表

    Args:
        model_ids: 模型ID列表（正数表示数据库模型，负数表示默认模型）

    Returns:
        Dict[int, YOLO]: 模型字典 {model_id: YOLO模型实例}
    """
    try:
        from ultralytics import YOLO

        models = {}

        for model_id in model_ids:
            try:
                # 默认模型映射
                default_model_map = {
                    -1: 'yolo11n.pt',
                    -2: 'yolov8n.pt',
                }

                # 如果是负数ID，表示默认模型
                if model_id < 0:
                    model_filename = default_model_map.get(model_id)
                    if not model_filename:
                        logger.warning(f"未知的默认模型ID: {model_id}，跳过")
                        continue

                    video_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
                    model_path = os.path.join(video_root, model_filename)

                    if not os.path.exists(model_path):
                        logger.warning(f"默认模型文件不存在: {model_path}，尝试从ultralytics下载")
                        # 尝试从ultralytics下载（如果本地不存在）
                        model_path = model_filename  # ultralytics会自动下载
                else:
                    # 边缘版：正数模型 ID 仅读取本机 VIDEO/data/models/<id>/，与 AI 模块无任何 HTTP 交互
                    model_path = _resolve_edge_local_model_weights(model_id)
                    if not model_path:
                        logger.warning(
                            f"模型 {model_id} 在本地未找到（请将 .pt/.onnx 放入 VIDEO/data/models/{model_id}/），跳过")
                        continue

                # 加载YOLO模型
                logger.info(f"正在加载YOLO模型: model_id={model_id}, path={model_path}")
                yolo_model = YOLO(str(model_path))
                models[model_id] = yolo_model
                logger.info(f"✅ YOLO模型加载成功: model_id={model_id}")

            except Exception as e:
                logger.error(f"❌ 加载YOLO模型失败: model_id={model_id}, error={str(e)}", exc_info=True)
                continue

        return models

    except Exception as e:
        logger.error(f"加载YOLO模型列表失败: {str(e)}", exc_info=True)
        return {}


def load_task_config():
    """从数据库加载任务配置（重启时会重新加载，确保获取最新的摄像头信息）"""
    global task_config, yolo_models, tracker

    try:
        logger.info(f"🔄 正在从数据库重新加载任务配置: task_id={TASK_ID}")
        # 刷新数据库会话，确保获取最新数据
        db_session.expire_all()

        task = db_session.query(AlgorithmTask).filter_by(id=TASK_ID).first()
        if not task:
            logger.error(f"任务 {TASK_ID} 不存在")
            return False

        task_config = task

        # 解析模型ID列表
        model_ids = []
        if task.model_ids:
            try:
                model_ids = json.loads(task.model_ids) if isinstance(task.model_ids, str) else task.model_ids
            except:
                pass

        if not model_ids:
            logger.error(f"任务 {TASK_ID} 没有配置模型ID列表")
            return False

        # 加载YOLO模型列表
        yolo_models = load_yolo_models(model_ids)
        if not yolo_models:
            logger.error(f"任务 {TASK_ID} 没有成功加载任何模型")
            return False

        logger.info(f"✅ 成功加载 {len(yolo_models)} 个YOLO模型")

        # 从摄像头列表获取输入流地址（支持RTSP和RTMP）和RTMP输出流地址（重新加载，确保获取最新地址）
        # 注意：rtmp_input_url和rtmp_output_url字段已废弃，改为从摄像头列表获取
        device_streams = {}
        if task.devices:
            # 刷新设备关联关系，确保获取最新的设备信息
            db_session.refresh(task)
            for device in task.devices:
                # 刷新设备对象，确保获取最新的source和ai_rtmp_stream
                db_session.refresh(device)
                # 输入流地址（支持RTSP和RTMP格式，从device.source获取）
                rtsp_url = device.source if device.source else None
                # AI RTMP流地址作为输出（从device.ai_rtmp_stream获取，如果不存在则回退到device.rtmp_stream）
                rtmp_url = device.ai_rtmp_stream if device.ai_rtmp_stream else (device.rtmp_stream if device.rtmp_stream else None)
                device_streams[device.id] = {
                    'rtsp_url': rtsp_url,  # 输入流地址
                    'rtmp_url': rtmp_url,  # AI输出流地址
                    'device_name': device.name or device.id
                }
                input_type = "RTSP" if rtsp_url and rtsp_url.startswith(
                    'rtsp://') else "RTMP" if rtsp_url and rtsp_url.startswith('rtmp://') else "输入流"
                logger.info(
                    f"📹 设备 {device.id} ({device.name or device.id}): {input_type}={rtsp_url}, AI RTMP输出={rtmp_url}")

        # 将设备流地址信息存储到task_config中（通过动态属性）
        task_config.device_streams = device_streams

        # 为每个摄像头初始化独立的资源
        for device_id, stream_info in device_streams.items():
            # 初始化帧缓存队列
            frame_buffers[device_id] = {}
            buffer_locks[device_id] = threading.Lock()
            frame_counts[device_id] = 0

            # 初始化队列（使用可配置的大小）
            extract_queues[device_id] = queue.Queue(maxsize=EXTRACT_QUEUE_SIZE)
            detection_queues[device_id] = queue.Queue(maxsize=DETECTION_QUEUE_SIZE)
            push_queues[device_id] = queue.Queue(maxsize=PUSH_QUEUE_SIZE)

            # 初始化追踪器（如果启用）
            if task.tracking_enabled:
                trackers[device_id] = SimpleTracker(
                    similarity_threshold=task.tracking_similarity_threshold,
                    max_age=task.tracking_max_age,
                    smooth_alpha=task.tracking_smooth_alpha
                )
                logger.info(f"设备 {device_id} 追踪器初始化成功")

        logger.info(f"任务配置加载成功: {task.task_name}, 模型IDs: {model_ids}, 关联设备数: {len(device_streams)}")

        if task.tracking_enabled:
            logger.info(f"已为 {len(trackers)} 个设备初始化追踪器")

        return True
    except Exception as e:
        logger.error(f"加载任务配置失败: {str(e)}", exc_info=True)
        return False


def send_alert_event_async(alert_data: Dict):
    """异步发送告警事件到 sink hook 接口（后台线程）"""

    def _send():
        try:
            if not task_config or not task_config.alert_event_enabled:
                logger.warning(f"⚠️ 告警事件发送被跳过：task_config={task_config is not None}, alert_event_enabled={task_config.alert_event_enabled if task_config else None}, device_id={alert_data.get('device_id')}")
                return
            
            logger.info(f"📤 开始发送告警事件: device_id={alert_data.get('device_id')}, object={alert_data.get('object')}, URL={ALERT_HOOK_URL}")

            # 通过 HTTP 发送告警事件到 sink hook 接口
            # sink 会负责将告警投入 Kafka
            try:
                # 标记为实时算法任务
                alert_data['task_type'] = 'realtime'
                response = requests.post(
                    ALERT_HOOK_URL,
                    json=alert_data,
                    timeout=5,
                    headers={'Content-Type': 'application/json'}
                )
                if response.status_code == 200:
                    logger.info(f"✅ 告警事件已成功发送到 sink hook: device_id={alert_data.get('device_id')}, object={alert_data.get('object')}, event={alert_data.get('event')}")
                else:
                    logger.warning(
                        f"❌ 发送告警事件到 sink hook 失败: status_code={response.status_code}, response={response.text}, device_id={alert_data.get('device_id')}")
            except requests.exceptions.RequestException as e:
                logger.warning(f"❌ 发送告警事件到 sink hook 异常: {str(e)}, URL={ALERT_HOOK_URL}, device_id={alert_data.get('device_id')}")
        except Exception as e:
            logger.error(f"发送告警事件失败: {str(e)}", exc_info=True)

    # 在后台线程中异步执行
    thread = threading.Thread(target=_send, daemon=True)
    thread.start()


def cleanup_alert_images(alert_image_dir: str, max_images: int = 300, keep_ratio: float = 0.1):
    """清理告警图片目录，当图片数量超过限制时，删除最旧的图片

    Args:
        alert_image_dir: 告警图片目录路径
        max_images: 最大图片数量，超过此数量时触发清理（默认300张）
        keep_ratio: 保留比例（0.0-1.0），例如0.1表示保留最新的10%（删除90%）
    """
    try:
        if not os.path.exists(alert_image_dir):
            return

        # 获取所有jpg图片文件
        image_files = []
        for filename in os.listdir(alert_image_dir):
            if filename.lower().endswith('.jpg') or filename.lower().endswith('.jpeg'):
                file_path = os.path.join(alert_image_dir, filename)
                if os.path.isfile(file_path):
                    # 获取文件修改时间
                    mtime = os.path.getmtime(file_path)
                    image_files.append((file_path, mtime))

        total_images = len(image_files)

        # 如果图片数量未超过限制，不需要清理
        if total_images <= max_images:
            return

        # 按修改时间排序（最旧的在前）
        image_files.sort(key=lambda x: x[1])

        # 计算需要保留的图片数量（最新的10%）
        keep_count = max(1, int(total_images * keep_ratio))

        # 计算需要删除的图片数量（最旧的90%）
        delete_count = total_images - keep_count

        # 删除最旧的图片
        deleted_count = 0
        for i in range(delete_count):
            try:
                file_path = image_files[i][0]
                os.remove(file_path)
                deleted_count += 1
            except Exception as e:
                logger.warning(f"删除告警图片失败: {file_path}, 错误: {str(e)}")

        if deleted_count > 0:
            logger.info(
                f"告警图片清理完成: 目录={alert_image_dir}, 总数={total_images}, 删除={deleted_count}, 保留={keep_count}")
    except Exception as e:
        logger.error(f"清理告警图片失败: {str(e)}", exc_info=True)


def cleanup_srs_recordings(srs_record_dir: str = '/data/playbacks', max_recordings: int = 500, keep_ratio: float = 0.1):
    """清理SRS录像目录，当录像数量超过限制时，删除最旧的录像

    Args:
        srs_record_dir: SRS录像目录路径，默认为 /data/playbacks
        max_recordings: 最大录像数量，超过此数量时触发清理
        keep_ratio: 保留比例（0.0-1.0），例如0.1表示保留最新的10%
    """
    try:
        if not os.path.exists(srs_record_dir):
            logger.debug(f"SRS录像目录不存在: {srs_record_dir}")
            return

        # 递归获取所有.flv录像文件
        recording_files = []
        for root, dirs, files in os.walk(srs_record_dir):
            for filename in files:
                if filename.lower().endswith('.flv'):
                    file_path = os.path.join(root, filename)
                    if os.path.isfile(file_path):
                        # 获取文件修改时间
                        try:
                            mtime = os.path.getmtime(file_path)
                            recording_files.append((file_path, mtime))
                        except Exception as e:
                            logger.warning(f"获取文件修改时间失败: {file_path}, 错误: {str(e)}")
                            continue

        total_recordings = len(recording_files)

        # 如果录像数量未超过限制，不需要清理
        if total_recordings <= max_recordings:
            logger.debug(f"SRS录像目录检查: 总数={total_recordings}, 未超过限制={max_recordings}")
            return

        # 按修改时间排序（最旧的在前）
        recording_files.sort(key=lambda x: x[1])

        # 计算需要保留的录像数量（最新的10%）
        keep_count = max(1, int(total_recordings * keep_ratio))

        # 计算需要删除的录像数量（最旧的90%）
        delete_count = total_recordings - keep_count

        # 不再删除 /data/playbacks 目录下的录像文件，只记录统计信息
        if delete_count > 0:
            logger.debug(
                f"SRS录像统计: 目录={srs_record_dir}, 总数={total_recordings}, 应删除={delete_count}, 保留={keep_count}（已禁用删除 /data/playbacks 逻辑）")
    except Exception as e:
        logger.error(f"清理SRS录像失败: {str(e)}", exc_info=True)


def save_alert_image(frame: np.ndarray, device_id: str, frame_number: int, detection: Dict) -> Optional[str]:
    """保存告警图片到本地目录

    Args:
        frame: 图片帧
        device_id: 设备ID
        frame_number: 帧号
        detection: 检测结果字典

    Returns:
        图片保存路径，如果保存失败返回None
    """
    try:
        # 创建告警图片保存目录
        video_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        alert_image_dir = os.path.join(video_root, 'alert_images', f'task_{TASK_ID}', device_id)
        os.makedirs(alert_image_dir, exist_ok=True)

        # 生成图片文件名（包含时间戳和帧号）
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        track_id = detection.get('track_id', 0)
        class_name = detection.get('class_name', 'unknown')
        image_filename = f"{timestamp}_frame{frame_number}_track{track_id}_{class_name}.jpg"
        image_path = os.path.join(alert_image_dir, image_filename)

        # 保存图片
        cv2.imwrite(image_path, frame)

        logger.debug(f"告警图片已保存: {image_path}")

        # 保存后检查并清理旧图片（超过300张时，删除最旧的90%）
        cleanup_alert_images(alert_image_dir, max_images=300, keep_ratio=0.1)

        return image_path
    except Exception as e:
        logger.error(f"保存告警图片失败: {str(e)}", exc_info=True)
        return None


def send_heartbeat():
    """发送心跳到VIDEO服务"""
    try:
        import socket
        import os as os_module

        # 获取服务器IP
        server_ip = os_module.getenv('POD_IP', '')
        if not server_ip:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(('8.8.8.8', 80))
                server_ip = s.getsockname()[0]
                s.close()
            except:
                server_ip = 'localhost'

        # 获取进程ID
        process_id = os_module.getpid()

        # 构建日志路径
        video_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        log_base_dir = os.path.join(video_root, 'logs')
        log_path = os.path.join(log_base_dir, f'task_{TASK_ID}')

        # 构建心跳URL
        heartbeat_url = f"http://localhost:{VIDEO_SERVICE_PORT}/video/algorithm/heartbeat/realtime"

        # 发送心跳
        response = requests.post(
            heartbeat_url,
            json={
                'task_id': TASK_ID,
                'server_ip': server_ip,
                'port': None,  # 实时算法服务不监听端口
                'process_id': process_id,
                'log_path': log_path
            },
            timeout=5
        )
        response.raise_for_status()
        logger.debug(f"心跳上报成功: task_id={TASK_ID}")
    except Exception as e:
        logger.warning(f"心跳上报失败: {str(e)}")


def heartbeat_worker():
    """心跳上报工作线程"""
    logger.info("💓 心跳上报线程启动")
    while not stop_event.is_set():
        try:
            send_heartbeat()
            # 每10秒发送一次心跳
            for _ in range(10):
                if stop_event.is_set():
                    break
                time.sleep(1)
        except Exception as e:
            logger.error(f"心跳上报线程异常: {str(e)}", exc_info=True)
            time.sleep(10)
    logger.info("💓 心跳上报线程停止")


def srs_recording_cleanup_worker():
    """SRS录像清理工作线程"""
    logger.info("🧹 SRS录像清理线程启动")
    # 获取SRS录像目录路径（可通过环境变量配置，默认为 /data/playbacks）
    srs_record_dir = os.getenv('SRS_RECORD_DIR', '/data/playbacks')

    while not stop_event.is_set():
        try:
            # 清理SRS录像目录（超过500个时，删除最旧的90%）
            cleanup_srs_recordings(srs_record_dir, max_recordings=500, keep_ratio=0.1)
            # 每60秒检查一次
            for _ in range(60):
                if stop_event.is_set():
                    break
                time.sleep(1)
        except Exception as e:
            logger.error(f"SRS录像清理线程异常: {str(e)}", exc_info=True)
            time.sleep(60)
    logger.info("🧹 SRS录像清理线程停止")


def save_tracking_target(track_data: Dict):
    """处理追踪目标（不保存到数据库，仅用于追踪逻辑）"""
    # 不再保存到数据库，仅用于追踪逻辑处理
    pass


def save_tracking_targets_periodically():
    """定期处理追踪目标（后台线程，不保存到数据库）"""
    logger.info("💾 追踪目标处理线程启动（不保存到数据库）")
    while not stop_event.is_set():
        try:
            if task_config and task_config.tracking_enabled:
                # 仅用于追踪逻辑处理，不保存到数据库
                for device_id, tracker in trackers.items():
                    try:
                        # 获取需要处理的追踪目标（用于追踪逻辑，不保存）
                        tracks_to_process = tracker.get_tracks_for_save()
                        # 这里可以添加其他追踪相关的处理逻辑，但不保存到数据库
                        if tracks_to_process and len(tracks_to_process) > 0:
                            logger.debug(f"设备 {device_id} 有 {len(tracks_to_process)} 个追踪目标需要处理")
                    except Exception as e:
                        logger.error(f"处理设备 {device_id} 的追踪目标失败: {str(e)}", exc_info=True)

            # 每5秒检查一次
            for _ in range(50):
                if stop_event.is_set():
                    break
                time.sleep(0.1)
        except Exception as e:
            logger.error(f"追踪目标处理线程异常: {str(e)}", exc_info=True)
            time.sleep(5)
    logger.info("💾 追踪目标处理线程停止")


def check_hardware_acceleration():
    """检测硬件加速是否可用
    
    Returns:
        tuple: (use_nvenc: bool, use_cuvid: bool, codec_name: str)
    """
    use_nvenc = False
    use_cuvid = False
    codec_name = 'libx264'
    
    # 如果明确设置为none，使用软件编码
    if FFMPEG_HWACCEL == 'none':
        logger.info("硬件加速已禁用，使用软件编码 libx264")
        return False, False, 'libx264'
    
    # 如果明确设置为nvenc，尝试使用硬件编码
    if FFMPEG_HWACCEL in ['nvenc', 'auto']:
        try:
            # 检查FFmpeg是否支持h264_nvenc编码器
            result = subprocess.run(
                ['ffmpeg', '-hide_banner', '-encoders'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=5
            )
            output = result.stdout.decode('utf-8', errors='ignore') + result.stderr.decode('utf-8', errors='ignore')
            
            if 'h264_nvenc' in output:
                use_nvenc = True
                codec_name = 'h264_nvenc'
                logger.info("✅ 检测到硬件加速支持，使用 h264_nvenc 编码器")
            else:
                logger.info("⚠️  未检测到 h264_nvenc 编码器，使用软件编码 libx264")
        except Exception as e:
            logger.warning(f"检测硬件加速时出错: {str(e)}，使用软件编码 libx264")
    
    return use_nvenc, use_cuvid, codec_name


# 在启动时检测硬件加速
_hwaccel_nvenc, _hwaccel_cuvid, _hwaccel_codec = check_hardware_acceleration()


def check_rtmp_server_connection(rtmp_url: str) -> bool:
    """检查RTMP服务器是否可用

    Args:
        rtmp_url: RTMP推流地址，格式如 rtmp://localhost:1935/live/stream

    Returns:
        bool: RTMP服务器是否可用
    """
    try:
        # 从RTMP URL中提取主机和端口
        if not rtmp_url.startswith('rtmp://'):
            return False

        # 解析URL: rtmp://host:port/path -> (host, port)
        url_part = rtmp_url.replace('rtmp://', '')
        if '/' in url_part:
            host_port = url_part.split('/')[0]
        else:
            host_port = url_part

        if ':' in host_port:
            host, port_str = host_port.split(':', 1)
            try:
                port = int(port_str)
            except ValueError:
                port = 1935  # 默认RTMP端口
        else:
            host = host_port
            port = 1935  # 默认RTMP端口

        # 重要：realtime_algorithm_service 使用 host 网络模式，必须使用 localhost 访问 SRS
        # 如果 RTMP URL 中使用的是容器名（如 srs-server 或 srs），需要强制转换为 localhost
        if host in ['srs-server', 'srs', 'SRS']:
            logger.debug(
                f'检测到 SRS 配置使用容器名 {host}，强制转换为 localhost（realtime_algorithm_service 使用 host 网络模式）')
            host = 'localhost'

        # 尝试连接RTMP服务器端口
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        result = sock.connect_ex((host, port))
        sock.close()

        if result == 0:
            return True
        else:
            return False
    except Exception as e:
        logger.debug(f"检查RTMP服务器连接时出错: {str(e)}")
        return False


def check_and_stop_existing_stream(stream_url: str):
    """检查并停止现有的 RTMP 流（通过 SRS HTTP API）

    当检测到流已存在时，会检查流是否真的在活动：
    1. 如果流存在但没有活跃的发布者（僵尸连接），直接清理流资源
    2. 如果流存在且有发布者，检查发布者连接是否真的在活动
    3. 如果发布者连接已断开，强制清理流资源
    4. 如果发布者连接正常，断开发布者连接

    Args:
        stream_url: RTMP流地址，格式如 rtmp://localhost:1935/live/stream
    """
    try:
        # 从 RTMP URL 中提取流名称和主机
        # rtmp://localhost:1935/live/test_input -> live/test_input
        if not stream_url.startswith('rtmp://'):
            logger.warning("⚠️  无效的RTMP URL格式，跳过流检查")
            return

        # 解析URL: rtmp://host:port/path -> (host, port, path)
        url_part = stream_url.replace('rtmp://', '')
        if '/' in url_part:
            host_port = url_part.split('/')[0]
            stream_path = '/'.join(url_part.split('/')[1:])
        else:
            host_port = url_part
            stream_path = ""

        if not stream_path:
            logger.warning("⚠️  无法从 URL 中提取流路径，跳过流检查")
            return

        # 提取主机地址（用于SRS API调用）
        if ':' in host_port:
            rtmp_host = host_port.split(':')[0]
        else:
            rtmp_host = host_port

        # 重要：realtime_algorithm_service 使用 host 网络模式，必须使用 localhost 访问 SRS
        # 如果 RTMP URL 中使用的是容器名（如 srs-server 或 srs），需要强制转换为 localhost
        # 这样可以避免在 host 网络模式下尝试解析容器名导致的连接失败
        if rtmp_host in ['srs-server', 'srs', 'SRS']:
            logger.info(
                f'检测到 SRS 配置使用容器名 {rtmp_host}，强制转换为 localhost（realtime_algorithm_service 使用 host 网络模式）')
            rtmp_host = 'localhost'

        # SRS HTTP API 地址（默认端口 1985）
        srs_api_url = f"http://{rtmp_host}:1985/api/v1/streams/"
        srs_clients_api_url = f"http://{rtmp_host}:1985/api/v1/clients/"

        logger.info(f"🔍 检查现有流: {stream_path}")

        try:
            # 获取所有流
            response = requests.get(srs_api_url, timeout=3)
            if response.status_code == 200:
                streams = response.json()

                # 查找匹配的流
                stream_to_stop = None
                if isinstance(streams, dict) and 'streams' in streams:
                    stream_list = streams['streams']
                elif isinstance(streams, list):
                    stream_list = streams
                else:
                    stream_list = []

                for stream in stream_list:
                    stream_name = stream.get('name', '')
                    stream_app = stream.get('app', '')
                    stream_stream = stream.get('stream', '')

                    # 匹配流路径（格式：app/stream）
                    # 使用精确匹配，避免误匹配其他流
                    full_stream_path = f"{stream_app}/{stream_stream}" if stream_stream else stream_app

                    # 精确匹配：只有当流路径完全匹配时才停止
                    # 这样可以避免误停止其他设备的流
                    if stream_path == full_stream_path:
                        stream_to_stop = stream
                        break

                if stream_to_stop:
                    stream_id = stream_to_stop.get('id', '')
                    publish_info = stream_to_stop.get('publish', {})
                    publish_cid = publish_info.get('cid', '') if isinstance(publish_info, dict) else None

                    logger.warning(f"⚠️  发现现有流: {stream_path} (ID: {stream_id})")

                    # 检查是否有活跃的发布者
                    if not publish_cid:
                        # 流存在但没有发布者（僵尸流），直接清理
                        logger.warning(f"   流存在但没有活跃的发布者（僵尸流），直接清理...")
                        try:
                            stop_url = f"{srs_api_url}{stream_id}"
                            stop_response = requests.delete(stop_url, timeout=3)
                            if stop_response.status_code in [200, 204]:
                                logger.info(f"✅ 已清理僵尸流: {stream_path}")
                                time.sleep(1)  # 等待流完全停止
                                return
                        except Exception as e:
                            logger.warning(f"   清理僵尸流异常: {str(e)}")
                    else:
                        # 有发布者ID，检查发布者连接是否真的在活动
                        logger.info(f"   检查发布者连接状态: {publish_cid}")
                        try:
                            # 获取客户端信息，检查连接是否真的存在
                            client_info_url = f"{srs_clients_api_url}{publish_cid}"
                            client_response = requests.get(client_info_url, timeout=2)

                            if client_response.status_code == 200:
                                client_info = client_response.json()
                                # 检查客户端是否真的在活动
                                client_active = client_info.get('active', True) if isinstance(client_info,
                                                                                              dict) else True

                                if not client_active:
                                    # 客户端已断开，清理僵尸流
                                    logger.warning(f"   发布者连接已断开（僵尸连接），清理流资源...")
                                    try:
                                        stop_url = f"{srs_api_url}{stream_id}"
                                        stop_response = requests.delete(stop_url, timeout=3)
                                        if stop_response.status_code in [200, 204]:
                                            logger.info(f"✅ 已清理僵尸流: {stream_path}")
                                            time.sleep(1)
                                            return
                                    except Exception as e:
                                        logger.warning(f"   清理僵尸流异常: {str(e)}")
                                else:
                                    # 客户端连接正常，尝试断开
                                    logger.info(f"   发布者连接正常，尝试断开连接...")
                                    try:
                                        stop_response = requests.delete(client_info_url, timeout=3)
                                        if stop_response.status_code in [200, 204]:
                                            logger.info(f"✅ 已断开发布者客户端，流将自动停止")
                                            time.sleep(2)  # 等待流完全停止
                                            return
                                        else:
                                            logger.warning(
                                                f"   断开客户端失败 (状态码: {stop_response.status_code})，尝试其他方法...")
                                    except Exception as e:
                                        logger.warning(f"   断开客户端异常: {str(e)}，尝试其他方法...")
                            else:
                                # 无法获取客户端信息，可能连接已断开，尝试清理流
                                logger.warning(
                                    f"   无法获取发布者信息 (状态码: {client_response.status_code})，可能连接已断开，尝试清理流...")
                                try:
                                    # 先尝试断开客户端（即使可能已断开）
                                    try:
                                        requests.delete(client_info_url, timeout=2)
                                    except:
                                        pass

                                    # 然后清理流
                                    stop_url = f"{srs_api_url}{stream_id}"
                                    stop_response = requests.delete(stop_url, timeout=3)
                                    if stop_response.status_code in [200, 204]:
                                        logger.info(f"✅ 已清理流: {stream_path}")
                                        time.sleep(1)
                                        return
                                except Exception as e:
                                    logger.warning(f"   清理流异常: {str(e)}")
                        except requests.exceptions.RequestException as e:
                            # 无法连接到客户端API，可能连接已断开，尝试清理流
                            logger.warning(f"   无法连接到客户端API: {str(e)}，尝试清理流...")
                            try:
                                stop_url = f"{srs_api_url}{stream_id}"
                                stop_response = requests.delete(stop_url, timeout=3)
                                if stop_response.status_code in [200, 204]:
                                    logger.info(f"✅ 已清理流: {stream_path}")
                                    time.sleep(1)
                                    return
                            except Exception as e2:
                                logger.warning(f"   清理流异常: {str(e2)}")

                    # 方法2: 尝试通过流ID停止（某些SRS版本支持）
                    logger.info(f"   尝试通过流ID停止: {stream_id}")
                    stop_url = f"{srs_api_url}{stream_id}"
                    try:
                        stop_response = requests.delete(stop_url, timeout=3)
                        if stop_response.status_code in [200, 204]:
                            logger.info(f"✅ 已停止现有流: {stream_path}")
                            time.sleep(2)  # 等待流完全停止
                            return
                        else:
                            logger.warning(f"   停止流失败 (状态码: {stop_response.status_code})")
                    except Exception as e:
                        logger.warning(f"   停止流异常: {str(e)}")

                    # 方法3: 如果API都失败，尝试查找并杀死占用该流的ffmpeg进程
                    logger.warning(f"⚠️  API方法失败，尝试查找占用该流的进程...")
                    try:
                        # 查找推流到该地址的ffmpeg进程
                        result = subprocess.run(
                            ["pgrep", "-f", f"rtmp://.*{stream_path.split('/')[-1]}"],
                            capture_output=True,
                            text=True,
                            timeout=3
                        )
                        if result.returncode == 0 and result.stdout.strip():
                            pids = result.stdout.strip().split('\n')
                            for pid in pids:
                                if pid.strip():
                                    logger.info(f"   发现进程 PID: {pid.strip()}，正在终止...")
                                    try:
                                        subprocess.run(["kill", "-TERM", pid.strip()], timeout=2)
                                        time.sleep(1)
                                        logger.info(f"✅ 已终止进程: {pid.strip()}")
                                    except:
                                        pass
                            time.sleep(2)  # 等待进程完全退出
                            return
                    except Exception as e:
                        logger.warning(f"   查找进程失败: {str(e)}")

                    logger.warning(f"⚠️  无法停止现有流，但将继续尝试推流...")
                else:
                    logger.info(f"✅ 未发现现有流: {stream_path}")
            else:
                logger.warning(f"⚠️  无法获取流列表 (状态码: {response.status_code})，继续尝试推流...")

        except requests.exceptions.RequestException as e:
            logger.warning(f"⚠️  无法连接到 SRS API: {str(e)}，继续尝试推流...")

    except Exception as e:
        logger.warning(f"⚠️  检查现有流时出错: {str(e)}，继续尝试推流...")


def read_ffmpeg_stderr(device_id: str, stderr_pipe, stderr_buffer: list, stderr_lock: threading.Lock):
    """实时读取FFmpeg进程的stderr输出"""
    try:
        for line in iter(stderr_pipe.readline, b''):
            if not line:
                break
            try:
                line_str = line.decode('utf-8', errors='ignore').strip()
                if line_str:
                    with stderr_lock:
                        stderr_buffer.append(line_str)
                        # 只保留最近100行
                        if len(stderr_buffer) > 100:
                            stderr_buffer.pop(0)
            except:
                pass
    except Exception as e:
        logger.debug(f"设备 {device_id} stderr读取线程异常: {str(e)}")
    finally:
        stderr_pipe.close()


def buffer_streamer_worker(device_id: str):
    """缓流器工作线程：为指定摄像头缓冲源流，接收推帧器插入的帧，输出到目标流"""
    logger.info(f"💾 缓流器线程启动 [设备: {device_id}]")

    if not task_config or not hasattr(task_config, 'device_streams'):
        logger.error(f"任务配置未加载，设备 {device_id} 缓流器退出")
        return

    device_stream_info = task_config.device_streams.get(device_id)
    if not device_stream_info:
        logger.error(f"设备 {device_id} 流信息不存在，缓流器退出")
        return

    rtsp_url = device_stream_info.get('rtsp_url')
    rtmp_url = device_stream_info.get('rtmp_url')
    device_name = device_stream_info.get('device_name', device_id)

    # 打印推流地址信息
    logger.info(f"📺 设备 {device_id} 流地址配置:")
    input_stream_type = "RTSP" if rtsp_url and rtsp_url.startswith(
        'rtsp://') else "RTMP" if rtsp_url and rtsp_url.startswith('rtmp://') else "输入流"
    logger.info(f"   {input_stream_type}输入流: {rtsp_url}")
    logger.info(f"   RTMP推流地址: {rtmp_url if rtmp_url else '(未配置)'}")

    if not rtsp_url:
        logger.error(f"设备 {device_id} 输入流地址不存在，缓流器退出")
        return

    # 兼容 RTSP 和 RTMP 两种格式的输入流
    stream_type = "RTSP" if rtsp_url.startswith('rtsp://') else "RTMP" if rtsp_url.startswith('rtmp://') else "未知"
    logger.info(f"📡 设备 {device_id} 输入流类型: {stream_type}")

    cap = None
    pusher_process = None
    frame_width = None
    frame_height = None
    next_output_frame = 1
    retry_count = 0
    max_retries = 5
    pending_frames = set()
    pusher_retry_count = 0  # FFmpeg 推送进程重试计数
    pusher_max_retries = 3  # FFmpeg 推送进程最大重试次数
    last_pusher_failure_time = 0  # 上次推送进程失败的时间

    # 初始化stderr缓冲区
    if device_id not in device_pusher_stderr_buffers:
        device_pusher_stderr_buffers[device_id] = []
        device_pusher_stderr_locks[device_id] = threading.Lock()
    
    # 初始化设备编码器状态（如果不存在，使用全局配置）
    if device_id not in device_codec_status:
        device_codec_status[device_id] = _hwaccel_codec
        device_codec_locks[device_id] = threading.Lock()

    # 流畅度优化：基于时间戳的帧率控制
    frame_interval = 1.0 / SOURCE_FPS
    last_frame_time = time.time()
    last_processed_frame = None
    last_processed_detections = []

    while not stop_event.is_set():
        try:
            # 打开源流（支持 RTSP 和 RTMP）
            if cap is None or not cap.isOpened():
                stream_type = "RTSP" if rtsp_url.startswith('rtsp://') else "RTMP" if rtsp_url.startswith(
                    'rtmp://') else "流"

                # 对于 RTMP 流，先检查服务器是否可用
                if rtsp_url.startswith('rtmp://'):
                    if not check_rtmp_server_connection(rtsp_url):
                        retry_count += 1
                        if retry_count >= max_retries:
                            logger.error(f"❌ 设备 {device_id} RTMP 服务器不可用，已达到最大重试次数 {max_retries}")
                            logger.info("等待30秒后重新尝试...")
                            time.sleep(30)
                            retry_count = 0
                        else:
                            logger.warning(
                                f"设备 {device_id} RTMP 服务器不可用，等待重试... ({retry_count}/{max_retries})")
                            time.sleep(2)
                        continue

                logger.info(f"正在连接设备 {device_id} 的 {stream_type} 流: {rtsp_url} (重试次数: {retry_count})")

                # 强制使用 FFmpeg 后端，避免 OpenCV 尝试其他后端导致错误
                try:
                    # 对于 RTMP/RTSP 流，使用 FFmpeg 后端
                    if rtsp_url.startswith('rtmp://') or rtsp_url.startswith('rtsp://'):
                        cap = cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)
                    else:
                        cap = cv2.VideoCapture(rtsp_url)

                    # 设置缓冲区大小为1，减少延迟
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

                    # 设置超时参数（毫秒）- 对于 RTMP/RTSP 流设置合理的超时
                    # 注意：这些属性可能在某些 OpenCV 版本中不可用，使用 try-except 处理
                    if rtsp_url.startswith('rtmp://') or rtsp_url.startswith('rtsp://'):
                        try:
                            # 设置连接超时为10秒（10000毫秒）
                            cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, 10000)
                        except (AttributeError, cv2.error):
                            # 如果属性不存在，忽略错误
                            pass
                        try:
                            # 设置读取超时为5秒（5000毫秒）
                            cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, 5000)
                        except (AttributeError, cv2.error):
                            # 如果属性不存在，忽略错误
                            pass

                except Exception as e:
                    logger.error(f"设备 {device_id} 创建 VideoCapture 时出错: {str(e)}")
                    # 确保释放资源
                    if cap is not None:
                        try:
                            cap.release()
                        except:
                            pass
                        cap = None
                    retry_count += 1
                    if retry_count >= max_retries:
                        logger.error(f"❌ 设备 {device_id} 连接 {stream_type} 流失败，已达到最大重试次数 {max_retries}")
                        logger.info("等待30秒后重新尝试...")
                        time.sleep(30)
                        retry_count = 0
                    else:
                        logger.warning(
                            f"设备 {device_id} 无法打开 {stream_type} 流，等待重试... ({retry_count}/{max_retries})")
                        time.sleep(2)
                    continue

                if not cap.isOpened():
                    retry_count += 1
                    if retry_count >= max_retries:
                        logger.error(f"❌ 设备 {device_id} 连接 {stream_type} 流失败，已达到最大重试次数 {max_retries}")
                        logger.info("等待30秒后重新尝试...")
                        time.sleep(30)
                        retry_count = 0
                    else:
                        logger.warning(
                            f"设备 {device_id} 无法打开 {stream_type} 流，等待重试... ({retry_count}/{max_retries})")
                        time.sleep(2)
                    # 确保释放资源
                    if cap is not None:
                        try:
                            cap.release()
                        except:
                            pass
                        cap = None
                    continue

                retry_count = 0
                device_caps[device_id] = cap
                logger.info(f"✅ 设备 {device_id} {stream_type} 流连接成功")

            # 从源流读取帧
            ret, frame = cap.read()

            if not ret or frame is None:
                logger.warning(f"设备 {device_id} 读取源流帧失败，重新连接...")
                if cap is not None:
                    cap.release()
                    cap = None
                    device_caps.pop(device_id, None)
                time.sleep(1)
                continue

            # 更新该设备的帧计数
            frame_counts[device_id] += 1
            frame_count = frame_counts[device_id]

            # 立即缩放到目标分辨率
            original_height, original_width = frame.shape[:2]
            if (original_width, original_height) != TARGET_RESOLUTION:
                frame = cv2.resize(frame, TARGET_RESOLUTION, interpolation=cv2.INTER_LINEAR)

            height, width = TARGET_HEIGHT, TARGET_WIDTH

            # 初始化推送进程（为该设备）- 只在需要时启动，避免频繁重启
            if pusher_process is None or pusher_process.poll() is not None:
                # 如果进程已退出，记录原因并添加重试延迟
                if pusher_process and pusher_process.poll() is not None:
                    # 检查是否需要等待重试（避免频繁重启）
                    current_time = time.time()
                    time_since_last_failure = current_time - last_pusher_failure_time
                    min_retry_interval = 2.0  # 最小重试间隔：2秒

                    if time_since_last_failure < min_retry_interval:
                        # 如果距离上次失败时间太短，等待一段时间
                        wait_time = min_retry_interval - time_since_last_failure
                        logger.debug(f"设备 {device_id} 推送进程失败后等待 {wait_time:.1f} 秒后重试...")
                        time.sleep(wait_time)

                    last_pusher_failure_time = time.time()
                    # 停止stderr读取线程
                    stderr_thread = device_pusher_stderr_threads.pop(device_id, None)
                    if stderr_thread and stderr_thread.is_alive():
                        try:
                            # 等待线程结束（最多等待1秒）
                            stderr_thread.join(timeout=1)
                        except:
                            pass

                    # 获取stderr错误信息
                    stderr_lines = []
                    with device_pusher_stderr_locks[device_id]:
                        stderr_lines = device_pusher_stderr_buffers[device_id].copy()
                        device_pusher_stderr_buffers[device_id].clear()

                    exit_code = pusher_process.returncode
                    logger.warning(f"⚠️  设备 {device_id} 推送进程已退出 (退出码: {exit_code})")

                    # 提取关键错误信息（过滤掉版本信息等）
                    error_lines = []
                    hw_encoder_error = False  # 标记是否是硬件编码器错误
                    for line in stderr_lines:
                        line_lower = line.lower()
                        # 跳过版本信息、配置信息等
                        if any(skip in line_lower for skip in
                               ['version', 'copyright', 'built with', 'configuration:', 'libav']):
                            continue
                        # 保留错误、警告、失败等信息
                        if any(keyword in line_lower for keyword in
                               ['error', 'failed', 'warning', 'cannot', 'unable', 'invalid', 'connection refused',
                                'connection reset', 'timeout']):
                            error_lines.append(line)
                            # 检测硬件编码器相关错误
                            if any(hw_err in line_lower for hw_err in ['cannot load libcuda', 'libcuda.so', 'h264_nvenc', 'nvenc', 'cuda']):
                                hw_encoder_error = True

                    if error_lines:
                        logger.warning(f"   关键错误信息:")
                        for err_line in error_lines[-10:]:  # 只显示最后10行关键错误
                            logger.warning(f"   {err_line}")
                    elif stderr_lines:
                        # 如果没有关键错误，显示最后几行
                        logger.warning(f"   最后输出: {stderr_lines[-3:]}")
                    else:
                        logger.warning(f"   未捕获到错误信息，可能是进程启动失败或RTMP服务器连接问题")
                    
                    # 如果是硬件编码器错误，自动切换到软件编码
                    should_retry_with_software = False
                    if hw_encoder_error:
                        # 初始化设备编码器锁（如果不存在）
                        if device_id not in device_codec_locks:
                            device_codec_locks[device_id] = threading.Lock()
                        
                        with device_codec_locks[device_id]:
                            current_codec = device_codec_status.get(device_id, _hwaccel_codec)
                            if current_codec == 'h264_nvenc':
                                logger.warning(f"🔄 设备 {device_id} 硬件编码器失败，自动切换到软件编码 (libx264)")
                                device_codec_status[device_id] = 'libx264'
                                should_retry_with_software = True
                            else:
                                # 已经使用软件编码，不需要切换
                                pass
                    
                    # 如果切换到软件编码，确保进程被重置以便立即重试
                    if should_retry_with_software:
                        # 关闭旧进程（如果还在运行）
                        if pusher_process and pusher_process.poll() is None:
                            try:
                                pusher_process.stdin.close()
                                pusher_process.terminate()
                                pusher_process.wait(timeout=2)
                            except:
                                if pusher_process.poll() is None:
                                    pusher_process.kill()
                        pusher_process = None
                        device_pushers.pop(device_id, None)
                        logger.info(f"🔄 设备 {device_id} 将使用软件编码重新启动推送进程...")

                    # 检查RTMP服务器连接状态（仅在首次失败时检查，避免频繁检查）
                    if pusher_retry_count == 0:
                        if not check_rtmp_server_connection(rtmp_url):
                            logger.warning("")
                            logger.warning("=" * 60)
                            logger.warning("💡 RTMP服务器连接检查失败，可能的原因和解决方案：")
                            logger.warning("=" * 60)
                            logger.warning("1. RTMP服务器（SRS）未运行")
                            logger.warning("   - 检查SRS服务状态: docker ps | grep srs")
                            logger.warning("")
                            logger.warning("2. 启动SRS服务器：")
                            logger.warning(
                                "   - 使用Docker Compose: cd /opt/projects/easyaiot/.scripts/docker && docker-compose up -d srs")
                            logger.warning(
                                "   - 或使用Docker: docker run -d --name srs-server -p 1935:1935 -p 1985:1985 -p 8080:8080 ossrs/srs:5")
                            logger.warning("")
                            logger.warning("3. SRS HTTP回调服务未运行（常见原因）")
                            logger.warning("   - 请确保VIDEO服务在端口48080上运行")
                            logger.warning("=" * 60)
                            logger.warning("")

                # 关闭旧进程
                if pusher_process and pusher_process.poll() is None:
                    try:
                        pusher_process.stdin.close()
                        pusher_process.terminate()
                        pusher_process.wait(timeout=2)
                    except:
                        if pusher_process.poll() is None:
                            pusher_process.kill()

                frame_width = width
                frame_height = height

                if not rtmp_url:
                    logger.warning(f"设备 {device_id} RTMP输出流地址不存在，跳过推送")
                else:
                    # 在启动推流前，检查并停止现有流（避免StreamBusy错误）
                    # 重要：只检查推流地址，不检查输入流地址，避免误停止输入流
                    # 如果输入流地址和推流地址相同，则跳过检查（避免误停止输入流）
                    if rtsp_url and rtsp_url == rtmp_url:
                        logger.warning(f"⚠️  设备 {device_id} 输入流地址和推流地址相同，跳过流检查（避免误停止输入流）")
                    else:
                        logger.info(f"🔍 检查设备 {device_id} 是否存在占用该地址的流...")
                        check_and_stop_existing_stream(rtmp_url)

                    # 构建 ffmpeg 命令（优化版本：低CPU占用、低推流速度）
                    # 优化参数说明：
                    # -preset ultrafast: 最快编码，最低CPU占用（软件编码）
                    # -b:v 500k: 降低视频比特率，减少推流速度
                    # -threads: 限制编码线程数，降低CPU占用（仅软件编码）
                    # -g: GOP 大小（关键帧间隔），增大可减少关键帧频率
                    # -keyint_min: 最小关键帧间隔（仅软件编码）
                    # -f flv: 输出格式为 FLV（RTMP 标准格式）
                    ffmpeg_cmd = [
                        "ffmpeg",
                        "-y",
                        "-fflags", "nobuffer",
                        "-f", "rawvideo",
                        "-vcodec", "rawvideo",
                        "-pix_fmt", "bgr24",
                        "-s", f"{width}x{height}",
                        "-r", str(SOURCE_FPS),
                        "-i", "-",
                    ]
                    
                    # 根据硬件加速配置和设备编码器状态选择编码器
                    # 初始化设备编码器锁（如果不存在）
                    if device_id not in device_codec_locks:
                        device_codec_locks[device_id] = threading.Lock()
                    
                    # 获取设备实际使用的编码器（如果设备有失败记录，使用软件编码；否则使用全局配置）
                    with device_codec_locks[device_id]:
                        device_codec = device_codec_status.get(device_id, _hwaccel_codec)
                    
                    # 根据编码器类型构建FFmpeg命令
                    if device_codec == 'h264_nvenc':
                        # 使用NVIDIA硬件编码器
                        ffmpeg_cmd.extend([
                            "-c:v", "h264_nvenc",
                            "-b:v", FFMPEG_VIDEO_BITRATE,
                            "-pix_fmt", "yuv420p",
                            "-preset", "p4",  # NVENC预设：p1(最快)到p7(最慢)，p4为平衡
                            "-tune", "ll",  # 低延迟调优
                            "-gpu", "0",  # 使用第一个GPU
                            "-g", str(FFMPEG_GOP_SIZE),
                            "-rc", "cbr",  # 恒定比特率模式
                            "-rc-lookahead", "0",  # 禁用lookahead以降低延迟
                            "-surfaces", "1",  # 最小表面数，降低延迟
                            "-delay", "0",  # 无延迟
                            "-f", "flv",
                        ])
                    else:
                        # 使用软件编码器
                        ffmpeg_cmd.extend([
                            "-c:v", "libx264",
                            "-b:v", FFMPEG_VIDEO_BITRATE,  # 使用配置的比特率（默认500k）
                            "-pix_fmt", "yuv420p",
                            "-preset", FFMPEG_PRESET,  # 使用配置的预设（默认ultrafast）
                            "-g", str(FFMPEG_GOP_SIZE),  # GOP 大小：2秒一个关键帧
                            "-keyint_min", str(SOURCE_FPS),  # 最小关键帧间隔：1秒
                            "-f", "flv",
                        ])
                        # 如果配置了线程数限制，添加线程参数（仅软件编码）
                        if FFMPEG_THREADS is not None and str(FFMPEG_THREADS).strip():
                            try:
                                # 验证是否为有效的整数
                                threads_value = int(FFMPEG_THREADS)
                                if threads_value > 0:
                                    ffmpeg_cmd.extend(["-threads", str(threads_value)])
                                else:
                                    logger.warning(f"   ⚠️  FFMPEG_THREADS 值无效 ({FFMPEG_THREADS})，跳过线程数限制")
                            except (ValueError, TypeError):
                                logger.warning(f"   ⚠️  FFMPEG_THREADS 值无效 ({FFMPEG_THREADS})，跳过线程数限制")
                    
                    # 添加输出地址
                    ffmpeg_cmd.append(rtmp_url)
                    
                    codec_info = f"硬件编码 ({device_codec})" if device_codec == 'h264_nvenc' else f"软件编码 ({device_codec})"
                    logger.info(f"🚀 启动设备 {device_id} 推送进程（优化模式：低CPU占用）")
                    logger.info(f"   📺 推流地址: {rtmp_url}")
                    logger.info(f"   📐 尺寸: {width}x{height}, 帧率: {SOURCE_FPS}fps")
                    logger.info(f"   🎬 编码器: {codec_info}, 比特率: {FFMPEG_VIDEO_BITRATE}, GOP: {FFMPEG_GOP_SIZE}")
                    if device_codec != 'h264_nvenc' and FFMPEG_THREADS is not None and str(FFMPEG_THREADS).strip():
                        logger.info(f"   🧵 编码线程数: {FFMPEG_THREADS}")
                    logger.debug(f"   FFmpeg命令: {' '.join(ffmpeg_cmd)}")
                    logger.debug(f"   FFmpeg命令参数列表: {ffmpeg_cmd}")

                    try:
                        pusher_process = subprocess.Popen(
                            ffmpeg_cmd,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            bufsize=0,
                            shell=False  # 明确指定不使用shell，避免容器环境中的参数解析问题
                        )

                        # 启动stderr读取线程
                        stderr_buffer = device_pusher_stderr_buffers[device_id]
                        stderr_lock = device_pusher_stderr_locks[device_id]
                        stderr_thread = threading.Thread(
                            target=read_ffmpeg_stderr,
                            args=(device_id, pusher_process.stderr, stderr_buffer, stderr_lock),
                            daemon=True
                        )
                        stderr_thread.start()
                        device_pusher_stderr_threads[device_id] = stderr_thread

                        # 等待一小段时间，检查进程是否立即退出
                        time.sleep(0.5)

                        if pusher_process.poll() is not None:
                            # 等待stderr线程读取一些输出
                            time.sleep(0.3)

                            # 获取错误信息
                            error_lines = []
                            with device_pusher_stderr_locks[device_id]:
                                error_lines = device_pusher_stderr_buffers[device_id].copy()
                                device_pusher_stderr_buffers[device_id].clear()

                            exit_code = pusher_process.returncode
                            logger.error(f"❌ 设备 {device_id} 推送进程启动失败 (退出码: {exit_code})")
                            logger.error(f"   FFmpeg命令: {' '.join(ffmpeg_cmd)}")
                            logger.error(f"   FFmpeg命令参数列表: {ffmpeg_cmd}")

                            # 提取关键错误信息
                            key_errors = []
                            hw_encoder_error = False  # 标记是否是硬件编码器错误
                            for line in error_lines:
                                line_lower = line.lower()
                                if any(skip in line_lower for skip in
                                       ['version', 'copyright', 'built with', 'configuration:', 'libav']):
                                    continue
                                if any(keyword in line_lower for keyword in
                                       ['error', 'failed', 'cannot', 'unable', 'invalid', 'connection refused',
                                        'connection reset', 'timeout', 'no such file', 'permission denied', 'splitting',
                                        'option not found']):
                                    key_errors.append(line)
                                    # 检测硬件编码器相关错误
                                    if any(hw_err in line_lower for hw_err in ['cannot load libcuda', 'libcuda.so', 'h264_nvenc', 'nvenc', 'cuda']):
                                        hw_encoder_error = True

                            if key_errors:
                                logger.error(f"   关键错误:")
                                for err in key_errors[-10:]:
                                    logger.error(f"   {err}")
                            elif error_lines:
                                logger.error(f"   输出: {error_lines[-5:]}")
                            else:
                                logger.error(f"   未捕获到错误信息，请检查RTMP服务器是否运行: {rtmp_url}")
                            
                            # 如果是硬件编码器错误，自动切换到软件编码并重新启动
                            should_retry_with_software = False
                            if hw_encoder_error:
                                # 初始化设备编码器锁（如果不存在）
                                if device_id not in device_codec_locks:
                                    device_codec_locks[device_id] = threading.Lock()
                                
                                with device_codec_locks[device_id]:
                                    current_codec = device_codec_status.get(device_id, _hwaccel_codec)
                                    if current_codec == 'h264_nvenc':
                                        logger.warning(f"🔄 设备 {device_id} 硬件编码器启动失败，自动切换到软件编码 (libx264)")
                                        device_codec_status[device_id] = 'libx264'
                                        should_retry_with_software = True
                            
                            # 如果切换到软件编码，重置进程以便立即重试
                            if should_retry_with_software:
                                pusher_process = None
                                device_pushers.pop(device_id, None)
                                logger.info(f"🔄 设备 {device_id} 将使用软件编码重新启动推送进程...")
                                continue

                            # 检查RTMP服务器连接状态
                            if not check_rtmp_server_connection(rtmp_url):
                                logger.error("")
                                logger.error("=" * 60)
                                logger.error("💡 RTMP服务器连接检查失败，可能的原因和解决方案：")
                                logger.error("=" * 60)
                                logger.error("1. RTMP服务器（SRS）未运行")
                                logger.error("   - 检查SRS服务状态: docker ps | grep srs")
                                logger.error("   - 或使用: systemctl status srs")
                                logger.error("")
                                logger.error("2. 启动SRS服务器：")
                                logger.error(
                                    "   - 使用Docker Compose: cd /opt/projects/easyaiot/.scripts/docker && docker-compose up -d srs")
                                logger.error(
                                    "   - 或使用Docker: docker run -d --name srs-server -p 1935:1935 -p 1985:1985 -p 8080:8080 ossrs/srs:5")
                                logger.error("")
                                logger.error("3. SRS HTTP回调服务未运行（常见原因）")
                                logger.error("   - SRS配置了on_publish回调，但回调服务未启动")
                                logger.error("   - 请确保VIDEO服务在端口48080上运行")
                                logger.error("   - 检查服务: docker ps | grep video")
                                logger.error("")
                                logger.error("4. 检查RTMP端口是否监听：")
                                logger.error("   - netstat -tuln | grep 1935")
                                logger.error("   - 或: ss -tuln | grep 1935")
                                logger.error("")
                                logger.error("5. 测试RTMP连接：")
                                logger.error("   - telnet localhost 1935")
                                logger.error("   - 或: curl http://localhost:1985/api/v1/versions")
                                logger.error("=" * 60)
                                logger.error("")

                            # 停止stderr线程
                            if stderr_thread.is_alive():
                                stderr_thread.join(timeout=0.5)
                            device_pusher_stderr_threads.pop(device_id, None)

                            pusher_retry_count += 1
                            if pusher_retry_count >= pusher_max_retries:
                                logger.error(
                                    f"❌ 设备 {device_id} 推送进程启动失败次数过多 ({pusher_retry_count}/{pusher_max_retries})，等待10秒后重置重试计数")
                                time.sleep(10)
                                pusher_retry_count = 0

                            pusher_process = None
                        else:
                            # 推送进程启动成功，重置重试计数
                            pusher_retry_count = 0
                            device_pushers[device_id] = pusher_process
                            logger.info(f"✅ 设备 {device_id} 推送进程已启动 (PID: {pusher_process.pid})")
                            logger.info(f"   📺 推流地址: {rtmp_url}")
                            logger.info(f"   📐 输出参数: {width}x{height} @ {SOURCE_FPS}fps")

                            # 额外等待一小段时间，确保 RTMP 连接已建立
                            time.sleep(0.3)
                    except Exception as e:
                        logger.error(f"❌ 设备 {device_id} 启动推送进程异常: {str(e)}", exc_info=True)
                        pusher_process = None
            elif frame_width != width or frame_height != height:
                # 分辨率变化，需要重启推送进程
                logger.info(
                    f"🔄 设备 {device_id} 分辨率变化 ({frame_width}x{frame_height} -> {width}x{height})，重启推送进程")
                if pusher_process and pusher_process.poll() is None:
                    try:
                        pusher_process.stdin.close()
                        pusher_process.terminate()
                        pusher_process.wait(timeout=2)
                    except:
                        if pusher_process.poll() is None:
                            pusher_process.kill()

                # 停止stderr读取线程
                stderr_thread = device_pusher_stderr_threads.pop(device_id, None)
                if stderr_thread and stderr_thread.is_alive():
                    try:
                        stderr_thread.join(timeout=1)
                    except:
                        pass

                pusher_process = None
                device_pushers.pop(device_id, None)

            # 将帧存入该设备的缓冲区
            with buffer_locks[device_id]:
                frame_buffer = frame_buffers[device_id]

                # 清理旧帧（保持缓冲区大小）
                # 注意：只清理已经输出过的帧，并且不清理正在处理中的帧（pending_frames）
                # 参考测试脚本，使用更保守的清理策略
                buffer_threshold = int(BUFFER_SIZE * 0.98)
                if len(frame_buffer) >= buffer_threshold:
                    frames_to_remove = []
                    for frame_num in frame_buffer.keys():
                        # 只清理已经输出过的帧，并且不在pending_frames中（不在处理中）
                        # 更保守：只清理明显超出最小缓冲要求的帧
                        if frame_num < next_output_frame and frame_num not in pending_frames and len(
                                frame_buffer) > MIN_BUFFER_FRAMES * 3:
                            frames_to_remove.append(frame_num)

                    frames_to_remove.sort()
                    # 只清理少量帧，不要过度清理
                    remove_count = min(2, max(1, len(frame_buffer) - buffer_threshold + 1))
                    for frame_num in frames_to_remove[:remove_count]:
                        frame_buffer.pop(frame_num, None)

                # 紧急清理：如果缓冲区仍然过大（>99%），才强制清理最旧的已输出帧（但不在处理中）
                if len(frame_buffer) >= int(BUFFER_SIZE * 0.99):
                    frames_to_remove_urgent = []
                    for frame_num in frame_buffer.keys():
                        # 只清理已经输出过的帧，并且不在pending_frames中（不在处理中）
                        if frame_num < next_output_frame and frame_num not in pending_frames:
                            frames_to_remove_urgent.append(frame_num)

                    if frames_to_remove_urgent:
                        frames_to_remove_urgent.sort()
                        # 只清理最旧的1帧，非常保守
                        oldest_frame = frames_to_remove_urgent[0]
                        frame_buffer.pop(oldest_frame, None)

                frame_buffer[frame_count] = {
                    'frame': frame.copy(),
                    'frame_number': frame_count,
                    'timestamp': time.time(),
                    'processed': False
                }

                # 如果该帧需要抽帧，发送给抽帧器
                if frame_count % EXTRACT_INTERVAL == 0:
                    pending_frames.add(frame_count)
                    frame_sent = False
                    retry_count = 0
                    max_retries = 5
                    while not frame_sent and retry_count < max_retries:
                        try:
                            extract_queues[device_id].put({
                                'frame': frame.copy(),
                                'frame_number': frame_count,
                                'timestamp': frame_buffer[frame_count]['timestamp'],
                                'device_id': device_id
                            }, timeout=0.1)
                            frame_sent = True
                        except queue.Full:
                            retry_count += 1
                            if retry_count < max_retries:
                                time.sleep(0.02)  # 增加等待时间减少CPU占用
                            else:
                                logger.warning(f"⚠️  设备 {device_id} 抽帧队列已满，帧 {frame_count} 等待处理中...")

            # 检查推帧队列，将处理后的帧插入缓冲区
            processed_count = 0
            max_process_per_cycle = 20  # 增加每次处理的帧数，加快处理速度
            while processed_count < max_process_per_cycle:
                try:
                    push_data = push_queues[device_id].get(timeout=0.05)
                    processed_frame = push_data['frame']
                    frame_number = push_data['frame_number']
                    detections = push_data.get('detections', [])

                    with buffer_locks[device_id]:
                        frame_buffer = frame_buffers[device_id]
                        if frame_number in frame_buffer:
                            frame_buffer[frame_number]['frame'] = processed_frame
                            frame_buffer[frame_number]['processed'] = True
                            frame_buffer[frame_number]['detections'] = detections
                            pending_frames.discard(frame_number)
                            if frame_number % 10 == 0:
                                logger.info(
                                    f"✅ 设备 {device_id} 帧 {frame_number} 已更新处理后的帧（{len(detections)}个检测目标）")
                        else:
                            # 如果帧不在缓冲区中，可能是已经被清理了
                            # 检查是否是因为处理太慢导致的（帧号小于当前输出帧号）
                            if frame_number < next_output_frame:
                                # 帧已经被输出过了，这是正常的清理（不记录警告）
                                if frame_number % 50 == 0:
                                    logger.debug(f"设备 {device_id} 帧 {frame_number} 不在缓冲区中（已输出，正常清理）")
                            else:
                                # 帧号大于等于当前输出帧号，但不在缓冲区中，可能是被过早清理了
                                # 这种情况不应该发生，记录警告
                                logger.warning(
                                    f"⚠️  设备 {device_id} 帧 {frame_number} 不在缓冲区中，可能已被清理（当前输出帧: {next_output_frame}）")
                            # 即使帧不在缓冲区中，也要从pending_frames中移除，避免内存泄漏
                            pending_frames.discard(frame_number)
                    processed_count += 1
                except queue.Empty:
                    break

            # 输出帧（按顺序输出，支持追踪缓存框绘制）
            output_count = 0
            max_output_per_cycle = 2  # 每次最多输出2帧

            while output_count < max_output_per_cycle:
                with buffer_locks[device_id]:
                    frame_buffer = frame_buffers[device_id]

                    if next_output_frame not in frame_buffer:
                        break

                    frame_data = frame_buffer[next_output_frame]
                    output_frame = frame_data['frame']
                    is_processed = frame_data.get('processed', False)
                    current_timestamp = frame_data.get('timestamp', time.time())
                    is_extracted = (next_output_frame % EXTRACT_INTERVAL == 0)

                # 如果该帧需要抽帧但还未处理完成，等待处理完成（在锁外等待）
                if is_extracted and next_output_frame in pending_frames:
                    # 等待处理完成，优化CPU占用
                    wait_start = time.time()
                    check_interval = 0.02  # 每20ms检查一次，进一步减少CPU轮询频率

                    while next_output_frame in pending_frames and (time.time() - wait_start) < MAX_WAIT_TIME:
                        time.sleep(check_interval)
                        # 持续检查推帧队列，处理所有到达的帧（关键：确保不遗漏）
                        processed_in_wait = 0
                        while processed_in_wait < 20:  # 增加处理数量
                            try:
                                push_data = push_queues[device_id].get(timeout=0.05)
                                processed_frame = push_data['frame']
                                fn = push_data['frame_number']
                                detections = push_data.get('detections', [])
                                with buffer_locks[device_id]:
                                    frame_buffer = frame_buffers[device_id]
                                    if fn in frame_buffer:
                                        frame_buffer[fn]['frame'] = processed_frame
                                        frame_buffer[fn]['processed'] = True
                                        frame_buffer[fn]['detections'] = detections
                                        pending_frames.discard(fn)

                                        # 如果目标帧已处理完成，立即退出
                                        if fn == next_output_frame:
                                            # 更新帧数据
                                            frame_data = frame_buffer[next_output_frame]
                                            output_frame = frame_data['frame']
                                            is_processed = True
                                            break
                                processed_in_wait += 1
                            except queue.Empty:
                                break

                        # 如果目标帧已处理完成，退出等待循环
                        if next_output_frame not in pending_frames:
                            # 重新获取帧数据（可能已更新）
                            with buffer_locks[device_id]:
                                if next_output_frame in frame_buffers[device_id]:
                                    frame_data = frame_buffers[device_id][next_output_frame]
                                    output_frame = frame_data['frame']
                                    is_processed = frame_data.get('processed', False)
                            break

                    # 如果超时仍未处理完成，再等待一小段时间，尽量等待处理完成
                    if next_output_frame in pending_frames:
                        # 再给一次机会，等待额外的时间（优化CPU占用）
                        extra_wait_start = time.time()
                        extra_wait_time = 0.05
                        while next_output_frame in pending_frames and (
                                time.time() - extra_wait_start) < extra_wait_time:
                            time.sleep(0.02)  # 增加sleep时间，减少轮询频率
                            # 再次检查推帧队列
                            try:
                                push_data = push_queues[device_id].get(timeout=0.05)
                                processed_frame = push_data['frame']
                                fn = push_data['frame_number']
                                detections = push_data.get('detections', [])
                                with buffer_locks[device_id]:
                                    frame_buffer = frame_buffers[device_id]
                                    if fn in frame_buffer:
                                        frame_buffer[fn]['frame'] = processed_frame
                                        frame_buffer[fn]['processed'] = True
                                        frame_buffer[fn]['detections'] = detections
                                        pending_frames.discard(fn)
                                        if fn == next_output_frame:
                                            frame_data = frame_buffer[next_output_frame]
                                            output_frame = frame_data['frame']
                                            is_processed = True
                                            break
                            except queue.Empty:
                                pass

                # 在输出前，最后检查一次推帧队列，确保不遗漏已处理的帧
                last_check_count = 0
                while last_check_count < 5:  # 快速检查几次
                    try:
                        push_data = push_queues[device_id].get(timeout=0.05)
                        processed_frame = push_data['frame']
                        fn = push_data['frame_number']
                        detections = push_data.get('detections', [])
                        with buffer_locks[device_id]:
                            frame_buffer = frame_buffers[device_id]
                            if fn in frame_buffer:
                                frame_buffer[fn]['frame'] = processed_frame
                                frame_buffer[fn]['processed'] = True
                                frame_buffer[fn]['detections'] = detections
                                pending_frames.discard(fn)
                                # 如果正好是目标帧，更新输出帧
                                if fn == next_output_frame:
                                    frame_data = frame_buffer[next_output_frame]
                                    output_frame = frame_data['frame']
                                    is_processed = True
                        last_check_count += 1
                    except queue.Empty:
                        break

                # 重新获取帧数据（可能已更新）
                with buffer_locks[device_id]:
                    if next_output_frame in frame_buffers[device_id]:
                        frame_data = frame_buffers[device_id][next_output_frame]
                        output_frame = frame_data['frame']
                        is_processed = frame_data.get('processed', False)
                        current_timestamp = frame_data.get('timestamp', time.time())

                # 如果帧未处理完成，尝试使用追踪器缓存框或最近一次检测结果
                if not is_processed:
                    # 优先使用追踪器缓存框（如果启用追踪）
                    if task_config and task_config.tracking_enabled:
                        tracker = trackers.get(device_id)
                        if tracker:
                            cached_tracks = tracker.get_all_tracks(current_time=current_timestamp,
                                                                   frame_number=next_output_frame)
                            if cached_tracks:
                                # 使用追踪器的缓存框绘制原始帧
                                output_frame = draw_detections(
                                    output_frame.copy(),
                                    cached_tracks,
                                    frame_number=next_output_frame,
                                    tracking_enabled=task_config.tracking_enabled
                                )
                                is_processed = True
                                if next_output_frame % 50 == 0:
                                    logger.info(
                                        f"✅ 设备 {device_id} 帧 {next_output_frame} 使用追踪器缓存框绘制（{len(cached_tracks)}个目标）")

                    # 如果追踪器没有缓存框，使用最近一次检测结果进行插值绘制
                    if not is_processed and last_processed_detections:
                        # 将最近一次检测结果转换为追踪检测格式
                        interpolated_detections = []
                        for det in last_processed_detections:
                            bbox = det.get('bbox', [])
                            # 确保bbox有效（非空且包含4个元素）
                            if bbox and len(bbox) == 4:
                                interpolated_detections.append({
                                    'bbox': bbox,
                                    'class_name': det.get('class_name', 'unknown'),
                                    'confidence': det.get('confidence', 0.0),
                                    'track_id': det.get('track_id', 0),
                                    'is_cached': True,  # 标记为插值框
                                    'first_seen_time': det.get('first_seen_time', current_timestamp),
                                    'duration': det.get('duration', 0.0)
                                })

                        if interpolated_detections:
                            # 使用最近一次检测结果绘制原始帧
                            output_frame = draw_detections(
                                output_frame.copy(),
                                interpolated_detections,
                                frame_number=next_output_frame,
                                tracking_enabled=task_config.tracking_enabled if task_config else False
                            )
                            is_processed = True
                            if next_output_frame % 50 == 0:
                                logger.info(
                                    f"✅ 设备 {device_id} 帧 {next_output_frame} 使用插值检测框绘制（{len(interpolated_detections)}个目标）")
                else:
                    # 帧已处理，记录检测目标数量（用于调试）
                    detections = frame_data.get('detections', [])
                    if next_output_frame % 50 == 0 and detections:
                        logger.info(
                            f"✅ 设备 {device_id} 帧 {next_output_frame} 使用已处理的帧（{len(detections)}个检测目标）")

                # 如果帧已处理，检查是否有新的检测结果需要发送告警
                if is_processed:
                    detections = frame_data.get('detections', [])
                    should_send_alert = False  # 初始化为False
                    if detections and task_config and task_config.alert_event_enabled:
                        # 告警抑制：使用锁保护时间戳的访问和更新，确保线程安全
                        current_time = time.time()
                        with alert_time_lock:
                            last_time = last_alert_time.get(device_id, 0)
                            time_since_last_alert = current_time - last_time

                            # 如果距离上次推送已经超过5秒，才发送告警
                            if time_since_last_alert >= alert_suppression_interval:
                                # 立即更新上次告警时间（在发送告警之前），防止同一秒内多次推送
                                last_alert_time[device_id] = current_time
                                should_send_alert = True
                                logger.info(
                                    f"🔔 设备 {device_id} 准备发送告警：检测到 {len(detections)} 个目标，距离上次告警 {time_since_last_alert:.2f} 秒")
                            else:
                                # 不到5秒，跳过告警推送
                                should_send_alert = False
                                logger.info(
                                    f"⏸️  设备 {device_id} 告警抑制：距离上次推送仅 {time_since_last_alert:.2f} 秒，跳过告警推送（需要间隔5秒），检测到 {len(detections)} 个目标")
                    elif detections and (not task_config or not task_config.alert_event_enabled):
                        # 有检测结果但告警未启用
                        if next_output_frame % 100 == 0:  # 每100帧记录一次，避免日志过多
                            logger.debug(
                                f"设备 {device_id} 检测到 {len(detections)} 个目标，但告警事件未启用（alert_event_enabled={task_config.alert_event_enabled if task_config else None}）")

                    # 在锁外发送告警，避免长时间持有锁
                    if should_send_alert:
                        # 只发送一次告警，包含所有检测到的目标信息
                        try:
                            # 统计检测到的目标类型和数量
                            object_counts = {}
                            all_detections_info = []
                            for det in detections:
                                class_name = det.get('class_name', 'unknown')
                                object_counts[class_name] = object_counts.get(class_name, 0) + 1
                                all_detections_info.append({
                                    'track_id': det.get('track_id', 0),
                                    'class_name': class_name,
                                    'confidence': det.get('confidence', 0),
                                    'bbox': det.get('bbox', []),
                                    'first_seen_time': datetime.fromtimestamp(
                                        det.get('first_seen_time', current_timestamp), tz=BEIJING_TZ).isoformat() if det.get(
                                        'first_seen_time') else None,
                                    'duration': det.get('duration', 0)
                                })
                            
                            # 选择数量最多的目标类型作为主要对象（如果有多个类型，选择第一个）
                            primary_object = max(object_counts.items(), key=lambda x: x[1])[0] if object_counts else 'unknown'
                            
                            # 保存告警图片到本地（使用第一个检测结果作为代表）
                            image_path = save_alert_image(
                                output_frame,
                                device_id,
                                next_output_frame,
                                detections[0] if detections else {}
                            )

                            # 构建告警数据（参照告警表字段）
                            # 获取算法名称（任务名称）
                            algorithm_name = task_config.task_name if task_config and hasattr(task_config,
                                                                                                  'task_name') else 'detection'

                            alert_data = {
                                'object': primary_object,  # 主要对象类型
                                'event': algorithm_name,  # 使用算法名称作为事件类型
                                'device_id': device_id,
                                'device_name': device_name,
                                'time': datetime.fromtimestamp(current_timestamp, tz=BEIJING_TZ).strftime('%Y-%m-%d %H:%M:%S'),
                                'information': json.dumps({
                                    'total_count': len(detections),  # 总目标数量
                                    'object_counts': object_counts,  # 各类型目标数量统计
                                    'detections': all_detections_info,  # 所有检测目标的详细信息
                                    'frame_number': next_output_frame,
                                }),
                                # 不直接传输图片，而是传输图片所在磁盘路径
                                'image_path': image_path if image_path else None,
                            }

                            # 异步发送告警事件（只发送一次）
                            send_alert_event_async(alert_data)
                            logger.info(f"📨 已发送告警事件：检测到 {len(detections)} 个目标（{object_counts}）")
                        except Exception as e:
                            logger.error(f"发送告警失败: {str(e)}", exc_info=True)

                # 推送到RTMP流
                if pusher_process and pusher_process.poll() is None and rtmp_url:
                    try:
                        pusher_process.stdin.write(output_frame.tobytes())
                        pusher_process.stdin.flush()
                    except Exception as e:
                        logger.error(f"❌ 设备 {device_id} 推送帧失败: {str(e)}")
                        if pusher_process.poll() is not None:
                            pusher_process = None
                            device_pushers.pop(device_id, None)

                # 清理已输出的帧
                with buffer_locks[device_id]:
                    frame_buffer = frame_buffers[device_id]
                    frame_buffer.pop(next_output_frame, None)
                    next_output_frame += 1

                # 更新插值用的上一帧结果
                if is_processed:
                    last_processed_frame = output_frame.copy()
                    last_processed_detections = frame_data.get('detections', [])

                output_count += 1

            # 如果还有未输出的帧，使用插值帧
            if output_count == 0 and last_processed_frame is not None and pusher_process and pusher_process.poll() is None and rtmp_url:
                try:
                    pusher_process.stdin.write(last_processed_frame.tobytes())
                    pusher_process.stdin.flush()
                except Exception as e:
                    logger.error(f"❌ 设备 {device_id} 推送插值帧失败: {str(e)}")

            # 流畅度优化：基于时间戳的帧率控制
            current_time = time.time()
            elapsed = current_time - last_frame_time
            if elapsed < frame_interval:
                time.sleep(frame_interval - elapsed)
            last_frame_time = time.time()

            # 优化CPU占用：在处理完所有队列后，如果没有更多工作，短暂休眠
            # 检查是否有待处理的帧或队列中有数据
            has_pending_work = False
            with buffer_locks[device_id]:
                if len(frame_buffers[device_id]) > 0 or len(pending_frames) > 0:
                    has_pending_work = True

            # 如果队列为空且没有待处理帧，短暂休眠以减少CPU占用
            try:
                if not has_pending_work and push_queues[device_id].empty():
                    time.sleep(0.005)  # 5ms，减少空轮询
            except:
                pass

        except Exception as e:
            logger.error(f"❌ 设备 {device_id} 缓流器异常: {str(e)}", exc_info=True)
            time.sleep(2)

    # 清理资源
    if cap is not None:
        cap.release()
        device_caps.pop(device_id, None)
    if pusher_process and pusher_process.poll() is None:
        try:
            pusher_process.stdin.close()
            pusher_process.terminate()
            pusher_process.wait(timeout=2)
        except:
            if pusher_process.poll() is None:
                pusher_process.kill()
        device_pushers.pop(device_id, None)

    # 停止stderr读取线程
    stderr_thread = device_pusher_stderr_threads.pop(device_id, None)
    if stderr_thread and stderr_thread.is_alive():
        try:
            stderr_thread.join(timeout=1)
        except:
            pass

    # 清理stderr缓冲区
    device_pusher_stderr_buffers.pop(device_id, None)
    device_pusher_stderr_locks.pop(device_id, None)

    logger.info(f"💾 设备 {device_id} 缓流器线程停止")


def extractor_worker():
    """抽帧器工作线程：从多个摄像头的缓流器获取帧，抽帧并标记位置"""
    logger.info("📹 抽帧器线程启动（多摄像头并行）")

    idle_count = 0
    max_idle_count = 10

    while not stop_event.is_set():
        try:
            # 尝试从每个设备的队列中获取帧（带超时）
            device_queue_items = list(extract_queues.items())
            frame_data = None
            device_id = None
            extract_queue = None

            for device_id, extract_queue in device_queue_items:
                try:
                    frame_data = extract_queue.get(timeout=0.1)
                    break  # 成功获取到一个帧，跳出循环
                except queue.Empty:
                    continue
                except Exception as e:
                    logger.error(f"❌ 设备 {device_id} 队列获取异常: {str(e)}")
                    continue

            if frame_data is not None:
                # 处理帧
                frame = frame_data['frame']
                frame_number = frame_data['frame_number']
                timestamp = frame_data['timestamp']
                device_id_from_data = frame_data.get('device_id', device_id)
                frame_id = f"{device_id_from_data}_frame_{frame_number}_{int(timestamp)}"

                # 将帧发送给YOLO检测（带设备ID和位置信息）
                detection_queue = detection_queues.get(device_id_from_data)
                if detection_queue:
                    try:
                        detection_queue.put({
                            'frame_id': frame_id,
                            'frame': frame.copy(),
                            'frame_number': frame_number,
                            'timestamp': timestamp,
                            'device_id': device_id_from_data
                        }, timeout=0.2)
                        if frame_number % 10 == 0:
                            logger.info(f"✅ 抽帧器 [{device_id_from_data}]: {frame_id} (帧号: {frame_number})")
                    except queue.Full:
                        logger.warning(
                            f"⚠️  设备 {device_id_from_data} 检测队列已满，丢弃帧 {frame_id}（队列大小: {DETECTION_QUEUE_SIZE}）")
                        # 尝试丢弃一个旧帧以腾出空间
                        try:
                            detection_queue.get_nowait()
                            logger.debug(f"🔄 设备 {device_id_from_data} 检测队列满，丢弃最旧帧以腾出空间")
                        except queue.Empty:
                            pass

                idle_count = 0  # 重置空闲计数器
            else:
                # 没有找到工作，增加空闲计数并采用指数退避休眠
                idle_count += 1
                sleep_time = min(0.05 * (2 ** idle_count), 1.0)  # 指数退避，最大1秒
                time.sleep(sleep_time)

        except Exception as e:
            logger.error(f"❌ 抽帧器异常: {str(e)}", exc_info=True)
            time.sleep(1)

    logger.info("📹 抽帧器线程停止")


def draw_detections(frame, tracked_detections, frame_number=None, tracking_enabled=False):
    """在帧上绘制检测结果

    Args:
        frame: 输入帧
        tracked_detections: 检测结果列表
        frame_number: 帧号
        tracking_enabled: 是否启用追踪
            - False: 画框 + 显示类别名（text）
            - True: 画框 + 显示类别名 + ID（text），不画卡片
    """
    import cv2
    from datetime import datetime

    if not tracked_detections:
        return frame

    annotated_frame = frame.copy()

    for tracked_det in tracked_detections:
        bbox = tracked_det.get('bbox', [])
        if not bbox or len(bbox) != 4:
            continue

        x1, y1, x2, y2 = bbox
        # 确保坐标在有效范围内
        h, w = annotated_frame.shape[:2]
        x1 = max(0, min(x1, w - 1))
        y1 = max(0, min(y1, h - 1))
        x2 = max(x1 + 1, min(x2, w))
        y2 = max(y1 + 1, min(y2, h))

        class_name = tracked_det.get('class_name', 'unknown')
        confidence = tracked_det.get('confidence', 0.0)
        track_id = tracked_det.get('track_id', 0)
        is_cached = tracked_det.get('is_cached', False)
        first_seen_time = tracked_det.get('first_seen_time', time.time())
        duration = tracked_det.get('duration', 0.0)

        # 根据是否为缓存框选择颜色和样式
        if is_cached:
            color = (0, 200, 0)  # 稍暗的亮绿色
            thickness = 2
            alpha = 0.7
        else:
            color = (0, 255, 0)  # 亮绿色 (BGR格式)
            thickness = 2
            alpha = 1.0

        # 画框
        if is_cached:
            overlay = annotated_frame.copy()
            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, thickness)
            cv2.addWeighted(overlay, alpha, annotated_frame, 1 - alpha, 0, annotated_frame)
        else:
            cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), color, thickness)

        # 绘制文字标签（根据是否启用追踪显示不同内容）
        font_scale = 0.8  # 增大字体
        font_thickness = 2  # 加粗字体

        # 根据是否启用追踪决定显示内容
        if tracking_enabled:
            # 启用追踪：显示类别名 + ID
            text = f"ID:{track_id} {class_name}"
        else:
            # 未启用追踪：只显示类别名
            text = class_name

        # 计算文字大小
        (text_width, text_height), baseline = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, font_scale,
                                                              font_thickness)

        # 在框的上方显示文字（不画背景卡片）
        text_x = x1
        text_y = max(text_height + 5, y1 - 5)

        # 只绘制文字，不绘制背景卡片
        cv2.putText(annotated_frame, text, (text_x, text_y),
                    cv2.FONT_HERSHEY_SIMPLEX, font_scale, color, font_thickness)

    return annotated_frame


def yolo_detection_worker(worker_id: int):
    """YOLO检测工作线程：使用YOLO模型进行识别和画框（多摄像头并行）"""
    logger.info(f"🤖 YOLO检测线程 {worker_id} 启动（多摄像头并行）")

    consecutive_errors = 0
    max_consecutive_errors = 10
    idle_count = 0

    while not stop_event.is_set():
        try:
            # 尝试从每个设备的队列中获取检测数据（带超时）
            device_queue_items = list(detection_queues.items())
            detection_data = None
            device_id = None
            detection_queue = None

            for device_id, detection_queue in device_queue_items:
                try:
                    detection_data = detection_queue.get(timeout=0.1)
                    break  # 成功获取到一个帧，跳出循环
                except queue.Empty:
                    continue
                except Exception as e:
                    logger.error(f"❌ 设备 {device_id} 队列获取异常: {str(e)}")
                    continue

            if detection_data is not None:
                # 处理检测数据
                frame = detection_data['frame']
                frame_number = detection_data['frame_number']
                timestamp = detection_data['timestamp']
                device_id_from_data = detection_data.get('device_id', device_id)
                frame_id = detection_data.get('frame_id', f"{device_id_from_data}_frame_{frame_number}")

                consecutive_errors = 0  # 重置错误计数
                idle_count = 0  # 重置空闲计数器

                # 减少日志输出
                if frame_number % 10 == 0:
                    logger.info(f"🔍 [Worker {worker_id}] 开始检测: {frame_id}")

                # 使用所有YOLO模型进行检测（合并结果，优化参数以降低CPU占用）
                all_detections = []
                try:
                    for model_id, yolo_model in yolo_models.items():
                        try:
                            # 优化检测参数以降低CPU占用：
                            # - imgsz: 降低检测分辨率（默认416，原640）
                            # - conf: 保持默认置信度阈值
                            # - iou: 保持默认IOU阈值
                            # - device: 使用CPU（如果支持GPU可改为'cuda'）
                            results = yolo_model(
                                frame,
                                conf=0.25,
                                iou=0.45,
                                imgsz=YOLO_IMG_SIZE,  # 使用配置的检测分辨率（默认416，原640）
                                verbose=False,
                                half=False,
                                device=get_device()
                            )
                            result = results[0]

                            if result.boxes is not None and len(result.boxes) > 0:
                                boxes = result.boxes.xyxy.cpu().numpy()
                                confidences = result.boxes.conf.cpu().numpy()
                                class_ids = result.boxes.cls.cpu().numpy().astype(int)

                                for box, conf, cls_id in zip(boxes, confidences, class_ids):
                                    x1, y1, x2, y2 = map(int, box)
                                    class_name = yolo_model.names[cls_id]
                                    all_detections.append({
                                        'class_id': int(cls_id),
                                        'class_name': class_name,
                                        'confidence': float(conf),
                                        'bbox': [int(x1), int(y1), int(x2), int(y2)]
                                    })
                        except Exception as e:
                            logger.error(f"❌ 模型 {model_id} 检测异常: {str(e)}", exc_info=True)
                            continue
                except Exception as e:
                    consecutive_errors += 1
                    logger.error(f"❌ YOLO检测异常: {str(e)} (连续错误: {consecutive_errors})", exc_info=True)
                    if consecutive_errors >= max_consecutive_errors:
                        logger.error(f"❌ 连续错误过多，等待10秒后继续...")
                        time.sleep(10)
                        consecutive_errors = 0
                    continue

                # 如果启用追踪，进行目标追踪
                tracked_detections = []
                if task_config and task_config.tracking_enabled:
                    tracker = trackers.get(device_id_from_data)
                    if tracker:
                        tracked_detections = tracker.update(all_detections, frame_number, current_time=timestamp)
                    else:
                        tracked_detections = [
                            dict(det, track_id=0, is_cached=False, first_seen_time=timestamp, duration=0.0) for det in
                            all_detections]
                else:
                    tracked_detections = [
                        dict(det, track_id=0, is_cached=False, first_seen_time=timestamp, duration=0.0) for det in
                        all_detections]

                # 在帧上绘制检测结果
                if tracked_detections:
                    processed_frame = draw_detections(
                        frame,
                        tracked_detections,
                        frame_number,
                        tracking_enabled=task_config.tracking_enabled if task_config else False
                    )
                    if frame_number % 10 == 0:
                        logger.info(
                            f"🎨 [Worker {worker_id}] 帧 {frame_number} 绘制了 {len(tracked_detections)} 个检测框")
                else:
                    processed_frame = frame.copy()

                # 构建检测结果列表（用于后续处理）
                detections = []
                for tracked_det in tracked_detections:
                    detections.append({
                        'track_id': tracked_det.get('track_id', 0),
                        'class_id': tracked_det.get('class_id', 0),
                        'class_name': tracked_det.get('class_name', 'unknown'),
                        'confidence': tracked_det.get('confidence', 0.0),
                        'bbox': tracked_det.get('bbox', []),
                        'timestamp': timestamp,
                        'frame_id': frame_id,
                        'frame_number': frame_number,
                        'is_cached': tracked_det.get('is_cached', False),
                        'first_seen_time': tracked_det.get('first_seen_time', timestamp),
                        'duration': tracked_det.get('duration', 0.0)
                    })

                # 将处理后的帧发送到推帧队列（带超时）
                push_queue = push_queues.get(device_id_from_data)
                if push_queue:
                    try:
                        push_queue.put({
                            'frame': processed_frame,
                            'frame_number': frame_number,
                            'detections': detections,
                            'device_id': device_id_from_data,
                            'timestamp': timestamp
                        }, timeout=0.2)
                        if frame_number % 10 == 0:
                            logger.info(
                                f"✅ [Worker {worker_id}] 检测完成: {frame_id} (帧号: {frame_number}), 检测到 {len(detections)} 个目标")
                    except queue.Full:
                        logger.warning(
                            f"⚠️  设备 {device_id_from_data} 推帧队列已满，丢弃帧 {frame_id}（队列大小: {PUSH_QUEUE_SIZE}）")
                        # 尝试丢弃一个旧帧以腾出空间
                        try:
                            push_queue.get_nowait()
                            logger.debug(f"🔄 设备 {device_id_from_data} 推帧队列满，丢弃最旧帧以腾出空间")
                        except queue.Empty:
                            pass
            else:
                # 没有找到工作，增加空闲计数并采用指数退避休眠
                idle_count += 1
                sleep_time = min(0.05 * (2 ** idle_count), 1.0)  # 指数退避，最大1秒
                time.sleep(sleep_time)

        except Exception as e:
            consecutive_errors += 1
            logger.error(f"❌ YOLO检测异常: {str(e)} (连续错误: {consecutive_errors})", exc_info=True)
            if consecutive_errors >= max_consecutive_errors:
                logger.error(f"❌ 连续错误过多，等待10秒后继续...")
                time.sleep(10)
                consecutive_errors = 0
            else:
                time.sleep(1)

    logger.info(f"🤖 YOLO检测线程 {worker_id} 停止")


def cleanup_all_resources():
    """清理所有资源（FFmpeg进程、VideoCapture等）"""
    logger.info("🧹 开始清理所有资源...")

    # 清理所有FFmpeg推送进程
    for device_id, pusher_process in list(device_pushers.items()):
        if pusher_process and pusher_process.poll() is None:
            try:
                logger.info(f"🛑 停止设备 {device_id} 的FFmpeg推送进程 (PID: {pusher_process.pid})")
                pusher_process.stdin.close()
                pusher_process.terminate()
                try:
                    pusher_process.wait(timeout=3)
                    logger.info(f"✅ 设备 {device_id} 的FFmpeg推送进程已停止")
                except subprocess.TimeoutExpired:
                    logger.warning(f"⚠️ 设备 {device_id} 的FFmpeg推送进程未在3秒内退出，强制终止")
                    pusher_process.kill()
                    pusher_process.wait(timeout=1)
            except Exception as e:
                logger.error(f"❌ 停止设备 {device_id} 的FFmpeg推送进程失败: {str(e)}")
                try:
                    if pusher_process.poll() is None:
                        pusher_process.kill()
                except:
                    pass
        device_pushers.pop(device_id, None)

    # 清理所有VideoCapture对象
    for device_id, cap in list(device_caps.items()):
        if cap is not None:
            try:
                logger.info(f"🛑 释放设备 {device_id} 的VideoCapture")
                cap.release()
            except Exception as e:
                logger.error(f"❌ 释放设备 {device_id} 的VideoCapture失败: {str(e)}")
        device_caps.pop(device_id, None)

    # 清理stderr读取线程
    for device_id, stderr_thread in list(device_pusher_stderr_threads.items()):
        if stderr_thread and stderr_thread.is_alive():
            try:
                stderr_thread.join(timeout=1)
            except:
                pass
        device_pusher_stderr_threads.pop(device_id, None)

    # 清理YOLO线程池
    global yolo_executor
    if yolo_executor:
        logger.info("🛑 停止YOLO线程池...")
        yolo_executor.shutdown(wait=False)
        yolo_executor = None

    # 清理其他资源
    device_pusher_stderr_buffers.clear()
    device_pusher_stderr_locks.clear()

    logger.info("✅ 所有资源已清理")


def signal_handler(sig, frame):
    """信号处理器"""
    logger.info("\n🛑 收到停止信号，正在关闭所有服务...")
    stop_event.set()

    # 清理所有资源（FFmpeg进程、VideoCapture等）
    cleanup_all_resources()

    # 等待所有线程结束（增加等待时间）
    logger.info("⏳ 等待所有线程结束...")
    time.sleep(3)

    logger.info("✅ 所有服务已停止")
    sys.exit(0)


def main():
    """主函数"""
    logger.info("=" * 60)
    logger.info("🚀 统一的实时算法任务服务启动（优化模式：低CPU占用）")
    logger.info("=" * 60)
    logger.info("📊 优化配置参数:")
    logger.info(f"   视频分辨率: {TARGET_WIDTH}x{TARGET_HEIGHT} (原1280x720)")
    logger.info(f"   视频帧率: {SOURCE_FPS}fps (原25fps)")
    logger.info(f"   FFmpeg编码预设: {FFMPEG_PRESET}")
    logger.info(f"   视频比特率: {FFMPEG_VIDEO_BITRATE} (原1500k)")
    logger.info(f"   GOP大小: {FFMPEG_GOP_SIZE} (2秒一个关键帧)")
    logger.info(f"   编码线程数: {FFMPEG_THREADS if FFMPEG_THREADS else '自动'}")
    logger.info(f"   YOLO检测分辨率: {YOLO_IMG_SIZE} (原640)")
    logger.info(f"   检测队列大小: {DETECTION_QUEUE_SIZE} (原50)")
    logger.info(f"   推帧队列大小: {PUSH_QUEUE_SIZE} (原50)")
    logger.info(f"   YOLO检测线程数: {YOLO_WORKER_THREADS} (原1)")
    logger.info("=" * 60)

    # 加载任务配置
    if not load_task_config():
        logger.error("❌ 任务配置加载失败")
        sys.exit(1)

    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 为每个摄像头启动独立的缓流器线程
    buffer_threads = []
    if hasattr(task_config, 'device_streams'):
        for device_id in task_config.device_streams.keys():
            logger.info(f"💾 启动设备 {device_id} 的缓流器线程...")
            buffer_thread = threading.Thread(target=buffer_streamer_worker, args=(device_id,), daemon=True)
            buffer_thread.start()
            buffer_threads.append(buffer_thread)

    # 启动共享的抽帧器线程（处理所有摄像头）
    logger.info("📹 启动抽帧器线程（多摄像头并行）...")
    extractor_thread = threading.Thread(target=extractor_worker, daemon=True)
    extractor_thread.start()

    # 启动YOLO检测线程（处理所有摄像头，支持多线程）
    logger.info(f"🤖 启动 {YOLO_WORKER_THREADS} 个YOLO检测线程（多摄像头并行）...")
    global yolo_executor
    yolo_executor = concurrent.futures.ThreadPoolExecutor(max_workers=YOLO_WORKER_THREADS,
                                                          thread_name_prefix='yolo_worker')
    yolo_futures = []
    for worker_id in range(1, YOLO_WORKER_THREADS + 1):
        future = yolo_executor.submit(yolo_detection_worker, worker_id)
        yolo_futures.append(future)
        logger.info(f"   ✅ YOLO检测线程 {worker_id} 已启动")

    # 启动心跳上报线程
    logger.info("💓 启动心跳上报线程...")
    heartbeat_thread = threading.Thread(target=heartbeat_worker, daemon=True)
    heartbeat_thread.start()

    # 启动SRS录像清理线程
    logger.info("🧹 启动SRS录像清理线程...")
    srs_cleanup_thread = threading.Thread(target=srs_recording_cleanup_worker, daemon=True)
    srs_cleanup_thread.start()

    # 启动追踪目标保存线程（如果启用追踪）
    if task_config and task_config.tracking_enabled:
        logger.info("💾 启动追踪目标保存线程...")
        tracking_save_thread = threading.Thread(target=save_tracking_targets_periodically, daemon=True)
        tracking_save_thread.start()

    logger.info("=" * 60)
    logger.info("✅ 所有服务已启动")
    logger.info("=" * 60)
    logger.info("按 Ctrl+C 停止所有服务")
    logger.info("=" * 60)

    # 主循环
    try:
        while not stop_event.is_set():
            time.sleep(1)
    except KeyboardInterrupt:
        signal_handler(None, None)
    except Exception as e:
        logger.error(f"❌ 主循环异常: {str(e)}", exc_info=True)
        signal_handler(None, None)


if __name__ == "__main__":
    main()


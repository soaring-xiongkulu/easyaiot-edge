#!/usr/bin/env python3
"""
测试脚本：验证缓流器、抽帧器、推帧器的逻辑
架构设计：
1. 缓流器：缓冲源流，接收推帧器插入的处理后的帧
2. 抽帧器：从缓流器抽帧并标记位置，发送给YOLO检测
3. 推帧器：将YOLO检测后的帧推送给缓流器插入

流畅度优化算法：
1. 精确帧率控制：使用基于时间戳的帧率控制，替代简单的sleep，确保帧输出时间精确
2. 减少等待时间：将最大等待处理时间从1秒减少到0.1秒，大幅降低延迟
3. 帧插值算法：对于未及时处理的帧，使用上一帧的检测结果进行插值，避免使用原始帧
4. 缓冲区优化：限制缓冲区大小，使用滑动窗口机制，及时清理旧帧
5. 异步非阻塞处理：优化等待逻辑，避免长时间阻塞，提升响应速度
6. YOLO推理优化：使用优化的推理参数，在保持精度的同时提升检测速度

性能优化（平衡清晰度和速度）：
1. 分辨率优化：所有帧统一缩放到1280x720（16:9），保持良好清晰度
2. 码率优化：输入流2000kbps，输出流1500kbps，平衡清晰度和传输速度
3. FFmpeg优化：使用-nobuffer标志降低延迟，BGR像素格式提升处理速度
4. YOLO检测优化：使用640尺寸进行检测（自动保持宽高比），提升检测速度
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
import argparse
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
from collections import deque

# 添加项目路径
video_root = Path(__file__).parent.absolute()
sys.path.insert(0, str(video_root))


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


# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(name)s] [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# 全局配置（将在main函数中根据命令行参数设置）
VIDEO_FILE = None  # 将在main函数中设置
YOLO_MODEL_PATH = video_root / "yolo11n.pt"
RTMP_INPUT_URL = "rtmp://localhost:1935/live/test_input"  # ffmpeg 推送的地址
RTMP_OUTPUT_URL = "rtmp://localhost:1935/live/test_output"  # 最终推送的地址
RTMP_SERVER_HOST = "localhost"
RTMP_SERVER_PORT = 1935

# 服务端口
EXTRACTOR_PORT = 8001
SORTER_PORT = 8002
PUSHER_PORT = 8003

# 抽帧间隔（全局变量，供多个函数使用）
EXTRACT_INTERVAL = 5  # 每5帧抽一次

# 原始视频帧率（假设输入视频是25fps，可根据实际情况调整）
SOURCE_FPS = 25  # 原始视频帧率

# 分辨率配置（1280x720以提升清晰度）
TARGET_WIDTH = 1280  # 目标宽度
TARGET_HEIGHT = 720  # 目标高度
TARGET_RESOLUTION = (TARGET_WIDTH, TARGET_HEIGHT)  # 目标分辨率

# 码率配置（1280x720需要更高的码率以保持清晰度）
INPUT_BITRATE = "2000k"  # 输入流码率
OUTPUT_BITRATE = "1500k"  # 输出流码率

# 缓流器配置
# 缓冲区大小优化：平衡缓冲和流畅度，找到最佳平衡点
# 2.5秒缓冲：提供足够的缓冲帧，同时避免过长等待
BUFFER_SECONDS = 2.5  # 缓冲区时间长度（秒），2.5秒平衡缓冲和延迟
BUFFER_SIZE = int(SOURCE_FPS * BUFFER_SECONDS)  # 根据帧率和时间计算缓冲区大小（帧数）
# 确保缓冲区在合理范围内
if BUFFER_SIZE < 40:
    BUFFER_SIZE = 40  # 最小40帧（约1.6秒）
if BUFFER_SIZE > 70:
    BUFFER_SIZE = 70  # 最大70帧（约2.8秒），平衡缓冲和延迟

# 推送优化配置
PUSH_TIMEOUT = 0.1  # 推送超时时间（秒），避免阻塞

# 流畅度优化配置
MAX_WAIT_TIME = 0.08  # 最大等待处理时间（秒），缩短到0.08秒以提升流畅度，更快使用插值帧
FRAME_INTERPOLATION = True  # 启用帧插值，使用上一帧的检测结果
# 最小缓冲帧数：基于时间计算，确保有足够缓冲防止卡顿
MIN_BUFFER_SECONDS = 0.6  # 最小缓冲时间（秒），0.6秒平衡缓冲和启动速度
MIN_BUFFER_FRAMES = max(12, int(SOURCE_FPS * MIN_BUFFER_SECONDS))  # 最小缓冲帧数，至少12帧

# 全局变量
ffmpeg_process = None
buffer_streamer_thread = None  # 缓流器线程
extractor_thread = None  # 抽帧器线程
pusher_thread = None  # 推帧器线程
yolo_threads = []
stop_event = threading.Event()

# 队列
extract_queue = queue.Queue(maxsize=50)  # 抽帧队列（从缓流器到抽帧器）
detection_queue = queue.Queue(maxsize=50)  # 检测结果队列（从抽帧器到推帧器）
push_queue = queue.Queue(maxsize=50)  # 推帧队列（从推帧器到缓流器）

# 缓流器帧缓冲区（线程安全）
buffer_lock = threading.Lock()
frame_buffer = {}  # {frame_number: frame_data} 缓流器的帧缓冲区

# YOLO 模型
yolo_model = None


def check_rtmp_server():
    """检查 RTMP 服务器是否可用"""
    import socket

    logger.info(f"🔍 检查 RTMP 服务器连接: {RTMP_SERVER_HOST}:{RTMP_SERVER_PORT}")

    try:
        # 尝试连接 RTMP 服务器端口
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        result = sock.connect_ex((RTMP_SERVER_HOST, RTMP_SERVER_PORT))
        sock.close()

        if result == 0:
            logger.info(f"✅ RTMP 服务器连接成功: {RTMP_SERVER_HOST}:{RTMP_SERVER_PORT}")
            return True
        else:
            logger.error(f"❌ RTMP 服务器不可用: {RTMP_SERVER_HOST}:{RTMP_SERVER_PORT}")
            logger.error("")
            logger.error("=" * 60)
            logger.error("💡 解决方案：")
            logger.error("=" * 60)
            logger.error("1. 使用 Docker Compose 启动 SRS 服务器：")
            logger.error("   cd /opt/projects/easyaiot/.scripts/docker")
            logger.error("   docker-compose up -d SRS")
            logger.error("")
            logger.error("2. 或者使用 Docker 直接启动 SRS：")
            logger.error("   docker run -d --name srs-server -p 1935:1935 -p 1985:1985 -p 8080:8080 ossrs/srs:5")
            logger.error("")
            logger.error("3. 检查 SRS 服务状态：")
            logger.error("   docker ps | grep srs")
            logger.error("   # 或者")
            logger.error("   curl http://localhost:1985/api/v1/versions")
            logger.error("=" * 60)
            return False
    except Exception as e:
        logger.error(f"❌ 检查 RTMP 服务器时出错: {str(e)}")
        logger.error("")
        logger.error("=" * 60)
        logger.error("💡 解决方案：")
        logger.error("=" * 60)
        logger.error("请确保 RTMP 服务器（SRS）正在运行")
        logger.error("=" * 60)
        return False


def check_and_stop_existing_stream(stream_url: str):
    """检查并停止现有的 RTMP 流（通过 SRS HTTP API）"""
    try:
        # 从 RTMP URL 中提取流名称
        # rtmp://localhost:1935/live/test_input -> live/test_input
        if "rtmp://" in stream_url:
            stream_path = stream_url.split("rtmp://")[1].split("/", 1)[1] if "/" in stream_url.split("rtmp://")[
                1] else ""
        else:
            stream_path = stream_url

        if not stream_path:
            logger.warning("⚠️  无法从 URL 中提取流路径，跳过流检查")
            return True

        # SRS HTTP API 地址（默认端口 1985）
        srs_api_url = f"http://{RTMP_SERVER_HOST}:1985/api/v1/streams/"

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
                    full_stream_path = f"{stream_app}/{stream_stream}" if stream_stream else stream_app

                    if stream_path in full_stream_path or full_stream_path in stream_path:
                        stream_to_stop = stream
                        break

                if stream_to_stop:
                    stream_id = stream_to_stop.get('id', '')
                    publish_info = stream_to_stop.get('publish', {})
                    publish_cid = publish_info.get('cid', '') if isinstance(publish_info, dict) else None

                    logger.warning(f"⚠️  发现现有流: {stream_path} (ID: {stream_id})，正在停止...")

                    # 方法1: 尝试断开发布者客户端连接（推荐方法）
                    if publish_cid:
                        logger.info(f"   尝试断开发布者客户端: {publish_cid}")
                        client_api_url = f"http://{RTMP_SERVER_HOST}:1985/api/v1/clients/{publish_cid}"
                        try:
                            stop_response = requests.delete(client_api_url, timeout=3)
                            if stop_response.status_code in [200, 204]:
                                logger.info(f"✅ 已断开发布者客户端，流将自动停止")
                                time.sleep(2)  # 等待流完全停止
                                return True
                            else:
                                logger.warning(
                                    f"   断开客户端失败 (状态码: {stop_response.status_code})，尝试其他方法...")
                        except Exception as e:
                            logger.warning(f"   断开客户端异常: {str(e)}，尝试其他方法...")

                    # 方法2: 尝试通过流ID停止（某些SRS版本支持）
                    logger.info(f"   尝试通过流ID停止: {stream_id}")
                    stop_url = f"{srs_api_url}{stream_id}"
                    try:
                        stop_response = requests.delete(stop_url, timeout=3)
                        if stop_response.status_code in [200, 204]:
                            logger.info(f"✅ 已停止现有流: {stream_path}")
                            time.sleep(2)  # 等待流完全停止
                            return True
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
                            return True
                    except Exception as e:
                        logger.warning(f"   查找进程失败: {str(e)}")

                    logger.warning(f"⚠️  无法停止现有流，但将继续尝试推流...")
                    return True
                else:
                    logger.info(f"✅ 未发现现有流: {stream_path}")
                    return True
            else:
                logger.warning(f"⚠️  无法获取流列表 (状态码: {response.status_code})，继续尝试推流...")
                return True

        except requests.exceptions.RequestException as e:
            logger.warning(f"⚠️  无法连接到 SRS API: {str(e)}，继续尝试推流...")
            return True

    except Exception as e:
        logger.warning(f"⚠️  检查现有流时出错: {str(e)}，继续尝试推流...")
        return True


def check_dependencies():
    """检查依赖"""
    # 检查 ffmpeg
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, timeout=5)
        logger.info("✅ ffmpeg 已安装")
    except (FileNotFoundError, subprocess.TimeoutExpired):
        logger.error("❌ ffmpeg 未安装，请先安装: sudo apt-get install ffmpeg")
        return False

    # 检查 ultralytics
    try:
        from ultralytics import YOLO
        logger.info("✅ ultralytics 已安装")
    except ImportError:
        logger.error("❌ ultralytics 未安装，请先安装: pip install ultralytics")
        return False

    # 检查文件
    if not VIDEO_FILE.exists():
        logger.error(f"❌ 视频文件不存在: {VIDEO_FILE}")
        return False
    logger.info(f"✅ 视频文件存在: {VIDEO_FILE}")

    if not YOLO_MODEL_PATH.exists():
        logger.error(f"❌ YOLO 模型文件不存在: {YOLO_MODEL_PATH}")
        return False
    logger.info(f"✅ YOLO 模型文件存在: {YOLO_MODEL_PATH}")

    # 检查 RTMP 服务器
    if not check_rtmp_server():
        return False

    return True


def load_yolo_model():
    """加载 YOLO 模型"""
    global yolo_model
    try:
        from ultralytics import YOLO
        logger.info(f"正在加载 YOLO 模型: {YOLO_MODEL_PATH}")
        yolo_model = YOLO(str(YOLO_MODEL_PATH))
        logger.info("✅ YOLO 模型加载成功")
        return True
    except Exception as e:
        logger.error(f"❌ YOLO 模型加载失败: {str(e)}", exc_info=True)
        return False


def start_ffmpeg_stream():
    """使用 ffmpeg 推送视频流到 RTMP"""
    global ffmpeg_process

    # 在启动推流前，检查并停止现有流
    logger.info("🔍 检查是否存在占用该地址的流...")
    check_and_stop_existing_stream(RTMP_INPUT_URL)

    # 优化：缩放视频到1280x720并优化编码参数
    cmd = [
        "ffmpeg",
        "-y",  # 覆盖输出文件
        "-fflags", "nobuffer",  # 无缓冲，降低延迟
        "-re",  # 以原始帧率读取
        "-stream_loop", "-1",  # 无限循环
        "-i", str(VIDEO_FILE),
        "-vf", f"scale={TARGET_WIDTH}:{TARGET_HEIGHT}",  # 缩放到1280x720
        "-c:v", "libx264",
        "-preset", "veryfast",  # 快速编码
        "-tune", "zerolatency",  # 零延迟
        "-b:v", INPUT_BITRATE,  # 输入流码率
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "128k",  # 音频码率
        "-f", "flv",
        "-loglevel", "error",
        RTMP_INPUT_URL
    ]

    logger.info(f"🚀 启动 ffmpeg 推流: {VIDEO_FILE} -> {RTMP_INPUT_URL}")
    logger.info(f"   分辨率: {TARGET_WIDTH}x{TARGET_HEIGHT}, 码率: {INPUT_BITRATE}")
    logger.info(f"   命令: {' '.join(cmd)}")

    try:
        ffmpeg_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        logger.info(f"✅ ffmpeg 进程已启动 (PID: {ffmpeg_process.pid})")

        # 等待一下确保流已建立
        time.sleep(2)

        # 检查进程是否还在运行
        if ffmpeg_process.poll() is not None:
            stderr = ffmpeg_process.stderr.read() if ffmpeg_process.stderr else ""
            logger.error(f"❌ ffmpeg 进程异常退出: {stderr}")

            # 如果失败，再次尝试停止现有流并重试一次
            logger.info("🔄 推流失败，尝试清理并重试...")
            check_and_stop_existing_stream(RTMP_INPUT_URL)
            time.sleep(2)

            # 重新启动
            try:
                ffmpeg_process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    universal_newlines=True
                )
                logger.info(f"✅ ffmpeg 进程已重新启动 (PID: {ffmpeg_process.pid})")
                time.sleep(2)

                if ffmpeg_process.poll() is not None:
                    stderr = ffmpeg_process.stderr.read() if ffmpeg_process.stderr else ""
                    logger.error(f"❌ ffmpeg 进程再次异常退出: {stderr}")
                    return False

                return True
            except Exception as e:
                logger.error(f"❌ 重新启动 ffmpeg 失败: {str(e)}", exc_info=True)
                return False

            return False

        return True
    except Exception as e:
        logger.error(f"❌ 启动 ffmpeg 失败: {str(e)}", exc_info=True)
        return False


def monitor_ffmpeg_stream():
    """监控 ffmpeg 推流进程，如果退出则自动重启"""
    global ffmpeg_process

    logger.info("📡 FFmpeg 监控线程启动")

    while not stop_event.is_set():
        try:
            # 检查 ffmpeg 进程是否还在运行
            if ffmpeg_process is None or ffmpeg_process.poll() is not None:
                logger.warning("⚠️  FFmpeg 推流进程已停止，正在重启...")

                # 清理旧进程
                if ffmpeg_process:
                    try:
                        ffmpeg_process.terminate()
                        ffmpeg_process.wait(timeout=2)
                    except:
                        if ffmpeg_process.poll() is None:
                            ffmpeg_process.kill()
                    ffmpeg_process = None

                # 等待一下再重启
                time.sleep(2)

                # 重新启动
                if start_ffmpeg_stream():
                    logger.info("✅ FFmpeg 推流进程重启成功")
                else:
                    logger.error("❌ FFmpeg 推流进程重启失败，30秒后重试...")
                    time.sleep(30)

            # 每10秒检查一次
            time.sleep(10)

        except Exception as e:
            logger.error(f"❌ FFmpeg 监控异常: {str(e)}", exc_info=True)
            time.sleep(10)

    logger.info("📡 FFmpeg 监控线程停止")


def buffer_streamer_worker():
    """缓流器工作线程：缓冲源流，接收推帧器插入的帧，输出到目标流"""
    logger.info("💾 缓流器线程启动")

    cap = None
    pusher_process = None
    frame_count = 0
    frame_width = None
    frame_height = None
    next_output_frame = 1  # 下一个要输出的帧号
    retry_count = 0
    max_retries = 5
    pending_frames = set()  # 等待处理完成的帧号集合

    # 流畅度优化：基于时间戳的帧率控制
    frame_interval = 1.0 / SOURCE_FPS  # 每帧的时间间隔
    last_frame_time = time.time()  # 上一帧的输出时间
    last_processed_frame = None  # 上一帧处理后的结果（用于插值）
    last_processed_detections = []  # 上一帧的检测结果（用于插值）

    while not stop_event.is_set():
        try:
            # 打开源 RTMP 流
            if cap is None or not cap.isOpened():
                logger.info(f"正在连接源 RTMP 流: {RTMP_INPUT_URL} (重试次数: {retry_count})")
                cap = cv2.VideoCapture(RTMP_INPUT_URL)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

                if not cap.isOpened():
                    retry_count += 1
                    if retry_count >= max_retries:
                        logger.error(f"❌ 连接源 RTMP 流失败，已达到最大重试次数 {max_retries}")
                        logger.info("等待30秒后重新尝试...")
                        time.sleep(30)
                        retry_count = 0
                    else:
                        logger.warning(f"无法打开源 RTMP 流，等待重试... ({retry_count}/{max_retries})")
                        time.sleep(2)
                    continue

                retry_count = 0
                logger.info("✅ 源 RTMP 流连接成功")

            # 从源流读取帧
            ret, frame = cap.read()

            if not ret or frame is None:
                logger.warning("读取源流帧失败，重新连接...")
                if cap is not None:
                    cap.release()
                    cap = None
                time.sleep(1)
                continue

            frame_count += 1

            # 立即缩放到目标分辨率（1280x720）以保持清晰度
            original_height, original_width = frame.shape[:2]
            if (original_width, original_height) != TARGET_RESOLUTION:
                frame = cv2.resize(frame, TARGET_RESOLUTION, interpolation=cv2.INTER_LINEAR)

            height, width = TARGET_HEIGHT, TARGET_WIDTH

            # 初始化推送进程
            if pusher_process is None or pusher_process.poll() is not None or \
                    frame_width != width or frame_height != height:

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

                # 构建 ffmpeg 命令（优化参数）
                ffmpeg_cmd = [
                    "ffmpeg",
                    "-y",  # 覆盖输出文件
                    "-fflags", "nobuffer",  # 无缓冲，降低延迟
                    "-f", "rawvideo",
                    "-vcodec", "rawvideo",
                    "-pix_fmt", "bgr24",  # BGR格式，ffmpeg标准格式，速度更快
                    "-s", f"{width}x{height}",
                    "-r", str(SOURCE_FPS),
                    "-i", "-",
                    "-c:v", "libx264",
                    "-b:v", OUTPUT_BITRATE,  # 输出流码率
                    "-pix_fmt", "yuv420p",
                    "-preset", "ultrafast",  # 最快编码速度
                    "-f", "flv",
                    RTMP_OUTPUT_URL
                ]

                logger.info(f"🚀 启动缓流器推送进程: {RTMP_OUTPUT_URL}")
                logger.info(f"   尺寸: {width}x{height}, 帧率: {SOURCE_FPS}fps, 码率: {OUTPUT_BITRATE}")

                try:
                    pusher_process = subprocess.Popen(
                        ffmpeg_cmd,
                        stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        bufsize=0
                    )
                    time.sleep(0.5)

                    if pusher_process.poll() is not None:
                        stderr = pusher_process.stderr.read() if pusher_process.stderr else ""
                        logger.error(f"❌ 推送进程启动失败: {stderr.decode('utf-8', errors='ignore')}")
                        pusher_process = None
                        continue

                    logger.info(f"✅ 推送进程已启动 (PID: {pusher_process.pid})")
                except Exception as e:
                    logger.error(f"❌ 启动推送进程异常: {str(e)}", exc_info=True)
                    pusher_process = None
                    continue

            # 将帧存入缓冲区（平衡清理策略，确保稳定）
            with buffer_lock:
                # 优化：更保守的清理策略，确保有足够缓冲防止转圈
                # 只在缓冲区接近满载时才清理，保留足够缓冲
                buffer_threshold = int(BUFFER_SIZE * 0.98)  # 98%阈值，非常保守，保留更多缓冲
                if len(frame_buffer) >= buffer_threshold:
                    # 只清理已输出且明显超出最小缓冲要求的旧帧
                    frames_to_remove = []
                    for frame_num in frame_buffer.keys():
                        # 只清理已输出且超出最小缓冲要求3倍的帧，更保守
                        if frame_num < next_output_frame and len(frame_buffer) > MIN_BUFFER_FRAMES * 3:
                            frames_to_remove.append(frame_num)

                    # 按帧号排序，优先清理最旧的帧
                    frames_to_remove.sort()
                    # 只清理少量帧，不要过度清理
                    remove_count = min(2, max(1, len(frame_buffer) - buffer_threshold + 1))
                    for frame_num in frames_to_remove[:remove_count]:
                        frame_buffer.pop(frame_num, None)

                # 如果缓冲区仍然过大（>99%），才强制清理最旧的帧
                if len(frame_buffer) >= int(BUFFER_SIZE * 0.99):
                    oldest_frame = min(frame_buffer.keys())
                    if oldest_frame < next_output_frame:
                        frame_buffer.pop(oldest_frame, None)

                frame_buffer[frame_count] = {
                    'frame': frame.copy(),
                    'frame_number': frame_count,
                    'timestamp': time.time(),
                    'processed': False  # 标记是否已处理
                }

                # 如果该帧需要抽帧，立即发送给抽帧器并标记为待处理
                if frame_count % EXTRACT_INTERVAL == 0:
                    pending_frames.add(frame_count)
                    # 优化：队列满时等待一下再尝试，避免跳过帧导致遗漏识别
                    frame_sent = False
                    retry_count = 0
                    max_retries = 5
                    while not frame_sent and retry_count < max_retries:
                        try:
                            extract_queue.put_nowait({
                                'frame': frame.copy(),
                                'frame_number': frame_count,
                                'timestamp': frame_buffer[frame_count]['timestamp']
                            })
                            frame_sent = True
                        except queue.Full:
                            retry_count += 1
                            if retry_count < max_retries:
                                # 等待一小段时间后重试
                                time.sleep(0.01)
                            else:
                                # 如果多次重试仍失败，记录警告但不丢弃，让后续处理
                                logger.warning(f"⚠️  抽帧队列已满，帧 {frame_count} 等待处理中...")
                                # 不丢弃 pending_frames，让后续有机会处理

            # 持续检查推帧队列，将处理后的帧插入缓冲区（在输出前处理）
            # 优化：限制处理数量，避免阻塞输出循环
            processed_count = 0
            max_process_per_cycle = 10  # 限制每次循环处理的数量，确保及时输出
            while processed_count < max_process_per_cycle:
                try:
                    push_data = push_queue.get_nowait()
                    processed_frame = push_data['frame']
                    frame_number = push_data['frame_number']
                    detections = push_data.get('detections', [])

                    # 替换缓冲区中对应位置的帧
                    with buffer_lock:
                        if frame_number in frame_buffer:
                            frame_buffer[frame_number]['frame'] = processed_frame
                            frame_buffer[frame_number]['processed'] = True
                            frame_buffer[frame_number]['detections'] = detections
                            pending_frames.discard(frame_number)  # 从待处理集合中移除

                            # 更新上一帧的处理结果（用于插值）
                            last_processed_frame = processed_frame.copy()
                            last_processed_detections = detections.copy()

                            if frame_number % 50 == 0:  # 减少日志频率
                                logger.info(f"🔄 缓流器：帧 {frame_number} 已替换为处理后的帧（带识别框）")
                    processed_count += 1
                except queue.Empty:
                    break

            # 按顺序输出帧（使用精确的帧率控制，确保连续稳定输出）
            output_count = 0
            # 检查缓冲区大小
            with buffer_lock:
                current_buffer_size = len(frame_buffer)

            # 优化：保持稳定且连续的输出，关键是不间断
            # 确保有足够缓冲才输出，同时保持流畅
            if current_buffer_size < MIN_BUFFER_FRAMES:
                # 缓冲区不足，等待积累更多帧，不输出
                max_output_per_cycle = 0
            elif current_buffer_size < MIN_BUFFER_FRAMES * 1.2:
                # 缓冲区刚达到最小要求，保守输出
                max_output_per_cycle = 1
            elif current_buffer_size > BUFFER_SIZE * 0.85:
                # 缓冲区较大（>85%），适度加快输出
                max_output_per_cycle = 3
            else:
                # 缓冲区正常，保持稳定的输出速度（关键：连续稳定）
                max_output_per_cycle = 2  # 每次输出2帧，保持流畅度

            while output_count < max_output_per_cycle:
                # 计算下一帧应该输出的时间
                current_time = time.time()
                time_since_last_frame = current_time - last_frame_time

                # 优化：保持稳定的帧率输出，确保连续平滑
                # 只有在缓冲区严重过载时才跳过等待
                buffer_critical = False
                with buffer_lock:
                    current_buffer_size = len(frame_buffer)
                    # 只有在缓冲区非常大时才跳过等待，确保平滑输出
                    buffer_critical = current_buffer_size > BUFFER_SIZE * 0.95

                # 如果距离上一帧输出时间不足，且缓冲区不严重过载，则等待以保持稳定帧率
                if not buffer_critical and time_since_last_frame < frame_interval:
                    sleep_time = frame_interval - time_since_last_frame
                    # 精确等待，保持稳定的帧率输出（关键：平滑连续）
                    time.sleep(min(sleep_time, frame_interval * 0.98))  # 最多等待98%的帧间隔，更精确
                    continue

                with buffer_lock:
                    # 检查是否有可输出的帧
                    if next_output_frame not in frame_buffer:
                        break

                    frame_data = frame_buffer[next_output_frame]
                    is_extracted = (next_output_frame % EXTRACT_INTERVAL == 0)

                # 如果该帧需要抽帧但还未处理完成，等待处理完成（在锁外等待）
                if is_extracted and next_output_frame in pending_frames:
                    # 等待处理完成，缩短等待时间以提升流畅度
                    wait_start = time.time()
                    check_interval = 0.003  # 每3ms检查一次，更频繁，提升响应速度

                    while next_output_frame in pending_frames and (time.time() - wait_start) < MAX_WAIT_TIME:
                        time.sleep(check_interval)
                        # 持续检查推帧队列，处理所有到达的帧（关键：确保不遗漏）
                        processed_in_wait = 0
                        while processed_in_wait < 20:  # 增加处理数量
                            try:
                                push_data = push_queue.get_nowait()
                                processed_frame = push_data['frame']
                                fn = push_data['frame_number']
                                detections = push_data.get('detections', [])
                                with buffer_lock:
                                    if fn in frame_buffer:
                                        frame_buffer[fn]['frame'] = processed_frame
                                        frame_buffer[fn]['processed'] = True
                                        frame_buffer[fn]['detections'] = detections
                                        pending_frames.discard(fn)

                                        # 更新上一帧的处理结果（用于插值）- 更新所有已处理的帧
                                        last_processed_frame = processed_frame.copy()
                                        last_processed_detections = detections.copy()

                                        # 如果目标帧已处理完成，立即退出
                                        if fn == next_output_frame:
                                            break
                                processed_in_wait += 1
                            except queue.Empty:
                                break

                        # 如果目标帧已处理完成，退出等待循环
                        if next_output_frame not in pending_frames:
                            break

                    # 如果超时仍未处理完成，再等待一小段时间，尽量等待处理完成
                    if next_output_frame in pending_frames:
                        # 再给一次机会，等待额外的时间（缩短到0.02秒以提升流畅度）
                        extra_wait_start = time.time()
                        extra_wait_time = 0.02
                        while next_output_frame in pending_frames and (
                                time.time() - extra_wait_start) < extra_wait_time:
                            time.sleep(0.005)
                            # 再次检查推帧队列
                            try:
                                push_data = push_queue.get_nowait()
                                processed_frame = push_data['frame']
                                fn = push_data['frame_number']
                                detections = push_data.get('detections', [])
                                with buffer_lock:
                                    if fn in frame_buffer:
                                        frame_buffer[fn]['frame'] = processed_frame
                                        frame_buffer[fn]['processed'] = True
                                        frame_buffer[fn]['detections'] = detections
                                        pending_frames.discard(fn)
                                        if fn == next_output_frame:
                                            last_processed_frame = processed_frame.copy()
                                            last_processed_detections = detections.copy()
                                            break
                            except queue.Empty:
                                pass

                        # 如果仍然未处理完成，使用帧插值或原始帧
                        if next_output_frame in pending_frames:
                            if FRAME_INTERPOLATION and last_processed_frame is not None:
                                # 使用上一帧的检测结果进行插值（在原始帧上画框）
                                with buffer_lock:
                                    if next_output_frame in frame_buffer:
                                        original_frame = frame_buffer[next_output_frame]['frame'].copy()
                                        # 在原始帧上绘制上一帧的检测框（使用透明度）
                                        interpolated_frame = original_frame.copy()
                                        for det in last_processed_detections:
                                            bbox = det.get('bbox', [])
                                            if len(bbox) == 4:
                                                x1, y1, x2, y2 = bbox
                                                # 使用半透明框
                                                overlay = interpolated_frame.copy()
                                                cv2.rectangle(overlay, (x1, y1), (x2, y2), (0, 255, 0), 2)
                                                cv2.addWeighted(overlay, 0.5, interpolated_frame, 0.5, 0,
                                                                interpolated_frame)

                                        frame_buffer[next_output_frame]['frame'] = interpolated_frame
                                        frame_buffer[next_output_frame]['processed'] = True
                                        if next_output_frame % 50 == 0:
                                            logger.warning(
                                                f"⚠️  帧 {next_output_frame} 处理超时，使用插值结果（基于上一帧检测）")
                            else:
                                if next_output_frame % 50 == 0:
                                    logger.warning(f"⚠️  帧 {next_output_frame} 处理超时，使用原始帧输出（未识别）")
                            pending_frames.discard(next_output_frame)

                # 在输出前，最后检查一次推帧队列，确保不遗漏已处理的帧
                # 优化：确保在输出前能获取到最新处理完成的帧
                last_check_count = 0
                while last_check_count < 5:  # 快速检查几次
                    try:
                        push_data = push_queue.get_nowait()
                        processed_frame = push_data['frame']
                        fn = push_data['frame_number']
                        detections = push_data.get('detections', [])
                        with buffer_lock:
                            if fn in frame_buffer:
                                frame_buffer[fn]['frame'] = processed_frame
                                frame_buffer[fn]['processed'] = True
                                frame_buffer[fn]['detections'] = detections
                                pending_frames.discard(fn)
                                # 如果正好是目标帧，更新插值用的结果
                                if fn == next_output_frame:
                                    last_processed_frame = processed_frame.copy()
                                    last_processed_detections = detections.copy()
                        last_check_count += 1
                    except queue.Empty:
                        break

                # 获取并输出帧
                with buffer_lock:
                    if next_output_frame not in frame_buffer:
                        break

                    output_frame_data = frame_buffer.pop(next_output_frame)
                    output_frame = output_frame_data['frame']
                    processed_status = "已处理" if output_frame_data.get('processed', False) else "原始"
                    buffer_size = len(frame_buffer)  # 在锁内记录缓冲区大小

                    # 优化：输出后非常保守地清理，确保有足够缓冲
                    # 只在缓冲区明显过大时才清理，保留更多缓冲防止转圈
                    if buffer_size > MIN_BUFFER_FRAMES * 4:
                        frames_to_clean = [fn for fn in frame_buffer.keys()
                                           if fn < next_output_frame]
                        if frames_to_clean:
                            # 按帧号排序
                            frames_to_clean.sort()
                            # 只清理超出最小缓冲要求3.5倍的帧，非常保守
                            excess_count = len(frames_to_clean) - int(MIN_BUFFER_FRAMES * 3.5)
                            if excess_count > 0:
                                # 只清理最旧的少量帧，不要过度清理
                                for fn in frames_to_clean[:min(excess_count, 1)]:
                                    frame_buffer.pop(fn, None)

                    # 如果输出的是已处理的帧，更新插值用的上一帧结果
                    if output_frame_data.get('processed', False):
                        last_processed_frame = output_frame.copy()
                        last_processed_detections = output_frame_data.get('detections', [])

                # 推送到输出流（在锁外执行，避免阻塞）
                if pusher_process and pusher_process.stdin:
                    try:
                        frame_bytes = output_frame.tobytes()
                        pusher_process.stdin.write(frame_bytes)
                        pusher_process.stdin.flush()

                        if next_output_frame % 50 == 0:
                            logger.info(
                                f"📤 缓流器输出: 帧号 {next_output_frame} ({processed_status}), 缓冲区: {buffer_size}")
                    except (BrokenPipeError, OSError):
                        pusher_process = None
                        continue

                # 更新帧率控制时间戳
                last_frame_time = time.time()
                next_output_frame += 1
                output_count += 1

            # 根据缓冲区大小决定是否休眠，确保连续稳定的输出
            with buffer_lock:
                buffer_size = len(frame_buffer)

            # 优化：保持连续稳定的输出节奏，关键是不间断
            if buffer_size < MIN_BUFFER_FRAMES:
                # 缓冲区太小，等待积累更多帧，但不要等太久
                time.sleep(0.02)  # 减少等待时间，避免卡顿
            elif buffer_size < MIN_BUFFER_FRAMES * 1.2:
                # 缓冲区刚达到最小要求，短暂等待
                time.sleep(0.01)
            elif buffer_size > BUFFER_SIZE * 0.9:
                # 缓冲区过大（>90%），跳过休眠，加快处理
                pass
            else:
                # 缓冲区正常，精确的帧率控制，保持连续稳定输出
                current_time = time.time()
                time_since_last_frame = current_time - last_frame_time
                if time_since_last_frame < frame_interval:
                    # 精确等待，保持稳定的帧率输出（关键：连续平滑）
                    sleep_time = frame_interval - time_since_last_frame
                    # 精确等待，但不要超过帧间隔
                    time.sleep(min(sleep_time, frame_interval * 0.95))

        except Exception as e:
            logger.error(f"❌ 缓流器异常: {str(e)}", exc_info=True)
            if cap is not None:
                try:
                    cap.release()
                except:
                    pass
                cap = None
            time.sleep(2)

    # 清理
    if cap is not None:
        try:
            cap.release()
        except:
            pass
    if pusher_process:
        try:
            if pusher_process.stdin:
                pusher_process.stdin.close()
            pusher_process.terminate()
            pusher_process.wait(timeout=5)
        except:
            if pusher_process.poll() is None:
                pusher_process.kill()

    logger.info("💾 缓流器线程停止")


def extractor_worker():
    """抽帧器工作线程：从缓流器获取帧，抽帧并标记位置"""
    logger.info("📹 抽帧器线程启动")

    while not stop_event.is_set():
        try:
            # 从缓流器获取帧
            try:
                frame_data = extract_queue.get(timeout=1)
            except queue.Empty:
                continue

            frame = frame_data['frame']
            frame_number = frame_data['frame_number']
            timestamp = frame_data['timestamp']
            frame_id = f"frame_{frame_number}_{int(timestamp)}"

            # 将帧发送给YOLO检测（带位置信息）
            # 优化：队列满时等待一下再尝试，避免跳过帧导致遗漏识别
            frame_sent = False
            retry_count = 0
            max_retries = 10  # 增加重试次数，确保不遗漏
            while not frame_sent and retry_count < max_retries:
                try:
                    detection_queue.put_nowait({
                        'frame_id': frame_id,
                        'frame': frame.copy(),
                        'frame_number': frame_number,
                        'timestamp': timestamp
                    })
                    frame_sent = True
                    if frame_number % 10 == 0:
                        logger.info(f"✅ 抽帧器: {frame_id} (帧号: {frame_number})")
                except queue.Full:
                    retry_count += 1
                    if retry_count < max_retries:
                        # 等待一小段时间后重试
                        time.sleep(0.01)
                    else:
                        # 如果多次重试仍失败，记录警告
                        logger.warning(f"⚠️  检测队列已满，帧 {frame_id} 多次重试失败，可能遗漏识别")

        except Exception as e:
            logger.error(f"❌ 抽帧器异常: {str(e)}", exc_info=True)
            time.sleep(1)

    logger.info("📹 抽帧器线程停止")


def yolo_detection_worker(worker_id: int):
    """YOLO 检测工作线程：使用 YOLO 模型进行识别和画框，将结果发送给推帧器"""
    logger.info(f"🤖 YOLO 检测线程 {worker_id} 启动")

    consecutive_errors = 0
    max_consecutive_errors = 10

    while not stop_event.is_set():
        try:
            # 从抽帧器获取帧
            try:
                frame_data = detection_queue.get(timeout=1)
                consecutive_errors = 0  # 重置错误计数
            except queue.Empty:
                continue

            frame = frame_data['frame']
            frame_id = frame_data['frame_id']
            timestamp = frame_data['timestamp']
            frame_number = frame_data['frame_number']

            # 减少日志输出
            if frame_number % 10 == 0:
                logger.info(f"🔍 [Worker {worker_id}] 开始检测: {frame_id}")

            # 使用 YOLO 进行检测（优化配置以提升速度）
            try:
                # 帧已经是1280x720，使用640尺寸进行检测（YOLO会自动调整，保持宽高比）
                # 使用优化的推理参数
                results = yolo_model(
                    frame,
                    conf=0.25,
                    iou=0.45,
                    imgsz=640,  # 使用640尺寸，YOLO会自动保持宽高比缩放
                    verbose=False,
                    half=False,  # 如果GPU支持，可以设置为True以提升速度
                    device=get_device()  # 可以根据实际情况使用GPU
                )
                result = results[0]

                # 提取检测结果
                detections = []
                annotated_frame = frame.copy()

                if result.boxes is not None and len(result.boxes) > 0:
                    boxes = result.boxes.xyxy.cpu().numpy()  # x1, y1, x2, y2
                    confidences = result.boxes.conf.cpu().numpy()
                    class_ids = result.boxes.cls.cpu().numpy().astype(int)

                    # 在图像上画框
                    for i, (box, conf, cls_id) in enumerate(zip(boxes, confidences, class_ids)):
                        x1, y1, x2, y2 = map(int, box)

                        # 获取类别名称
                        class_name = yolo_model.names[cls_id]

                        # 画框
                        color = (0, 255, 0)  # 绿色
                        cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), color, 2)

                        # 画标签
                        label = f"{class_name}: {conf:.2f}"
                        label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
                        cv2.rectangle(annotated_frame, (x1, y1 - label_size[1] - 10),
                                      (x1 + label_size[0], y1), color, cv2.FILLED)
                        cv2.putText(annotated_frame, label, (x1, y1 - 5),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

                        # 添加到检测结果
                        detections.append({
                            'class_id': int(cls_id),
                            'class_name': class_name,
                            'confidence': float(conf),
                            'bbox': [int(x1), int(y1), int(x2), int(y2)],
                            'timestamp': timestamp,
                            'frame_id': frame_id,
                            'frame_number': frame_number
                        })

                # 将检测结果发送给推帧器（带位置信息）
                # 优化：队列满时等待一下再尝试，避免跳过已检测的帧导致遗漏识别
                frame_sent = False
                retry_count = 0
                max_retries = 10  # 增加重试次数，确保不遗漏
                while not frame_sent and retry_count < max_retries:
                    try:
                        push_queue.put_nowait({
                            'frame': annotated_frame,
                            'frame_number': frame_number,
                            'detections': detections,
                            'timestamp': timestamp
                        })
                        frame_sent = True
                        # 减少日志输出，每10帧打印一次
                        if frame_number % 10 == 0:
                            logger.info(
                                f"✅ [Worker {worker_id}] 检测完成: {frame_id} (帧号: {frame_number}), 检测到 {len(detections)} 个目标")
                    except queue.Full:
                        retry_count += 1
                        if retry_count < max_retries:
                            # 等待一小段时间后重试
                            time.sleep(0.01)
                        else:
                            # 如果多次重试仍失败，记录警告
                            logger.warning(
                                f"⚠️  [Worker {worker_id}] 推帧队列已满，帧 {frame_id} 多次重试失败，可能遗漏识别")

            except Exception as e:
                consecutive_errors += 1
                logger.error(f"❌ [Worker {worker_id}] YOLO 检测异常: {str(e)} (连续错误: {consecutive_errors})",
                             exc_info=True)
                if consecutive_errors >= max_consecutive_errors:
                    logger.error(f"❌ [Worker {worker_id}] 连续错误过多，等待10秒后继续...")
                    time.sleep(10)
                    consecutive_errors = 0

        except Exception as e:
            consecutive_errors += 1
            logger.error(f"❌ [Worker {worker_id}] 检测线程异常: {str(e)} (连续错误: {consecutive_errors})",
                         exc_info=True)
            if consecutive_errors >= max_consecutive_errors:
                logger.error(f"❌ [Worker {worker_id}] 连续错误过多，等待10秒后继续...")
                time.sleep(10)
                consecutive_errors = 0
            else:
                time.sleep(1)

    logger.info(f"🤖 YOLO 检测线程 {worker_id} 停止")


# 排序器已移除，新架构中不需要
# 旧的推送器已移除，新架构中推帧器功能集成在缓流器中


def signal_handler(sig, frame):
    """信号处理器"""
    logger.info("\n🛑 收到停止信号，正在关闭所有服务...")
    stop_event.set()

    # 停止 ffmpeg 推流
    global ffmpeg_process
    if ffmpeg_process:
        try:
            ffmpeg_process.terminate()
            ffmpeg_process.wait(timeout=5)
        except:
            if ffmpeg_process.poll() is None:
                ffmpeg_process.kill()

    # 等待所有线程结束
    if buffer_streamer_thread:
        buffer_streamer_thread.join(timeout=5)
    if extractor_thread:
        extractor_thread.join(timeout=5)
    for yolo_thread in yolo_threads:
        yolo_thread.join(timeout=5)

    logger.info("✅ 所有服务已停止")
    sys.exit(0)


def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='视频流处理管道测试脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s                          # 使用默认视频 video2.mp4
  %(prog)s -v video/video1.mp4      # 指定视频文件
  %(prog)s --video /path/to/video.mp4  # 使用绝对路径
        """
    )
    parser.add_argument(
        '-v', '--video',
        type=str,
        default=None,
        help='视频文件路径（相对或绝对路径），默认为 video/video2.mp4'
    )

    args = parser.parse_args()

    # 设置视频文件路径
    global VIDEO_FILE
    if args.video:
        # 如果提供了参数，使用提供的路径
        video_path = Path(args.video)
        if video_path.is_absolute():
            VIDEO_FILE = video_path
        else:
            # 相对路径，相对于脚本目录
            VIDEO_FILE = video_root / video_path
    else:
        # 默认使用 video2.mp4
        VIDEO_FILE = video_root / "video" / "video2.mp4"

    # 验证视频文件是否存在
    if not VIDEO_FILE.exists():
        logger.error(f"❌ 视频文件不存在: {VIDEO_FILE}")
        logger.error(f"   请检查文件路径，或使用 -v 参数指定正确的视频文件")
        sys.exit(1)

    logger.info(f"📹 使用视频文件: {VIDEO_FILE}")
    return args


def main():
    """主函数"""
    # 解析命令行参数
    parse_arguments()

    logger.info("=" * 60)
    logger.info("🚀 服务管道测试脚本启动")
    logger.info("=" * 60)

    # 检查依赖
    if not check_dependencies():
        logger.error("❌ 依赖检查失败")
        sys.exit(1)

    # 加载 YOLO 模型
    if not load_yolo_model():
        logger.error("❌ YOLO 模型加载失败")
        sys.exit(1)

    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 启动 ffmpeg 推流
    if not start_ffmpeg_stream():
        logger.error("❌ ffmpeg 推流启动失败")
        sys.exit(1)

    # 等待一下确保流已建立
    time.sleep(3)

    # 启动缓流器线程
    logger.info("💾 启动缓流器线程...")
    global buffer_streamer_thread
    buffer_streamer_thread = threading.Thread(target=buffer_streamer_worker, daemon=True)
    buffer_streamer_thread.start()

    # 启动抽帧器线程
    logger.info("📹 启动抽帧器线程...")
    global extractor_thread
    extractor_thread = threading.Thread(target=extractor_worker, daemon=True)
    extractor_thread.start()

    # 启动 1 个 YOLO 检测线程
    logger.info("🤖 启动 YOLO 检测线程（1个）...")
    yolo_thread = threading.Thread(target=yolo_detection_worker, args=(1,), daemon=True)
    yolo_thread.start()
    yolo_threads.append(yolo_thread)

    # 启动 FFmpeg 监控线程（自动重启）
    logger.info("📡 启动 FFmpeg 监控线程...")
    ffmpeg_monitor_thread = threading.Thread(target=monitor_ffmpeg_stream, daemon=True)
    ffmpeg_monitor_thread.start()

    logger.info("=" * 60)
    logger.info("✅ 所有服务已启动")
    logger.info("=" * 60)
    logger.info(f"📹 输入流: {RTMP_INPUT_URL}")
    logger.info(f"📤 输出流: {RTMP_OUTPUT_URL}")
    logger.info("")
    logger.info("📊 缓流器缓冲区配置:")
    logger.info(f"   缓冲区大小: {BUFFER_SIZE} 帧 ({BUFFER_SECONDS:.2f} 秒 @ {SOURCE_FPS}fps)")
    logger.info(f"   最小缓冲: {MIN_BUFFER_FRAMES} 帧 ({MIN_BUFFER_SECONDS:.2f} 秒)")
    logger.info(f"   抽帧间隔: 每 {EXTRACT_INTERVAL} 帧抽一次")
    logger.info(f"   最大等待时间: {MAX_WAIT_TIME} 秒")
    logger.info("")
    logger.info("按 Ctrl+C 停止所有服务")
    logger.info("=" * 60)

    # 主循环：持续监控队列状态和系统健康
    try:
        last_stats_time = time.time()
        stats_interval = 10  # 每10秒输出一次统计

        while not stop_event.is_set():
            current_time = time.time()

            # 定期输出统计信息
            if current_time - last_stats_time >= stats_interval:
                with buffer_lock:
                    buffer_size = len(frame_buffer)

                queue_sizes = {
                    '抽帧': extract_queue.qsize(),
                    '检测': detection_queue.qsize(),
                    '推帧': push_queue.qsize()
                }

                # 检查进程状态
                ffmpeg_running = ffmpeg_process is not None and ffmpeg_process.poll() is None

                buffer_usage_percent = (buffer_size / BUFFER_SIZE * 100) if BUFFER_SIZE > 0 else 0
                logger.info(
                    f"📊 系统状态 - 队列: {queue_sizes}, 缓流器缓冲区: {buffer_size}/{BUFFER_SIZE} ({buffer_usage_percent:.1f}%), FFmpeg推流: {'运行中' if ffmpeg_running else '已停止'}")

                # 检查缓冲区是否过大（可能导致卡顿）
                if buffer_size > BUFFER_SIZE * 0.8:
                    logger.warning(
                        f"⚠️  缓流器缓冲区过大: {buffer_size}/{BUFFER_SIZE} ({buffer_usage_percent:.1f}%)，可能导致卡顿，正在加速清理...")
                elif buffer_size > BUFFER_SIZE * 0.6:
                    logger.warning(
                        f"⚠️  缓流器缓冲区较大: {buffer_size}/{BUFFER_SIZE} ({buffer_usage_percent:.1f}%)，建议监控")

                # 检查队列是否堆积过多
                if extract_queue.qsize() > 20:
                    logger.warning(f"⚠️  抽帧队列堆积过多: {extract_queue.qsize()}")
                if detection_queue.qsize() > 20:
                    logger.warning(f"⚠️  检测队列堆积过多: {detection_queue.qsize()}")
                if push_queue.qsize() > 20:
                    logger.warning(f"⚠️  推帧队列堆积过多: {push_queue.qsize()}")

                last_stats_time = current_time

            # 短暂休眠
            time.sleep(1)

    except KeyboardInterrupt:
        signal_handler(None, None)
    except Exception as e:
        logger.error(f"❌ 主循环异常: {str(e)}", exc_info=True)
        signal_handler(None, None)


if __name__ == "__main__":
    main()


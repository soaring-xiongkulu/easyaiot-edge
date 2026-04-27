#!/usr/bin/env python3
"""
测试脚本：验证缓流器、抽帧器、推帧器的逻辑（带目标追踪功能）
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

目标追踪优化：
1. 框近似度匹配：使用框相似度算法（IOU+中心点距离+形状相似度）匹配，不依赖识别结果
2. 框缓存机制：每个目标缓存上一次的框位置，避免框闪烁
3. 平滑显示：对于未检测到的目标，使用缓存的框进行平滑显示
4. 追踪ID管理：为每个目标分配唯一追踪ID，保持追踪连续性
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
from PIL import Image, ImageDraw, ImageFont

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

# 目标追踪配置
TRACKING_SIMILARITY_THRESHOLD = 0.2  # 框相似度匹配阈值，进一步降低以匹配快速移动的目标
TRACKING_MAX_AGE = 25  # 追踪目标最大存活帧数（未匹配时保留的帧数），增加以应对快速移动导致的短暂失配
TRACKING_SMOOTH_ALPHA = 0.25  # 框位置平滑系数（0-1），大幅降低以提升响应速度，新框占75%权重，快速跟上目标移动
TRACKING_CENTER_SIMILARITY_THRESHOLD = 150  # 中心点相似度阈值（像素），大幅增加阈值以匹配快速移动的目标
TRACKING_LEAVE_TIME_THRESHOLD = 0.5  # 确认物体离开所需的时间阈值（秒）
TRACKING_LEAVE_PERCENT_THRESHOLD = 0.0  # 确认物体离开时所需的检测比（从有到无），0表示只要检测比<=0就认为离开

# 绘制优化配置
LABEL_DRAW_INTERVAL = 10  # 文字标签绘制间隔（每N帧绘制一次文字标签，其他帧只绘制框），减少画面卡顿

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

# 目标追踪器（线程安全）
tracker_lock = threading.Lock()
tracker = None  # 将在初始化时创建


class SimpleTracker:
    """目标追踪器，使用框近似度算法匹配，不依赖识别结果"""

    def __init__(self, similarity_threshold=0.5, max_age=5, smooth_alpha=0.7):
        """
        初始化追踪器

        Args:
            similarity_threshold: 框相似度匹配阈值
            max_age: 追踪目标最大存活帧数（未匹配时保留的帧数）
            smooth_alpha: 框位置平滑系数（0-1），值越大越平滑
        """
        self.similarity_threshold = similarity_threshold
        self.max_age = max_age
        self.smooth_alpha = smooth_alpha
        self.tracks = {}  # {track_id: {'bbox': [x1, y1, x2, y2], 'class_id': int, 'class_name': str, 'confidence': float, 'age': int, 'last_seen': int, 'first_seen_time': float, 'leave_time': float, 'ex_trace_count': int, 'total_trace_count': int, 'last_trace_time': float, 'velocity': [vx, vy], 'last_bbox': [x1, y1, x2, y2]}}
        self.next_id = 1  # 下一个追踪ID
        self.lock = threading.Lock()

    def calculate_center_similarity(self, center1, center2, threshold_distance=None):
        """
        计算两个中心点的相似度（基于距离）

        Args:
            center1: 中心点1 (x, y)
            center2: 中心点2 (x, y)
            threshold_distance: 阈值距离（像素），小于此距离认为相似，如果为None则使用全局配置

        Returns:
            bool: 如果中心点相似返回True，否则返回False
        """
        if center1 is None or center2 is None:
            return False

        if threshold_distance is None:
            threshold_distance = TRACKING_CENTER_SIMILARITY_THRESHOLD

        x1, y1 = center1
        x2, y2 = center2

        # 计算欧氏距离
        distance = np.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)

        # 如果距离小于阈值，认为相似
        return distance <= threshold_distance

    def calculate_box_similarity(self, box1, box2):
        """
        计算两个框的相似度（基于IOU、中心点距离、形状相似度）
        不依赖类别，只根据框的位置和形状判断
        """
        xmin1, ymin1, xmax1, ymax1 = box1
        xmin2, ymin2, xmax2, ymax2 = box2
        w1, h1, w2, h2 = xmax1 - xmin1, ymax1 - ymin1, xmax2 - xmin2, ymax2 - ymin2

        # 计算IOU
        inter = max(0, min(xmax1, xmax2) - max(xmin1, xmin2)) * max(0, min(ymax1, ymax2) - max(ymin1, ymin2))
        union = w1 * h1 + w2 * h2 - inter
        if inter <= 0 or union <= 0:
            iou = 0
        else:
            iou = inter / union

        # 计算包围框
        xmin = min(xmin1, xmin2)
        ymin = min(ymin1, ymin2)
        xmax = max(xmax1, xmax2)
        ymax = max(ymax1, ymax2)
        w, h = xmax - xmin, ymax - ymin

        # 中心点距离相似度（0~1）
        # 优化：使用更宽松的距离计算，对快速移动的目标更宽容
        try:
            center1_x = (xmin1 + xmax1) / 2
            center1_y = (ymin1 + ymax1) / 2
            center2_x = (xmin2 + xmax2) / 2
            center2_y = (ymin2 + ymax2) / 2
            # 计算中心点距离
            center_distance = np.sqrt((center1_x - center2_x) ** 2 + (center1_y - center2_y) ** 2)
            # 使用框的对角线长度作为归一化基准，更宽容
            diagonal = np.sqrt(w ** 2 + h ** 2)
            if diagonal > 0:
                # 距离越近相似度越高，使用更宽松的衰减函数
                normalized_distance = center_distance / (diagonal * 1.5)  # 增加1.5倍容忍度
                dis_sim = max(0, 1 - normalized_distance)
            else:
                dis_sim = 1
        except (ZeroDivisionError, ValueError):
            dis_sim = 1

        # 形状相似度（降低权重，因为快速移动时形状可能变化）
        try:
            if w > 0 and h > 0:
                # 使用更宽松的形状相似度计算
                width_diff = abs(w1 - w2) / max(w, 1)
                height_diff = abs(h1 - h2) / max(h, 1)
                shape_sim = 1 - (width_diff + height_diff) / 2
                shape_sim = max(0, shape_sim)  # 确保在0-1范围内
            else:
                shape_sim = 1
        except (ZeroDivisionError, ValueError):
            shape_sim = 1

        # 综合相似度：对于快速移动的目标，更重视IOU和中心点距离，大幅降低形状权重
        # IOU * 0.6 + 中心点距离 * 0.35 + 形状 * 0.05（更重视位置匹配，忽略形状变化）
        return iou * 0.6 + dis_sim * 0.35 + shape_sim * 0.05

    def update(self, detections, frame_number, current_time=None):
        """
        更新追踪器，匹配检测结果和已有追踪目标

        Args:
            detections: 当前帧的检测结果列表，每个元素包含 'bbox', 'class_id', 'class_name', 'confidence'
            frame_number: 当前帧号
            current_time: 当前时间戳（秒），如果为None则使用time.time()

        Returns:
            tracked_detections: 带追踪ID的检测结果列表，包含时间信息
        """
        if current_time is None:
            current_time = time.time()

        with self.lock:
            # 更新所有追踪目标的age（未匹配的帧数）和检测计数
            tracks_to_remove = []
            for track_id, track in self.tracks.items():
                track['age'] += 1
                track['total_trace_count'] = track.get('total_trace_count', 0) + 1
                # 如果超过最大存活帧数，标记为删除
                if track['age'] > self.max_age:
                    tracks_to_remove.append(track_id)
                    continue

                # 基于时间阈值和检测比判断离开
                last_trace_time = track.get('last_trace_time', current_time)
                if current_time - last_trace_time > TRACKING_LEAVE_TIME_THRESHOLD:
                    # 计算检测比
                    ex_trace_count = track.get('ex_trace_count', 0)
                    total_trace_count = track.get('total_trace_count', 1)
                    trace_percent = ex_trace_count / total_trace_count if total_trace_count > 0 else 0

                    # 如果检测比 <= 阈值，认为离开，记录离开时间并删除
                    if trace_percent <= TRACKING_LEAVE_PERCENT_THRESHOLD:
                        track['leave_time'] = current_time
                        tracks_to_remove.append(track_id)
                        if frame_number % 50 == 0:
                            logger.info(
                                f"🚪 追踪目标 ID={track_id} 离开（检测比={trace_percent:.2f}, 离开时间={datetime.fromtimestamp(current_time).strftime('%H:%M:%S')}）")
                        continue

                    # 重置计数器
                    track['ex_trace_count'] = 0
                    track['total_trace_count'] = 0
                    track['last_trace_time'] = current_time

            # 删除标记为删除的追踪目标
            for track_id in tracks_to_remove:
                del self.tracks[track_id]

            # 如果没有检测结果，返回缓存的追踪目标（用于平滑显示）
            if not detections:
                tracked_detections = []
                for track_id, track in self.tracks.items():
                    # 计算持续时间
                    first_seen_time = track.get('first_seen_time', current_time)
                    duration = current_time - first_seen_time

                    tracked_detections.append({
                        'track_id': track_id,
                        'bbox': track['bbox'],
                        'class_id': track['class_id'],
                        'class_name': track['class_name'],
                        'confidence': track['confidence'],
                        'is_cached': True,  # 标记为缓存的框
                        'first_seen_time': first_seen_time,
                        'duration': duration
                    })
                return tracked_detections

            # 匹配检测结果和已有追踪目标
            matched_tracks = set()
            matched_detections = set()
            tracked_detections = []

            # 对每个检测结果，找到最佳匹配的追踪目标（使用框近似度+速度预测，不依赖类别）
            for det_idx, detection in enumerate(detections):
                best_similarity = 0
                best_track_id = None

                bbox = detection['bbox']
                # 计算检测框的中心点
                det_center = ((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)

                for track_id, track in self.tracks.items():
                    if track_id in matched_tracks:
                        continue

                    # 方法1：直接使用当前框位置计算相似度
                    similarity1 = self.calculate_box_similarity(bbox, track['bbox'])

                    # 方法2：如果目标有速度信息，使用预测位置计算相似度（对快速移动目标更有效）
                    similarity2 = similarity1
                    if 'velocity' in track and track['velocity'] is not None:
                        vx, vy = track['velocity']
                        # 预测目标当前位置（基于速度）
                        predicted_bbox = [
                            int(track['bbox'][0] + vx),
                            int(track['bbox'][1] + vy),
                            int(track['bbox'][2] + vx),
                            int(track['bbox'][3] + vy)
                        ]
                        similarity2 = self.calculate_box_similarity(bbox, predicted_bbox)

                    # 方法3：基于中心点距离的快速匹配（对快速移动目标更宽容）
                    similarity3 = similarity1
                    if 'last_bbox' in track and track['last_bbox'] is not None:
                        last_center = ((track['last_bbox'][0] + track['last_bbox'][2]) / 2,
                                       (track['last_bbox'][1] + track['last_bbox'][3]) / 2)
                        track_center = ((track['bbox'][0] + track['bbox'][2]) / 2,
                                        (track['bbox'][1] + track['bbox'][3]) / 2)
                        # 计算中心点距离
                        center_distance = np.sqrt((det_center[0] - track_center[0]) ** 2 +
                                                  (det_center[1] - track_center[1]) ** 2)
                        # 如果中心点距离在阈值内，给予额外相似度加成
                        if center_distance <= TRACKING_CENTER_SIMILARITY_THRESHOLD:
                            # 距离越近，加成越多（最多0.3）
                            distance_bonus = max(0, 0.3 * (1 - center_distance / TRACKING_CENTER_SIMILARITY_THRESHOLD))
                            similarity3 = min(1.0, similarity1 + distance_bonus)

                    # 使用三种方法中的最高相似度
                    similarity = max(similarity1, similarity2, similarity3)

                    if similarity > best_similarity and similarity >= self.similarity_threshold:
                        best_similarity = similarity
                        best_track_id = track_id

                if best_track_id is not None:
                    # 匹配成功，更新追踪目标
                    matched_tracks.add(best_track_id)
                    matched_detections.add(det_idx)

                    track = self.tracks[best_track_id]
                    # 使用平滑系数更新框位置，避免框跳跃
                    old_bbox = track['bbox']
                    new_bbox = bbox
                    smoothed_bbox = [
                        int(old_bbox[0] * self.smooth_alpha + new_bbox[0] * (1 - self.smooth_alpha)),
                        int(old_bbox[1] * self.smooth_alpha + new_bbox[1] * (1 - self.smooth_alpha)),
                        int(old_bbox[2] * self.smooth_alpha + new_bbox[2] * (1 - self.smooth_alpha)),
                        int(old_bbox[3] * self.smooth_alpha + new_bbox[3] * (1 - self.smooth_alpha))
                    ]

                    # 计算速度（用于预测下一帧位置，提升快速移动目标的匹配）
                    if 'last_bbox' in track and track['last_bbox'] is not None:
                        # 计算中心点移动速度
                        old_center = ((old_bbox[0] + old_bbox[2]) / 2, (old_bbox[1] + old_bbox[3]) / 2)
                        new_center = ((new_bbox[0] + new_bbox[2]) / 2, (new_bbox[1] + new_bbox[3]) / 2)
                        # 使用指数移动平均更新速度，平滑速度变化
                        velocity_alpha = 0.7  # 速度平滑系数
                        if 'velocity' in track and track['velocity'] is not None:
                            old_velocity = track['velocity']
                            new_velocity = [
                                old_velocity[0] * velocity_alpha + (new_center[0] - old_center[0]) * (
                                            1 - velocity_alpha),
                                old_velocity[1] * velocity_alpha + (new_center[1] - old_center[1]) * (
                                            1 - velocity_alpha)
                            ]
                        else:
                            new_velocity = [new_center[0] - old_center[0], new_center[1] - old_center[1]]
                        track['velocity'] = new_velocity
                    else:
                        # 首次匹配，初始化速度
                        track['velocity'] = [0, 0]

                    # 保存上一帧的框位置（用于速度计算）
                    track['last_bbox'] = old_bbox.copy()

                    # 获取首次出现时间（如果不存在则使用当前时间）
                    first_seen_time = track.get('first_seen_time', current_time)

                    track['bbox'] = smoothed_bbox
                    track['class_id'] = detection['class_id']
                    track['class_name'] = detection['class_name']
                    track['confidence'] = detection['confidence']
                    track['age'] = 0  # 重置age
                    track['last_seen'] = frame_number
                    track['first_seen_time'] = first_seen_time
                    # 更新检测计数（匹配成功，检测到）
                    track['ex_trace_count'] = track.get('ex_trace_count', 0) + 1
                    track['last_trace_time'] = current_time

                    # 计算持续时间
                    duration = current_time - first_seen_time

                    tracked_detections.append({
                        'track_id': best_track_id,
                        'bbox': smoothed_bbox,
                        'class_id': detection['class_id'],
                        'class_name': detection['class_name'],
                        'confidence': detection['confidence'],
                        'is_cached': False,
                        'first_seen_time': first_seen_time,
                        'duration': duration
                    })
                else:
                    # 未匹配，创建新的追踪目标
                    new_track_id = self.next_id
                    self.next_id += 1

                    self.tracks[new_track_id] = {
                        'bbox': bbox,
                        'class_id': detection['class_id'],
                        'class_name': detection['class_name'],
                        'confidence': detection['confidence'],
                        'age': 0,
                        'last_seen': frame_number,
                        'first_seen_time': current_time,
                        'ex_trace_count': 1,  # 初始化检测计数
                        'total_trace_count': 1,  # 初始化总计数
                        'last_trace_time': current_time,  # 初始化最后追踪时间
                        'velocity': [0, 0],  # 初始化速度
                        'last_bbox': None  # 初始化上一帧框位置
                    }

                    tracked_detections.append({
                        'track_id': new_track_id,
                        'bbox': bbox,
                        'class_id': detection['class_id'],
                        'class_name': detection['class_name'],
                        'confidence': detection['confidence'],
                        'is_cached': False,
                        'first_seen_time': current_time,
                        'duration': 0.0
                    })

            # 对于未匹配的追踪目标，也添加到结果中（使用缓存的框）
            for track_id, track in self.tracks.items():
                if track_id not in matched_tracks:
                    # 计算持续时间
                    first_seen_time = track.get('first_seen_time', current_time)
                    duration = current_time - first_seen_time

                    tracked_detections.append({
                        'track_id': track_id,
                        'bbox': track['bbox'],
                        'class_id': track['class_id'],
                        'class_name': track['class_name'],
                        'confidence': track['confidence'],
                        'is_cached': True,  # 标记为缓存的框
                        'first_seen_time': first_seen_time,
                        'duration': duration
                    })

            return tracked_detections

    def get_all_tracks(self, current_time=None, frame_number=None):
        """
        获取所有当前追踪目标的缓存框信息（用于在未处理完成的帧上绘制）
        会自动清理超过最大存活帧数的追踪目标

        Args:
            current_time: 当前时间戳（秒），如果为None则使用time.time()
            frame_number: 当前帧号，如果提供则用于清理过期追踪目标（可选，主要用于日志）

        Returns:
            tracked_detections: 所有追踪目标的列表，包含缓存框信息
        """
        if current_time is None:
            current_time = time.time()

        tracked_detections = []
        with self.lock:
            # 清理过期的追踪目标（age 在 update 方法中更新，这里只检查并删除）
            tracks_to_remove = []
            for track_id, track in self.tracks.items():
                # 如果超过最大存活帧数，标记为删除
                if track['age'] > self.max_age:
                    tracks_to_remove.append(track_id)

            # 删除过期的追踪目标
            if tracks_to_remove:
                for track_id in tracks_to_remove:
                    del self.tracks[track_id]
                if frame_number is not None and frame_number % 50 == 0:
                    logger.info(f"🗑️  移除过期追踪目标: {len(tracks_to_remove)}个 (超过{self.max_age}帧未检测到)")

            # 返回剩余的追踪目标
            for track_id, track in self.tracks.items():
                # 计算持续时间
                first_seen_time = track.get('first_seen_time', current_time)
                duration = current_time - first_seen_time

                tracked_detections.append({
                    'track_id': track_id,
                    'bbox': track['bbox'].copy(),  # 复制框，避免修改原始数据
                    'class_id': track['class_id'],
                    'class_name': track['class_name'],
                    'confidence': track['confidence'],
                    'is_cached': True,  # 标记为缓存的框
                    'first_seen_time': first_seen_time,
                    'duration': duration
                })

        return tracked_detections


def put_chinese_text(img, text, position, font_scale=0.6, color=(0, 0, 0), thickness=1):
    """
    在OpenCV图像上绘制文本（支持中文，失败时使用英文fallback）

    Args:
        img: OpenCV图像 (numpy array, BGR格式)
        text: 要绘制的文本（支持中文）
        position: 文本位置 (x, y)
        font_scale: 字体大小
        color: 文本颜色 (B, G, R)
        thickness: 文本粗细

    Returns:
        修改后的图像
    """
    # 检查是否包含中文字符
    has_chinese = any('\u4e00' <= char <= '\u9fff' for char in text)

    # 如果不包含中文，直接使用OpenCV的putText（更快）
    if not has_chinese:
        try:
            cv2.putText(img, text, position, cv2.FONT_HERSHEY_SIMPLEX, font_scale, color, thickness)
            return img
        except:
            pass

    # 尝试使用PIL绘制中文
    try:
        # 将OpenCV图像转换为PIL图像
        img_pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        draw = ImageDraw.Draw(img_pil)

        # 尝试加载中文字体
        font = None
        try:
            font_paths = [
                '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
                '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
                '/System/Library/Fonts/PingFang.ttc',  # macOS
                'C:/Windows/Fonts/simhei.ttf',  # Windows
                'C:/Windows/Fonts/msyh.ttc',  # Windows
            ]
            for font_path in font_paths:
                if os.path.exists(font_path):
                    try:
                        font_size = int(font_scale * 30)
                        font = ImageFont.truetype(font_path, font_size)
                        break
                    except:
                        continue
        except:
            pass

        if font is None:
            font = ImageFont.load_default()

        # 绘制文本
        rgb_color = (color[2], color[1], color[0])  # BGR -> RGB
        draw.text(position, text, font=font, fill=rgb_color)

        # 将PIL图像转换回OpenCV图像
        img = cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)
        return img
    except Exception as e:
        # 如果PIL绘制失败，尝试将中文转换为英文或使用ASCII字符
        try:
            # 简单的翻译映射（常用词汇）
            translation_map = {
                '置信度': 'Conf',
                '开始': 'Start',
                '持续': 'Dur',
                '缓存': 'Cached',
                'ID:': 'ID:',
            }

            # 尝试翻译
            translated_text = text
            for cn, en in translation_map.items():
                translated_text = translated_text.replace(cn, en)

            # 如果还有中文字符，使用ASCII替代
            if any('\u4e00' <= char <= '\u9fff' for char in translated_text):
                # 移除所有中文字符，只保留ASCII
                translated_text = ''.join(char for char in translated_text if ord(char) < 128)

            # 使用OpenCV绘制英文文本
            cv2.putText(img, translated_text, position, cv2.FONT_HERSHEY_SIMPLEX, font_scale, color, thickness)
        except:
            # 最后的fallback：只绘制ASCII字符
            ascii_text = ''.join(char for char in text if ord(char) < 128)
            if ascii_text:
                cv2.putText(img, ascii_text, position, cv2.FONT_HERSHEY_SIMPLEX, font_scale, color, thickness)

    return img


def draw_tracked_detections(frame, tracked_detections, timestamp, frame_number=None, draw_labels=True):
    """
    在原始帧上绘制追踪目标的缓存框（用于未处理完成的帧）

    Args:
        frame: 原始帧（OpenCV图像，BGR格式）
        tracked_detections: 追踪目标列表，每个元素包含追踪信息
        timestamp: 当前时间戳
        frame_number: 当前帧号，用于控制文字标签绘制频率
        draw_labels: 是否绘制文字标签（如果为False，只绘制框）

    Returns:
        绘制后的帧
    """
    annotated_frame = frame.copy()

    # 根据帧号决定是否绘制文字标签（减少绘制频率以提升性能）
    should_draw_labels = draw_labels
    if frame_number is not None:
        should_draw_labels = draw_labels and (frame_number % LABEL_DRAW_INTERVAL == 0)

    for tracked_det in tracked_detections:
        x1, y1, x2, y2 = tracked_det['bbox']
        class_name = tracked_det['class_name']
        confidence = tracked_det['confidence']
        track_id = tracked_det.get('track_id', 0)
        is_cached = tracked_det.get('is_cached', True)  # 缓存框默认为True
        first_seen_time = tracked_det.get('first_seen_time', timestamp)
        duration = tracked_det.get('duration', 0.0)

        # 缓存框使用半透明绿色（缩小尺寸）
        color = (0, 200, 0)  # 稍暗的绿色
        thickness = 1  # 减小框的粗细从2到1
        alpha = 0.6  # 半透明

        # 画框（半透明）
        overlay = annotated_frame.copy()
        cv2.rectangle(overlay, (x1, y1), (x2, y2), color, thickness)
        cv2.addWeighted(overlay, alpha, annotated_frame, 1 - alpha, 0, annotated_frame)

        # 只在需要时绘制文字标签（减少绘制频率以提升性能）
        if should_draw_labels:
            # 格式化时间信息
            start_time_str = datetime.fromtimestamp(first_seen_time).strftime("%H:%M:%S")
            duration_str = f"{duration:.1f}s"

            # 画标签（包含追踪ID、时间信息和持续时间）- 使用英文避免中文显示问题（缩小字体）
            label_lines = [
                f"ID:{track_id} {class_name}",
                f"Conf: {confidence:.2f}",
                f"Start: {start_time_str}",
                f"Dur: {duration_str}"
            ]

            # 计算标签总高度（缩小字体和行高）
            font_scale = 0.4  # 减小字体大小从0.6到0.4
            line_height = 12  # 减小行高从18到12
            label_height = len(label_lines) * line_height + 6  # 减小内边距从10到6

            # 估算标签宽度（缩小）
            label_width = 0
            for line in label_lines:
                estimated_width = len(line) * 8  # 减小字符宽度估算从12到8
                label_width = max(label_width, estimated_width)

            # 标签背景
            label_bg_y1 = max(0, y1 - label_height)
            label_bg_y2 = y1
            label_bg_x1 = x1
            label_bg_x2 = min(annotated_frame.shape[1], x1 + label_width + 15)
            cv2.rectangle(annotated_frame, (label_bg_x1, label_bg_y1), (label_bg_x2, label_bg_y2), color, cv2.FILLED)

            # 绘制标签文本（使用中文绘制函数）
            y_offset = y1 - 8
            for line in reversed(label_lines):  # 从下往上绘制
                annotated_frame = put_chinese_text(
                    annotated_frame,
                    line,
                    (x1 + 8, y_offset),
                    font_scale=font_scale,
                    color=(0, 0, 0),  # 黑色文本
                    thickness=1
                )
                y_offset -= line_height

    return annotated_frame


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


def init_tracker():
    """初始化目标追踪器"""
    global tracker
    try:
        tracker = SimpleTracker(
            similarity_threshold=TRACKING_SIMILARITY_THRESHOLD,
            max_age=TRACKING_MAX_AGE,
            smooth_alpha=TRACKING_SMOOTH_ALPHA
        )
        logger.info("✅ 目标追踪器初始化成功")
        logger.info(
            f"   追踪配置: 相似度阈值={TRACKING_SIMILARITY_THRESHOLD}, 最大存活={TRACKING_MAX_AGE}帧, 平滑系数={TRACKING_SMOOTH_ALPHA}")
        return True
    except Exception as e:
        logger.error(f"❌ 目标追踪器初始化失败: {str(e)}", exc_info=True)
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

                        # 如果仍然未处理完成，使用追踪器的缓存框绘制原始帧
                        # 关键：一旦对象被识别，之后所有帧都要绘制框，不再输出原始帧
                        if next_output_frame in pending_frames:
                            if tracker is not None:
                                # 从追踪器获取所有追踪目标的缓存框（通过对象ID）
                                with buffer_lock:
                                    if next_output_frame in frame_buffer:
                                        original_frame = frame_buffer[next_output_frame]['frame'].copy()
                                        # 获取当前时间戳
                                        current_timestamp = frame_buffer[next_output_frame].get('timestamp',
                                                                                                time.time())

                                        # 从追踪器获取所有追踪目标的缓存框（传入帧号以清理过期目标）
                                        cached_tracks = tracker.get_all_tracks(current_time=current_timestamp,
                                                                               frame_number=next_output_frame)

                                        if cached_tracks:
                                            # 在原始帧上绘制追踪器的缓存框
                                            interpolated_frame = draw_tracked_detections(
                                                original_frame,
                                                cached_tracks,
                                                current_timestamp,
                                                frame_number=next_output_frame
                                            )
                                            frame_buffer[next_output_frame]['frame'] = interpolated_frame
                                            frame_buffer[next_output_frame]['processed'] = True
                                            frame_buffer[next_output_frame]['detections'] = cached_tracks
                                            if next_output_frame % 50 == 0:
                                                logger.info(
                                                    f"✅ 帧 {next_output_frame} 超时，使用追踪器缓存框绘制（{len(cached_tracks)}个目标）")
                                        else:
                                            # 如果没有缓存框，标记为已处理（避免输出原始帧）
                                            # 但保持原始帧不变（因为没有追踪目标需要绘制）
                                            frame_buffer[next_output_frame]['processed'] = True
                                            frame_buffer[next_output_frame]['detections'] = []
                                            if next_output_frame % 50 == 0:
                                                logger.info(
                                                    f"⚠️  帧 {next_output_frame} 处理超时，无追踪目标，保持原始帧")
                            else:
                                # 如果追踪器未初始化，标记为已处理（避免输出原始帧）
                                with buffer_lock:
                                    if next_output_frame in frame_buffer:
                                        frame_buffer[next_output_frame]['processed'] = True
                                        frame_buffer[next_output_frame]['detections'] = []
                                if next_output_frame % 50 == 0:
                                    logger.warning(f"⚠️  帧 {next_output_frame} 处理超时，追踪器未初始化")
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
                    is_processed = output_frame_data.get('processed', False)
                    buffer_size = len(frame_buffer)  # 在锁内记录缓冲区大小

                    # 获取当前时间戳
                    current_timestamp = output_frame_data.get('timestamp', time.time())

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

                # 关键修改：在输出前，检查追踪器是否有追踪目标
                # 如果有追踪目标，即使帧未处理，也要使用追踪器的缓存框绘制
                # 确保不再输出原始帧（没有框的帧）
                if not is_processed and tracker is not None:
                    # 从追踪器获取所有追踪目标的缓存框（传入帧号以清理过期目标）
                    cached_tracks = tracker.get_all_tracks(current_time=current_timestamp,
                                                           frame_number=next_output_frame)

                    if cached_tracks:
                        # 使用追踪器的缓存框绘制原始帧
                        output_frame = draw_tracked_detections(
                            output_frame.copy(),
                            cached_tracks,
                            current_timestamp,
                            frame_number=next_output_frame
                        )
                        is_processed = True  # 标记为已处理
                        if next_output_frame % 50 == 0:
                            logger.info(f"✅ 帧 {next_output_frame} 使用追踪器缓存框绘制（{len(cached_tracks)}个目标）")

                processed_status = "已处理" if is_processed else "原始"

                # 如果输出的是已处理的帧，更新插值用的上一帧结果
                if is_processed:
                    last_processed_frame = output_frame.copy()
                    # 获取检测结果（如果有）
                    if output_frame_data.get('detections'):
                        last_processed_detections = output_frame_data.get('detections', [])
                    elif tracker is not None:
                        # 如果没有检测结果，从追踪器获取（传入帧号以清理过期目标）
                        cached_tracks = tracker.get_all_tracks(current_time=current_timestamp,
                                                               frame_number=next_output_frame)
                        last_processed_detections = cached_tracks if cached_tracks else []

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

                # 准备检测结果用于追踪
                raw_detections = []
                if result.boxes is not None and len(result.boxes) > 0:
                    boxes = result.boxes.xyxy.cpu().numpy()  # x1, y1, x2, y2
                    confidences = result.boxes.conf.cpu().numpy()
                    class_ids = result.boxes.cls.cpu().numpy().astype(int)

                    for i, (box, conf, cls_id) in enumerate(zip(boxes, confidences, class_ids)):
                        x1, y1, x2, y2 = map(int, box)
                        class_name = yolo_model.names[cls_id]
                        raw_detections.append({
                            'class_id': int(cls_id),
                            'class_name': class_name,
                            'confidence': float(conf),
                            'bbox': [int(x1), int(y1), int(x2), int(y2)]
                        })

                # 使用追踪器更新追踪状态（即使没有检测结果也要调用，以获取缓存的追踪目标）
                if tracker is not None:
                    tracked_detections = tracker.update(raw_detections, frame_number, current_time=timestamp)
                else:
                    # 如果追踪器未初始化，直接使用原始检测结果
                    tracked_detections = [
                        dict(det, track_id=0, is_cached=False, first_seen_time=timestamp, duration=0.0) for det in
                        raw_detections]

                # 在图像上画框（包括追踪ID、时间信息）
                # 根据帧号决定是否绘制文字标签（减少绘制频率以提升性能）
                should_draw_labels = (frame_number % LABEL_DRAW_INTERVAL == 0)

                if tracked_detections:
                    for tracked_det in tracked_detections:
                        x1, y1, x2, y2 = tracked_det['bbox']
                        class_name = tracked_det['class_name']
                        confidence = tracked_det['confidence']
                        track_id = tracked_det.get('track_id', 0)
                        is_cached = tracked_det.get('is_cached', False)
                        first_seen_time = tracked_det.get('first_seen_time', timestamp)
                        duration = tracked_det.get('duration', 0.0)

                        # 根据是否为缓存框选择颜色和样式（缩小尺寸）
                        if is_cached:
                            # 缓存的框使用半透明绿色，表示使用上一帧的框
                            color = (0, 200, 0)  # 稍暗的绿色
                            thickness = 1  # 减小框的粗细从2到1
                            alpha = 0.6  # 半透明
                        else:
                            # 新检测的框使用实心绿色
                            color = (0, 255, 0)  # 绿色
                            thickness = 1  # 减小框的粗细从2到1
                            alpha = 1.0

                        # 画框
                        if is_cached:
                            # 半透明框
                            overlay = annotated_frame.copy()
                            cv2.rectangle(overlay, (x1, y1), (x2, y2), color, thickness)
                            cv2.addWeighted(overlay, alpha, annotated_frame, 1 - alpha, 0, annotated_frame)
                        else:
                            cv2.rectangle(annotated_frame, (x1, y1), (x2, y2), color, thickness)

                        # 只在需要时绘制文字标签（减少绘制频率以提升性能）
                        if should_draw_labels:
                            # 格式化时间信息
                            start_time_str = datetime.fromtimestamp(first_seen_time).strftime("%H:%M:%S")
                            duration_str = f"{duration:.1f}s"

                            # 画标签（包含追踪ID、时间信息和持续时间）- 使用英文避免中文显示问题
                            label_lines = [
                                f"ID:{track_id} {class_name}",
                                f"Conf: {confidence:.2f}",
                                f"Start: {start_time_str}",
                                f"Dur: {duration_str}"
                            ]

                            # 计算标签总高度（使用PIL字体估算，更准确）- 缩小字体
                            font_scale = 0.4  # 减小字体大小从0.6到0.4
                            line_height = 12  # 减小行高从18到12
                            label_height = len(label_lines) * line_height + 6  # 减小内边距从10到6

                            # 估算标签宽度（缩小）
                            label_width = 0
                            for line in label_lines:
                                # 粗略估算：中文字符约18像素宽，英文字符约10像素宽
                                estimated_width = len(line) * 8  # 减小字符宽度估算从12到8
                                label_width = max(label_width, estimated_width)

                            # 标签背景
                            label_bg_y1 = max(0, y1 - label_height)
                            label_bg_y2 = y1
                            label_bg_x1 = x1
                            label_bg_x2 = min(annotated_frame.shape[1], x1 + label_width + 15)
                            cv2.rectangle(annotated_frame, (label_bg_x1, label_bg_y1), (label_bg_x2, label_bg_y2),
                                          color, cv2.FILLED)

                            # 绘制标签文本（使用中文绘制函数）
                            y_offset = y1 - 8
                            for line in reversed(label_lines):  # 从下往上绘制
                                annotated_frame = put_chinese_text(
                                    annotated_frame,
                                    line,
                                    (x1 + 8, y_offset),
                                    font_scale=font_scale,
                                    color=(0, 0, 0),  # 黑色文本
                                    thickness=1
                                )
                                y_offset -= line_height

                        # 添加到检测结果
                        detections.append({
                            'track_id': track_id,
                            'class_id': tracked_det['class_id'],
                            'class_name': class_name,
                            'confidence': confidence,
                            'bbox': [x1, y1, x2, y2],
                            'timestamp': timestamp,
                            'frame_id': frame_id,
                            'frame_number': frame_number,
                            'is_cached': is_cached,
                            'first_seen_time': first_seen_time,
                            'duration': duration
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
        description='视频流处理管道测试脚本（带目标追踪功能）',
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

    # 初始化目标追踪器
    if not init_tracker():
        logger.error("❌ 目标追踪器初始化失败")
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
    logger.info("🎯 目标追踪配置:")
    logger.info(f"   相似度阈值: {TRACKING_SIMILARITY_THRESHOLD}")
    logger.info(f"   最大存活: {TRACKING_MAX_AGE} 帧")
    logger.info(f"   平滑系数: {TRACKING_SMOOTH_ALPHA}")
    logger.info("")
    logger.info("🎨 绘制优化配置:")
    logger.info(f"   文字标签绘制间隔: 每 {LABEL_DRAW_INTERVAL} 帧绘制一次（其他帧只绘制框）")
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


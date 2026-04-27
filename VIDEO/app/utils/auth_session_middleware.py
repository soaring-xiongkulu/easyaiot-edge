"""
请求进入业务前，将 Bearer / X-Authorization 中的访问令牌拿到 iot-system 校验（Redis 会话）。
通过环境变量启用，避免未配置网关地址时影响现有部署。

@author 翱翔的雄库鲁
"""
from __future__ import annotations

import logging
import os
import re
from typing import Optional

import requests
from flask import Flask, jsonify, request

logger = logging.getLogger(__name__)

# 监控录像直链：/video/record/space/{id}/video/{object}
_RECORD_SPACE_VIDEO = re.compile(r'^/video/record/space/\d+/video/')
# 抓拍空间图片直链：/video/snap/space/{id}/image/{object}
_SNAP_SPACE_IMAGE = re.compile(r'^/video/snap/space/\d+/image/')


def _extract_bearer() -> Optional[str]:
    auth = (
        request.headers.get('Authorization')
        or request.headers.get('X-Authorization')
        or ''
    ).strip()
    if auth.lower().startswith('bearer '):
        return auth[7:].strip() or None
    return None


def _is_bucket_objects_download(path: str) -> bool:
    """本地 MinIO 兼容下载：/api/v1/buckets/{bucket}/objects/download（供 img/video 标签直接访问）"""
    p = (path or '').rstrip('/')
    parts = p.split('/')
    return (
        len(parts) == 7
        and parts[1] == 'api'
        and parts[2] == 'v1'
        and parts[3] == 'buckets'
        and parts[5] == 'objects'
        and parts[6] == 'download'
    )


def _is_public_media_get(path: str, method: str) -> bool:
    """VIDEO 侧可直接在浏览器中加载的图片/视频 GET（无 Authorization 头）"""
    if method != 'GET':
        return False
    if path.startswith('/video/alert/static/'):
        return True
    if path in ('/video/alert/image', '/video/alert/record'):
        return True
    if _RECORD_SPACE_VIDEO.match(path):
        return True
    if _SNAP_SPACE_IMAGE.match(path):
        return True
    return False


def _should_skip_path(path: str) -> bool:
    if request.method == 'OPTIONS':
        return True
    # 内部服务心跳：由本机守护进程/子进程上报，不携带用户态 token
    # 默认放行，避免会话校验导致 401 造成服务被误判异常
    if path in (
        '/video/stream-forward/heartbeat',
        '/video/algorithm/heartbeat/realtime',
        '/video/algorithm/heartbeat/snap',
        '/video/algorithm/heartbeat/extractor',
        '/video/algorithm/heartbeat/sorter',
        '/video/algorithm/heartbeat/pusher',
    ):
        return True
    if _is_bucket_objects_download(path):
        return True
    if _is_public_media_get(path, request.method):
        return True
    skip = os.getenv('AUTH_SESSION_SKIP_PREFIXES', '/actuator/').strip()
    if not skip:
        return False
    for prefix in (p.strip() for p in skip.split(',') if p.strip()):
        if path.startswith(prefix):
            return True
    return False


def register_auth_session_check(app: Flask) -> None:
    enabled = os.getenv('AUTH_SESSION_VALIDATE', 'false').lower() == 'true'
    validate_url = os.getenv('AUTH_SESSION_VALIDATE_URL', '').strip()
    if not enabled:
        return
    if not validate_url:
        logger.warning(
            'AUTH_SESSION_VALIDATE=true 但未设置 AUTH_SESSION_VALIDATE_URL，跳过会话校验'
        )
        return
    timeout = float(os.getenv('AUTH_SESSION_VALIDATE_TIMEOUT', '3'))

    @app.before_request
    def _check_auth_session():  # type: ignore[no-redef]
        path = request.path or ''
        if _should_skip_path(path):
            return None
        token = _extract_bearer()
        if not token:
            return jsonify({'code': 401, 'msg': '未登录或令牌缺失'}), 401
        headers = {'Authorization': f'Bearer {token}'}
        tid = request.headers.get('tenant-id') or request.headers.get('Tenant-Id')
        if tid:
            headers['tenant-id'] = str(tid)
        try:
            r = requests.get(validate_url, headers=headers, timeout=timeout)
        except requests.RequestException as e:
            logger.warning('会话校验请求失败: %s', e)
            return jsonify({'code': 503, 'msg': '登录校验服务不可用'}), 503
        if r.status_code == 401:
            return jsonify({'code': 401, 'msg': '登录已失效，请重新登录'}), 401
        try:
            body = r.json()
        except Exception:
            return jsonify({'code': 401, 'msg': '登录校验失败'}), 401
        if r.status_code >= 200 and r.status_code < 300 and body.get('code') == 0:
            return None
        return jsonify(
            {'code': 401, 'msg': body.get('msg') or '登录已失效，请重新登录'}
        ), 401

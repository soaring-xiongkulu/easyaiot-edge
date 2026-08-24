"""FFmpeg 版本兼容：RTSP 超时参数等在 FFmpeg 8+ 有变更。"""
from __future__ import annotations

import subprocess
from typing import List, Optional

# FFmpeg 8+：-stimeout/-rw_timeout 已移除，统一为 -timeout（单位仍为微秒）
_FFMPEG_RTSP_OPEN_TIMEOUT_FLAG: Optional[str] = None
_FFMPEG_SUPPORTS_RW_TIMEOUT: Optional[bool] = None
_RTSP_DEMUXER_HELP: Optional[str] = None


def ffmpeg_option_missing(stderr: bytes, option: str = "") -> bool:
    err = (stderr or b"").decode(errors="replace")
    if "Unrecognized option" in err or "Option not found" in err:
        return True
    if option and f"Option {option} not found" in err:
        return True
    return False


def _rtsp_demuxer_help_text() -> str:
    """读取 ffmpeg RTSP demuxer 帮助，用于判断各版本支持的超时参数。"""
    global _RTSP_DEMUXER_HELP
    if _RTSP_DEMUXER_HELP is not None:
        return _RTSP_DEMUXER_HELP
    try:
        probe = subprocess.run(
            ["ffmpeg", "-hide_banner", "-h", "demuxer=rtsp"],
            capture_output=True,
            timeout=5,
        )
        _RTSP_DEMUXER_HELP = (probe.stdout or b"").decode(errors="replace")
    except Exception:
        _RTSP_DEMUXER_HELP = ""
    return _RTSP_DEMUXER_HELP


def _rtsp_demuxer_has_option(option: str) -> bool:
    name = option.lstrip("-")
    text = _rtsp_demuxer_help_text()
    return f"-{name}" in text


def ffmpeg_rtsp_open_timeout_flag() -> str:
    """返回当前 ffmpeg 支持的 RTSP 连接超时参数名。"""
    global _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG
    if _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG is not None:
        return _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG
    if _rtsp_demuxer_has_option("stimeout"):
        _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG = "-stimeout"
    else:
        _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG = "-timeout"
    return _FFMPEG_RTSP_OPEN_TIMEOUT_FLAG


def ffmpeg_supports_rw_timeout() -> bool:
    """FFmpeg 8+ 已移除 -rw_timeout，仅保留 -timeout 覆盖 socket I/O。"""
    global _FFMPEG_SUPPORTS_RW_TIMEOUT
    if _FFMPEG_SUPPORTS_RW_TIMEOUT is not None:
        return _FFMPEG_SUPPORTS_RW_TIMEOUT
    if _rtsp_demuxer_has_option("rw_timeout"):
        _FFMPEG_SUPPORTS_RW_TIMEOUT = True
        return _FFMPEG_SUPPORTS_RW_TIMEOUT
    # 帮助文本不可用时，回退到运行时探测（lavfi 轻量输入）
    try:
        probe = subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-rw_timeout",
                "1",
                "-f",
                "lavfi",
                "-i",
                "nullsrc=s=1x1:d=0.01",
                "-frames:v",
                "1",
                "-f",
                "null",
                "-",
            ],
            capture_output=True,
            timeout=8,
        )
        _FFMPEG_SUPPORTS_RW_TIMEOUT = not ffmpeg_option_missing(probe.stderr, "rw_timeout")
    except Exception:
        _FFMPEG_SUPPORTS_RW_TIMEOUT = False
    return _FFMPEG_SUPPORTS_RW_TIMEOUT


def ffmpeg_rtsp_timeout_args(open_us: int, io_us: int) -> List[str]:
    """按当前 ffmpeg 版本组装 RTSP 超时参数。"""
    open_flag = ffmpeg_rtsp_open_timeout_flag()
    if ffmpeg_supports_rw_timeout():
        return [open_flag, str(open_us), "-rw_timeout", str(io_us)]
    # FFmpeg 8：-timeout 同时覆盖连接与读写，取较大值
    return [open_flag, str(max(open_us, io_us))]

#!/usr/bin/env bash
# 在控制面下载 FFmpeg 静态二进制包（BtbN/FFmpeg-Builds），供无外网节点离线安装
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${FFMPEG_ARCH:-x86_64}"
EASYAIOT_ROOT="$(cd "${ROOT}/.." && pwd)"
BASE_URL="${FFMPEG_DOWNLOAD_BASE:-https://github.com/BtbN/FFmpeg-Builds/releases/download/latest}"

case "${ARCH}" in
  x86_64|amd64|linux64)
    ARCH="x86_64"
    TAR_NAME="ffmpeg-master-latest-linux64-gpl.tar.xz"
    ;;
  aarch64|arm64|linuxarm64)
    ARCH="arm64"
    TAR_NAME="ffmpeg-master-latest-linuxarm64-gpl.tar.xz"
    ;;
    *)
        echo "[ERROR] 不支持的 FFMPEG_ARCH=${ARCH}（支持 x86_64 / arm64）" >&2
        exit 1
        ;;
esac

if [ -z "${FFMPEG_CACHE_DIR:-}" ]; then
    if [ "$ARCH" = "arm64" ]; then
        FFMPEG_CACHE_DIR="${EASYAIOT_ROOT}/.build-cache/arm/video/ffmpeg"
    else
        FFMPEG_CACHE_DIR="${ROOT}/.bundle-ffmpeg/${ARCH}"
    fi
fi
CACHE_DIR="${FFMPEG_CACHE_DIR}"

mkdir -p "${CACHE_DIR}"
TAR_PATH="${CACHE_DIR}/${TAR_NAME}"
MARKER="${CACHE_DIR}/.ready"

print_step() { echo ">>> $*"; }
print_ok() { echo "[OK] $*"; }
print_err() { echo "[ERROR] $*" >&2; }

if [[ -f "${MARKER}" && -f "${TAR_PATH}" ]]; then
  size="$(stat -c%s "${TAR_PATH}" 2>/dev/null || stat -f%z "${TAR_PATH}" 2>/dev/null || echo 0)"
  if [[ "${size}" -gt 1048576 ]]; then
    print_ok "FFmpeg 离线包已就绪 arch=${ARCH} size=${size} path=${TAR_PATH}"
    exit 0
  fi
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  print_err "控制面需要 curl 或 wget 下载 FFmpeg 静态包"
  exit 1
fi

URL="${BASE_URL}/${TAR_NAME}"
print_step "Downloading ${URL} ..."
tmp="${TAR_PATH}.part"
rm -f "${tmp}"
if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 --connect-timeout 30 -o "${tmp}" "${URL}"
else
  wget -q -O "${tmp}" "${URL}"
fi
mv "${tmp}" "${TAR_PATH}"
size="$(stat -c%s "${TAR_PATH}" 2>/dev/null || stat -f%z "${TAR_PATH}" 2>/dev/null || echo 0)"
if [[ "${size}" -le 1048576 ]]; then
  print_err "下载文件过小，可能失败: ${TAR_PATH}"
  exit 1
fi
echo "${ARCH}" > "${MARKER}"
print_ok "Downloaded FFmpeg static bundle arch=${ARCH} (${size} bytes) -> ${TAR_PATH}"

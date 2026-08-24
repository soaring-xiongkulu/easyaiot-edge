#!/usr/bin/env bash
# 在无外网节点安装 FFmpeg 静态二进制（由 iot-node SSH 同步 tarball 后执行）
set -euo pipefail

INSTALL_DIR="${1:-/opt/easyaiot/tools/ffmpeg}"
TAR_PATH="${2:-}"

if [[ -z "${TAR_PATH}" || ! -f "${TAR_PATH}" ]]; then
  echo "INSTALL_FAIL: 缺少 FFmpeg tarball: ${TAR_PATH}" >&2
  exit 1
fi

echo "==> 安装 FFmpeg 至 ${INSTALL_DIR}"
sudo mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/cache"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

tar -xf "${TAR_PATH}" -C "${work}"
inner="$(find "${work}" -maxdepth 1 -type d -name 'ffmpeg-*' | head -1)"
if [[ -z "${inner}" || ! -d "${inner}/bin" ]]; then
  echo "INSTALL_FAIL: tarball 结构异常" >&2
  exit 1
fi

sudo cp -f "${inner}/bin/ffmpeg" "${inner}/bin/ffprobe" "${INSTALL_DIR}/bin/"
sudo chmod +x "${INSTALL_DIR}/bin/ffmpeg" "${INSTALL_DIR}/bin/ffprobe"

version="$("${INSTALL_DIR}/bin/ffmpeg" -version 2>/dev/null | head -1 || true)"
sudo tee "${INSTALL_DIR}/.installed" > /dev/null <<EOF
installed_at=$(date -Iseconds 2>/dev/null || date)
tar=${TAR_PATH}
version=${version}
EOF

# 可选：写入 profile.d，便于交互式 shell；工作负载通过 FFMPEG_PATH / PATH 注入
if [[ -d /etc/profile.d ]]; then
  sudo tee /etc/profile.d/easyaiot-ffmpeg.sh > /dev/null <<'PROFILE'
export PATH="/opt/easyaiot/tools/ffmpeg/bin:${PATH}"
export FFMPEG_PATH="/opt/easyaiot/tools/ffmpeg/bin/ffmpeg"
export FFPROBE_PATH="/opt/easyaiot/tools/ffmpeg/bin/ffprobe"
PROFILE
fi

echo "FFMPEG_OK: ${INSTALL_DIR}/bin/ffmpeg"
"${INSTALL_DIR}/bin/ffmpeg" -version | head -3

#!/usr/bin/env bash
# 临时禁用 Docker 镜像源并从 Docker Hub 直连拉取（解决 mirror 返回 not found/EOF）
set -e
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_JSON="/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] 备份当前配置: $DAEMON_JSON -> $BACKUP_JSON"
cp -a "$DAEMON_JSON" "$BACKUP_JSON"

echo "[INFO] 临时移除 registry-mirrors，改用 Docker Hub 直连..."
python3 << 'PYEOF'
import json
import sys
with open("/etc/docker/daemon.json", "r") as f:
    config = json.load(f)
old = config.get("registry-mirrors", [])
config["registry-mirrors"] = []
with open("/etc/docker/daemon.json", "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print("已移除的镜像源:", old)
PYEOF

echo "[INFO] 重启 Docker 使配置生效..."
systemctl restart docker

echo "[INFO] 等待 Docker 就绪..."
sleep 3

echo "[INFO] 清除本地 Docker 登录凭据（避免 authentication required 报错）..."
docker logout 2>/dev/null || true

echo "[INFO] 在项目目录拉取镜像: $SCRIPT_DIR"
cd "$SCRIPT_DIR"
docker compose pull

echo "[SUCCESS] 镜像拉取完成。是否恢复镜像源？(y/N)"
read -r ans
if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    echo "[INFO] 恢复镜像源配置..."
    cp -a "$BACKUP_JSON" "$DAEMON_JSON"
    systemctl restart docker
    echo "[SUCCESS] 已恢复并重启 Docker"
else
    echo "[INFO] 未恢复镜像源，当前使用 Docker Hub。若要恢复可执行: sudo cp $BACKUP_JSON $DAEMON_JSON && sudo systemctl restart docker"
fi

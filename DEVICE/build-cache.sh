#!/bin/bash
# DEVICE 已精简为仅 iot-system；根目录 Dockerfile 无多服务 build 缓存分段。
# 直接构建镜像即可（BuildKit 会自动利用层缓存）：
#   docker build --target iot-system -t iot-module-system-biz:latest .
set -e
echo "请使用: docker build --target iot-system -t iot-module-system-biz:latest ."
exit 0

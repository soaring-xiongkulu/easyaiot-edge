#!/bin/bash
# SRS 容器健康检查（ossrs/srs 镜像不含 curl/wget，使用 bash /dev/tcp 探测 HTTP API）
set -euo pipefail

exec 3<>/dev/tcp/127.0.0.1/1985
printf 'GET /api/v1/versions HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n' >&3

while IFS= read -r line; do
  line="${line//$'\r'/}"
  if [[ "$line" == HTTP/*" 200 "* ]]; then
    exit 0
  fi
  [[ -z "$line" ]] && break
done <&3

exit 1

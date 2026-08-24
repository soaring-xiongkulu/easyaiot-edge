#!/usr/bin/env bash
# ============================================
# EasyAIoT-Edge 纯边缘形态（standalone）一键安装
# ============================================
# 流程：Docker 检查 → 媒体根准备 → 中间件（PG/Redis/SRS）→ RUNTIME 编译 → VIDEO → WEB → 校验
# 用法：
#   ./install.sh install    # 首次安装（默认）
#   ./install.sh clean      # 清理容器与镜像（中间件数据默认保留，确认后删除）
#   ./install.sh verify     # 仅健康校验
#   ./install.sh stop|start|restart|status|logs
#   ./install.sh build-runtime [--push] [--tag <t>] [--arch <a>] [--force-rebuild]
#                           # 构建 edge 独立 WEB 镜像（aiot-web-edge），透传参数给 runtime_image.sh；
#                           # 只构建/推送本仓自己的镜像，不触碰 easyaiot 其它镜像
# 环境变量：
#   EASYAIOT_MEDIA_ROOT     媒体根（默认 /mnt/easyaiot-media）
#   WEB_PORT                WEB HTTPS 端口（默认 8888）
#   EASYAIOT_EDGE_APP_TITLE     系统名（默认 EasyAIoT Edge 边缘智能平台，共用镜像免重建生效）
#   EASYAIOT_EDGE_DASHBOARD_TITLE 监控大屏标题（默认 EasyAIoT Edge 算法预警监控平台）
#   EASYAIOT_RUNTIME_SKIP=1 跳过 RUNTIME（C++）编译
# ============================================
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export EASYAIOT_ROOT="$SCRIPT_DIR"
export EASYAIOT_DEPLOY_PROFILE=edge
export EASYAIOT_EDGE_MORPHOLOGY=standalone
export EASYAIOT_MEDIA_ROOT="${EASYAIOT_MEDIA_ROOT:-/mnt/easyaiot-media}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

COMPOSE_CMD="docker compose"
$COMPOSE_CMD version >/dev/null 2>&1 || COMPOSE_CMD="docker-compose"

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "未检测到 docker，请先安装 Docker（含 compose 插件）"
        exit 1
    fi
    docker info >/dev/null 2>&1 || { error "Docker 守护进程未运行"; exit 1; }
    $COMPOSE_CMD version >/dev/null 2>&1 || { error "未检测到 docker compose"; exit 1; }
    success "Docker 环境就绪（profile=${EASYAIOT_DEPLOY_PROFILE}/${EASYAIOT_EDGE_MORPHOLOGY}）"
}

prepare_media_root() {
    info "准备媒体根 ${EASYAIOT_MEDIA_ROOT}（alert_images / playbacks / local-storage）"
    mkdir -p "${EASYAIOT_MEDIA_ROOT}"/{alert_images,playbacks,local-storage} 2>/dev/null \
        || sudo mkdir -p "${EASYAIOT_MEDIA_ROOT}"/{alert_images,playbacks,local-storage}
}

wait_healthy() {
    local container="$1" timeout="${2:-180}" waited=0
    until [ "$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)" = "healthy" ]; do
        sleep 5; waited=$((waited + 5))
        if [ "$waited" -ge "$timeout" ]; then
            error "等待 ${container} 健康超时（${timeout}s）"; docker logs --tail 50 "$container" || true; return 1
        fi
    done
    success "${container} 健康"
}

install_middleware() {
    info "启动中间件（PostgreSQL / Redis / SRS）..."
    (cd deploy && $COMPOSE_CMD up -d --remove-orphans)
    wait_healthy postgres-server 180
    wait_healthy redis-server 60
    wait_healthy srs-server 120
}

install_modules() {
    info "安装 VIDEO（含 RUNTIME 编译与 .env.docker 固化 edge 开关）..."
    bash VIDEO/install_linux.sh install

    info "安装 WEB（edge 构建参数：profile=mini + EDGE_STANDALONE=true，nginx.edge.conf）..."
    WEB_PORT="${WEB_PORT:-8888}" bash WEB/install_linux.sh install
}

verify_all() {
    local rc=0
    for c in postgres-server redis-server srs-server video-service web-service; do
        if docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null | grep -q running; then
            success "容器 ${c} 运行中"
        else
            error "容器 ${c} 未运行"; rc=1
        fi
    done
    if curl -sf http://127.0.0.1:6000/actuator/health >/dev/null; then
        success "VIDEO /actuator/health OK"
    else
        error "VIDEO /actuator/health 不可达"; rc=1
    fi
    if curl -skf "https://127.0.0.1:${WEB_PORT:-8888}/health" >/dev/null || curl -skf "https://127.0.0.1:${WEB_PORT:-8888}/" >/dev/null; then
        success "WEB 入口 OK（https://<本机IP>:${WEB_PORT:-8888}）"
    else
        error "WEB 入口不可达"; rc=1
    fi
    [ "$rc" -eq 0 ] && success "校验通过：默认账号 admin/admin123，登录页 https://<本机IP>:${WEB_PORT:-8888}"
    return "$rc"
}

module_ctl() {
    local cmd="$1"
    (cd deploy && $COMPOSE_CMD "$cmd")
    bash VIDEO/install_linux.sh "$cmd" || true
    bash WEB/install_linux.sh "$cmd" || true
}

clean_all() {
    check_docker
    info "清理 VIDEO / WEB 模块（容器、网络、镜像）..."
    bash VIDEO/install_linux.sh clean || true
    bash WEB/install_linux.sh clean || true

    info "下线中间件（PostgreSQL / Redis / SRS）..."
    (cd deploy && $COMPOSE_CMD down --remove-orphans) || true

    if [ -t 0 ]; then
        echo ""
        read -r -p "是否同时删除中间件数据卷（数据库/缓存数据将丢失）？(y/N) " _rm_volumes
        case "${_rm_volumes:-N}" in
            y|Y|yes|YES)
                info "删除中间件数据卷..."
                (cd deploy && $COMPOSE_CMD down -v --remove-orphans) || true
                ;;
            *) info "保留中间件数据卷（重新 install 可恢复数据）" ;;
        esac
    else
        info "非交互模式，保留中间件数据卷（重新 install 可恢复数据）"
    fi
    success "清理完成"
}

# build-runtime：委托 .scripts/docker/runtime_image.sh 构建 edge 独立 WEB 镜像（aiot-web-edge）。
# 仅覆盖本仓自己的业务镜像；easyaiot 的 aiot-web* 等其它镜像不受影响。
build_runtime_image() {
    check_docker
    local rt="${EASYAIOT_ROOT}/.scripts/docker/runtime_image.sh"
    if [ ! -f "$rt" ]; then
        error "未找到 runtime_image.sh: ${rt}"
        return 1
    fi
    shift  # 去掉 'build-runtime'，透传 --push / --tag / --arch / --force-rebuild 等
    bash "$rt" build --profile edge --module WEB "$@"
}

main() {
    case "${1:-install}" in
        install)
            check_docker
            prepare_media_root
            install_middleware
            install_modules
            verify_all
            ;;
        build-runtime) build_runtime_image "$@" ;;
        verify) verify_all ;;
        clean) clean_all ;;
        stop|start|restart|status) module_ctl "$1" ;;
        logs) (cd deploy && $COMPOSE_CMD logs); bash VIDEO/install_linux.sh logs || true; ;;
        help|--help|-h|*)
            sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            ;;
    esac
}

main "$@"

#!/bin/bash

# ============================================
# Redis 容器修复脚本
# ============================================
# 用于修复电脑重启或异常后 Redis 容器未运行/端口未暴露，导致后台连不上 Redis 的问题
# 错误示例：io.netty.channel.AbstractChannel$AnnotatedConnectException: 连接被拒绝: localhost/127.0.0.1:6379
# 若 Redis 因 AOF 损坏无法启动（Bad file format reading the append only file），会尝试修复或禁用 AOF 后重启
# 执行：停止并删除容器 -> 确保数据目录 -> 修复损坏的 AOF（如有）-> 重新创建并启动 -> 验证 PING
# 使用方法：
#   ./fix_redis.sh
#   ./fix_redis.sh -y   # 跳过确认
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Redis 密码（与 docker-compose.yml 中一致）
REDIS_PASSWORD="${REDIS_PASSWORD:-basiclab@iot975248395}"
REDIS_PORT="${REDIS_PORT:-6379}"

# 脚本所在目录（即 .scripts/docker）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info &> /dev/null; then
        print_error "Docker daemon 未运行或无法访问"
        exit 1
    fi
}

# 获取 docker compose 命令
get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# 显示当前 Redis 容器状态与端口
show_redis_status() {
    if docker ps -a --filter "name=redis-server" --format "{{.Names}}" | grep -q "redis-server"; then
        print_info "当前 redis-server 状态："
        docker ps -a --filter "name=redis-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        print_info "端口映射："
        docker port redis-server 2>/dev/null || print_warning "无法获取端口映射（可能未暴露或容器未运行）"
    else
        print_info "当前未发现 redis-server 容器"
    fi
}

# 检查本机 6379 是否可连接（用于诊断）
check_port_listen() {
    if command -v ss &> /dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":${REDIS_PORT} "; then
            print_info "本机端口 ${REDIS_PORT} 已被监听"
        else
            print_warning "本机端口 ${REDIS_PORT} 未被监听（Redis 可能未启动或未暴露）"
        fi
    fi
}

# 停止并移除 Redis 容器
stop_redis() {
    print_section "停止并移除 Redis 容器"

    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    # 1. 强制终止
    print_info "步骤 1: 强制终止 redis-server 容器..."
    if docker ps --filter "name=redis-server" --format "{{.Names}}" | grep -q "redis-server"; then
        docker kill redis-server 2>/dev/null && print_success "容器已强制终止" || print_info "容器未运行，跳过 kill"
    else
        print_info "容器未运行，跳过 kill"
    fi

    # 2. 优雅停止
    print_info "步骤 2: 优雅停止 redis-server 容器..."
    if docker ps -a --filter "name=redis-server" --format "{{.Names}}" | grep -q "redis-server"; then
        docker stop redis-server 2>/dev/null && print_success "容器已停止" || print_info "容器已停止"
    else
        print_info "容器不存在，跳过 stop"
    fi

    # 3. 使用 compose 清理
    print_info "步骤 3: 使用 docker compose 清理 Redis 服务..."
    cd "$SCRIPT_DIR"
    $compose_cmd stop Redis 2>/dev/null || true
    $compose_cmd rm -f Redis 2>/dev/null || true
    print_success "Redis 容器已清理"

    # 4. 确保容器完全移除
    print_info "步骤 4: 确保容器完全移除..."
    if docker ps -a --filter "name=redis-server" --format "{{.Names}}" | grep -q "redis-server"; then
        docker rm -f redis-server 2>/dev/null && print_success "残留容器已移除" || print_warning "无法移除残留容器"
    else
        print_success "容器已完全移除"
    fi

    sleep 2
}

# 确保 Redis 数据目录存在
prepare_redis_dirs() {
    print_section "检查 Redis 数据目录"

    local redis_data="${SCRIPT_DIR}/redis_data"
    local redis_data_dir="${redis_data}/data"
    local redis_log_dir="${redis_data}/logs"

    mkdir -p "$redis_data_dir" "$redis_log_dir"
    print_success "目录已就绪: redis_data/data, redis_data/logs"
}

# 修复损坏的 AOF（Redis 无法启动常见原因：Bad file format reading the append only file）
repair_redis_aof() {
    print_section "检查并修复 Redis AOF 文件（如有损坏）"

    local redis_data_dir="${SCRIPT_DIR}/redis_data/data"
    local aof_dir="${redis_data_dir}/appendonlydir"
    local backup_name="backup_aof_$(date +%Y%m%d_%H%M%S)"

    # 通过临时容器检查是否存在 appendonlydir（容器内权限足够）
    if ! docker run --rm -v "${redis_data_dir}:/data:rw" redis:7.2.9 ls /data/appendonlydir &>/dev/null; then
        print_info "未发现 appendonlydir 或目录为空，跳过 AOF 修复"
        return 0
    fi

    print_info "发现 AOF 目录，尝试使用 redis-check-aof --fix 修复（自动确认）..."
    if echo "y" | docker run --rm -i -v "${redis_data_dir}:/data:rw" redis:7.2.9 redis-check-aof --fix /data/appendonlydir/appendonly.aof.manifest 2>&1; then
        print_success "AOF 修复命令已执行"
        return 0
    fi

    print_warning "AOF 修复失败或未完全修复，将备份并移除损坏的 AOF 目录以便 Redis 能启动（会从 dump.rdb 恢复或全新启动）"
    mkdir -p "${SCRIPT_DIR}/redis_data/${backup_name}"
    # 在容器内完成备份移动，避免宿主机权限问题（appendonlydir 可能为 root 创建）
    if docker run --rm -v "${SCRIPT_DIR}/redis_data:/r:rw" redis:7.2.9 sh -c "mv /r/data/appendonlydir /r/${backup_name}/ 2>/dev/null && echo ok"; then
        if [ -d "${SCRIPT_DIR}/redis_data/${backup_name}/appendonlydir" ]; then
            print_success "已备份并移除 appendonlydir 到 redis_data/${backup_name}/appendonlydir"
        fi
    fi
    # 若仍存在则强制删除（容器内执行）
    if docker run --rm -v "${redis_data_dir}:/data:rw" redis:7.2.9 sh -c "rm -rf /data/appendonlydir" 2>/dev/null; then
        print_success "已移除损坏的 AOF 目录"
    else
        print_error "无法移除 AOF 目录，请手动执行: sudo rm -rf ${aof_dir}"
    fi
}

# 启动 Redis 容器（按 docker-compose 暴露 6379）
start_redis() {
    print_section "启动 Redis 容器"

    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    print_info "使用命令: $compose_cmd"
    cd "$SCRIPT_DIR"

    print_info "重新创建并启动 Redis 容器（绑定 127.0.0.1:${REDIS_PORT}）..."
    if $compose_cmd up -d --force-recreate --no-deps Redis 2>&1; then
        print_success "Redis 容器启动命令已执行"
    else
        print_error "启动 Redis 容器失败"
        return 1
    fi
}

# 等待并验证 Redis 可连接（PING PONG）
wait_and_verify_redis() {
    print_section "等待并验证 Redis 服务"

    local max_attempts=60
    local attempt=0

    print_info "等待 5 秒后开始检测（给 Redis 启动时间）..."
    sleep 5
    print_info "等待 Redis 就绪 (localhost:${REDIS_PORT})..."
    # 使用 REDISCLI_AUTH 传密码，避免 -a 中 @ 等字符被 shell 解析
    while [ $attempt -lt $max_attempts ]; do
        if docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" redis-server redis-cli ping 2>/dev/null | grep -q PONG; then
            print_success "Redis 容器内 PING 正常"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ $attempt -ge $max_attempts ]; then
        print_warning "Redis 未在容器内响应 PING，请检查: docker logs redis-server"
        print_info "最近日志："
        docker logs redis-server 2>&1 | tail -20
        return 1
    fi

    # 从宿主机再测一次（模拟后台连 localhost:6379）
    print_info "从宿主机验证 localhost:${REDIS_PORT} 可连接..."
    if command -v redis-cli &> /dev/null; then
        if REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h 127.0.0.1 -p "$REDIS_PORT" --no-auth-warning ping 2>/dev/null | grep -q PONG; then
            print_success "宿主机 localhost:${REDIS_PORT} 连接 Redis 成功（PING PONG）"
            return 0
        fi
    fi
    # 无 redis-cli 时用 nc 检测端口
    if command -v nc &> /dev/null; then
        if nc -z 127.0.0.1 "$REDIS_PORT" 2>/dev/null; then
            print_success "宿主机端口 ${REDIS_PORT} 已开放，Redis 可连接"
            return 0
        fi
    fi
    print_warning "无法从宿主机执行 redis-cli/nc 验证，请手动测试: redis-cli -h 127.0.0.1 -p ${REDIS_PORT} -a '<password>' ping"
    return 0
}

# 支持 -y 跳过确认
if [[ "${1:-}" == "-y" ]] || [[ "${1:-}" == "--yes" ]]; then
    SKIP_CONFIRM=1
fi

# 主流程
run_fix() {
    check_docker
    show_redis_status
    check_port_listen
    echo ""
    stop_redis
    prepare_redis_dirs
    repair_redis_aof
    start_redis
    wait_and_verify_redis
    print_section "修复完成"
    print_success "Redis 修复脚本执行完成"
    echo ""
    show_redis_status
    echo ""
    print_info "连接说明："
    print_info "  地址: 127.0.0.1 或 localhost，端口: ${REDIS_PORT}"
    print_info "  若后台在 Docker 同一 compose 内，请使用主机名 Redis 和端口 6379"
    print_info "  若仍有问题，请查看: docker logs redis-server"
}

# 主函数（交互式）
main() {
    print_section "Redis 容器修复脚本"

    print_info "此脚本将："
    print_info "  1. 停止并移除现有 redis-server 容器"
    print_info "  2. 确保 redis_data 目录存在"
    print_info "  3. 若存在损坏的 AOF 则尝试修复，失败则备份并移除以便 Redis 能启动"
    print_info "  4. 按 docker-compose 重新创建并启动 Redis（暴露 6379）"
    print_info "  5. 验证 Redis PING 及宿主机 localhost:6379 可连接"
    echo ""

    show_redis_status
    check_port_listen
    echo ""

    if [[ -z "${SKIP_CONFIRM:-}" ]]; then
        read -p "是否继续？(y/N): " -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_info "已取消操作"
            exit 0
        fi
    fi

    run_fix
}

# 入口
case "${1:-}" in
    -y|--yes) SKIP_CONFIRM=1 ;;
esac
main "$@"

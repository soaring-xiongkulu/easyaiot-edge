#!/bin/bash
# EasyAIoT 统一构建缓存（项目根目录 .build-cache）
# 用法: source 本脚本后调用 init_easyaiot_build_cache_dirs "$EASYAIOT_ROOT"
#
# 各业务模块宿主机缓存互不共享：
#   ai / video  → pip-cache、pip-wheels
#   device                      → m2/repository（Maven）
#   web / app / visualize       → pnpm-store、.build-stamp
#
# 环境变量:
#   BUILD_CACHE_UID  默认 1000
#   BUILD_CACHE_GID  默认 1000

: "${BUILD_CACHE_UID:=1000}"
: "${BUILD_CACHE_GID:=1000}"

EASYAIOT_PYTHON_CACHE_MODULES=(ai video)
EASYAIOT_BUILD_CACHE_MODULES=(ai video device web app visualize)

easyaiot_build_cache_base() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    echo "$(cd "$root" && pwd)/.build-cache"
}

easyaiot_normalize_module() {
    local module="${1,,}"
    case "$module" in
        ai|video|device|web|app|visualize) echo "$module" ;;
        *)
            echo "未知构建缓存模块: $1（支持: ${EASYAIOT_BUILD_CACHE_MODULES[*]}）" >&2
            return 1
            ;;
    esac
}

# 兼容旧名
easyaiot_normalize_python_cache_module() {
    easyaiot_normalize_module "$1"
}

module_cache_root() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module
    module="$(easyaiot_normalize_module "$2")" || return 1
    echo "$(easyaiot_build_cache_base "$root")/${module}"
}

python_module_cache_root() {
    module_cache_root "$@"
}

pip_cache_build_context_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="$2"
    local cache
    cache="$(python_module_cache_root "$root" "$module")/pip-cache"
    mkdir -p "${cache}/http"
    echo "$cache"
}

pip_wheels_build_context_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="$2"
    local cache
    cache="$(python_module_cache_root "$root" "$module")/pip-wheels"
    mkdir -p "$cache"
    echo "$cache"
}

arm_pip_wheels_build_context_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="$2"
    local cache
    module="$(easyaiot_normalize_module "$module")" || return 1
    cache="$(easyaiot_build_cache_base "$root")/arm/${module}/pip-wheels"
    mkdir -p "$cache"
    echo "$cache"
}

maven_repository_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local repo
    repo="$(module_cache_root "$root" device)/m2/repository"
    mkdir -p "$repo"
    echo "$repo"
}

pnpm_store_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="${2:-web}"
    local store
    module="$(easyaiot_normalize_module "$module")" || return 1
    store="$(module_cache_root "$root" "$module")/pnpm-store"
    mkdir -p "$store"
    echo "$store"
}

build_stamp_file_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="${2:-web}"
    local stamp
    module="$(easyaiot_normalize_module "$module")" || return 1
    stamp="$(module_cache_root "$root" "$module")/.build-stamp"
    mkdir -p "$(dirname "$stamp")"
    echo "$stamp"
}

web_build_stamp_file() {
    build_stamp_file_for "${1:-${EASYAIOT_ROOT:-.}}" web
}

app_build_stamp_file() {
    build_stamp_file_for "${1:-${EASYAIOT_ROOT:-.}}" app
}

visualize_build_stamp_file() {
    build_stamp_file_for "${1:-${EASYAIOT_ROOT:-.}}" visualize
}

app_pnpm_store_dir() {
    pnpm_store_dir_for "${1:-${EASYAIOT_ROOT:-.}}" app
}

visualize_pnpm_store_dir() {
    pnpm_store_dir_for "${1:-${EASYAIOT_ROOT:-.}}" visualize
}

# 兼容旧调用（默认 ai / device / web）
pip_cache_build_context_dir() {
    pip_cache_build_context_dir_for "${1:-${EASYAIOT_ROOT:-.}}" "ai"
}

pip_wheels_build_context_dir() {
    pip_wheels_build_context_dir_for "${1:-${EASYAIOT_ROOT:-.}}" "ai"
}

pip_wheels_dir() {
    pip_wheels_build_context_dir_for "$@"
}

arm_pip_wheels_build_context_dir() {
    arm_pip_wheels_build_context_dir_for "${1:-${EASYAIOT_ROOT:-.}}" "ai"
}

arm_pip_wheels_dir() {
    arm_pip_wheels_build_context_dir_for "$@"
}

maven_repository_dir() {
    maven_repository_dir_for "$@"
}

pnpm_store_dir() {
    pnpm_store_dir_for "${1:-${EASYAIOT_ROOT:-.}}" web
}

migrate_legacy_python_cache_if_needed() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local base legacy_pip legacy_wheels module target

    base="$(easyaiot_build_cache_base "$root")"
    legacy_pip="${base}/pip-cache"
    legacy_wheels="${base}/pip-wheels"

    if [ -d "${legacy_pip}/http" ] && [ -n "$(ls -A "${legacy_pip}/http" 2>/dev/null)" ]; then
        for module in "${EASYAIOT_PYTHON_CACHE_MODULES[@]}"; do
            target="$(pip_cache_build_context_dir_for "$root" "$module")/http"
            if [ ! -d "$target" ] || [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
                mkdir -p "$target"
                cp -a "${legacy_pip}/http/." "$target/" 2>/dev/null || true
            fi
        done
    fi

    if find "$legacy_wheels" -maxdepth 1 -type f 2>/dev/null | grep -q .; then
        for module in "${EASYAIOT_PYTHON_CACHE_MODULES[@]}"; do
            target="$(pip_wheels_build_context_dir_for "$root" "$module")"
            if ! find "$target" -maxdepth 1 -type f 2>/dev/null | grep -q .; then
                mkdir -p "$target"
                cp -a "${legacy_wheels}/." "$target/" 2>/dev/null || true
            fi
        done
    fi
}

migrate_legacy_device_web_cache_if_needed() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local base legacy_m2 legacy_pnpm target

    base="$(easyaiot_build_cache_base "$root")"
    legacy_m2="${base}/m2/repository"
    legacy_pnpm="${base}/pnpm-store"

    if [ -d "$legacy_m2" ] && [ -n "$(ls -A "$legacy_m2" 2>/dev/null)" ]; then
        target="$(maven_repository_dir_for "$root")"
        if [ ! -d "$target" ] || [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
            mkdir -p "$target"
            cp -a "${legacy_m2}/." "$target/" 2>/dev/null || true
        fi
    fi

    if [ -d "$legacy_pnpm" ] && [ -n "$(find "$legacy_pnpm" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        target="$(pnpm_store_dir_for "$root")"
        if [ ! -d "$target" ] || [ -z "$(find "$target" -mindepth 1 -print -quit 2>/dev/null)" ]; then
            mkdir -p "$target"
            cp -a "${legacy_pnpm}/." "$target/" 2>/dev/null || true
        fi
    fi
}

init_easyaiot_build_cache_dirs() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local base module
    base="$(easyaiot_build_cache_base "$root")"

    for module in "${EASYAIOT_PYTHON_CACHE_MODULES[@]}"; do
        pip_cache_build_context_dir_for "$root" "$module" >/dev/null
        pip_wheels_build_context_dir_for "$root" "$module" >/dev/null
        arm_pip_wheels_build_context_dir_for "$root" "$module" >/dev/null
    done
    arm_ffmpeg_cache_dir_for "$root" >/dev/null

    maven_repository_dir_for "$root" >/dev/null
    pnpm_store_dir_for "$root" web >/dev/null
    pnpm_store_dir_for "$root" app >/dev/null
    pnpm_store_dir_for "$root" visualize >/dev/null
    web_build_stamp_file "$root" >/dev/null
    app_build_stamp_file "$root" >/dev/null
    visualize_build_stamp_file "$root" >/dev/null

    migrate_legacy_python_cache_if_needed "$root"
    migrate_legacy_device_web_cache_if_needed "$root"
    migrate_legacy_arm_ffmpeg_cache_if_needed "$root"

    easyaiot_chown_build_cache "${base}"
}

# 兼容旧函数名（参数为 EASYAIOT_ROOT，非模块目录）
init_project_build_cache_dirs() {
    init_easyaiot_build_cache_dirs "$@"
}

print_build_cache_chown_hint() {
    echo "[build-cache] 提示: 若构建报权限错误，请执行: sudo chown -R ${BUILD_CACHE_UID}:${BUILD_CACHE_GID} $1"
}

# 规范化构建缓存属主为构建用户（整盘递归 chown，自愈历史 root 污染）。
# root 下 chown 必成功；非 root 但为属主时成功；否则打印提示（让用户手动 sudo chown）。
easyaiot_chown_build_cache() {
    local base="$1"
    command -v chown >/dev/null 2>&1 || return 0
    chown -R "${BUILD_CACHE_UID}:${BUILD_CACHE_GID}" "$base" 2>/dev/null \
        || print_build_cache_chown_hint "$base" 2>/dev/null || true
}

# 确保 docker-buildx 可用。Docker 23+ 默认启用 BuildKit，但缺 buildx 插件时
# docker build 会报: BuildKit is enabled but the buildx component is missing
ensure_docker_buildx() {
    if docker buildx version >/dev/null 2>&1; then
        return 0
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo "[build-cache] 警告: 未知架构 $(uname -m)，无法自动安装 buildx" >&2
            return 1
            ;;
    esac

    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y -qq docker-buildx-plugin >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q docker-buildx-plugin >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q docker-buildx-plugin >/dev/null 2>&1 || true
    fi
    docker buildx version >/dev/null 2>&1 && return 0

    local ver="${DOCKER_BUILDX_VERSION:-v0.19.3}"
    local dest_dirs=(
        "/usr/local/lib/docker/cli-plugins"
        "/usr/libexec/docker/cli-plugins"
        "${HOME}/.docker/cli-plugins"
    )
    local urls=(
        "https://github.com/docker/buildx/releases/download/${ver}/buildx-${ver}.linux-${arch}"
        "https://ghproxy.net/https://github.com/docker/buildx/releases/download/${ver}/buildx-${ver}.linux-${arch}"
        "https://mirror.ghproxy.com/https://github.com/docker/buildx/releases/download/${ver}/buildx-${ver}.linux-${arch}"
        "https://ghfast.top/https://github.com/docker/buildx/releases/download/${ver}/buildx-${ver}.linux-${arch}"
    )
    local dest url tmpf
    tmpf=$(mktemp 2>/dev/null || echo "/tmp/docker-buildx.$$")
    for dest in "${dest_dirs[@]}"; do
        mkdir -p "$dest" 2>/dev/null || continue
        for url in "${urls[@]}"; do
            if command -v curl >/dev/null 2>&1 \
                && curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o "$tmpf" 2>/dev/null \
                && [ -s "$tmpf" ]; then
                # ELF magic
                if head -c 4 "$tmpf" 2>/dev/null | grep -q $'\x7fELF'; then
                    install -m 0755 "$tmpf" "${dest}/docker-buildx" 2>/dev/null \
                        || cp "$tmpf" "${dest}/docker-buildx" && chmod +x "${dest}/docker-buildx"
                    rm -f "$tmpf"
                    docker buildx version >/dev/null 2>&1 && return 0
                fi
            fi
        done
    done
    rm -f "$tmpf"
    return 1
}

enable_docker_buildkit() {
    # 使用 BuildKit 内置 Dockerfile 前端，不依赖 docker.io/docker/dockerfile 镜像
    # （部分 registry 镜像站缺少该镜像，会导致 # syntax=docker/dockerfile:1.4 构建失败）
    if ! docker buildx version >/dev/null 2>&1; then
        echo "[build-cache] 未检测到 docker-buildx，尝试自动安装..." >&2
        ensure_docker_buildx || true
    fi
    if docker buildx version >/dev/null 2>&1; then
        export DOCKER_BUILDKIT=1
        export BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-plain}"
        return 0
    fi
    # 无 buildx 时禁用 BuildKit，避免报 "buildx component is missing"
    # 注意：含 --build-context / cache-from=type=local 的构建仍会失败，需先装 buildx
    echo "[build-cache] 警告: docker-buildx 不可用，已设置 DOCKER_BUILDKIT=0；请安装 docker-buildx-plugin 后重试" >&2
    export DOCKER_BUILDKIT=0
    unset BUILDKIT_PROGRESS
}

# 可选：仍使用外部 Dockerfile 语法镜像时预拉（export DOCKERFILE_FRONTEND_IMAGE=docker/dockerfile:1.4）
ensure_dockerfile_frontend() {
    local img="${DOCKERFILE_FRONTEND_IMAGE:-}"
    [ -n "$img" ] || return 0
    if ! docker image inspect "$img" >/dev/null 2>&1; then
        docker pull "$img" 2>/dev/null || \
            echo "[build-cache] 警告: 无法预拉 Dockerfile 前端 $img，请确认 BuildKit 已启用或网络可达" >&2
    fi
}

ARM_FFMPEG_TAR_NAME="ffmpeg-master-latest-linuxarm64-gpl.tar.xz"
ARM_FFMPEG_MIN_BYTES=1048576

arm_ffmpeg_cache_dir_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local dir
    dir="$(easyaiot_build_cache_base "$root")/arm/video/ffmpeg"
    mkdir -p "$dir"
    echo "$dir"
}

arm_ffmpeg_tar_path_for() {
    echo "$(arm_ffmpeg_cache_dir_for "$1")/${ARM_FFMPEG_TAR_NAME}"
}

arm_ffmpeg_file_size() {
    local path="$1"
    stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0
}

arm_ffmpeg_ready_for() {
    local path size
    path="$(arm_ffmpeg_tar_path_for "$1")"
    [ -f "$path" ] || return 1
    size="$(arm_ffmpeg_file_size "$path")"
    [ "$size" -gt "$ARM_FFMPEG_MIN_BYTES" ]
}

migrate_legacy_arm_ffmpeg_cache_if_needed() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local target legacy_dir legacy_staging size

    target="$(arm_ffmpeg_tar_path_for "$root")"
    if arm_ffmpeg_ready_for "$root"; then
        return 0
    fi

    legacy_dir="${root}/VIDEO/.bundle-ffmpeg/arm64/${ARM_FFMPEG_TAR_NAME}"
    legacy_staging="${root}/VIDEO/${ARM_FFMPEG_TAR_NAME}"

    for legacy_dir in \
        "${root}/VIDEO/.bundle-ffmpeg/arm64/${ARM_FFMPEG_TAR_NAME}" \
        "${root}/VIDEO/${ARM_FFMPEG_TAR_NAME}"; do
        if [ -f "$legacy_dir" ]; then
            size="$(arm_ffmpeg_file_size "$legacy_dir")"
            if [ "$size" -gt "$ARM_FFMPEG_MIN_BYTES" ]; then
                mkdir -p "$(dirname "$target")"
                cp -f "$legacy_dir" "$target" 2>/dev/null || true
                arm_ffmpeg_ready_for "$root" && return 0
            fi
        fi
    done
}

ensure_arm_ffmpeg_cached() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local cache_dir export_script

    init_easyaiot_build_cache_dirs "$root"
    migrate_legacy_arm_ffmpeg_cache_if_needed "$root"

    if arm_ffmpeg_ready_for "$root"; then
        echo "[build-cache] ARM ffmpeg 已就绪: $(arm_ffmpeg_tar_path_for "$root")"
        return 0
    fi

    export_script="${root}/VIDEO/export_ffmpeg_static.sh"
    if [ ! -f "$export_script" ]; then
        echo "[build-cache] 未找到 export_ffmpeg_static.sh，跳过 ARM ffmpeg 预下载" >&2
        return 1
    fi

    cache_dir="$(arm_ffmpeg_cache_dir_for "$root")"
    echo "[build-cache] ARM ffmpeg 缺失，下载到 ${cache_dir} ..."
    FFMPEG_CACHE_DIR="$cache_dir" FFMPEG_ARCH=arm64 /bin/bash "$export_script" || return 1
    easyaiot_chown_build_cache "$(easyaiot_build_cache_base "$root")"
}

# 将 .build-cache 中的 ffmpeg 包链入 VIDEO 构建上下文（供 Dockerfile.arm COPY）
stage_arm_ffmpeg_into_build_context() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local video_dir="${2:-${root}/VIDEO}"
    local staging cache_tar staging_size

    staging="${video_dir}/${ARM_FFMPEG_TAR_NAME}"
    cache_tar="$(arm_ffmpeg_tar_path_for "$root")"

    ensure_arm_ffmpeg_cached "$root" || true

    if ! arm_ffmpeg_ready_for "$root"; then
        touch "$staging" 2>/dev/null || true
        return 1
    fi

    staging_size="$(arm_ffmpeg_file_size "$staging")"
    if [ -f "$staging" ] && [ "$staging_size" -gt "$ARM_FFMPEG_MIN_BYTES" ]; then
        if cmp -s "$cache_tar" "$staging" 2>/dev/null; then
            echo "[build-cache] ffmpeg 构建上下文已就绪: ${staging}"
            return 0
        fi
    fi

    rm -f "$staging" 2>/dev/null || true
    if ln "$cache_tar" "$staging" 2>/dev/null || cp -f "$cache_tar" "$staging"; then
        echo "[build-cache] ffmpeg 已链入构建上下文: ${staging}（缓存: ${cache_tar}）"
        return 0
    fi
    return 1
}

arm_docker_images_dir() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local dir
    dir="$(easyaiot_build_cache_base "$root")/arm/docker-images"
    mkdir -p "$dir"
    echo "$dir"
}

arm_pip_wheels_stamp_file_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="$2"
    local wheels
    wheels="$(arm_pip_wheels_build_context_dir_for "$root" "$module")" || return 1
    echo "${wheels}/.requirements-flat-lines"
}

# ARM pip-wheels 是否已有完整离线包（供 build-runtime / install 脚本复用）
arm_pip_wheels_ready_for() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    local module="$2"
    local wheels stamp stamped_lines min_lines=8
    wheels="$(arm_pip_wheels_build_context_dir_for "$root" "$module")" || return 1
    stamp="$(arm_pip_wheels_stamp_file_for "$root" "$module")" || return 1

    if ! find "$wheels" -maxdepth 1 -type f \( -name "*.whl" -o -name "*.tar.gz" -o -name "*.zip" \) 2>/dev/null | grep -q .; then
        return 1
    fi
    if [ ! -f "$stamp" ]; then
        return 1
    fi
    stamped_lines=$(tr -d '[:space:]' < "$stamp" 2>/dev/null || echo 0)
    if [ "${stamped_lines:-0}" -lt "$min_lines" ]; then
        return 1
    fi
    return 0
}

# build-runtime 跨架构构建前：缺失则预下载 .build-cache/arm/{ai,video}/pip-wheels
# 用法: ensure_arm_python_wheels_cached [root] [module...]
#   未传 module 时默认 ai + video；可传 ai / video 限定范围（单模块 build-runtime 用）
ensure_arm_python_wheels_cached() {
    local root="${1:-${EASYAIOT_ROOT:-.}}"
    shift || true
    local -a modules=()
    if [ "$#" -gt 0 ]; then
        modules=("$@")
    else
        modules=("${EASYAIOT_PYTHON_CACHE_MODULES[@]}")
    fi
    local module cache_script base
    base="$(easyaiot_build_cache_base "$root")"

    init_easyaiot_build_cache_dirs "$root"

    for module in "${modules[@]}"; do
        if arm_pip_wheels_ready_for "$root" "$module"; then
            echo "[build-cache] [${module}] ARM pip-wheels 已就绪: $(arm_pip_wheels_build_context_dir_for "$root" "$module")"
            continue
        fi
        case "$module" in
            ai) cache_script="${root}/AI/cache_resources_arm.sh" ;;
            video) cache_script="${root}/VIDEO/cache_resources_arm.sh" ;;
            *) continue ;;
        esac
        if [ "${AUTO_CACHE_PIP:-1}" != "1" ] || [ ! -f "$cache_script" ]; then
            echo "[build-cache] [${module}] ARM pip-wheels 缺失且 AUTO_CACHE_PIP=0，跳过预下载" >&2
            continue
        fi
        echo "[build-cache] [${module}] ARM pip-wheels 缺失，预下载到 $(arm_pip_wheels_build_context_dir_for "$root" "$module") ..."
        if [ -x "$cache_script" ]; then
            "$cache_script" || /bin/bash "$cache_script" || true
        else
            /bin/bash "$cache_script" || true
        fi
    done

    easyaiot_chown_build_cache "$base"
}

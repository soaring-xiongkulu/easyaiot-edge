# BuildKit 内置前端，支持 RUN --mount
# 使用PyTorch官方镜像作为基础镜像（与AI服务保持一致）
# pip 缓存：.build-cache/video/（--build-context pip-cache / pip-wheels）
FROM pytorch/pytorch:2.9.0-cuda12.8-cudnn9-devel AS base

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    CUDA_VISIBLE_DEVICES=0 \
    QT_QPA_PLATFORM=xcb \
    QT_X11_NO_MITSHM=1 \
    PIP_UPGRADE_STRATEGY=only-if-needed

# 设置工作目录
WORKDIR /app

# ======================= 第一阶段：系统依赖安装 =======================
FROM base AS dependencies

# 镜像源配置（通过 --build-arg 传入，默认腾讯云）
ARG APT_MIRROR_URL=https://mirrors.tuna.tsinghua.edu.cn

# 配置镜像源和时区
RUN set -ex && \
    # 设置时区
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    # 配置apt镜像源
    if [ -n "${APT_MIRROR_URL}" ]; then \
        sed -i "s|http://.*archive.ubuntu.com|${APT_MIRROR_URL}|g" /etc/apt/sources.list && \
        sed -i "s|http://.*security.ubuntu.com|${APT_MIRROR_URL}|g" /etc/apt/sources.list; \
    fi

# 安装系统依赖包（apt 缓存跨次构建复用；含 ffmpeg 等 VIDEO 专用包）
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache-ai-video-devel \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=apt-lib-ai-video-devel \
    set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        vim \
        htop \
        gnupg \
        gcc \
        g++ \
        make \
        libgl1 \
        libglib2.0-0 \
        libpython3-dev \
        libusb-1.0-0 \
        libsm6 \
        libgomp1 \
        libgtk-3-0 \
        x11-apps \
        libgl1-mesa-glx \
        libxcb-xinerama0 \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libmagic1 \
        ffmpeg \
        iputils-ping \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ======================= 第二阶段：Python依赖安装 =======================
FROM dependencies AS python-deps

COPY requirements-docker.txt requirements-base.txt ./
COPY --from=pip-wheels . /opt/offline-pip
ARG OFFLINE_MODE=0
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ENV PIP_INDEX_URL=${PIP_INDEX_URL}

RUN --mount=type=bind,from=pip-cache,source=.,target=/mnt/pip-cache,rw \
    --mount=type=cache,target=/tmp/pip-wheels-build,id=pip-wheels-build-video \
    set -ex && \
    mkdir -p /mnt/pip-cache/http /tmp/pip-wheels-build && \
    rm -rf /mnt/pip-cache/wheels && \
    ln -sfn /tmp/pip-wheels-build /mnt/pip-cache/wheels && \
    export PIP_CACHE_DIR=/mnt/pip-cache && \
    pip install --upgrade pip -i "${PIP_INDEX_URL}" && \
    if [ -n "$(find /opt/offline-pip -maxdepth 1 -type f 2>/dev/null)" ]; then \
        py_tag="$(python -c 'import sys; print("cp{}{}".format(sys.version_info.major, sys.version_info.minor))')" && \
        if grep -Eq '^torch([<>= ].*)?$' requirements-docker.txt && ls /opt/offline-pip/torch-*.whl >/dev/null 2>&1; then \
            if ! ls /opt/offline-pip/torch-*-"${py_tag}"-*.whl >/dev/null 2>&1; then \
                echo "离线 wheel ABI 不匹配: ${py_tag}" && exit 1; \
            fi; \
        fi && \
        if [ "$OFFLINE_MODE" = "1" ]; then \
            echo "OFFLINE_MODE=1：仅使用 pip-wheels 离线安装..." && \
            pip install -r requirements-docker.txt --no-index --find-links /opt/offline-pip --prefer-binary; \
        elif pip install -r requirements-docker.txt --dry-run --no-index --find-links /opt/offline-pip --prefer-binary >/dev/null 2>&1; then \
            echo "pip-wheels 可覆盖全部依赖，离线安装..." && \
            pip install -r requirements-docker.txt --no-index --find-links /opt/offline-pip --prefer-binary; \
        else \
            echo "pip-wheels 与 requirements 未完全匹配，使用清华源 + find-links 混合安装..." && \
            pip install -r requirements-docker.txt --find-links /opt/offline-pip --prefer-binary -i "${PIP_INDEX_URL}"; \
        fi; \
    elif [ "$OFFLINE_MODE" = "1" ]; then \
        echo "OFFLINE_MODE=1 且无 pip-wheels，请先执行 cache_resources.sh" && exit 1; \
    else \
        echo "使用清华源 + 宿主机 pip-cache 在线安装..." && \
        pip install -r requirements-docker.txt -i "${PIP_INDEX_URL}"; \
    fi

# ======================= 第三阶段：应用部署 =======================
FROM python-deps AS runtime

# 复制项目源码
COPY . .

# 创建必要的目录结构
RUN set -ex && \
    mkdir -p \
        data/uploads \
        data/datasets \
        data/models \
        data/inference_results \
        temp_uploads \
        static/models && \
    # 设置执行权限
    chmod +x run.py docker-entrypoint.sh

# 创建非root用户和权限设置
RUN set -ex && \
    groupadd -r appuser && \
    useradd -r -m -g appuser appuser && \
    mkdir -p /home/appuser/.paddlex/temp /home/appuser/.config/Ultralytics && \
    chown -R appuser:appuser /app /home/appuser

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 6000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -fs http://localhost:6000/actuator/health > /dev/null || exit 1

# 启动前动态补全 onnxruntime-gpu 所需的 nvidia 库路径
ENTRYPOINT ["/app/docker-entrypoint.sh"]
# 启动命令
CMD ["python", "run.py"]


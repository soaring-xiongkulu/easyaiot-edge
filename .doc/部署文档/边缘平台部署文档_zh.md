# EasyAIoT Edge 部署文档（Docker 一键部署）

## 📋 目录

- [概述](#概述)
- [环境要求](#环境要求)
- [快速开始（推荐：一键脚本）](#快速开始推荐一键脚本)
- [脚本使用说明](#脚本使用说明)
- [模块说明](#模块说明)
- [服务端口](#服务端口)
- [部署后验证](#部署后验证)
- [边缘资源与裁剪建议](#边缘资源与裁剪建议)
- [常见问题](#常见问题)
- [日志管理](#日志管理)

## 概述

EasyAIoT Edge 是 EasyAIoT 主项目面向边缘场景的独立子项目，默认面向**单机/少量节点**部署：视频接入、推理、告警闭环优先本地完成，可在弱网/离线环境运行。

与主项目部署方式保持高度一致：采用 `Docker + Docker Compose`，并提供统一安装脚本进行一键部署。差异主要在：

- **资源目标不同**：Edge 默认以“资源受限”设备为目标（典型 **4GB 内存级别**跑通核心链路），因此更强调**最小服务集**与按需启用组件。
- **服务组合可裁剪**：边缘侧通常不需要云端大规模场景下的全部中间件；可根据摄像头路数、算法类型、是否需要时序/消息队列等进行裁剪。

## 环境要求

### 系统要求（建议）

- **操作系统**：
  - Linux（推荐 Ubuntu 22.04/24.04）
  - 国产 Linux（麒麟等）：仓库已提供对应脚本入口
  - ARM 边缘设备（如 RK3588）：仓库已提供 ARM 脚本入口（实际推理栈需按设备能力适配）
- **CPU**：
  - 最小：2 核
  - 推荐：4 核及以上（多路视频/多模型并发建议 6-8 核）
- **内存（关键）**：
  - **最小可跑通**：4GB（建议启用最小服务集，避免同时开启高占用组件）
  - **推荐**：8GB-16GB（更适合多路视频与多模型并发）
- **磁盘**：
  - 最小：50GB 可用空间
  - 推荐：100GB+（录像/抓拍/模型/日志会快速增长）
- **网络**：
  - 需能访问摄像头所在局域网
  - 如需拉取镜像，需能访问镜像仓库（或配置镜像源）

### 软件依赖

部署前请确保已安装：

1. **Docker**
2. **Docker Compose（v2）**

> 说明：Edge 的一键脚本会自动进行环境检查与网络创建，并对部分常见 Docker/文件系统问题给出诊断建议。

### Docker 权限（Linux）

如果提示无法访问 Docker daemon：

```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps
```

## 快速开始（推荐：一键脚本）

Edge 仓库提供统一安装脚本（Linux/macOS/部分国产发行版/ARM），命令与主项目保持一致。

### 最小服务集（4GB 级）快速跑通建议

在 4GB 内存设备上，建议用“先中间件 → 再业务模块”的方式跑通链路，并尽量减少一次性启动的模块数：

1. **先启动基础中间件（PostgreSQL/Redis/SRS）**
2. **再按需启动业务服务**（例如先启动 `VIDEO` + `AI`，确认推理链路 OK 后再启用 `DEVICE/WEB`）

如果你希望完全通过统一脚本一键启动，也可以先 `install` 后立刻观察内存占用，再决定是否停止/裁剪某些模块（见下文“边缘资源与裁剪建议”）。

### Linux（x86_64）

```bash
cd .scripts/docker
chmod +x install_linux.sh
./install_linux.sh install
./install_linux.sh verify
```

### Linux（ARM，例如 RK3588）

```bash
cd .scripts/docker
chmod +x install_linux_arm.sh
./install_linux_arm.sh install
./install_linux_arm.sh verify
```

### 国产 Linux（麒麟等）

```bash
cd .scripts/docker
chmod +x install_linux_kylin.sh
./install_linux_kylin.sh install
./install_linux_kylin.sh verify
```

### macOS（开发/测试）

```bash
cd .scripts/docker
chmod +x install_mac.sh
./install_mac.sh install
./install_mac.sh verify
```

> 注意：生产环境更推荐 Linux。macOS/Windows 更适合开发调试；涉及 `network_mode: host` 的组件在非 Linux 环境需要额外注意（详见常见问题）。

## 脚本使用说明

### 脚本位置

统一安装脚本位于 `.scripts/docker/`：

- `install_linux.sh`：Linux x86_64 一键部署入口
- `install_linux_arm.sh`：ARM 一键部署入口
- `install_linux_kylin.sh`：国产 Linux 适配入口
- `install_mac.sh`：macOS 一键部署入口

脚本会按依赖顺序编排模块（基础服务 → DEVICE → AI → VIDEO → WEB），并创建外部网络 `easyaiot-network`。

### 可用命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `install` | 首次安装并启动全部模块 | `./install_linux.sh install` |
| `start` | 启动全部模块 | `./install_linux.sh start` |
| `stop` | 停止全部模块 | `./install_linux.sh stop` |
| `restart` | 重启全部模块 | `./install_linux.sh restart` |
| `status` | 查看模块状态 | `./install_linux.sh status` |
| `logs` | 查看模块日志 | `./install_linux.sh logs` |
| `build` | 重新构建镜像 | `./install_linux.sh build` |
| `clean` | 清理容器/镜像/数据卷（危险） | `./install_linux.sh clean` |
| `update` | 更新并重启 | `./install_linux.sh update` |
| `verify` | 验证服务可用性 | `./install_linux.sh verify` |
| `check` | 检查 Docker/Compose/系统信息 | `./install_linux.sh check` |

### 仅部署基础中间件（不启动业务模块）

当你只想先把数据库/缓存/流媒体准备好时，可以直接使用中间件脚本：

```bash
cd .scripts/docker
chmod +x install_middleware_linux.sh
./install_middleware_linux.sh install
```

中间件脚本的常用命令与统一脚本类似：

```bash
./install_middleware_linux.sh start
./install_middleware_linux.sh stop
./install_middleware_linux.sh status
./install_middleware_linux.sh logs
```

> 说明：中间件默认编排服务列表为 `PostgreSQL`、`Redis`、`SRS`（以 `.scripts/docker/install_middleware_linux.sh` 当前实现为准）。

## 模块说明

### 基础服务（`.scripts/docker`）

基础服务通过 `.scripts/docker/docker-compose.yml` 启动，通常包含：

- **PostgreSQL**：业务数据库（首次启动会自动初始化 edge 所需库与 SQL）
- **Redis**：缓存与队列能力
- **SRS**：流媒体（默认 `network_mode: host`，便于边缘侧与摄像头/局域网互通）

数据库初始化脚本位于 `.scripts/docker/init-databases.sh`，默认创建并导入（首次启动时）：

- `iot-edge-ai20`
- `iot-edge-video20`
- `ruoyi-vue-pro20`（DEVICE 侧默认使用的业务库）

### 基础中间件自检（推荐）

基础服务启动后，可使用校验脚本快速检查容器状态/健康检查/端口连通性：

```bash
cd .scripts/docker
chmod +x verify_services.sh
./verify_services.sh
```

### DEVICE

`DEVICE/docker-compose.yml` 默认编排 `iot-system`（system-server）。在边缘设备上，建议优先按需启动最小后端能力，避免一次性拉起过多微服务导致内存压力。

### AI / VIDEO / WEB

这三个模块通常分别通过各模块目录内的 `docker-compose.yml` 启动（由统一脚本编排）。其中：

- **VIDEO**：常见会使用 `host` 网络以获得更好的局域网互通与 RTSP/RTMP 处理体验
- **AI**：推理服务资源占用受模型与并发影响较大，建议先以单模型/低并发验证链路

> 若你希望“最小可跑通”部署（4GB 级），建议优先只启动与当前场景相关的模块，并参考下文的裁剪建议。

## 服务端口

以下端口以脚本默认配置为准（不同模块的 `docker-compose.yml` 可能存在差异，请以实际 compose 文件为准）：

| 服务 | 端口 | 说明 |
|------|------|------|
| PostgreSQL | 5432 | 数据库 |
| Redis | 6379 | 缓存 |
| SRS RTMP | 1935 | 推流/拉流 |
| SRS HTTP-FLV | 8080 | 播放 |
| SRS API | 1985 | 管理 API |
| DEVICE（Gateway/后端） | 48080 | 后端入口（视模块配置） |
| VIDEO | 6000 | 视频服务 |
| AI | 5000 | AI 服务（视模块配置） |
| WEB | 8888 | 前端（视模块配置） |

## 部署后验证

建议按“中间件 → 业务模块 → 前端联通”的顺序进行验证，能快速定位问题属于哪一层。

### 1. 一键自检（推荐）

基础中间件启动后先跑一次自检脚本：

```bash
cd .scripts/docker
chmod +x verify_services.sh
./verify_services.sh
```

### 2. 容器与健康检查

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker compose -f .scripts/docker/docker-compose.yml ps
```

> 若 `STATUS` 显示 `unhealthy`，优先从对应容器日志入手（见下文“日志管理”）。

### 3. 端口连通性（示例）

在宿主机上快速验证基础端口（以脚本默认配置为准）：

```bash
# PostgreSQL
nc -zv 127.0.0.1 5432

# Redis（有密码时仅做端口检查）
nc -zv 127.0.0.1 6379

# SRS API（如果启用了 SRS 且为 host 网络）
curl -fsS "http://127.0.0.1:1985/api/v1/versions" >/dev/null && echo "SRS OK"
```

> 若系统没有 `nc`，可使用 `telnet` 或直接用浏览器访问 SRS API 地址验证。

### 4. 配置位置（排障高频）

- **基础中间件**：`.scripts/docker/docker-compose.yml`
- **数据库初始化**：`.scripts/docker/init-databases.sh` 与 `.scripts/postgresql/` 下 SQL
- **模块 compose**：各模块目录内的 `docker-compose.yml`
- **前端联调**：`WEB/.env.production`（`VITE_API_BASE_URL` 指向边缘机 IP/域名）

## 边缘资源与裁剪建议

### 4GB 内存“最小可跑通”建议

建议采用“先跑通链路，再逐步加组件”的方式：

- **优先启动**：
  - 基础中间件（PostgreSQL + Redis）
  - 必要的业务模块（如只做视频接入与推理：VIDEO + AI）
- **谨慎启用/按需启用**：
  - SRS（多路转发/播放场景再启用；且 `host` 网络对非 Linux 环境不友好）
  - 其他高占用/非必须组件（如消息队列、时序库等——若 edge 侧未使用可不启用）

### 常用资源调优方向（Edge 侧）

- **PostgreSQL**：当前 compose 对 `shared_buffers` 等参数有默认值，边缘设备上建议结合内存容量评估（避免数据库吃掉过多内存导致业务 OOM）。
- **Redis**：如果仅用于轻量缓存/队列，可结合业务量设置合理的淘汰策略与连接数上限。
- **Java（DEVICE）**：通过 `JAVA_OPTS` 控制堆内存（例如 `-Xms512m -Xmx512m` 起步），并按实际路数/告警量调整。
- **AI/VIDEO**：控制推理并发、Worker 数量、模型大小；先从 1 路开始逐步加。

### Java/Python 进程资源控制

边缘侧常见的“内存打满”来自 Java 堆与 Python Worker/推理并发：

- **Java（DEVICE）**：建议通过 `JAVA_OPTS` 或 compose 环境变量限制堆内存（例如 `-Xms512m -Xmx512m`，并按实际负载调优）
- **推理并发**：建议从 1 路/1 模型开始，逐步增加并发并观察内存/温度/吞吐

### 摄像头路数与磁盘规划

- **录像/抓拍**会快速占用磁盘，建议单独规划数据盘或挂载目录（脚本与 compose 里通常已将数据目录与宿主机目录映射）。
- 建议定期清理历史数据与日志，避免边缘设备磁盘被占满导致容器异常。

## 常见问题

### 1. PostgreSQL 权限问题

若遇到类似 `Permission denied` 的报错，可在 `.scripts/docker/` 目录内使用修复脚本（仓库已提供）：

```bash
cd .scripts/docker
./fix_postgresql_permissions.sh
```

也可参考 `.scripts/docker/Readme.md` 中的相关说明。

### 2. 外部网络 `easyaiot-network` 异常（宿主机 IP 变化后）

当宿主机网络变化导致容器加入网络失败，可尝试：

```bash
docker network rm easyaiot-network
docker network create easyaiot-network
cd .scripts/docker
docker compose restart
```

### 3. `network_mode: host` 在非 Linux 环境限制

`host` 网络在 Docker Desktop（macOS/Windows）上行为与 Linux 不一致。若需要在 macOS/Windows 进行开发测试：

- 优先以 Linux 环境验证完整链路
- 或在相关模块中调整网络模式与端口映射（以实际 `docker-compose.yml` 为准）

同时注意：`.scripts/docker/docker-compose.yml` 中 `SRS` 默认使用 `network_mode: host`，在 Windows/macOS 下可能需要改为端口映射模式后再使用。

### 4. 数据备份（PostgreSQL，Edge 三库）

Edge 仓库提供了基于容器内 `pg_dump` 的备份脚本：`.scripts/postgresql/backup_databases.sh`。默认会备份：

- `iot-edge-ai20`
- `iot-edge-video20`
- `ruoyi-vue-pro20`

使用方法：

```bash
cd .scripts/postgresql
chmod +x backup_databases.sh
./backup_databases.sh
```

备份输出目录：

- `.scripts/postgresql/backup/<时间戳>/`

> 建议：生产边缘机务必把该 `backup` 目录或数据库数据卷纳入周期性备份策略（并做好磁盘空间监控）。

## 日志管理

统一安装脚本会将执行日志写入 `.scripts/docker/logs/`，文件名带时间戳，便于排查问题。

同时，容器日志可通过脚本查看：

```bash
cd .scripts/docker
./install_linux.sh logs
```

---

**文档版本**：1.0  
**最后更新**：2026-04-07  
**适用仓库**：`easyaiot-edge`  


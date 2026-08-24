# EasyAIoT 纯边缘模式（edge/standalone）独立工程迁移文档

> 目标：把仓库中的"纯边缘形态"（`EASYAIOT_DEPLOY_PROFILE=edge` + `EASYAIOT_EDGE_MORPHOLOGY=standalone`）迁移为一个独立可构建、可部署、可维护的工程。本文档面向执行迁移的智能体/工程师，所有文件行号基于当前 main 分支（ec6b3d70）。

---

## 1. 迁移范围总览

### 1.1 纯边缘形态是什么

- 本机本地闭环：汇聚面（VIDEO）与算力（RUNTIME）同机，无云端、无联邦集群。
- `deploy_profile.sh:413` 的定位描述："纯边缘形态（汇聚面与算力同机，本地闭环），推荐 ≥ 2 GB 内存"。
- 安装入口：`.scripts/docker/install_linux.sh`，`./install_linux.sh edge install` 等价于强制 standalone 一键安装（`install_linux.sh:2168-2173`）。

### 1.2 保留 vs 裁弃清单

| 类别 | 保留 | 裁弃（不带入新工程） |
|---|---|---|
| 业务模块 | `VIDEO/`、`WEB/`、`RUNTIME/` | `DEVICE/`（全部 12 个 iot-* 微服务）、`APP/`、`AI/`、`RTC/`、`POST/`、`EDGE/`、`SENTINEL/`、`VISUALIZE/`、`TRANSFORM/`、`NODE/`、`PANEL/`、`IDEA/`、`HARNESS/`、`SITE/`、`COMPILE/`（仅打 PANEL 安装包，可弃） |
| 中间件 | PostgreSQL 18、Redis 7.4.8、SRS (ossrs/srs:5) | TDengine、EMQX、Kafka、Nacos、MinIO、Milvus、ZLMediaKit、Node-RED、FUXA（见 `deploy_profile.sh:105-122` `middleware_skipped_services`；edge 注释"仅保留 PostgreSQL / Redis / SRS；无 DEVICE → 无 Nacos/MinIO/EMQX/Kafka"） |
| 数据库 | 仅 `iot-video20` 一个库 | ruoyi-vue-pro、iot-device、iot-ai、iot-gb28181、iot-message、iot-node、iot-transform、iot-visualize 等全部不要 |
| 安装编排 | 精简版 compose + 安装脚本 | 完整 `MODULES` 顺序编排（edge 下仅执行 基础服务、VIDEO、WEB，见 `install_linux.sh:199-214` 与 `deploy_profile.sh:191-234`） |

裁弃依据（源码级判定，迁移时无需重新分析）：
- edge 禁 AI、RTC：`deploy_profile.sh:205-208`；禁 DEVICE：`:200-203`；禁 POST：`:185-189`（仅 standard/full）。
- APP/VISUALIZE/TRANSFORM 仅 full：`deploy_profile.sh:196`。
- PANEL/IDEA/HARNESS edge 显式置 0：`deploy_profile.sh:58-59`。

---

## 2. 需要迁移的模块详情

### 2.1 VIDEO（Python/Flask，核心编排服务，端口 6000，host 网络）

- compose：`VIDEO/docker-compose.yaml` — `network_mode: host`、`env_file: .env.docker`，挂载 `./:/app`、`${EASYAIOT_MEDIA_ROOT:-/mnt/easyaiot-media}:/mnt/easyaiot-media`、`../.scripts/minio:/model-seed-data:ro`（模型种子目录，flat 文件、不启 MinIO）、`DATABASE_URL=postgresql://...@localhost:5432/iot-video20`。
- **edge 开关契约**（由 `deploy_profile.sh:823-860` `apply_python_service_deploy_env` 生成 `VIDEO/.env.docker`，迁移后必须保留同等键值，建议直接固化为新工程 env 模板）：

| 变量 | 值 | 作用（代码位置） |
|---|---|---|
| `JAVA_BACKEND_URL` / `GATEWAY_URL` | `http://127.0.0.1:6000` | 回环到自身（无 Java 后端） |
| `MINIO_ENABLED` | `false` | 关 MinIO 客户端，`app/utils/service_urls.py:45` |
| `POST_ENABLED` | `false` | 旁路 POST 后处理，`app/utils/algo_mqtt_bus.py:205` |
| `ALGO_BUS_TRANSPORT` | `http` | 无 EMQX，告警走 HTTP，`app/utils/algo_mqtt_bus.py:43`、`app/services/runtime_config_service.py:1077-1090` |
| `ALERT_HOOK_URL` | `http://127.0.0.1:6000/video/alert/hook` | RUNTIME 告警直连落库 |
| `IOT_SINK_USE_GATEWAY` | `0` | 不走 Gateway→iot-sink，`app/services/post_process_sink_client.py:24`、`dvr_upload_service.py:20` |
| `ALERT_USE_DIRECT_PERSIST` / `ALERT_KEEP_LATEST` | `true` | 告警本地直写，`alert_hook_service.py:630` |
| `DVR_LOCAL_PERSIST` / `PLAYBACK_DELETE_AFTER_UPLOAD` | `1` / `false` | 录像本地闭环，不上传 |
| `SINK_DVR_HOOK_URL` / `IOT_SINK_MEDIA_HOOK_URL` | 空 | 同上 |
| `LOCAL_STORAGE_ROOT` | `/mnt/easyaiot-media/local-storage` | 本地对象存储根，`app/services/local_storage_service.py:23` |
| `MODEL_SEED_DATA_ROOT` | `/model-seed-data` | 模型种子目录，`local_storage_service.py:49` |
| `VIDEO_AUTH_ENABLED` | `1` | 自带鉴权 |
| `AUTH_CHECK_URL` | `http://127.0.0.1:6000/video/system/auth/get-permission-info` | 自检权限 |
| `STREAM_TICKET_SECRET` | 与 nginx 一致 | 流签名（见 §4） |

- **登录/权限不依赖 ruoyi**：VIDEO 自带 `app/auth/auth_manager.py`（iot-video20 库内 `CREATE TABLE IF NOT EXISTS users`，`auth_manager.py:103`）+ `app/auth/auth_api.py`（`/video/system/auth/*`、tenant/captcha 桩）。
- **数据库**：仅 `iot-video20`，种子 SQL `.scripts/postgresql/iot-video10.sql`（库名映射规约 `*10.sql → *20` 库，见 `install_middleware_linux.sh:4156-4170` 与 `.scripts/docker/init-databases.sh:11-62` 的容器内自动发现逻辑）。

### 2.2 WEB（Vue3 + Vite 纯前端 + nginx）

- **不含 Java 后端**；edge 下 nginx 上游全部指向 VIDEO:6000。
- nginx 配置：`WEB/conf/nginx.edge.conf`，关键路由：
  - `/admin-api(system|tenant|captcha|user/profile)` → `video-host:6000/video/system/...`
  - `/admin-api/model/`、`/dev-api/model/` → `video-host:6000/video/model/`（模型管理由 VIDEO 代理，替代被裁掉的 AI 模块）
  - `/dev-api/video/` → `video-host:6000/video/`
  - 其余 `/admin-api/`、`/dev-api/` → 友好空响应"edge规格未部署平台服务"
  - `/api/v1/buckets` → VIDEO `minio_proxy` 本地存储代理
  - SRS：API `srs-host:1985`、HTTP/WS-FLV `/ai|/live/*.flv` → `srs-host:8080` + secure_link 签名
  - GB28181、`/rtp/`（ZLM）拦截为空响应——迁移时**可顺手删除这些 dead 路由**
- 前端裁剪机制（迁移时原样保留）：
  - `WEB/src/utils/deployProfile.ts`：`VITE_GLOB_DEPLOY_PROFILE` 只识别 mini/standard/full，edge 复用 mini（`deploy_profile.sh:170-176`）
  - 独立 `VITE_GLOB_EDGE_STANDALONE=true` → `isEdgeStandaloneDeployProfile()`：隐藏 NFS 集群 Camera Tab、默认落地 `/camera/index?tab=1`、`isRtcEnabled/isTrainAdvancedEnabled=false`、登录免租户免验证码
  - 构建参数：`WEB/install_linux.sh:204-255`；edge 镜像标签 `web-service:latest-mini`（`:133`）；nginx 选择 `conf=./conf/nginx.edge.conf`（`:552-553`）
- 迁移建议：新工程可把 `VITE_GLOB_DEPLOY_PROFILE` 直接固化为 mini + `VITE_GLOB_EDGE_STANDALONE=true`，并删除 standard/full 专属前端代码路径（可选优化，非必需）。

### 2.3 RUNTIME（C++ 执行器，CMake + FFmpeg + ONNX Runtime）

- 角色：VIDEO 生成 `config/task_{id}.ini` 并拉起二进制（realtime/snap/patrol）；realtime 推带框流到 SRS `ai/{device_id}`。
- 与 VIDEO 的协议（必须整体保留）：
  - `VIDEO_BASE_URL=http://127.0.0.1:6000`
  - 心跳：`{VIDEO_BASE_URL}/video/algorithm/heartbeat/realtime`（patrol 用 `/heartbeat/patrol`，间隔 15s/10s）— `RUNTIME/install_linux.sh:1113-1156`、`VIDEO/app/services/runtime_config_service.py:796-800,962`
  - 告警：edge 下 HTTP 直连 `{VIDEO_BASE_URL}/video/alert/hook`（`runtime_config_service.py:1079-1090`）
- 构建：`VIDEO/scripts/ensure_runtime_cpp.sh`（VIDEO 安装时调用，`VIDEO/install_linux.sh:95-101`）；镜像/离线包预检 `.scripts/docker/runtime_cpp_bundle_common.sh`、`runtime_image.sh`（转发 `RUNTIME/build_runtime_matrix.sh`、`RUNTIME/scripts/preflight_runtime_bundle.sh`）。
- 模型：`RUNTIME/models` + 种子 `.scripts/minio/`（挂 `/model-seed-data`）；推理权重产物落 `LOCAL_STORAGE_ROOT`。

---

## 3. 需要迁移的中间件

只部署三个，直接从 `.scripts/docker/docker-compose.yml` 抽取对应 service 段：

| 中间件 | 镜像 | compose 行号 | 端口 | 数据卷 | 备注 |
|---|---|---|---|---|---|
| PostgreSQL | postgres:18 | `:52`（init）、`:70` | 5432 | `./db_data` | max_connections=10240；entrypoint 挂 `postgresql-entrypoint.sh` + `init-databases.sh` + `../postgresql` SQL 目录 |
| Redis | redis:7.4.8 | `:178` | 6379 | `./redis_data`（AOF） | 密码 `basiclab@iot975248395`（`:192`），迁移时建议改为可配置 |
| SRS | ossrs/srs:5 | `:339` | host 网络：1985(API)/8080(HTTP-FLV)/1935(RTMP) | `./srs_data/conf` + `${EASYAIOT_MEDIA_ROOT}:/data` | 健康检查 `srs-healthcheck.sh`、entrypoint `srs-entrypoint.sh` |

配套文件：
- `.scripts/postgresql/iot-video10.sql` — 唯一需要的种子 SQL（其余 8 个 SQL 全部不带）。
- `.scripts/docker/srs_data/` — SRS 配置。
- 初始化逻辑：`init-databases.sh`（容器内 `<名字>10.sql → 库 <名字>20` 自动发现 + 清空 iot-node 样例数据）可精简为只处理 iot-video，或原样带走（其他 SQL 不存在时自动跳过）。

**流约定（必须保持一致）**：
- 原画流：VIDEO 推 SRS `live/{device_id}`；AI 带框流：RUNTIME 推 `ai/{device_id}`。
- 播放签名：nginx secure_link `md5("$arg_e$uri <secret>")`，`nginx.edge.conf:74-76` 的 `$stream_secret` **必须等于** VIDEO 的 `STREAM_TICKET_SECRET`（当前值 `Zr1y9tiPBhB3FhFYUE0G1bWPiQ0Fgva`）。

---

## 4. 共享契约与关键路径

| 契约 | 内容 |
|---|---|
| 媒体根 | `EASYAIOT_MEDIA_ROOT`（默认 `/mnt/easyaiot-media`）：告警图 `alert_images/`、录像 `playbacks/`、本地对象存储 `local-storage/`（`deploy_profile.sh:73-76,789-794,842`） |
| 数据库 | 仅 `iot-video20`；VIDEO 自建 `users` 表，无 ruoyi 依赖 |
| 告警链路 | RUNTIME →（HTTP）→ VIDEO `/video/alert/hook` → 直写 iot-video20；无 MQTT/iot-sink |
| 心跳链路 | RUNTIME → VIDEO `/video/algorithm/heartbeat/{realtime|patrol}` |
| 对象存储 | MinIO 关闭，VIDEO `minio_proxy` + `LOCAL_STORAGE_ROOT` 本地实现 S3 兼容语义的最小子集（`/api/v1/buckets`） |
| 模型种子 | `.scripts/minio/` flat 目录 → 容器 `/model-seed-data` |

---

## 5. 脚本迁移方案

原仓库安装脚本深度耦合 `deploy_profile.sh`（`VIDEO/install_linux.sh:38-39`、`WEB/install_linux.sh:37-38`、`install_business_linux.sh:39-40` 均 `source` 它）。两个方案：

**方案 A（推荐）：固化 edge 配置，重写精简安装脚本**
- 新工程写一个独立的 `install.sh` + 精简 `docker-compose.yml`（PostgreSQL/PostgresSQL-init/Redis/SRS + VIDEO + WEB 六个 service），edge 开关键值直接写死在各模块 env/compose 中（§2.1 表格）。
- 优点：无死代码、无 full/mini 分支逻辑，后续维护面最小。
- 带走参考：`.scripts/docker/deploy_profile.sh`（edge 分支逻辑）、`edge_deploy_common.sh`（standalone 交互，可简化为无交互）、`install_middleware_linux.sh`（仅参考 DB 初始化段落 `:4121-4192`）、`install_linux.sh`（参考 edge 流程 `:1037-1106` 与 verify `:1881-1952`）。

**方案 B：原样带走脚本链**（`.scripts/docker/deploy_profile.sh` + `edge_deploy_common.sh` + `install_middleware_linux.sh` + `install_linux.sh` + `runtime_image.sh` + `runtime_cpp_bundle_common.sh` + `.scripts/media-cluster/nfs/resolve_media_root.sh` 依赖），保留多形态逻辑。
- 仅当新工程未来还打算合并回主仓库同步时选此方案。

无论哪个方案必须验证：`VIDEO/.env.docker` 生成结果与 §2.1 表格一致；`WEB` 构建带 `VITE_GLOB_DEPLOY_PROFILE=mini` + `VITE_GLOB_EDGE_STANDALONE=true`。

---

## 6. 迁移执行步骤（给执行智能体的操作清单）

1. **建仓**：新工程目录（建议名单 `easyaiot-edge`），初始化 git，保留原仓库 LICENSE。
2. **拷贝模块**（整体拷走，清掉 `node_modules/`、`dist/`、`__pycache__/`、`.venv/`、构建产物）：
   - `VIDEO/`、`RUNTIME/`、`WEB/`
3. **拷贝共享资产**（保持相对路径关系或同步修改引用）：
   - `.scripts/postgresql/iot-video10.sql` → 新工程 `deploy/postgresql/`
   - `.scripts/minio/`（模型种子）→ 新工程 `deploy/model-seed-data/`，并同步修改 `VIDEO/docker-compose.yaml` 中 `../.scripts/minio:/model-seed-data` 挂载路径
   - `.scripts/docker/srs_data/`、`srs-entrypoint.sh`、`srs-healthcheck.sh`、`postgresql-entrypoint.sh`、`init-databases.sh` → 新工程 `deploy/`
4. **编写新 compose**：从 `.scripts/docker/docker-compose.yml` 抽取 PostgreSQL(:52,:70)、Redis(:178)、SRS(:339) 三个 service 段，另建 `VIDEO`、`WEB` service（参考 `VIDEO/docker-compose.yaml` 与 `WEB/install_linux.sh` 的 docker run 参数）。
5. **固化 edge 环境**：按 §2.1 表格生成 `VIDEO/.env.docker`（模板化密码/密钥）；确认 `WEB` 构建 arg；确认 `nginx.edge.conf` 中 `$stream_secret` 与 `STREAM_TICKET_SECRET` 一致（改为同一 env 注入）。
6. **裁剪死代码（可选但建议）**：
   - WEB：删除 standard/full 专属页面分支、GB28181/ZLM/`/rtp/` 的 nginx 空响应路由、APP 相关埋点。
   - VIDEO：确认所有云端分支均由既有开关关闭（`MINIO_ENABLED`/`POST_ENABLED`/`IOT_SINK_USE_GATEWAY`/`ALGO_BUS_TRANSPORT`），无需改代码即可运行；如要瘦身可删 DEVICE/Gateway/EMQX 客户端代码路径。
   - RUNTIME：保留 standalone 形态逻辑（`RUNTIME/install_linux.sh` 支持 standalone/atomic/integrated，保留 standalone 即可）。
7. **编写新安装/校验脚本**：参考 `install_linux.sh:1037-1106` 流程（Docker 检查 → 网络 → 中间件 → 等待 PG/Redis 就绪 → init DB → RUNTIME 镜像 → VIDEO → WEB）与 `verify_all()`（`:1881-1952`，edge 只验：PostgreSQL/Redis/SRS 容器与端口、VIDEO `/actuator/health`、WEB `/health`）。
8. **文档**：带走 `VIDEO/README.md`、`RUNTIME/README.md`、`WEB/README.md`、根 `AGENTS.md`（模块关系），新写工程 README（安装/升级/回滚，默认账号 admin/admin123，入口 `https://<ip>:8888`）。

## 7. 验收标准（迁移完成的定义）

在 ≥2GB 内存的干净 Linux + Docker 环境：
1. 一条命令完成安装，容器总计内存约 1GB 左右（对齐原 edge 形态预算，`deploy_profile.sh:289,298`）。
2. PostgreSQL（iot-video20 完成种子初始化）、Redis、SRS、VIDEO、WEB 容器全部健康。
3. admin/admin123 登录 WEB（无租户、无验证码输入项），默认落地摄像头页。
4. 添加 ONVIF 摄像头 → 原画流经 SRS 播放（HTTP-FLV 签名有效）。
5. 创建实时算法任务 → RUNTIME 心跳在线（VIDEO 侧可见）→ AI 带框流 `ai/{device_id}` 可播放 → 触发告警图片落 `/mnt/easyaiot-media/alert_images` 且在 WEB 告警页可见（全程无 MQTT/MinIO/Kafka）。
6. 录像任务 → 文件落 `/mnt/easyaiot-media/playbacks`，本地回放可用。
7. 新工程内 `grep -r` 找不到对 DEVICE、EMQX、Kafka、Nacos、TDengine、MinIO、Milvus、ZLMediaKit、Node-RED、FUXA、POST、SENTINEL、TRANSFORM 的**运行时依赖**（纯注释/文档提及可接受）。

## 8. 风险与注意事项

- `STREAM_TICKET_SECRET` 与 nginx `$stream_secret` 不一致 → 所有播放 403；务必同源注入。
- `VIDEO/.env.docker` 是核心契约文件：漏掉任一 edge 开关（尤其 `ALGO_BUS_TRANSPORT=http`、`IOT_SINK_USE_GATEWAY=0`）会导致服务尝试连不存在的 EMQX/Gateway 后超时或静默丢告警。
- 模型种子目录挂载路径：`VIDEO/docker-compose.yaml` 引用 `../.scripts/minio`，新工程改路径后要同步 `MODEL_SEED_DATA_ROOT`。
- WEB 形态变更需重建镜像（`deploy_profile.sh:748-755`），迁移后首次构建就要用对 arg，不要复用旧 `web-service:latest-mini` 镜像。
- Redis 密码、PG 密码原为硬编码默认值，迁移时改为 env 并同步 VIDEO 的 `DATABASE_URL`/Redis 配置。
- 原仓库脚本含大量与 cloud/mini 相关的工具函数；采用方案 A 时不要盲目全量拷贝 `.scripts/`，按 §6 清单带走。

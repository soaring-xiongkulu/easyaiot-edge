# DEVICE 模块

EasyAIoT 边缘侧 **system-server（iot-system）** 的 Java 工程与容器编排：本目录包含 **`iot-parent` / `iot-common` / `iot-system` 源码**、**仅编排 `iot-system` 的 `docker-compose.yml`**，以及安装与数据库辅助脚本。

## 本目录包含

| 类别 | 说明 |
|------|------|
| **Java 源码** | `iot-parent`（BOM）、`iot-common`、`iot-system`（`iot-system-api` + `iot-system-biz`） |
| **容器编排** | `docker-compose.yml`：仅服务 **`iot-system`**，接入外部网络 `easyaiot-network`，通过服务名访问 PostgreSQL、Redis 等 |
| **镜像构建** | 根目录 `Dockerfile`：多阶段构建，仅产出 **`iot-system`** → 镜像名 **`iot-module-system-biz:latest`** |
| **运维脚本** | `install_linux.sh` / `install_mac.sh`（构建上述镜像并管理 Compose） |
| **数据库脚本** | `import_tables.py`、`drop_import_tables.py`；Python 依赖见 `requirements.txt` |

## 技术栈

- **Java**：21  
- **Spring Boot**：2.7.18  
- **构建**：Maven，`groupId`：`com.basiclab.iot`  

## `iot-system` 能力概览

认证与权限、用户/部门/租户、字典与地区、通知/邮件/短信、OAuth2、操作日志等（详见 `iot-system` 模块代码）。

默认容器内健康检查端口：**48099**。

## Docker Compose 说明

- **服务**：仅 `iot-system`（镜像 `iot-module-system-biz:latest`）。  
- **网络**：`easyaiot-network` 为 **external**，需先创建：`docker network create easyaiot-network`。  
- **中间件**：Compose 中通过 `PostgresSQL`、`Redis` 等主机名连接数据库与 Redis，请与你在同一网络上的中间件容器命名一致。  
- **Feign 调用 infra**：默认设置 `IOT_RPC_INFRA_BASE_URL=http://host.docker.internal:48082`，并配置 `extra_hosts`，便于在**宿主机**运行 `iot-infra` 时访问。若完全不部署 infra，可删除该环境变量，并在应用配置中改为可达地址；依赖 infra 的接口可能不可用。

## 快速使用

1. 创建网络：`docker network create easyaiot-network`（若尚无）。  
2. 构建镜像：`docker build --target iot-system -t iot-module-system-biz:latest .`  
   或使用：`./install_linux.sh build` / `./install_mac.sh build`  
3. 启动：`./install_linux.sh start` 或 `docker compose up -d`（在 `DEVICE` 目录下）。  
4. 数据库表：`pip install -r requirements.txt` 后执行 `import_tables.py` / `drop_import_tables.py`（按脚本要求配置连接）。

## 本地 Maven 开发

```bash
mvn clean package -DskipTests
```

---

[English README](README_en.md)

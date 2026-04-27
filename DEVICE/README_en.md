# EasyAIoT DEVICE Module

[中文文档](README.md) | English

This directory holds the **iot-system (system-server)** Java project and Docker orchestration for the EasyAIoT edge stack: **`iot-parent` / `iot-common` / `iot-system` source**, a **`docker-compose.yml` that runs only `iot-system`**, and install / database helper scripts.

## Contents

| Category | Description |
|----------|-------------|
| **Java source** | `iot-parent` (BOM), `iot-common`, `iot-system` (`iot-system-api` + `iot-system-biz`) |
| **Orchestration** | `docker-compose.yml`: **only `iot-system`**, attached to external `easyaiot-network`, uses service names for PostgreSQL, Redis, etc. |
| **Image build** | Root `Dockerfile`: multi-stage build for **`iot-system` only** → **`iot-module-system-biz:latest`** |
| **Scripts** | `install_linux.sh` / `install_mac.sh` (build that image and manage Compose) |
| **DB helpers** | `import_tables.py`, `drop_import_tables.py`; Python deps in `requirements.txt` |

## Stack

- **Java:** 21  
- **Spring Boot:** 2.7.18  
- **Build:** Maven, `groupId`: `com.basiclab.iot`  

## `iot-system` scope

Auth & RBAC, users/dept/tenant, dictionaries & regions, notify/mail/SMS, OAuth2, operation logs, etc. Health check in Compose targets port **48099** inside the container.

## Compose notes

- **Services:** `iot-system` only (`iot-module-system-biz:latest`).  
- **Network:** `easyaiot-network` is **external** — create with `docker network create easyaiot-network`.  
- **Infra Feign:** defaults to `IOT_RPC_INFRA_BASE_URL=http://host.docker.internal:48082` with `extra_hosts` so **infra on the host** is reachable. If you do not run infra, remove or change this; infra-dependent APIs may fail.

## Quick start

1. `docker network create easyaiot-network` (if missing).  
2. `docker build --target iot-system -t iot-module-system-biz:latest .`  
   or `./install_linux.sh build` / `./install_mac.sh build`.  
3. `./install_linux.sh start` or `docker compose up -d` from the `DEVICE` directory.  
4. DB scripts: install `requirements.txt`, then run `import_tables.py` / `drop_import_tables.py` as configured.

## Local Maven

```bash
mvn clean package -DskipTests
```

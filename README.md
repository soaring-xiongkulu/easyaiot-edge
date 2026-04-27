# EasyAIoT Edge (Edge Intelligent Algorithm Application Platform)

[![Gitee star](https://gitee.com/volara/easyaiot/badge/star.svg?theme=gvp)](https://gitee.com/soaring-xiongkulu/easyaiot/stargazers)
[![Gitee fork](https://gitee.com/volara/easyaiot/badge/fork.svg?theme=gvp)](https://gitee.com/soaring-xiongkulu/easyaiot/members)

<p style="font-size: 16px; line-height: 1.8; color: #555; font-weight: 400; margin: 20px 0;">
  <strong>An AI platform purpose-built for the edge, fully open-source under the MIT license.</strong> Breaking the hardware lock-in of current edge platforms — no need to purchase any proprietary devices, memory footprint controlled under 4GB. Everyone can become an AI edge expert. From cameras to alert closed-loop, AI should not be confined to cloud giants, nor locked by hardware vendors; with the MIT license, you have no worries.
</p>

<div align="center">
  <img src=".image/logo.png" width="30%" alt="EasyAIoT Edge Logo">
</div>

<h4 align="center" style="display: flex; justify-content: center; gap: 20px; flex-wrap: wrap; padding: 20px; font-weight: bold;">
  <a href="./README.md">English</a>
  <span style="display: flex; align-items: center; color: #666; font-weight: bold;">|</span>
  <a href="./README_zh.md">简体中文</a>
</h4>

## 📍 Project Positioning

**EasyAIoT Edge** is an **independent sub-project** of the main EasyAIoT project, tailored for edge scenarios. It is a one-stop intelligent algorithm stack trimmed and enhanced for resource-constrained, network-unstable edge sites (campuses, factories, server rooms, ARM all-in-one machines).

The platform continues the main project's concept of cloud-edge-device integration, but **default configurations, service composition, and deployment topology** are all oriented towards **single-node / few-node** edge all-in-one scenarios: video ingestion, algorithm scheduling, inference, and alerts are **closed-loop locally by default**. The core path runs on about **4GB of RAM**, and it can either synchronize with the cloud EasyAIoT for **cloud-edge collaboration** or run **completely offline and standalone**.

## 🧠 AI Capabilities

| Capability | Description |
|------|------|
| **Multi-protocol camera ingestion** | Supports ONVIF and RTSP protocols, auto-discovery, unified management |
| **Real-time stream AI analysis** | RTSP/RTMP real-time frame analysis, millisecond response, supports concurrent streams |
| **Capture algorithm task** | Intelligent recognition of captured images, suitable for event replay and image retrieval |
| **Model service cluster inference** | Lightweight model service with load balancing and high availability (single-node multi-instance possible) |
| **Deployment period management** | Full/partial defense modes, flexible time-scheduled monitoring rules |
| **Detection region drawing** | Visual drawing of quadrilateral/polygon detection regions, linked with algorithm models |
| **Intelligent alert linkage** | Triple filtering by detection region + deployment period + event type, greatly reducing false positives |
| **Alert recording and playback** | Alerts automatically trigger recording, support timeline playback and speed control |

## 🔌 IoT Edge Collection Capabilities

The platform integrates **Node-RED** as the edge-side **IoT collection and protocol gateway**: on the all-in-one machine or on-site gateway, use visual flows to connect to complex industrial devices such as PLCs, Modbus, OPC UA, etc., completing collection, cleaning, and standardized reporting. This forms a multi-source data closed-loop with the DEVICE thing model, rule engine, and upstream AI/alerting.

| Feature | Description |
|------|------|
| **Visual low-code orchestration** | Drag-and-drop nodes and connections to build collection and forwarding logic, familiar to electrical and process engineers, significantly reducing hardcoding and on-site secondary development |
| **Industrial multi-protocol & complex addressing** | Covers typical field protocols like PLC, Modbus (RTU/TCP), OPC UA, serial/Ethernet, supporting registers, tags, node addresses and other common industrial control models |
| **Edge local processing** | Parsing, buffering, and lightweight computation at the edge reduces uplink bandwidth and cloud dependency; maintains local collection and basic closed-loop even in weak or private networks |
| **Polling & event dual mode** | Periodic polling coexists with change-of-state and alarm triggers, suiting both steady-state conditions and sudden anomalies, matching SCADA/industrial control practices |
| **Cleaning & thing model alignment** | Use Function, JSON, template nodes for unit conversion, invalid value filtering, and field mapping, outputting data that conforms to the platform's thing model and uplink specifications |
| **Ecosystem expansion & private protocols** | Leverage community nodes and custom nodes to quickly support vendor-specific protocols or third-party gateways, avoiding repeated backend changes for every new device type |
| **Platform business integration** | Connect to the DEVICE module via MQTT, HTTP, etc.; data enters the rule engine and alerting pipeline, enabling multi-source linkage and policy orchestration with video and AI detection tasks |
| **Operability & traceability** | Flows support import/export and versioning, built-in debugging and message tracing for troubleshooting, auditing, and multi-site configuration replication |

## 💡 Technical Philosophy

We adhere to a **Java + Python + C++** multi-language mixed architecture, leveraging the strengths of each:

- **Java**: Builds a stable and reliable platform with enterprise-grade capabilities
- **Python**: Stream processing, AI algorithm orchestration, model serving
- **C++**: High-performance inference hot path, low latency, memory efficient

In edge scenarios, modules communicate directly via **environment variables + fixed ports + host networking**, without relying on centralized service discovery, reducing operational overhead.

## 🔗 Relationship with the Main Project EasyAIoT

| Aspect | Edge Sub-project Focus |
|------|-------------------|
| **Product form** | Edge-first, image and service composition orchestrated for all-in-one/box scenarios |
| **Memory & resources** | **4GB target** (streamlined service set + adjustable JVM/worker/inference parameters) |
| **Deployment topology** | Single node or few nodes, middleware and services directly connected, no multi-tenancy |
| **Service discovery** | Fixed ports + environment variables, **no dependency** on centralized registry |
| **Networking** | Video services default to `network_mode: host` for easy interoperability with cameras/LAN |
| **Database** | Default database names `ruoyi-vue-pro20` / `iot-edge-video20` / `iot-edge-ai20` |
| **Compute** | Supports NVIDIA Container Toolkit; TASK (C++) focuses on low-latency inference |
| **Cloud-edge collaboration** | Can connect to the main project cloud for policy/model/alert synchronization, or run completely offline |

> For centralized operations of thousands of streams and multi-tenant operational dashboards, please use the main project's cloud deployment solution.

## 🧩 Project Structure

EasyAIoT Edge consists of five core modules, each independently deployable:

| Module | Description |
|------|------|
| **WEB** | Vue 3 + Vite management UI: cameras, algorithm tasks, models, alerts, permissions, etc. |
| **DEVICE** | IoT device/product/thing model/rule engine backend (JDK 21) |
| **VIDEO** | Video and algorithm task Python services (including frame extractor, sequencer, stream pusher, etc.) |
| **AI** | Training, inference, model serving (YOLO/LLM/OCR/speech, etc.) |
| **TASK** | C++ high-performance edge inference module |

## 🏗️ Architecture & Data Flow

![EasyAIoT Edge Architecture Diagram](.image/iframe2.jpg)  

Brief data flow:
1. Cameras connect to the VIDEO module via ONVIF/GB28181
2. VIDEO extracts frames according to algorithm task configuration and distributes them to the AI module or TASK module
3. AI/TASK performs inference and returns results to VIDEO
4. VIDEO triggers alerts based on deployment rules and writes to the rule engine of the DEVICE module
5. DEVICE sends alerts via notification channels and triggers recording storage
6. WEB frontend displays device status, alert events, and recording playback

## 🖥️ Localization & Hardware Support

| Category | Support Status |
|------|----------|
| **Memory** | Starting from ~4GB (tunable; recommended as default reference configuration) |
| **Edge chips** | Rockchip RK3588 and other ARM architectures (requires replacing images for NPU/CPU inference stack) |
| **Server CPUs** | Hygon x86, Intel/AMD, etc. |
| **Operating systems** | Kylin, UOS, Deepin, and other domestic Linux distributions, as well as mainstream Linux distros |

## 📚 Deployment Documentation

- [Edge Platform Deployment Guide](.doc/部署文档/边缘平台部署文档_zh.md) (Chinese)

## ⚙️ Project Repositories

- Gitee: https://gitee.com/volara/easyaiot-edge
- Github: https://github.com/soaring-xiongkulu/easyaiot-edge

## ☁️ Cross-Platform Deployment Advantages

EasyAIoT Edge supports deployment on Linux / Mac / Windows (Linux recommended for production):

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; margin: 20px 0;">
  <div style="padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; color: white;">
    <h4>🐧 Linux</h4>
    <ul style="font-size: 14px;"><li>Preferred for production, low resource usage</li><li>One-click Docker startup</li><li>Perfectly adapted to ARM/x86 edge devices</li></ul>
  </div>
  <div style="padding: 20px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 10px; color: white;">
    <h4>🍎 Mac</h4>
    <ul style="font-size: 14px;"><li>Convenient for development and testing</li><li>Supports local debugging</li><li>Homebrew script provided</li></ul>
  </div>
  <div style="padding: 20px; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); border-radius: 10px; color: white;">
    <h4>🪟 Windows</h4>
    <ul style="font-size: 14px;"><li>Windows Server friendly</li><li>PowerShell automation</li><li>Lower learning curve</li></ul>
  </div>
</div>

## 🎯 Use Cases

- 🏭 **All-in-one security and production line visual inspection for campuses/factories**
- 📶 **Localized alerting and recording retention in weak or private network environments**
- 🔄 **Edge-side model closed-loop**: collection → labeling → training → inference deployment
- ☁️ **Collaboration with cloud EasyAIoT**: two-way sync of policies, models, alerts

<img src=".image/适用场景.png" alt="Use Cases" style="max-width:100%;">

## 📸 Interface Preview

<div>
  <img src=".image/banner/banner1000.png" width="49%">
  <img src=".image/banner/banner1001.png" width="49%">
</div>
<div>
  <img src=".image/banner/banner1002.png" width="49%">
  <img src=".image/banner/banner1003.png" width="49%">
</div>

## 📞 Contact (After adding WeChat, follow the official account to join the technical exchange group)

<div>
  <img src=".image/联系方式.jpg" alt="Contact" width="30%" style="margin-right: 50px;">
</div>

## 👥 Official Account

<div>
  <img src=".image/公众号.jpg" alt="Official Account" width="30%">
</div>

## 🪐 Knowledge Planet

<p>
  <img src=".image/知识星球.jpg" alt="Knowledge Planet" width="30%">
</p>

## 💰 Donations / Sponsorship

<div>
    <img src=".image/微信支付.jpg" alt="WeChat Pay" width="30%" height="30%">
    <img src=".image/支付宝支付.jpg" alt="Alipay" width="30%" height="10%">
</div>

## 🤝 Contribution Guidelines

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
We welcome all forms of contribution! Whether you are a code developer, documentation writer, or issue reporter, your contribution will help make EasyAIoT better. Here are several main ways to contribute:
</p>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0;">

<div style="padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">💻 Code Contribution</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>Fork the project to your GitHub/Gitee account</li>
  <li>Create a feature branch (git checkout -b feature/AmazingFeature)</li>
  <li>Commit your changes (git commit -m 'Add some AmazingFeature')</li>
  <li>Push to the branch (git push origin feature/AmazingFeature)</li>
  <li>Open a Pull Request</li>
</ul>
</div>

<div style="padding: 20px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">📚 Documentation Contribution</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>Improve existing documentation</li>
  <li>Add usage examples and best practices</li>
  <li>Provide multilingual translations</li>
  <li>Fix documentation errors</li>
</ul>
</div>

<div style="padding: 20px; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">🌟 Other Ways to Contribute</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>Report and fix bugs</li>
  <li>Suggest feature improvements</li>
  <li>Participate in community discussions and help other developers</li>
  <li>Share usage experiences and case studies</li>
</ul>
</div>

</div>

## 💡 Expectations

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
We welcome your valuable suggestions to help improve easyaiot-edge.
</p>

## 📄 License

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
Soaring Xiongkulu/easyaiot-edge is open-sourced under the <a href="https://gitee.com/soaring-xiongkulu/easyaiot-edge/blob/main/LICENSE" style="color: #3498db; text-decoration: none; font-weight: 600;">MIT LICENSE</a>. We are committed to promoting the popularization and development of AI technology, allowing more people to freely use and benefit from it.
</p>

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
<strong>Usage Permissions</strong>: Individuals and enterprises can use it 100% free of charge, without the need to retain the author or copyright information. We believe the value of technology lies in its widespread use and continuous innovation, not being constrained by copyright. We hope you can freely use, modify, and distribute this project, so that AI technology truly benefits everyone.
</p>
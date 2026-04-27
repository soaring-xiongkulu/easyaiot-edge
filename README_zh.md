# EasyAIoT Edge（异构边缘算力平台）

[![Gitee star](https://gitee.com/volara/easyaiot-edge/badge/star.svg)](https://gitee.com/soaring-xiongkulu/easyaiot-edge/stargazers)
[![Gitee fork](https://gitee.com/volara/easyaiot-edge/badge/fork.svg)](https://gitee.com/soaring-xiongkulu/easyaiot-edge/members)

### 一个平台，覆盖主流边缘算力——不换业务，只换芯片。

<p style="font-size: 16px; line-height: 1.8; color: #555; font-weight: 400; margin: 20px 0;">
  EasyAIoT Edge 是一套完全开源的边缘智能算法应用平台，在同一套操作习惯、数据链路和运维体系下，<strong>同时支持华为昇腾、NVIDIA Jetson、瑞芯微 RK3588、算能 BM1688 以及海光/Intel/AMD x86</strong>等异构边缘算力。平台覆盖摄像头接入、算法任务编排、推理、告警、录像、IoT 采集与规则引擎的全链路，采用 MIT 协议，无厂商锁定风险。
</p>

<div align="center">
  <img src=".image/logo.png" width="30%" alt="EasyAIoT Edge Logo">
</div>

<h4 align="center" style="display: flex; justify-content: center; gap: 20px; flex-wrap: wrap; padding: 20px; font-weight: bold;">
  <a href="./README.md">English</a>
  <span style="display: flex; align-items: center; color: #666; font-weight: bold;">|</span>
  <a href="./README_zh.md">简体中文</a>
</h4>

## 💎 为什么值得关注

| 你关心的 | 说明 |
|----------|------|
| **少重复建设** | 现场可能是信创昇腾、工控 Jetson、性价比 RK3588、大算力 BM1688 或机房 x86；业务逻辑和界面统一，不必为每种板子各做一套后台与运维手册。 |
| **省学习与对接成本** | 运维和集成只熟悉一套模块（WEB / DEVICE / VIDEO / AI / TASK）和一套端口拓扑；换机器主要是换推理镜像与参数，而不是从零再造系统。 |
| **边缘能自己闭环** | 弱网、专网也能本地告警与录像；约 <strong>4GB</strong> 内存可跑通核心链路，适合盒子、一体机、小服务器。 |
| **合规与商业友好** | MIT 协议，个人与企业均可自由使用、二次开发，无厂商锁定焦虑。 |

## 🎯 为什么要做「一块平台、多块芯片」

边缘落地最大的痛点往往不是「没有模型」，而是**换一块板子就要换一套系统**：国产化要昇腾和海光 x86，产线常见 Jetson，低成本方案用 RK3588，重推理盒子常见 BM1688——每家 SDK、容器和推理入口都不一样，同一套安防或质检业务被迫维护多条技术线，人力和时间都耗在重复对接上。

**EasyAIoT Edge** 用固定的 **WEB / DEVICE / VIDEO / AI / TASK** 五模块和 **固定端口 + 环境变量 + host 网络**，把「日常用的平台」和「跟芯片绑定的推理部分」分开：**界面、告警、录像、物模型、规则引擎这一套不变**；换昇腾、Jetson、RK、BM1688 或 x86，主要是换推理镜像、编排参数和 TASK（C++）的构建目标，对齐 CANN、CUDA/TensorRT、RK NPU、TPU 与 x86 CPU/GPU 等常见路线，从而**用一套开源平台**串起信创、工控、ARM 盒子和 x86 服务器。

## 🧩 支持的芯片与典型用法

| 芯片 / 平台 | 典型硬件 / 场景 | 在本平台里做什么 |
|----------|-----------------|------------------|
| **华为昇腾** | Atlas 边缘推理卡、昇腾 NPU 一体机等 | 信创与国产化推理栈；与 DEVICE / 告警 / 录像同一套业务闭环 |
| **NVIDIA Jetson** | Orin / Xavier / Nano 等 | 工业视觉、低时延 CUDA 生态；支持容器化 GPU / NVIDIA 工具链对接 |
| **瑞芯微 RK3588** | ARM 边缘一体机、NVR 形态 | 高能效 ARM + NPU；适合多路视频与轻量推理组合 |
| **算能 BM1688** | Sophon 边缘计算盒、1688 系 SoC | 大算力 INT8/TPU 路线；适合重推理或模型服务集群 |
| **x86（海光 / Intel / AMD）** | 机架式边缘服务器、工控机 | 通用 CPU 与可选独立 GPU；适合集中多路、规则引擎与存储 |

> 各芯片具体镜像、驱动版本与推理后端以 [.doc/部署文档/边缘平台部署文档_zh.md](.doc/部署文档/边缘平台部署文档_zh.md) 为准；**ARM（含 RK3588）等需按设备能力选择或构建对应推理栈镜像**，与平台模块解耦部署。

## 📍 项目定位

**EasyAIoT Edge** 是 EasyAIoT 主项目面向边缘场景的**独立子项目**，在「一套软件可对接多种主流芯片」的前提下，为资源受限、网络不稳的现场（园区、工厂、机房、ARM/x86 一体机）裁剪强化的一站式智能算法栈。

平台延续主项目的云边端一体化理念，但**默认配置、服务组合、部署拓扑**全部面向**单机 / 少量节点**：视频接入、算法调度、推理、告警默认**本地闭环**，约 **4GB 内存**即可跑通核心链路，可与云端 EasyAIoT **云边协同**，也可**完全离线独立运行**。

## 🧠 AI 能力

| 能力 | 说明 |
|------|------|
| **多协议摄像头接入** | 支持 ONVIF 和 RTSP 双协议，自动发现、统一管理 |
| **实时流 AI 分析** | RTSP/RTMP 实时画面分析，毫秒级响应，支持多路并发 |
| **抓拍算法任务** | 抓拍图片智能识别，适用于事件回溯、图像检索 |
| **模型服务集群推理** | 轻量级模型服务，支持负载均衡与高可用（可单机多实例） |
| **布防时段管理** | 全防/半防模式，灵活配置时段化监控规则 |
| **检测区域绘制** | 可视化绘制四边形/多边形检测区域，与算法模型关联 |
| **智能联动告警** | 检测区域 + 布防时段 + 事件类型三重过滤，大幅降低误报 |
| **告警录像与回放** | 告警自动触发录像，支持时间轴回放、倍速播放 |

## 🔌 IoT 边缘采集能力

平台将 **Node-RED** 作为边缘侧 **IoT 采集与协议网关**：在一体机或现场网关上以可视化流程对接 PLC、Modbus、OPC UA 等复杂工业设备，完成采集、清洗与规范上报，与 DEVICE 物模型、规则引擎及上游 AI/告警形成多源数据闭环。

| 特性 | 说明 |
|------|------|
| **可视化低代码编排** | 拖拽节点、连线即可搭建采集与转发逻辑，贴近电气与工艺工程师习惯，显著减少硬编码与现场二开周期 |
| **工业多协议与复杂寻址** | 覆盖 PLC、Modbus（RTU/TCP）、OPC UA、串口/以太网等典型现场形态，支持寄存器、标签、节点地址等工控侧常见模型 |
| **边缘就近处理** | 在边缘完成解析、缓冲与轻量计算，降低上行带宽与云端依赖；弱网或专网环境下仍可保持本地采集与基础闭环 |
| **轮询与事件双模式** | 周期轮询与变位、报警触发可并存，兼顾稳态工况与突发异常，符合 SCADA/工控使用习惯 |
| **清洗与物模型对齐** | 借助 Function、JSON、模板等节点完成单位换算、非法值过滤与字段映射，输出符合平台物模型与上行规范的数据 |
| **生态扩展与私协议** | 依托社区节点与自研节点快速补齐厂商协议或第三方网关，避免「每换一类设备就改一版后台」的重复投入 |
| **与平台业务联动** | 经 MQTT、HTTP 等对接 DEVICE 模块，数据进入规则引擎与告警链路，并可与视频、AI 检测任务做多源联动与策略编排 |
| **可运维与可追溯** | 流程支持导入导出与版本留存，内置调试与消息追踪，便于排障、审计及多站点配置复制 |

## 💡 技术理念

我们坚持 **Java + Python + C++** 三语言混编架构，发挥各自优势：

- **Java**：构建稳定可靠的平台与企业级能力
- **Python**：流媒体处理、AI 算法编排、模型服务
- **C++**：高性能推理热点路径（TASK），低延迟、省内存；同一套调度逻辑下，可按不同芯片做推理加速

在边缘场景中，模块间通过**环境变量 + 固定端口 + host 网络**直连，不依赖中心化注册发现，降低运维成本；**换芯不换业务**——管理端与 DEVICE/VIDEO 协议层保持稳定，推理层按芯片切换。

## 🔗 与主项目 EasyAIoT 的关系

| 维度 | Edge 子项目侧重点 |
|------|-------------------|
| **产品形态** | 边缘设备优先，镜像与服务组合按一体机/盒子场景编排 |
| **内存与资源** | **4GB 级目标**（精简服务集 + 可调 JVM/Worker/推理参数） |
| **部署拓扑** | 单机或少量节点，中间件与业务直连，无多租户 |
| **服务发现** | 固定端口 + 环境变量，**不依赖**中心化注册中心 |
| **网络** | 视频服务默认 `network_mode: host`，便于与摄像头/局域网互通 |
| **数据库** | 默认库名 `ruoyi-vue-pro20` / `iot-edge-video20` / `iot-edge-ai20` |
| **算力** | **昇腾 / Jetson / RK3588 / BM1688 / x86** 等：TASK（C++）+ AI 容器按目标芯片编排；可参考 NVIDIA Container Toolkit 等官方容器方案 |
| **云边协同** | 可对接主项目云端，实现策略/模型/告警同步，也可完全离线 |

> 若需上千路集中运维、多租户运营大屏，请使用主项目云部署方案。

## 🧩 项目结构

EasyAIoT Edge 由五个核心模块组成，可独立部署：

| 模块 | 描述 |
|------|------|
| **WEB** | Vue 3 + Vite 管理端：摄像头、算法任务、模型、告警、权限等 |
| **DEVICE** | IoT 设备/产品/物模型/规则引擎后端（JDK 21） |
| **VIDEO** | 视频与算法任务 Python 服务（含抽帧器、排序器、推流等） |
| **AI** | 训练、推理、模型服务（YOLO/LLM/OCR/语音等） |
| **TASK** | C++ 高性能边缘推理模块 |

## 🏗️ 架构与数据流

![EasyAIoT Edge 架构图](.image/iframe2.jpg)  

数据流转简要流程：
1. 摄像头通过 ONVIF/GB28181 接入 VIDEO 模块
2. VIDEO 根据算法任务配置，抽取视频帧并分发至 AI 模块或 TASK 模块
3. AI/TASK 执行推理，将结果返回 VIDEO
4. VIDEO 根据布防规则触发告警，写入 DEVICE 模块的规则引擎
5. DEVICE 通过通知渠道发送告警，同时触发录像存储
6. WEB 前端统一展示设备状态、告警事件、录像回放

## 🖥️ 本土化与操作系统

| 类别 | 支持情况 |
|------|----------|
| **内存规格** | 约 4GB 起（可按需调优；建议作为默认参考配置） |
| **操作系统** | 麒麟、统信 UOS、方德等国产化 Linux，以及主流 Linux 发行版 |

## 📚 部署文档

- [边缘平台部署文档](.doc/部署文档/边缘平台部署文档_zh.md)

## ⚙️ 项目地址

- Gitee: https://gitee.com/volara/easyaiot-edge
- Github: https://github.com/soaring-xiongkulu/easyaiot-edge

## ☁️ 跨平台部署优势

EasyAIoT Edge 支持 Linux / Mac / Windows 三大平台部署（推荐 Linux 生产环境）：

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; margin: 20px 0;">
  <div style="padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; color: white;">
    <h4>🐧 Linux</h4>
    <ul style="font-size: 14px;"><li>生产环境首选，资源占用低</li><li>Docker 一键启动</li><li>完美适配 ARM/x86 与多类 NPU/GPU 边缘形态</li></ul>
  </div>
  <div style="padding: 20px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 10px; color: white;">
    <h4>🍎 Mac</h4>
    <ul style="font-size: 14px;"><li>开发测试便捷</li><li>支持本地调试</li><li>提供 Homebrew 脚本</li></ul>
  </div>
  <div style="padding: 20px; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); border-radius: 10px; color: white;">
    <h4>🪟 Windows</h4>
    <ul style="font-size: 14px;"><li>Windows Server 友好</li><li>PowerShell 自动化</li><li>降低学习成本</li></ul>
  </div>
</div>

## 🎯 适用场景

- 🏭 **园区/工厂安防与产线视觉质检一体机**（Jetson / x86 / 国产化混合环境）
- 📶 **弱网或专网环境下的本地化告警与录像留存**
- 🔄 **边缘侧模型闭环**：采集 → 标注 → 训练 → 下发推理
- ☁️ **与云端 EasyAIoT 协同**：策略、模型、告警双向同步
- 🇨🇳 **信创与多种芯片同一机房**：昇腾 + 海光 x86 等与视频、IoT 统一纳管

<img src=".image/适用场景.png" alt="适用场景" style="max-width:100%;">

## 📸 界面预览

<div>
  <img src=".image/banner/banner1000.png" width="49%">
  <img src=".image/banner/banner1001.png" width="49%">
</div>
<div>
  <img src=".image/banner/banner1002.png" width="49%">
  <img src=".image/banner/banner1003.png" width="49%">
</div>

## 📞 联系方式（添加微信后，需关注公众号，拉入技术交流群）

<div>
  <img src=".image/联系方式.jpg" alt="联系方式" width="30%" style="margin-right: 50px;">
</div>

## 👥 公众号

<div>
  <img src=".image/公众号.jpg" alt="公众号" width="30%">
</div>

## 🪐 知识星球：

<p>
  <img src=".image/知识星球.jpg" alt="知识星球" width="30%">
</p>

## 💰 打赏赞助

<div>
    <img src=".image/微信支付.jpg" alt="微信支付" width="30%" height="30%">
    <img src=".image/支付宝支付.jpg" alt="支付宝支付" width="30%" height="10%">
</div>

## 🤝 贡献指南

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
我们欢迎所有形式的贡献！无论您是代码开发者、文档编写者，还是问题反馈者，您的贡献都将帮助 EasyAIoT 变得更好。以下是几种主要的贡献方式：
</p>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0;">

<div style="padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">💻 代码贡献</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>Fork 项目到您的 GitHub/Gitee 账号</li>
  <li>创建特性分支 (git checkout -b feature/AmazingFeature)</li>
  <li>提交更改 (git commit -m 'Add some AmazingFeature')</li>
  <li>推送到分支 (git push origin feature/AmazingFeature)</li>
  <li>提交 Pull Request</li>
</ul>
</div>

<div style="padding: 20px; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">📚 文档贡献</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>完善现有文档内容</li>
  <li>补充使用示例和最佳实践</li>
  <li>提供多语言翻译</li>
  <li>修正文档错误</li>
</ul>
</div>

<div style="padding: 20px; background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); border-radius: 10px; color: white; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
<h4 style="margin-top: 0; color: white; font-size: 18px;">🌟 其他贡献方式</h4>
<ul style="font-size: 14px; line-height: 1.8; margin: 10px 0; padding-left: 20px;">
  <li>报告并修复 Bug</li>
  <li>提出功能改进建议</li>
  <li>参与社区讨论，帮助其他开发者</li>
  <li>分享使用经验和案例</li>
</ul>
</div>

</div>

## 💡 期望 

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
欢迎提出更好的意见，帮助完善 easyaiot-edge；也欢迎补充各芯片下的最佳实践与镜像说明，让「一套平台、多块芯片」真正落到每一条产线。
</p>

## 📄 版权

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
翱翔的雄库鲁/easyaiot-edge 采用 <a href="https://gitee.com/soaring-xiongkulu/easyaiot-edge/blob/main/LICENSE" style="color: #3498db; text-decoration: none; font-weight: 600;">MIT LICENSE</a> 开源协议。我们致力于推动 AI 技术的普及与发展，让更多人能够自由使用和受益于这项技术。
</p>

<p style="font-size: 15px; line-height: 1.8; color: #333; margin: 15px 0;">
<strong>使用许可</strong>：个人与企业可 100% 免费使用，无需保留作者、Copyright 信息。我们相信技术的价值在于被广泛使用和持续创新，而非被版权束缚。希望您能够自由地使用、修改、分发本项目，让 AI 技术真正惠及每一个人。
</p>

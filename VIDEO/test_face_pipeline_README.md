# 人脸功能测试脚本使用说明

## 简介

`test_face_pipeline.py` 是 `VIDEO` 模块的人脸功能全链路测试脚本，用于快速验证以下能力是否可用：

- 人脸服务健康检查
- 人脸库新增/查询/更新/删除
- 上传图片识别
- 摄像头抓拍识别（可选）
- 生成测试报告（可选）

该脚本适合在你完成 Milvus + 人脸功能接入后做一键验收。

## 前置条件

### 1) 服务已启动

请先确保中间件和 `VIDEO` 服务可用：

- Milvus: `localhost:19530`（gRPC）和 `localhost:9091`（health）
- VIDEO: `http://localhost:6000`

### 2) 依赖

脚本依赖 `requests`：

```bash
pip install requests
```

### 3) 准备测试图片

准备若干张清晰的人脸图片，例如：

```text
VIDEO/test_data/face/zhangsan_1.jpg
VIDEO/test_data/face/zhangsan_2.jpg
VIDEO/test_data/face/lisi_1.jpg
VIDEO/test_data/face/unknown_1.jpg
```

## 快速开始

在 `VIDEO` 目录执行：

```bash
python test_face_pipeline.py \
  --register 张三=./test_data/face/zhangsan_1.jpg \
  --register 李四=./test_data/face/lisi_1.jpg \
  --recognize 样本1=./test_data/face/zhangsan_2.jpg \
  --recognize 样本2=./test_data/face/unknown_1.jpg \
  --update 张三=./test_data/face/zhangsan_2.jpg \
  --cleanup \
  --output ./test_reports/face_test_report.json
```

## 参数说明

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--base-url` | VIDEO 服务地址 | `http://localhost:6000` |
| `--register` | 入库样本，格式 `label=图片路径`，可重复 | 无 |
| `--recognize` | 识别样本，格式 `标签=图片路径`，可重复 | 无 |
| `--update` | 更新样本，格式 `label=图片路径`，可重复 | 无 |
| `--device-id` | 可选，设备抓拍识别测试的设备ID | 空 |
| `--top-k` | 识别TopK | `3` |
| `--cleanup` | 结束后删除本次 `--register` 的标签 | 关闭 |
| `--output` | 输出JSON报告文件路径 | 空 |
| `--sleep` | 接口调用间隔秒数 | `0.2` |

## 典型场景

### 场景1：只做健康检查 + 人脸库增删查

```bash
python test_face_pipeline.py \
  --register 张三=./test_data/face/zhangsan_1.jpg \
  --cleanup
```

### 场景2：验证识别命中

```bash
python test_face_pipeline.py \
  --register 张三=./test_data/face/zhangsan_1.jpg \
  --recognize 命中测试=./test_data/face/zhangsan_2.jpg
```

### 场景3：验证设备抓拍识别

```bash
python test_face_pipeline.py \
  --register 张三=./test_data/face/zhangsan_1.jpg \
  --device-id 1744093812734000000
```

## 输出说明

脚本会打印每个步骤的 `PASS/FAIL`，最后输出汇总：

- 总用例数
- 通过数
- 失败数

若传了 `--output`，会输出完整JSON报告，便于留档和回归对比。

## 失败排查建议

### 1) 健康检查失败

- 检查 `VIDEO` 服务是否启动
- 检查 `VIDEO` 是否已安装 `insightface`、`pymilvus`
- 检查 Milvus 服务与端口是否可达

### 2) 入库失败（未检测到人脸）

- 更换清晰、正脸、无遮挡图片
- 图片中尽量保证单人脸，避免多人干扰

### 3) 识别结果全是未命中

- 提高入库图片质量
- 适当下调 `FACE_SIMILARITY_THRESHOLD`（例如从 `0.55` 调到 `0.5`）
- 确认识别样本与入库人脸属于同一人

### 4) 设备抓拍识别失败

- 确认设备ID正确且视频源可拉流
- RTMP源需确保 ffmpeg 可抓帧
- RTSP源需确保网络连通与权限正常


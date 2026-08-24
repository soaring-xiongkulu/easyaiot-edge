<template>
  <div class="face-model-setup">
    <!-- 检查中 -->
    <div v-if="checking" class="setup-loading">
      <Spin size="large" />
      <p>正在检测本地模型环境…</p>
    </div>

    <!-- 主界面 -->
    <div v-else class="setup-shell">
      <div class="setup-bg" aria-hidden="true">
        <div class="setup-bg-glow setup-bg-glow--left" />
        <div class="setup-bg-glow setup-bg-glow--right" />
        <div class="setup-bg-grid" />
      </div>

      <div class="setup-layout">
        <!-- 左侧：品牌与说明 -->
        <section class="setup-intro">
          <div class="setup-badge">
            <span class="setup-badge-dot" />
            人脸库 · 引擎初始化
          </div>

          <h1 class="setup-headline">配置人脸特征识别引擎</h1>
          <p class="setup-lead">
            启用人脸库管理、1:N 比对与算法任务人脸匹配前，需在本机部署
            <strong>face_rec.onnx</strong> 特征提取模型。下载一次，持久可用。
          </p>

          <div class="setup-metrics">
            <div v-for="item in metricItems" :key="item.label" class="setup-metric">
              <div class="setup-metric-value">{{ item.value }}</div>
              <div class="setup-metric-label">{{ item.label }}</div>
            </div>
          </div>

          <ul class="setup-features">
            <li v-for="feat in featureItems" :key="feat">
              <CheckCircleFilled class="setup-feature-icon" />
              <span>{{ feat }}</span>
            </li>
          </ul>
        </section>

        <!-- 右侧：操作区 -->
        <section class="setup-panel">
          <div class="setup-panel-inner">
            <!-- 模型信息头 -->
            <div class="panel-model-header">
              <div class="panel-model-icon">
                <Icon icon="ant-design:deployment-unit-outlined" :size="22" />
              </div>
              <div class="panel-model-meta">
                <div class="panel-model-name">face_rec.onnx</div>
                <div class="panel-model-sub">InsightFace · ArcFace · buffalo_l</div>
              </div>
              <Tag v-if="!showProgress && modelStatus?.resumable" color="warning">可续传</Tag>
              <Tag v-else-if="!showProgress && modelStatus?.stage !== 'error'" color="blue">待安装</Tag>
              <Tag v-else-if="modelStatus?.stage === 'error'" color="error">安装失败</Tag>
              <Tag v-else-if="finished" color="success">已完成</Tag>
              <Tag v-else color="processing">安装中</Tag>
            </div>

            <!-- 进度区 -->
            <div v-if="showProgress" class="panel-progress-zone">
              <div class="progress-ring-wrap">
                <Progress
                  type="circle"
                  :percent="progress"
                  :width="120"
                  :stroke-width="8"
                  :status="progressStatus"
                  :stroke-color="progressColor"
                />
              </div>

              <div class="progress-headline">{{ stageText }}</div>
              <div v-if="showBytes" class="progress-bytes">
                {{ formatSize(modelStatus?.downloaded_bytes) }}
                <span class="progress-bytes-sep">/</span>
                {{ formatSize(modelStatus?.total_bytes) }}
              </div>

              <!-- 自定义步骤条 -->
              <div class="setup-stepper">
                <div
                  v-for="(step, idx) in steps"
                  :key="step.key"
                  class="setup-step"
                  :class="{
                    'setup-step--done': finished || idx < currentStep,
                    'setup-step--active': !finished && idx === currentStep,
                    'setup-step--pending': !finished && idx > currentStep,
                  }"
                >
                  <div class="setup-step-node">
                    <CheckOutlined v-if="finished || idx < currentStep" />
                    <LoadingOutlined v-else-if="idx === currentStep" spin />
                    <span v-else>{{ idx + 1 }}</span>
                  </div>
                  <div class="setup-step-text">
                    <div class="setup-step-title">{{ step.title }}</div>
                    <div class="setup-step-desc">{{ step.desc }}</div>
                  </div>
                  <div v-if="idx < steps.length - 1" class="setup-step-line" />
                </div>
              </div>

              <p class="progress-footnote">
                <InfoCircleOutlined />
                {{ tipText }}
              </p>
            </div>

            <!-- 错误 -->
            <div v-else-if="modelStatus?.stage === 'error'" class="panel-error">
              <div class="panel-error-icon">
                <CloseCircleFilled />
              </div>
              <p class="panel-error-msg">{{ modelStatus.error || '下载失败，请检查网络连接后重试' }}</p>
              <p v-if="modelStatus?.resumable && showPartialProgress" class="panel-resume-hint">
                已下载 {{ formatSize(modelStatus?.downloaded_bytes) }}，点击「继续下载」将从断点续传
              </p>
            </div>

            <div v-else-if="showPartialProgress" class="panel-idle panel-idle--resume">
              <div class="panel-idle-visual">
                <div class="panel-idle-ring panel-idle-ring--outer" />
                <div class="panel-idle-ring panel-idle-ring--inner" />
                <CloudDownloadOutlined class="panel-idle-icon" />
              </div>
              <p class="panel-idle-text">
                检测到未完成下载：<strong>{{ formatSize(modelStatus?.downloaded_bytes) }}</strong>
                <span v-if="modelStatus?.total_bytes"> / {{ formatSize(modelStatus?.total_bytes) }}</span>
              </p>
              <p class="panel-resume-hint">下载在 VIDEO 服务端后台进行，可关闭页面后稍后回来继续</p>
            </div>

            <!-- 待下载说明 -->
            <div v-else class="panel-idle">
              <div class="panel-idle-visual">
                <div class="panel-idle-ring panel-idle-ring--outer" />
                <div class="panel-idle-ring panel-idle-ring--inner" />
                <CloudDownloadOutlined class="panel-idle-icon" />
              </div>
              <p class="panel-idle-text">
                模型约 <strong>167 MB</strong>，首次下载预计 <strong>1–5 分钟</strong>，请确保 VIDEO 服务可访问外网。
              </p>
            </div>

            <!-- CTA -->
            <div class="panel-actions">
              <Button
                v-if="!showProgress"
                type="primary"
                size="large"
                block
                class="panel-cta"
                @click="$emit('download')"
              >
                <template #icon><CloudDownloadOutlined /></template>
                {{ downloadButtonText }}
              </Button>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import {
  CheckCircleFilled,
  CheckOutlined,
  CloseCircleFilled,
  CloudDownloadOutlined,
  InfoCircleOutlined,
  LoadingOutlined,
} from '@ant-design/icons-vue';
import { Progress, Spin, Tag } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import type { FaceRecModelStatus } from '@/api/device/face_library';
import { Button } from '@/components/Button'
defineOptions({ name: 'FaceModelSetupPanel' });

const props = defineProps<{
  checking?: boolean;
  modelStatus?: FaceRecModelStatus | null;
  showProgress?: boolean;
  progress?: number;
  currentStep?: number;
  finished?: boolean;
}>();

defineEmits<{ download: [] }>();

const metricItems = [
  { value: '167 MB', label: '模型体积' },
  { value: '512 维', label: '特征向量' },
  { value: '1:N', label: '比对模式' },
];

const featureItems = [
  '支持人脸库录入、归一化与批量管理',
  '算法任务开启人脸匹配后自动 1:N 检索',
  '本地部署，数据不出域，满足隐私合规要求',
];

const steps = [
  { key: 'download', title: '下载模型包', desc: 'buffalo_l 官方发行包' },
  { key: 'extract', title: '解压安装', desc: '提取 face_rec.onnx' },
  { key: 'ready', title: '引擎就绪', desc: '加载人脸库功能' },
];

const progressStatus = computed(() => {
  if (props.finished) return 'success';
  if (props.modelStatus?.stage === 'error') return 'exception';
  return 'active';
});

const progressColor = computed(() => {
  if (props.finished) return '#52c41a';
  return { '0%': '#266cfb', '100%': '#5ba3f5' };
});

const stageText = computed(() => {
  if (props.finished) return '安装完成，正在进入人脸库';
  const stage = props.modelStatus?.stage;
  if (stage === 'extracting') return '正在解压并写入模型文件';
  if (stage === 'downloading') return '正在从 InsightFace 拉取模型包';
  return '正在准备安装';
});

const tipText = computed(() => {
  if (props.finished) return '请稍候，系统正在加载人脸库模块';
  const stage = props.modelStatus?.stage;
  if (stage === 'extracting') return '解压阶段通常只需数秒，请勿关闭页面';
  if (props.modelStatus?.resumable) {
    return '下载在服务端后台进行，支持断点续传；关闭或刷新页面后可再次点击继续下载';
  }
  return '下载在服务端后台进行，支持断点续传；网络中断后可继续下载';
});

const showPartialProgress = computed(() => {
  const downloaded = props.modelStatus?.downloaded_bytes ?? 0;
  return !!props.modelStatus?.resumable && downloaded > 0 && !props.showProgress;
});

const downloadButtonText = computed(() => {
  if (props.modelStatus?.resumable) return '继续下载';
  if (props.modelStatus?.stage === 'error') return '重新下载模型';
  return '立即下载并安装';
});

const showBytes = computed(() => {
  const total = props.modelStatus?.total_bytes ?? 0;
  return total > 0 && props.showProgress;
});

function formatSize(bytes?: number) {
  if (!bytes || bytes <= 0) return '--';
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${bytes} B`;
}
</script>

<style scoped lang="less">
.face-model-setup {
  min-height: calc(100vh - 220px);
  min-height: 560px;
}

.setup-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  min-height: 560px;
  color: rgba(0, 0, 0, 0.45);
  font-size: 14px;
}

.setup-shell {
  position: relative;
  overflow: hidden;
  border-radius: 12px;
  background: #fff;
  min-height: 560px;
}

.setup-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.setup-bg-glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.45;

  &--left {
    width: 420px;
    height: 420px;
    top: -120px;
    left: -80px;
    background: radial-gradient(circle, #266cfb 0%, transparent 70%);
    opacity: 0.12;
  }

  &--right {
    width: 360px;
    height: 360px;
    bottom: -80px;
    right: 10%;
    background: radial-gradient(circle, #5ba3f5 0%, transparent 70%);
    opacity: 0.1;
  }
}

.setup-bg-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(38, 108, 251, 0.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(38, 108, 251, 0.04) 1px, transparent 1px);
  background-size: 32px 32px;
  mask-image: linear-gradient(to bottom, rgba(0, 0, 0, 0.6), transparent 85%);
}

.setup-layout {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 1fr 420px;
  gap: 0;
  min-height: 560px;

  @media (max-width: 960px) {
    grid-template-columns: 1fr;
  }
}

.setup-intro {
  padding: 56px 48px 56px 56px;
  display: flex;
  flex-direction: column;
  justify-content: center;

  @media (max-width: 960px) {
    padding: 40px 32px 24px;
  }
}

.setup-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  width: fit-content;
  padding: 6px 14px;
  margin-bottom: 24px;
  border-radius: 20px;
  background: rgba(38, 108, 251, 0.08);
  border: 1px solid rgba(38, 108, 251, 0.15);
  color: #266cfb;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 0.02em;
}

.setup-badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #266cfb;
  box-shadow: 0 0 0 3px rgba(38, 108, 251, 0.25);
  animation: pulse-dot 2s ease-in-out infinite;
}

@keyframes pulse-dot {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.setup-headline {
  margin: 0 0 16px;
  font-size: 32px;
  font-weight: 700;
  line-height: 1.25;
  color: #050708;
  letter-spacing: -0.02em;

  @media (max-width: 960px) {
    font-size: 26px;
  }
}

.setup-lead {
  margin: 0 0 32px;
  max-width: 480px;
  font-size: 15px;
  line-height: 1.7;
  color: rgba(0, 0, 0, 0.55);

  strong {
    color: #266cfb;
    font-weight: 600;
  }
}

.setup-metrics {
  display: flex;
  gap: 16px;
  margin-bottom: 36px;
  flex-wrap: wrap;
}

.setup-metric {
  flex: 1;
  min-width: 100px;
  padding: 16px 20px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.8);
  border: 1px solid rgba(38, 108, 251, 0.1);
  backdrop-filter: blur(8px);
}

.setup-metric-value {
  font-size: 20px;
  font-weight: 700;
  color: #050708;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
}

.setup-metric-label {
  margin-top: 4px;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
}

.setup-features {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 14px;

  li {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    font-size: 14px;
    line-height: 1.5;
    color: rgba(0, 0, 0, 0.65);
  }
}

.setup-feature-icon {
  flex-shrink: 0;
  margin-top: 2px;
  color: #266cfb;
  font-size: 15px;
}

.setup-panel {
  display: flex;
  align-items: stretch;
  padding: 32px 32px 32px 0;

  @media (max-width: 960px) {
    padding: 0 24px 32px;
  }
}

.setup-panel-inner {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 28px;
  border-radius: 16px;
  background: #fff;
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow:
    0 4px 24px rgba(38, 108, 251, 0.08),
    0 1px 3px rgba(0, 0, 0, 0.04);
}

.panel-model-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-bottom: 20px;
  margin-bottom: 24px;
  border-bottom: 1px solid #f0f0f0;
}

.panel-model-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 10px;
  background: linear-gradient(135deg, #eef4ff, #dce8ff);
  color: #266cfb;
}

.panel-model-meta {
  flex: 1;
  min-width: 0;
}

.panel-model-name {
  font-size: 15px;
  font-weight: 600;
  color: #050708;
  font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
}

.panel-model-sub {
  margin-top: 2px;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
}

.panel-progress-zone {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.progress-ring-wrap {
  margin-bottom: 20px;

  :deep(.ant-progress-text) {
    font-size: 22px !important;
    font-weight: 700 !important;
    color: #050708 !important;
  }
}

.progress-headline {
  font-size: 16px;
  font-weight: 600;
  color: #050708;
  margin-bottom: 6px;
}

.progress-bytes {
  font-size: 13px;
  color: rgba(0, 0, 0, 0.45);
  font-variant-numeric: tabular-nums;
  margin-bottom: 28px;
}

.progress-bytes-sep {
  margin: 0 4px;
  opacity: 0.4;
}

.setup-stepper {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 0;
  margin-bottom: 20px;
  text-align: left;
}

.setup-step {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  position: relative;
  padding-bottom: 20px;

  &:last-child {
    padding-bottom: 0;

    .setup-step-line {
      display: none;
    }
  }

  &--done .setup-step-node {
    background: #52c41a;
    border-color: #52c41a;
    color: #fff;
  }

  &--active .setup-step-node {
    background: #266cfb;
    border-color: #266cfb;
    color: #fff;
    box-shadow: 0 0 0 4px rgba(38, 108, 251, 0.2);
  }

  &--pending .setup-step-node {
    background: #fafafa;
    border-color: #e8e8e8;
    color: rgba(0, 0, 0, 0.25);
  }
}

.setup-step-node {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 2px solid #e8e8e8;
  font-size: 12px;
  font-weight: 600;
  transition: all 0.3s ease;
}

.setup-step-text {
  flex: 1;
  padding-top: 3px;
}

.setup-step-title {
  font-size: 14px;
  font-weight: 500;
  color: #050708;
  line-height: 1.3;
}

.setup-step-desc {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
  margin-top: 2px;
}

.setup-step-line {
  position: absolute;
  left: 13px;
  top: 30px;
  width: 2px;
  height: calc(100% - 14px);
  background: #f0f0f0;
}

.setup-step--done .setup-step-line {
  background: #b7eb8f;
}

.progress-footnote {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0;
  padding: 10px 14px;
  width: 100%;
  border-radius: 8px;
  background: #f8faff;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
  line-height: 1.5;
}

.panel-error {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px 16px;
  text-align: center;
}

.panel-error-icon {
  font-size: 40px;
  color: #ff4d4f;
  margin-bottom: 12px;
}

.panel-error-msg {
  margin: 0;
  font-size: 14px;
  color: rgba(0, 0, 0, 0.65);
  line-height: 1.6;
}

.panel-resume-hint {
  margin: 12px 0 0;
  font-size: 12px;
  color: #266cfb;
  line-height: 1.6;
}

.panel-idle {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 16px 8px 24px;
}

.panel-idle-visual {
  position: relative;
  width: 100px;
  height: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20px;
}

.panel-idle-ring {
  position: absolute;
  border-radius: 50%;
  border: 1px solid rgba(38, 108, 251, 0.15);

  &--outer {
    inset: 0;
    animation: ring-pulse 3s ease-in-out infinite;
  }

  &--inner {
    inset: 12px;
    border-color: rgba(38, 108, 251, 0.25);
    animation: ring-pulse 3s ease-in-out infinite 0.5s;
  }
}

@keyframes ring-pulse {
  0%,
  100% {
    transform: scale(1);
    opacity: 0.6;
  }
  50% {
    transform: scale(1.05);
    opacity: 1;
  }
}

.panel-idle-icon {
  position: relative;
  z-index: 1;
  font-size: 36px;
  color: #266cfb;
}

.panel-idle-text {
  margin: 0;
  font-size: 13px;
  line-height: 1.7;
  color: rgba(0, 0, 0, 0.55);
  text-align: center;

  strong {
    color: #050708;
    font-weight: 600;
  }
}

.panel-actions {
  margin-top: auto;
  padding-top: 20px;
}

.panel-cta {
  height: 48px;
  font-size: 15px;
  font-weight: 500;
  border-radius: 10px;
  box-shadow: 0 4px 14px rgba(38, 108, 251, 0.35);

  &:hover {
    box-shadow: 0 6px 20px rgba(38, 108, 251, 0.45);
  }
}
</style>

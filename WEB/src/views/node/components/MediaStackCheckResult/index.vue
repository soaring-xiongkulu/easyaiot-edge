<script lang="ts" setup>
import { computed, ref } from 'vue';
import {
  CheckCircleFilled,
  CloseCircleFilled,
  CloseOutlined,
  MinusCircleFilled,
  DownOutlined,
  UpOutlined,
} from '@ant-design/icons-vue';
import { Button } from '@/components/Button';
import { copyText } from '@/utils/copyTextToClipboard';
import type { MediaStackCheckResult } from '@/api/device/node';
import { NODE_TERM } from '../../utils/constants';
import { formatDeployLog, stepStatusLabel } from '../../utils/deployLog';

defineOptions({ name: 'MediaStackCheckResult' });

const props = defineProps<{
  result: MediaStackCheckResult;
}>();

const emit = defineEmits<{ close: [] }>();

const detailExpanded = ref(false);

type OverallTone = 'success' | 'warning' | 'info' | 'error';

const overall = computed(() => {
  const r = props.result;
  if (!r.success) {
    return { tone: 'error' as OverallTone, badge: '检测失败', title: r.message || '无法完成远程检测' };
  }
  if (r.deployed) {
    return { tone: 'success' as OverallTone, badge: '已部署', title: r.message || 'SRS 与 ZLMediaKit 均在运行' };
  }
  if (r.srsRunning || r.zlmRunning) {
    return { tone: 'warning' as OverallTone, badge: '部分部署', title: r.message || `${NODE_TERM.mediaService}未完整部署` };
  }
  return { tone: 'info' as OverallTone, badge: '未部署', title: r.message || `可进行全新${NODE_TERM.deploy}` };
});

const badgeClass = computed(() => {
  const tone = overall.value.tone;
  if (tone === 'success') return 'node-meta-badge--readiness-ready';
  if (tone === 'warning') return 'node-meta-badge--readiness-pending';
  if (tone === 'info') return 'node-meta-badge--status-pending';
  return 'node-meta-badge--status-offline';
});

interface CheckCardItem {
  key: string;
  label: string;
  port?: string;
  status?: string;
  ok?: boolean;
  detail?: string;
}

const SERVICE_PORTS: Record<string, string> = {
  SRS: 'API',
  ZLMediaKit: 'HTTP',
};

function parsePortFromOutput(name: string, output?: string): string | undefined {
  if (!output) return undefined;
  const label = SERVICE_PORTS[name];
  if (!label) return undefined;
  const m = output.match(new RegExp(`${label}\\s+(\\d+)`));
  return m?.[1];
}

const checkCards = computed<CheckCardItem[]>(() => {
  const steps = props.result.steps || [];
  return steps.map((step) => {
    const ok = step.status === 'success' || step.status === 'skipped';
    const port = parsePortFromOutput(step.name, step.output);
    const detailLines = step.output?.split('\n').slice(1).join('\n').trim();
    return {
      key: step.name,
      label: step.name,
      port: port ? `${SERVICE_PORTS[step.name] || '端口'} ${port}` : undefined,
      status: stepStatusLabel(step.status),
      ok,
      detail: detailLines || undefined,
    };
  });
});

const infraCards = computed(() => checkCards.value.filter((c) => c.key === 'SSH 连接' || c.key === 'Docker' || c.key === 'Docker Compose'));
const serviceCards = computed(() => checkCards.value.filter((c) => c.key === 'SRS' || c.key === 'ZLMediaKit'));

const logText = computed(() => formatDeployLog(props.result.steps || []));

function handleCopyLog() {
  if (!logText.value.trim()) return;
  copyText(logText.value, '检测日志已复制');
}
</script>

<template>
  <div class="media-check" :class="`media-check--${overall.tone}`">
    <div class="media-check__hero">
      <div class="media-check__hero-main">
        <span class="node-meta-badge" :class="badgeClass">{{ overall.badge }}</span>
        <p class="media-check__title">{{ overall.title }}</p>
      </div>
      <button type="button" class="media-check__close" aria-label="关闭检测结果" @click="emit('close')">
        <CloseOutlined />
      </button>
    </div>

    <div v-if="serviceCards.length" class="media-check__section">
      <div class="media-check__section-title">{{ NODE_TERM.mediaService }}</div>
      <div class="media-check__grid media-check__grid--services">
        <div
          v-for="item in serviceCards"
          :key="item.key"
          class="media-check-card"
          :class="item.ok ? 'is-ok' : 'is-fail'"
        >
          <div class="media-check-card__head">
            <CheckCircleFilled v-if="item.ok" class="media-check-card__icon" />
            <CloseCircleFilled v-else class="media-check-card__icon" />
            <div class="media-check-card__meta">
              <span class="media-check-card__name">{{ item.label }}</span>
              <span v-if="item.port" class="media-check-card__port">{{ item.port }}</span>
            </div>
            <span class="media-check-card__pill">{{ item.status }}</span>
          </div>
          <pre v-if="item.detail" class="media-check-card__detail">{{ item.detail }}</pre>
        </div>
      </div>
    </div>

    <div v-if="infraCards.length" class="media-check__section">
      <div class="media-check__section-title">运行环境</div>
      <div class="media-check__grid media-check__grid--infra">
        <div
          v-for="item in infraCards"
          :key="item.key"
          class="media-check-chip"
          :class="item.ok ? 'is-ok' : 'is-fail'"
        >
          <CheckCircleFilled v-if="item.ok" class="media-check-chip__icon" />
          <CloseCircleFilled v-else-if="item.status === '失败'" class="media-check-chip__icon" />
          <MinusCircleFilled v-else class="media-check-chip__icon" />
          <span class="media-check-chip__name">{{ item.label }}</span>
          <span class="media-check-chip__status">{{ item.status }}</span>
        </div>
      </div>
    </div>

    <div v-if="logText.trim()" class="media-check__log">
      <div class="media-check__log-header">
        <button type="button" class="media-check__log-toggle" @click="detailExpanded = !detailExpanded">
          <span>检测明细</span>
          <UpOutlined v-if="detailExpanded" />
          <DownOutlined v-else />
        </button>
        <Button size="small" @click="handleCopyLog">复制日志</Button>
      </div>
      <pre v-show="detailExpanded" class="media-check__log-body">{{ logText }}</pre>
    </div>
  </div>
</template>

<style lang="less" scoped>
@import '../../utils/theme.less';
@import '../../utils/node-badge.less';
@import '../../utils/setup-panel.less';

.media-check {
  .setup-section-card();
  margin-top: 12px;
  padding: 16px 20px;
  border-left-width: 3px;
  border-left-style: solid;

  &--success {
    border-left-color: #d9f7be;
  }

  &--warning {
    border-left-color: #ffe7ba;
  }

  &--info {
    border-left-color: #adc6ff;
  }

  &--error {
    border-left-color: #ffccc7;
  }
}

.media-check__hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid @node-border-light;
}

.media-check__hero-main {
  flex: 1;
  min-width: 0;
}

.media-check__close {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  margin: -2px -2px 0 0;
  padding: 0;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: @node-text-muted;
  font-size: 12px;
  cursor: pointer;
  transition: color 0.2s, background 0.2s;

  &:hover {
    color: @node-text-secondary;
    background: @node-border-light;
  }
}

.media-check__title {
  margin: 10px 0 0;
  font-size: @node-font-body;
  line-height: 1.65;
  color: @node-text-body;
}

.media-check__section {
  & + & {
    margin-top: 14px;
    padding-top: 14px;
    border-top: 1px dashed @node-border-light;
  }
}

.media-check__section-title {
  margin-bottom: 10px;
  font-size: @node-font-caption;
  font-weight: 500;
  color: @node-text-muted;
}

.media-check__grid {
  display: grid;
  gap: 8px;

  &--services {
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  }

  &--infra {
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  }
}

.media-check-card {
  padding: 12px 14px;
  border-radius: @node-radius;
  border: 1px solid @node-border-light;
  background: #fff;
}

.media-check-card__head {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.media-check-card__icon {
  margin-top: 2px;
  font-size: 16px;

  .is-ok & {
    color: #52c41a;
  }

  .is-fail & {
    color: #ff4d4f;
  }
}

.media-check-card__meta {
  flex: 1;
  min-width: 0;
}

.media-check-card__name {
  display: block;
  font-size: @node-font-body;
  font-weight: 500;
  color: @node-text-primary;
}

.media-check-card__port {
  display: block;
  margin-top: 2px;
  font-size: 12px;
  color: @node-text-muted;
}

.media-check-card__pill {
  flex-shrink: 0;
  font-size: 12px;
  color: @node-text-muted;

  .is-ok & {
    color: #389e0d;
  }

  .is-fail & {
    color: #cf1322;
  }
}

.media-check-card__detail {
  margin: 10px 0 0;
  padding: 8px 10px;
  max-height: 88px;
  overflow: auto;
  border-radius: 6px;
  background: #fafafa;
  border: 1px solid @node-border-light;
  font-family: Consolas, Monaco, 'Courier New', monospace;
  font-size: 11px;
  line-height: 1.5;
  color: @node-text-secondary;
  white-space: pre-wrap;
  word-break: break-all;
}

.media-check-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: @node-radius;
  border: 1px solid @node-border-light;
  background: #fafafa;

  &.is-ok .media-check-chip__icon {
    color: #52c41a;
  }

  &.is-fail .media-check-chip__icon {
    color: #ff4d4f;
  }
}

.media-check-chip__icon {
  font-size: 14px;
}

.media-check-chip__name {
  flex: 1;
  font-size: @node-font-caption;
  color: @node-text-body;
}

.media-check-chip__status {
  font-size: 12px;
  color: @node-text-muted;
}

.media-check__log {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px dashed @node-border-light;
}

.media-check__log-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.media-check__log-toggle {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 0;
  border: none;
  background: none;
  font-size: @node-font-caption;
  color: @node-text-secondary;
  cursor: pointer;

  &:hover {
    color: @node-primary;
  }
}

.media-check__log-body {
  margin: 10px 0 0;
  padding: 12px 14px;
  max-height: 280px;
  overflow: auto;
  border-radius: 0 0 4px 4px;
  border: 1px solid #d9d9d9;
  background: #f5f5f5;
  font-family: Consolas, Monaco, 'Courier New', monospace;
  font-size: 13px;
  line-height: 1.6;
  color: #262626;
  white-space: pre-wrap;
  word-break: break-word;
}
</style>

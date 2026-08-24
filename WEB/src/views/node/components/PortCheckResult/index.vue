<script lang="ts" setup>
import { computed, ref } from 'vue';
import {
  CheckCircleFilled,
  CloseCircleFilled,
  CloseOutlined,
  DownOutlined,
  UpOutlined,
} from '@ant-design/icons-vue';
import { Button } from '@/components/Button';
import { copyText } from '@/utils/copyTextToClipboard';
import type { PortCheckResult } from '@/api/device/node';
import { formatDeployLog } from '../../utils/deployLog';

defineOptions({ name: 'PortCheckResult' });

const props = defineProps<{
  result: PortCheckResult;
}>();

const emit = defineEmits<{ close: [] }>();

const detailExpanded = ref(false);

type OverallTone = 'success' | 'warning' | 'error';

const overall = computed(() => {
  const r = props.result;
  if (!r.success) {
    return { tone: 'error' as OverallTone, badge: '检测失败', title: r.message || '无法完成端口检测' };
  }
  if (r.portsReady) {
    const occupied = (r.ports || []).filter((p) => p.status === 'allowed').length;
    if (occupied > 0) {
      return {
        tone: 'success' as OverallTone,
        badge: '可部署',
        title: r.message || `${occupied} 个端口已被本平台服务占用，其余端口空闲`,
      };
    }
    return { tone: 'success' as OverallTone, badge: '端口空闲', title: r.message || '部署端口均空闲' };
  }
  return { tone: 'error' as OverallTone, badge: '端口冲突', title: r.message || '存在端口占用冲突' };
});

const badgeClass = computed(() => {
  const tone = overall.value.tone;
  if (tone === 'success') return 'node-meta-badge--readiness-ready';
  return 'node-meta-badge--status-offline';
});

const statusLabel: Record<string, string> = {
  free: '空闲',
  allowed: '本平台占用',
  occupied: '冲突',
};

const portCards = computed(() =>
  (props.result.ports || []).map((item) => ({
    key: `${item.name}-${item.port}`,
    label: item.name,
    port: item.port,
    status: statusLabel[item.status] || item.status,
    ok: item.status === 'free' || item.status === 'allowed',
    detail: item.process,
  })),
);

const logText = computed(() => formatDeployLog(props.result.steps || []));

function handleCopyLog() {
  if (!logText.value.trim()) return;
  copyText(logText.value, '检测日志已复制');
}
</script>

<template>
  <div class="port-check" :class="`port-check--${overall.tone}`">
    <div class="port-check__hero">
      <div class="port-check__hero-main">
        <span class="node-meta-badge" :class="badgeClass">{{ overall.badge }}</span>
        <p class="port-check__title">{{ overall.title }}</p>
      </div>
      <button type="button" class="port-check__close" aria-label="关闭检测结果" @click="emit('close')">
        <CloseOutlined />
      </button>
    </div>

    <div v-if="portCards.length" class="port-check__section">
      <div class="port-check__section-title">部署端口</div>
      <div class="port-check__grid">
        <div
          v-for="item in portCards"
          :key="item.key"
          class="port-check-card"
          :class="item.ok ? 'is-ok' : 'is-fail'"
        >
          <div class="port-check-card__head">
            <CheckCircleFilled v-if="item.ok" class="port-check-card__icon" />
            <CloseCircleFilled v-else class="port-check-card__icon" />
            <div class="port-check-card__meta">
              <span class="port-check-card__name">{{ item.label }}</span>
              <span class="port-check-card__port">端口 {{ item.port }}</span>
            </div>
            <span class="port-check-card__pill">{{ item.status }}</span>
          </div>
          <pre v-if="item.detail" class="port-check-card__detail">{{ item.detail }}</pre>
        </div>
      </div>
    </div>

    <div v-if="logText.trim()" class="port-check__log">
      <div class="port-check__log-header">
        <button type="button" class="port-check__log-toggle" @click="detailExpanded = !detailExpanded">
          <span>检测明细</span>
          <UpOutlined v-if="detailExpanded" />
          <DownOutlined v-else />
        </button>
        <Button size="small" @click="handleCopyLog">复制日志</Button>
      </div>
      <pre v-show="detailExpanded" class="port-check__log-body">{{ logText }}</pre>
    </div>
  </div>
</template>

<style lang="less" scoped>
@import '../../utils/theme.less';
@import '../../utils/node-badge.less';
@import '../../utils/setup-panel.less';

.port-check {
  .setup-section-card();
  margin-top: 12px;
  padding: 16px 20px;
  border-left-width: 3px;
  border-left-style: solid;

  &--success {
    border-left-color: #d9f7be;
  }

  &--error {
    border-left-color: #ffccc7;
  }
}

.port-check__hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid @node-border-light;
}

.port-check__hero-main {
  flex: 1;
  min-width: 0;
}

.port-check__close {
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

.port-check__title {
  margin: 10px 0 0;
  font-size: @node-font-body;
  line-height: 1.65;
  color: @node-text-body;
}

.port-check__section-title {
  margin-bottom: 10px;
  font-size: @node-font-caption;
  font-weight: 500;
  color: @node-text-muted;
}

.port-check__grid {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
}

.port-check-card {
  padding: 12px 14px;
  border-radius: @node-radius;
  border: 1px solid @node-border-light;
  background: #fff;
}

.port-check-card__head {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.port-check-card__icon {
  margin-top: 2px;
  font-size: 16px;

  .is-ok & {
    color: #52c41a;
  }

  .is-fail & {
    color: #ff4d4f;
  }
}

.port-check-card__meta {
  flex: 1;
  min-width: 0;
}

.port-check-card__name {
  display: block;
  font-size: @node-font-body;
  font-weight: 500;
  color: @node-text-primary;
}

.port-check-card__port {
  display: block;
  margin-top: 2px;
  font-size: 12px;
  color: @node-text-muted;
}

.port-check-card__pill {
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

.port-check-card__detail {
  margin: 10px 0 0;
  padding: 8px 10px;
  max-height: 72px;
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

.port-check__log {
  margin-top: 14px;
  padding-top: 14px;
  border-top: 1px dashed @node-border-light;
}

.port-check__log-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.port-check__log-toggle {
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

.port-check__log-body {
  margin: 10px 0 0;
  padding: 12px 14px;
  max-height: 240px;
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

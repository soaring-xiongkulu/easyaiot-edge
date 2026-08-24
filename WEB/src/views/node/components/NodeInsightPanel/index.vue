<script lang="ts" setup>
import { computed } from 'vue';
import { Alert, Tag } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { ScrollContainer } from '@/components/Container';
import type { ClusterInsight, AttentionNode } from '../../utils/clusterMetrics';
import { NODE_STATUS_MAP, NODE_TERM } from '../../utils/constants';

defineOptions({ name: 'NodeInsightPanel' });

const props = defineProps<{
  insight: ClusterInsight;
  attentionNodes: AttentionNode[];
  stats: {
    pending: number;
    offline: number;
  };
}>();

const emit = defineEmits<{
  filter: [status?: string];
  view: [id: number];
}>();

const alertType = computed(() => {
  const map = {
    success: 'success',
    warning: 'warning',
    error: 'error',
    info: 'info',
  } as const;
  return map[props.insight.level] || 'info';
});

const showAttention = computed(() => props.attentionNodes.length > 0);

const quickActions = computed(() => {
  const actions: { label: string; status?: string }[] = [];
  if (props.stats.pending > 0) {
    actions.push({ label: `${NODE_STATUS_MAP.pending.text} (${props.stats.pending})`, status: 'pending' });
  }
  if (props.stats.offline > 0) {
    actions.push({ label: `离线节点 (${props.stats.offline})`, status: 'offline' });
  }
  return actions;
});

const alertMessage = computed(() => props.insight.title);
const alertDescription = computed(() => {
  const parts = [props.insight.description];
  if (props.insight.action) parts.push(props.insight.action);
  return parts.join(' ');
});
</script>

<template>
  <div class="insight-panel">
    <Alert
      :type="alertType"
      show-icon
      :message="alertMessage"
      :description="alertDescription"
      class="insight-panel__alert"
    >
      <template v-if="quickActions.length" #action>
        <div class="insight-panel__actions">
          <Button
            v-for="action in quickActions"
            :key="action.status"
            size="small"
            @click="emit('filter', action.status)"
          >
            {{ action.label }}
          </Button>
        </div>
      </template>
    </Alert>

    <div v-if="showAttention" class="attention-section">
      <div class="attention-section__head">
        <span class="attention-section__title">{{ NODE_TERM.attentionNodes }}</span>
        <Tag color="error">{{ attentionNodes.length }} 台</Tag>
      </div>
      <ScrollContainer class="attention-section__scroll">
        <div class="attention-list">
          <button
            v-for="node in attentionNodes.slice(0, 8)"
            :key="node.id"
            type="button"
            class="attention-item"
            @click="emit('view', node.id)"
          >
            <span class="attention-item__name">{{ node.name }}</span>
            <span class="attention-item__host">{{ node.host }}</span>
            <Tag color="error" class="attention-item__tag">{{ node.reasons[0] }}</Tag>
          </button>
          <span v-if="attentionNodes.length > 8" class="attention-more">
            另有 {{ attentionNodes.length - 8 }} 台节点需关注
          </span>
        </div>
      </ScrollContainer>
    </div>
  </div>
</template>

<style lang="less" scoped>
@import '../../utils/theme.less';

.insight-panel {
  margin-bottom: 12px;
}

.insight-panel__alert {
  border-radius: @node-radius;

  :deep(.ant-alert-message) {
    font-size: 13px;
    font-weight: 600;
  }

  :deep(.ant-alert-description) {
    font-size: 12px;
    line-height: 1.5;
  }
}

.attention-section {
  margin-top: 8px;
  padding: 10px 12px;
  background: @node-bg;
  border: 1px solid @node-border;
  border-radius: @node-radius;
}

.attention-section__head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.attention-section__title {
  font-size: 13px;
  font-weight: 600;
  color: @node-text-primary;
}

.insight-panel__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.attention-section__scroll {
  max-height: 64px;
}

.attention-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 12px;
}

.attention-item {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 4px 10px;
  background: @node-border-light;
  border: 1px solid transparent;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  transition: border-color 0.15s, background 0.15s;

  &:hover {
    border-color: @node-primary-light;
    background: @node-primary-bg;

    .attention-item__name {
      color: @node-primary;
    }
  }
}

.attention-item__name {
  font-weight: 600;
  color: @node-text-primary;
  white-space: nowrap;
  transition: color 0.15s;
}

.attention-item__host {
  color: @node-text-muted;
  font-family: Consolas, monospace;
  font-size: @node-font-caption;
  white-space: nowrap;
}

.attention-item__tag {
  margin: 0;
  font-size: 12px;
}

.attention-more {
  font-size: @node-font-caption;
  color: @node-text-muted;
  align-self: center;
}
</style>

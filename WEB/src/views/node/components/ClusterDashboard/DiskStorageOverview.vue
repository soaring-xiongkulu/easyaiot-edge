<script lang="ts" setup>
import MetricBar from './MetricBar.vue';
import { useRender } from '@/components/Table';
import type { NodeDiskItem } from '../../utils/clusterMetrics';
import { formatPercent, formatStorageRange, getProgressColor } from '../../utils/clusterMetrics';
import { NODE_DASHBOARD, NODE_STATUS_MAP } from '../../utils/constants';

defineOptions({ name: 'DiskStorageOverview' });

defineProps<{
  nodes: NodeDiskItem[];
}>();

function statusTag(status?: string) {
  return NODE_STATUS_MAP[status || ''] || { text: status || '-', color: 'default' };
}

function renderStatusTag(status?: string) {
  const item = statusTag(status);
  return useRender.renderTag(item.text, item.color);
}
</script>

<template>
  <div v-if="!nodes.length" class="disk-storage-empty">
    {{ NODE_DASHBOARD.noDiskData }}
  </div>
  <div v-else class="disk-storage-list">
    <div class="disk-storage-head">
      <span>{{ NODE_DASHBOARD.colName }}</span>
      <span>{{ NODE_DASHBOARD.diskColUsage }}</span>
      <span>{{ NODE_DASHBOARD.diskColCapacity }}</span>
    </div>
    <div v-for="node in nodes" :key="node.id" class="disk-storage-node">
      <div class="disk-storage-node__info">
        <div class="disk-storage-node__title">
          <span class="disk-storage-node__name">{{ node.name }}</span>
          <component :is="renderStatusTag(node.status)" class="disk-storage-node__tag" />
        </div>
        <div class="disk-storage-node__meta">
          <span>{{ node.host }}</span>
          <span v-if="node.disk >= 90" class="disk-storage-node__warn">{{ NODE_DASHBOARD.diskTight }}</span>
          <span v-else-if="node.disk >= 75" class="disk-storage-node__caution">{{ NODE_DASHBOARD.usageHigh }}</span>
        </div>
      </div>
      <div class="disk-storage-node__bar">
        <div class="disk-storage-node__percent">{{ formatPercent(node.disk) }}</div>
        <MetricBar :percent="node.disk" :stroke-color="getProgressColor(node.disk)" />
      </div>
      <div v-if="node.diskTotalBytes" class="disk-storage-node__capacity">
        {{ formatStorageRange(node.diskUsedBytes, node.diskTotalBytes) }}
      </div>
      <span v-else class="disk-storage-node__capacity disk-storage-node__capacity--empty">—</span>
    </div>
  </div>
</template>

<style lang="less" scoped>
.disk-storage-empty {
  padding: 32px 16px;
  text-align: center;
  font-size: 13px;
  color: #8c8c8c;
  background: #fafafa;
  border: 1px dashed #e8e8e8;
  border-radius: 4px;
}

.disk-storage-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.disk-storage-head,
.disk-storage-node {
  display: grid;
  grid-template-columns: 220px 1fr 120px;
  gap: 20px;
  align-items: center;
  padding: 0 16px;
}

.disk-storage-head {
  font-size: 12px;
  color: #8c8c8c;
  padding-bottom: 4px;

  span:nth-child(2),
  span:nth-child(3) {
    text-align: right;
  }
}

.disk-storage-node {
  padding: 14px 16px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 4px;

  &:hover {
    background: #f5f5f5;
  }
}

.disk-storage-node__info {
  min-width: 0;
}

.disk-storage-node__title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.disk-storage-node__name {
  font-size: 14px;
  font-weight: 600;
  color: #262626;
}

.disk-storage-node__tag {
  margin: 0;
}

.disk-storage-node__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  font-size: 12px;
  color: #8c8c8c;

  span:first-child {
    font-family: Consolas, monospace;
  }
}

.disk-storage-node__size {
  color: #595959;
  font-variant-numeric: tabular-nums;
}

.disk-storage-node__capacity {
  font-size: 13px;
  color: #595959;
  font-variant-numeric: tabular-nums;
  text-align: right;
  white-space: nowrap;

  &--empty {
    color: #bfbfbf;
    text-align: right;
  }
}

.disk-storage-node__warn {
  color: #ff4d4f;
  font-weight: 500;
}

.disk-storage-node__caution {
  color: #faad14;
  font-weight: 500;
}

.disk-storage-node__bar {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.disk-storage-node__percent {
  flex-shrink: 0;
  width: 48px;
  font-size: 13px;
  font-weight: 600;
  color: #595959;
  font-variant-numeric: tabular-nums;
  text-align: right;
}

@media (max-width: 900px) {
  .disk-storage-head {
    display: none;
  }

  .disk-storage-node {
    grid-template-columns: 1fr;
    gap: 10px;
  }

  .disk-storage-node__capacity {
    text-align: left;
  }
}
</style>

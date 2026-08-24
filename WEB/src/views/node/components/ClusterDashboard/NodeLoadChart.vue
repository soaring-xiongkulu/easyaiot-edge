<script lang="ts" setup>
import { useRender } from '@/components/Table';
import NodeGpuMiniBars from '../NodeGpuMiniBars/index.vue';
import MetricBar from './MetricBar.vue';
import type { NodeLoadItem } from '../../utils/clusterMetrics';
import { formatCpuQuantity, formatPercent, formatStorageRange, getProgressColor } from '../../utils/clusterMetrics';
import { NODE_DASHBOARD, NODE_METRIC, NODE_STATUS_MAP } from '../../utils/constants';

defineOptions({ name: 'ClusterNodeLoadTable' });

defineProps<{
  nodes: NodeLoadItem[];
}>();

function statusTag(status?: string) {
  const item = NODE_STATUS_MAP[status || ''];
  return item || { text: status || '-', color: 'default' };
}

function renderStatusTag(status?: string) {
  const item = statusTag(status);
  return useRender.renderTag(item.text, item.color);
}
</script>

<template>
  <div class="node-resource-table">
    <div v-if="!nodes.length" class="node-resource-table__empty">
      {{ NODE_DASHBOARD.noComputeNodes }}
    </div>
    <template v-else>
      <div class="table-head">
        <span>{{ NODE_DASHBOARD.colName }}</span>
        <span>{{ NODE_DASHBOARD.colHost }}</span>
        <span>{{ NODE_DASHBOARD.colStatus }}</span>
        <span>{{ NODE_METRIC.cpu }}</span>
        <span>{{ NODE_METRIC.mem }}</span>
        <span>{{ NODE_METRIC.vram }}</span>
        <span>{{ NODE_METRIC.disk }}</span>
      </div>
      <div v-for="node in nodes" :key="node.id" class="table-row">
        <span class="node-name">{{ node.name }}</span>
        <span class="node-host">{{ node.host }}</span>
        <span>
        <component :is="renderStatusTag(node.status)" />
        </span>
        <div class="metric-cell">
          <span class="metric-cell__pct">{{ formatCpuQuantity(node.cpu) }}</span>
          <MetricBar
            :percent="Math.min(node.cpu, 100)"
            :stroke-color="getProgressColor(Math.min(node.cpu, 100))"
          />
        </div>
        <div class="metric-cell">
          <div class="metric-cell__head">
            <span class="metric-cell__pct">{{ formatPercent(node.mem) }}</span>
            <span v-if="node.memTotalBytes" class="metric-cell__sep">·</span>
            <span v-if="node.memTotalBytes" class="metric-cell__size">
              {{ formatStorageRange(node.memUsedBytes, node.memTotalBytes) }}
            </span>
          </div>
          <MetricBar :percent="node.mem" :stroke-color="getProgressColor(node.mem)" />
        </div>
        <div class="gpu-cell">
          <NodeGpuMiniBars
            v-if="node.gpuInfo"
            :gpu-info="node.gpuInfo"
            metric="vram"
            compact
            :show-label="false"
          />
          <span v-else class="gpu-cell__empty">—</span>
        </div>
        <div class="metric-cell">
          <div class="metric-cell__head">
            <span class="metric-cell__pct">{{ formatPercent(node.disk) }}</span>
            <span v-if="node.diskTotalBytes" class="metric-cell__sep">·</span>
            <span v-if="node.diskTotalBytes" class="metric-cell__size">
              {{ formatStorageRange(node.diskUsedBytes, node.diskTotalBytes) }}
            </span>
          </div>
          <MetricBar :percent="node.disk" :stroke-color="getProgressColor(node.disk)" />
        </div>
      </div>
    </template>
  </div>
</template>

<style lang="less" scoped>
.node-resource-table {
  background: #fff;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  overflow: hidden;
}

.node-resource-table__empty {
  padding: 32px;
  text-align: center;
  color: #8c8c8c;
  font-size: 13px;
}

.table-head,
.table-row {
  display: grid;
  grid-template-columns: 1fr 1.1fr 0.7fr repeat(3, 0.9fr) 1.1fr;
  gap: 12px;
  align-items: center;
  padding: 12px 16px;
}

.table-head {
  font-size: 12px;
  color: #8c8c8c;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
}

.table-row {
  border-bottom: 1px solid #f0f0f0;
  font-size: 13px;

  &:last-child {
    border-bottom: none;
  }

  &:hover {
    background: #fafafa;
  }
}

.node-name {
  font-weight: 500;
  color: #262626;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.node-host {
  font-family: Consolas, monospace;
  font-size: 12px;
  color: #595959;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.metric-cell {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 12px;
  color: #595959;
  font-variant-numeric: tabular-nums;
}

.metric-cell__head {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 6px;
  line-height: 1.3;
}

.metric-cell__pct {
  font-weight: 500;
  color: #262626;
  white-space: nowrap;
}

.metric-cell__sep {
  color: #d9d9d9;
  user-select: none;
}

.metric-cell__size {
  font-size: 11px;
  color: #8c8c8c;
  white-space: nowrap;
}

.gpu-cell {
  min-width: 0;
}

.gpu-cell__empty {
  color: #bfbfbf;
}

@media (max-width: 1400px) {
  .table-head {
    display: none;
  }

  .table-row {
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
}
</style>

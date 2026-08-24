<script lang="ts" setup>
import { computed } from 'vue';
import { Progress, Spin } from 'ant-design-vue';
import type { ComputeNodeVO } from '@/api/device/node';
import {
  aggregateGpuVram,
  formatPercent,
  formatStorageRange,
  getProgressColor,
} from '../../utils/clusterMetrics';
import { NODE_DASHBOARD, NODE_DETAIL, NODE_METRIC, parseGpuInfo } from '../../utils/constants';
import NodeGpuMiniBars from '../NodeGpuMiniBars/index.vue';

defineOptions({ name: 'NodeDetailResourcePanel' });

const props = defineProps<{
  node?: ComputeNodeVO | null;
  loading?: boolean;
}>();

const hasMetrics = computed(
  () =>
    props.node?.cpuPercent != null ||
    props.node?.memPercent != null ||
    props.node?.diskPercent != null ||
    props.node?.lastHeartbeatAt,
);

const gpuList = computed(() => parseGpuInfo(props.node?.gpuInfo));
const gpuVram = computed(() => aggregateGpuVram(gpuList.value));

function progressPercent(value?: number | null): number {
  if (value == null) return 0;
  return Math.min(Number(value), 100);
}

function formatCapacityText(item: { key: string; capacity?: string | null }): string {
  if (item.capacity && item.capacity !== '-') return item.capacity;
  if (item.key === 'cpu') return '';
  return '—';
}

const metricCards = computed(() => {
  const node = props.node;
  return [
    {
      key: 'cpu',
      label: NODE_METRIC.cpu,
      percent: node?.cpuPercent,
      capacity: null,
    },
    {
      key: 'mem',
      label: NODE_DASHBOARD.statMemCapacity,
      percent: node?.memPercent,
      capacity: formatStorageRange(node?.memUsedBytes, node?.memTotalBytes),
    },
    {
      key: 'vram',
      label: NODE_DASHBOARD.statVramCapacity,
      percent: gpuVram.value.totalBytes > 0 ? gpuVram.value.avgPercent : null,
      capacity: formatStorageRange(gpuVram.value.usedBytes, gpuVram.value.totalBytes),
    },
    {
      key: 'disk',
      label: NODE_DASHBOARD.statDiskCapacity,
      percent: node?.diskPercent,
      capacity: formatStorageRange(node?.diskUsedBytes, node?.diskTotalBytes),
    },
  ];
});
</script>

<template>
  <Spin :spinning="!!loading">
    <div class="resource-panel">
      <div v-if="!loading && !hasMetrics" class="resource-panel__empty">
        {{ NODE_DETAIL.noMetrics }}
      </div>

      <template v-else-if="hasMetrics || !loading">
      <div class="metric-grid">
        <div v-for="item in metricCards" :key="item.key" class="metric-card">
          <span class="metric-card__label">{{ item.label }}</span>
          <div class="metric-card__body">
            <strong
              class="metric-card__capacity"
              :class="{ 'metric-card__capacity--empty': !formatCapacityText(item) }"
            >
              {{ formatCapacityText(item) }}
            </strong>
            <span
              class="metric-card__percent"
              :class="{ 'metric-card__percent--empty': item.percent == null }"
            >
              {{ item.percent != null ? formatPercent(item.percent) : '—' }}
            </span>
          </div>
          <Progress
            class="metric-card__progress"
            :percent="progressPercent(item.percent)"
            :stroke-color="getProgressColor(progressPercent(item.percent))"
            :show-info="false"
            size="small"
          />
        </div>
      </div>

      <div v-if="gpuList.length" class="gpu-block">
        <div class="gpu-block__head">
          <h4>{{ NODE_DETAIL.gpuSection }}</h4>
          <span class="gpu-block__hint">{{ NODE_DETAIL.gpuSectionHint }}</span>
        </div>

        <div class="gpu-util-grid">
          <div v-for="gpu in gpuList" :key="`util-${gpu.id ?? 0}`" class="gpu-util-item">
            <div class="gpu-util-item__label">
              <span>GPU{{ gpu.id ?? 0 }}</span>
              <span class="gpu-util-item__name">{{ gpu.name || '—' }}</span>
            </div>
            <div class="gpu-metric-row">
              <span class="gpu-metric-row__title">{{ NODE_METRIC.gpuUtil }}</span>
              <NodeGpuMiniBars :gpu-info="[gpu]" metric="util" :show-label="false" />
            </div>
            <div class="gpu-metric-row">
              <span class="gpu-metric-row__title">{{ NODE_METRIC.vramUsage }}</span>
              <NodeGpuMiniBars :gpu-info="[gpu]" metric="vram" :show-label="false" />
            </div>
          </div>
        </div>
      </div>
      </template>
    </div>
  </Spin>
</template>

<style lang="less" scoped>
.resource-panel {
  min-height: 200px;
}

.resource-panel__empty {
  padding: 28px 16px;
  text-align: center;
  font-size: 13px;
  color: #8c8c8c;
  background: #fafafa;
  border: 1px dashed #e8e8e8;
  border-radius: 8px;
}

.metric-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  margin-bottom: 16px;
}

.metric-card {
  display: flex;
  flex-direction: column;
  min-height: 88px;
  padding: 14px 16px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
}

.metric-card__label {
  flex-shrink: 0;
  font-size: 12px;
  color: #8c8c8c;
  line-height: 1.4;
}

.metric-card__body {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  flex: 1;
  min-height: 24px;
  margin-top: 6px;
}

.metric-card__capacity {
  flex: 1;
  min-width: 0;
  font-size: 16px;
  font-weight: 600;
  color: #262626;
  font-variant-numeric: tabular-nums;
  line-height: 1.35;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.metric-card__capacity--empty {
  visibility: hidden;
}

.metric-card__percent {
  flex-shrink: 0;
  min-width: 52px;
  font-size: 14px;
  font-weight: 600;
  color: #262626;
  font-variant-numeric: tabular-nums;
  line-height: 1.35;
  text-align: right;
}

.metric-card__percent--empty {
  color: #bfbfbf;
}

.metric-card__progress {
  flex-shrink: 0;
  margin-top: 10px;
  line-height: 0;

  :deep(.ant-progress) {
    margin: 0;
    line-height: 0;
  }

  :deep(.ant-progress-outer) {
    display: block;
  }

  :deep(.ant-progress-inner) {
    vertical-align: top;
  }
}

.gpu-block {
  margin-top: 4px;
}

.gpu-block__head {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 12px;

  h4 {
    margin: 0;
    font-size: 14px;
    font-weight: 600;
    color: #262626;
  }
}

.gpu-block__hint {
  font-size: 12px;
  color: #8c8c8c;
}

.gpu-util-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  margin-bottom: 12px;
}

.gpu-util-item {
  padding: 12px 14px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
}

.gpu-util-item__label {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
  font-size: 12px;
  color: #595959;
  font-weight: 500;
}

.gpu-util-item__name {
  color: #8c8c8c;
  font-weight: normal;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.gpu-metric-row {
  display: grid;
  grid-template-columns: 72px 1fr;
  gap: 8px;
  align-items: center;
  margin-top: 8px;
}

.gpu-metric-row__title {
  font-size: 11px;
  color: #8c8c8c;
}

@media (max-width: 900px) {
  .metric-grid,
  .gpu-util-grid {
    grid-template-columns: 1fr;
  }
}
</style>

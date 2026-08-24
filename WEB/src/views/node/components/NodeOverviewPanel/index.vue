<script lang="ts" setup>
import { computed } from 'vue';
import { CountTo } from '@/components/CountTo';
import { Icon } from '@/components/Icon';
import { RadioButtonGroup } from '@/components/Form';
import type { ClusterSnapshot } from '../../utils/clusterMetrics';
import { formatPercent, formatStorageRange } from '../../utils/clusterMetrics';
import { NODE_DASHBOARD } from '../../utils/constants';

defineOptions({ name: 'NodeOverviewPanel' });

const props = defineProps<{
  stats: {
    total: number;
    online: number;
    offline: number;
    pending: number;
    maintenance: number;
  };
  snapshot?: ClusterSnapshot | null;
  activeStatus?: string;
}>();

const emit = defineEmits<{
  filter: [status?: string];
}>();

const availability = computed(() => {
  if (props.snapshot) return props.snapshot.availability;
  if (!props.stats.total) return 0;
  return Math.round((props.stats.online / props.stats.total) * 100);
});

const statCards = computed(() => {
  const snap = props.snapshot;
  return [
    {
      key: 'total',
      label: NODE_DASHBOARD.statTotal,
      value: props.stats.total,
      suffix: '',
      icon: 'ant-design:cluster-outlined',
      numeric: true,
    },
    {
      key: 'gpu',
      label: NODE_DASHBOARD.statGpuCount,
      value: snap?.gpuCount ?? 0,
      suffix: '',
      icon: 'ant-design:thunderbolt-outlined',
      numeric: true,
    },
    {
      key: 'tasks',
      label: NODE_DASHBOARD.statRunningTasks,
      value: snap?.activeTasks ?? 0,
      suffix: snap?.maxTasks ? ` / ${snap.maxTasks}` : '',
      icon: 'ant-design:deployment-unit-outlined',
      numeric: true,
    },
    {
      key: 'vram',
      label: NODE_DASHBOARD.statVramCapacity,
      value:
        snap && snap.gpuMemTotalBytes > 0
          ? formatStorageRange(snap.gpuMemUsedBytes, snap.gpuMemTotalBytes)
          : '—',
      suffix:
        snap && snap.gpuMemTotalBytes > 0
          ? ` · ${formatPercent(snap.avgGpuMem)}`
          : '',
      icon: 'ant-design:cloud-server-outlined',
      numeric: false,
    },
    {
      key: 'availability',
      label: NODE_DASHBOARD.statOnlineRate,
      value: availability.value,
      suffix: '%',
      icon: 'ant-design:pie-chart-outlined',
      numeric: true,
    },
  ];
});

const filterOptions = computed(() => [
  { label: `全部 (${props.stats.total})`, value: '' },
  { label: `在线 (${props.stats.online})`, value: 'online' },
  { label: `离线 (${props.stats.offline})`, value: 'offline' },
  { label: `待纳管 (${props.stats.pending})`, value: 'pending' },
  { label: `维护中 (${props.stats.maintenance})`, value: 'maintenance' },
]);

const activeFilter = computed({
  get: () => props.activeStatus || '',
  set: (val: string) => emit('filter', val || undefined),
});
</script>

<template>
  <section class="node-overview">
    <div class="stat-cards">
      <div v-for="item in statCards" :key="item.key" class="stat-card">
        <div class="stat-card__icon">
          <Icon :icon="item.icon" :size="18" />
        </div>
        <div class="stat-card__body">
          <span class="stat-card__label">{{ item.label }}</span>
          <span class="stat-card__value">
            <CountTo
              v-if="item.numeric"
              :start-val="0"
              :end-val="item.value"
              :duration="800"
            />
            <template v-else>{{ item.value }}</template>
            <span v-if="item.suffix" class="stat-card__suffix">{{ item.suffix }}</span>
          </span>
        </div>
      </div>
    </div>

    <div class="filter-bar">
      <span class="filter-bar__label">状态筛选</span>
      <RadioButtonGroup
        v-model:value="activeFilter"
        :options="filterOptions"
        size="small"
        button-style="solid"
        class="filter-bar__group"
      />
    </div>
  </section>
</template>

<style lang="less" scoped>
@import '../../utils/theme.less';

.node-overview {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}

.stat-cards {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 10px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  background: @node-bg;
  border: 1px solid @node-border;
  border-radius: @node-radius;
  transition: border-color 0.2s;

  &:hover {
    border-color: @node-primary-light;
  }
}

.stat-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 6px;
  background: @node-primary-bg;
  color: @node-primary;
  flex-shrink: 0;
}

.stat-card__body {
  min-width: 0;
}

.stat-card__label {
  display: block;
  font-size: 12px;
  color: @node-text-secondary;
  margin-bottom: 2px;
  line-height: 1.3;
}

.stat-card__value {
  display: flex;
  align-items: baseline;
  gap: 2px;
  font-size: 20px;
  font-weight: 600;
  color: @node-text-primary;
  font-variant-numeric: tabular-nums;
  line-height: 1.2;
}

.stat-card__suffix {
  font-size: 13px;
  font-weight: 500;
  color: @node-text-muted;
}

.filter-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.filter-bar__label {
  font-size: 13px;
  color: @node-text-muted;
  flex-shrink: 0;
}

.filter-bar__group {
  flex: 1;
  min-width: 0;

  :deep(.ant-radio-button-wrapper) {
    font-size: @node-font-caption;
  }
}

@media (max-width: 1200px) {
  .stat-cards {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (max-width: 768px) {
  .stat-cards {
    grid-template-columns: repeat(2, 1fr);
  }

  .filter-bar {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>

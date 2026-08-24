<script lang="ts" setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { formatMemMb, formatPercent, getProgressColor } from '../../utils/clusterMetrics';
import { NODE_METRIC, parseGpuInfo, type GpuInfoItem } from '../../utils/constants';

defineOptions({ name: 'NodeGpuMiniBars' });

const props = withDefaults(
  defineProps<{
    gpuInfo?: string | GpuInfoItem[] | null;
    metric?: 'util' | 'vram';
    compact?: boolean;
    showLabel?: boolean;
  }>(),
  {
    metric: 'vram',
    compact: false,
    showLabel: true,
  },
);

const items = computed(() => parseGpuInfo(props.gpuInfo));
const animated = ref(false);

onMounted(() => {
  nextTick(() => {
    animated.value = true;
  });
});

function getPercent(gpu: GpuInfoItem): number {
  if (props.metric === 'util') {
    return Math.min(Math.max(Number(gpu.util ?? 0), 0), 100);
  }
  const total = Number(gpu.mem_total_mb ?? 0);
  const used = Number(gpu.mem_used_mb ?? 0);
  if (!total) return 0;
  return Math.min(Math.round((used / total) * 1000) / 10, 100);
}

function getTooltip(gpu: GpuInfoItem): string {
  const id = gpu.id ?? 0;
  const name = gpu.name || `GPU ${id}`;
  if (props.metric === 'util') {
    return `${name} · ${NODE_METRIC.gpuUtil} ${getPercent(gpu)}%`;
  }
  return `${name} · ${NODE_METRIC.vram} ${formatMemMb(Number(gpu.mem_used_mb ?? 0))} / ${formatMemMb(Number(gpu.mem_total_mb ?? 0))} (${getPercent(gpu)}%)`;
}

function getValueText(gpu: GpuInfoItem): string {
  if (props.metric === 'util') return formatPercent(getPercent(gpu));
  if (props.compact) return formatPercent(getPercent(gpu));
  return formatMemMb(Number(gpu.mem_used_mb ?? 0));
}
</script>

<template>
  <div class="gpu-mini-bars" :class="{ 'gpu-mini-bars--compact': compact }">
    <span v-if="!items.length" class="gpu-mini-bars__empty">—</span>
    <div v-for="gpu in items" :key="gpu.id ?? 0" class="gpu-mini-bar-row">
      <span v-if="showLabel && !compact" class="gpu-mini-bar-row__label">GPU{{ gpu.id ?? 0 }}</span>
      <div class="gpu-mini-bar-row__track" :title="getTooltip(gpu)">
        <div
          class="gpu-mini-bar-row__fill"
          :class="{ 'gpu-mini-bar-row__fill--animated': animated }"
          :style="{
            width: `${getPercent(gpu)}%`,
            backgroundColor: getProgressColor(getPercent(gpu)),
          }"
        />
      </div>
      <span class="gpu-mini-bar-row__value">{{ getValueText(gpu) }}</span>
    </div>
  </div>
</template>

<style lang="less" scoped>
.gpu-mini-bars {
  display: flex;
  flex-direction: column;
  gap: 5px;
  min-width: 0;
}

.gpu-mini-bars--compact {
  gap: 6px;
}

.gpu-mini-bars__empty {
  color: #999;
  font-size: 14px;
}

.gpu-mini-bar-row {
  display: grid;
  grid-template-columns: 36px 1fr auto;
  gap: 6px;
  align-items: center;
  min-width: 0;
}

.gpu-mini-bars--compact .gpu-mini-bar-row {
  grid-template-columns: 1fr auto;
  gap: 4px;
}

.gpu-mini-bar-row__label {
  font-size: 11px;
  color: #8c8c8c;
  font-variant-numeric: tabular-nums;
}

.gpu-mini-bar-row__track {
  height: 6px;
  background: #f0f0f0;
  border-radius: 3px;
  overflow: hidden;
  min-width: 48px;
}

.gpu-mini-bars--compact .gpu-mini-bar-row__track {
  height: 6px;
}

.gpu-mini-bar-row__fill {
  height: 100%;
  border-radius: 3px;
}

.gpu-mini-bar-row__fill--animated {
  transition: width 0.35s ease, background-color 0.35s ease;
}

.gpu-mini-bar-row__value {
  font-size: 13px;
  color: #333;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.gpu-mini-bars--compact .gpu-mini-bar-row__value {
  font-size: 14px;
  min-width: 36px;
  text-align: right;
  font-weight: 500;
}
</style>

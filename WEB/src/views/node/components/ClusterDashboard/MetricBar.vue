<script lang="ts" setup>
import { nextTick, onMounted, ref, watch } from 'vue';
import { getProgressColor } from '../../utils/clusterMetrics';

defineOptions({ name: 'ClusterMetricBar' });

const props = withDefaults(
  defineProps<{
    percent: number;
    strokeColor?: string;
    height?: number;
  }>(),
  {
    height: 6,
  },
);

const displayed = ref(0);
const animated = ref(false);

function clampPercent(raw: number): number {
  const value = Number(raw);
  if (!Number.isFinite(value)) return 0;
  return Math.min(Math.max(value, 0), 100);
}

function resolveColor(percent: number): string {
  return props.strokeColor ?? getProgressColor(percent);
}

watch(
  () => props.percent,
  (val) => {
    displayed.value = clampPercent(val);
  },
  { immediate: true },
);

onMounted(() => {
  nextTick(() => {
    animated.value = true;
  });
});
</script>

<template>
  <div class="metric-bar" :style="{ height: `${height}px` }">
    <div
      class="metric-bar__fill"
      :class="{ 'metric-bar__fill--animated': animated }"
      :style="{
        width: `${displayed}%`,
        backgroundColor: resolveColor(displayed),
      }"
    />
  </div>
</template>

<style lang="less" scoped>
.metric-bar {
  width: 100%;
  background: #f0f0f0;
  border-radius: 100px;
  overflow: hidden;
}

.metric-bar__fill {
  height: 100%;
  border-radius: 100px;
}

.metric-bar__fill--animated {
  transition: width 0.35s ease, background-color 0.35s ease;
}
</style>

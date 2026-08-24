<script lang="ts" setup>
import type { Ref } from 'vue';
import { nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import { useECharts } from '@/hooks/web/useECharts';
import { formatPercentValue, getProgressColor } from '../../utils/clusterMetrics';

defineOptions({ name: 'ClusterGaugePanel' });

const props = defineProps<{
  title: string;
  value: number;
}>();

const chartRef = ref<HTMLDivElement | null>(null);
const { setOptions, resize, getInstance } = useECharts(chartRef as Ref<HTMLDivElement>);
let resizeObserver: ResizeObserver | null = null;
let hasRendered = false;

function buildGaugeOptions(val: number) {
  const color = getProgressColor(Math.min(val, 100));
  const gaugeMax = Math.max(100, Math.ceil(val / 50) * 50);
  return {
    animationDurationUpdate: 600,
    animationEasingUpdate: 'cubicOut',
    series: [
      {
        type: 'gauge',
        animationDuration: 0,
        animationDurationUpdate: 600,
        animationEasingUpdate: 'cubicOut',
        min: 0,
        max: gaugeMax,
        radius: '90%',
        center: ['50%', '58%'],
        startAngle: 200,
        endAngle: -20,
        splitNumber: 4,
        axisLine: {
          lineStyle: {
            width: 12,
            color: [[1, '#f0f0f0']],
          },
        },
        progress: {
          show: true,
          width: 12,
          itemStyle: { color },
        },
        axisTick: { show: false },
        splitLine: { show: false },
        axisLabel: { show: false },
        pointer: { show: false },
        anchor: { show: false },
        detail: {
          show: true,
          valueAnimation: true,
          formatter: (value: number) => `${formatPercentValue(value)}%`,
          color: '#262626',
          fontSize: 20,
          fontWeight: 600,
          offsetCenter: [0, '12%'],
        },
        title: { show: false },
        data: [{ value: val }],
      },
    ],
  };
}

function buildGaugePatch(val: number) {
  const color = getProgressColor(Math.min(val, 100));
  const gaugeMax = Math.max(100, Math.ceil(val / 50) * 50);
  return {
    series: [
      {
        animationDurationUpdate: 600,
        animationEasingUpdate: 'cubicOut',
        max: gaugeMax,
        progress: { itemStyle: { color } },
        data: [{ value: val }],
      },
    ],
  };
}

function renderGauge(raw?: number, initial = false) {
  const val = Math.max(Number(raw ?? props.value) || 0, 0);
  if (initial || !hasRendered) {
    void setOptions(buildGaugeOptions(val), true);
  } else {
    getInstance()?.setOption(buildGaugePatch(val), false);
  }
  hasRendered = true;
}

function tryInitialRender() {
  const el = chartRef.value;
  if (!el || el.offsetWidth <= 0 || el.offsetHeight <= 0) return;
  resize();
  renderGauge(undefined, true);
}

watch(
  () => props.value,
  (val) => {
    if (!hasRendered) {
      tryInitialRender();
      return;
    }
    renderGauge(val, false);
  },
);

onMounted(() => {
  nextTick(() => {
    tryInitialRender();
  });

  const el = chartRef.value;
  if (!el || typeof ResizeObserver === 'undefined') return;

  resizeObserver = new ResizeObserver(() => {
    if (el.offsetWidth <= 0 || el.offsetHeight <= 0) return;
    resize();
    if (!hasRendered) {
      renderGauge(undefined, true);
    }
  });
  resizeObserver.observe(el);
});

onUnmounted(() => {
  resizeObserver?.disconnect();
  resizeObserver = null;
});
</script>

<template>
  <div class="gauge-panel">
    <div ref="chartRef" class="gauge-chart" />
    <div class="gauge-panel__title">{{ title }}</div>
  </div>
</template>

<style lang="less" scoped>
.gauge-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 0;
}

.gauge-chart {
  width: 100%;
  height: 110px;
  min-height: 110px;
}

.gauge-panel__title {
  margin-top: 2px;
  padding: 0 4px;
  font-size: 12px;
  line-height: 1.4;
  color: #8c8c8c;
  text-align: center;
  word-break: break-all;
}
</style>

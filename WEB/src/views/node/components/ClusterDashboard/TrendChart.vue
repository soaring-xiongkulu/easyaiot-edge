<script lang="ts" setup>
import type { Ref } from 'vue';
import { computed, ref, watch } from 'vue';
import { useECharts } from '@/hooks/web/useECharts';
import type {
  ClusterTrendPoint,
  NodeTrendPoint,
  NodeTrendSeries,
  TrendMetricKey,
  TrendViewMode,
} from '../../utils/clusterMetrics';
import {
  buildClusterNodeTrendSeries,
  buildContinuousTrendData,
  collectTrendTimestamps,
  formatClusterTrendTooltipValue,
  formatTrendAxisBytes,
  formatTrendTimestamps,
  formatTrendTooltipValue,
  getNodeTrendPalette,
  getTrendMetricValue,
  getTrendVolumeBytes,
  isTrendVolumeMetric,
} from '../../utils/clusterMetrics';
import { NODE_DASHBOARD, NODE_METRIC } from '../../utils/constants';

defineOptions({ name: 'ClusterTrendChart' });

const props = defineProps<{
  viewMode: TrendViewMode;
  metricKey: TrendMetricKey;
  clusterData: ClusterTrendPoint[];
  nodeSeries: NodeTrendSeries[];
  selectedNodeIds?: number[];
}>();

const chartRef = ref<HTMLDivElement | null>(null);
const { setOptions } = useECharts(chartRef as Ref<HTMLDivElement>);
let lastChartKey = '';

const chartAnimation = {
  animationDurationUpdate: 500,
  animationEasingUpdate: 'linear' as const,
};

const metricLabels: Record<TrendMetricKey, string> = {
  cpu: NODE_METRIC.cpu,
  mem: NODE_METRIC.mem,
  disk: NODE_METRIC.disk,
  gpuMem: NODE_METRIC.vram,
  gpuUtil: NODE_METRIC.gpuUtil,
};

const filteredNodeSeries = computed(() => {
  const ids = props.selectedNodeIds ?? [];
  const withPoints = props.nodeSeries.filter((series) => series.points.length > 0);
  if (!ids.length) return withPoints;
  const idSet = new Set(ids);
  return withPoints.filter((series) => idSet.has(series.nodeId));
});

const CLUSTER_METRICS_PER_NODE = 4;

/** 节点增多时图例会分页，仅抬高 grid.top 至不重叠 */
function resolveTrendChartLayout(nodeCount: number, viewMode: TrendViewMode) {
  const legendItemCount = viewMode === 'cluster' ? nodeCount * CLUSTER_METRICS_PER_NODE : nodeCount;
  const needsLegendPager = legendItemCount > 6;

  let gridTop = 40;
  if (needsLegendPager) gridTop += 16;
  else if (viewMode === 'node' && nodeCount > 3) gridTop += 8;

  return {
    gridTop,
    legend: {
      top: 2,
      left: 'center' as const,
      type: 'scroll' as const,
      textStyle: { color: '#595959', fontSize: 12, lineHeight: 16 },
      itemWidth: 14,
      itemHeight: 8,
      itemGap: 12,
      padding: [2, 8, needsLegendPager ? 6 : 4, 8] as [number, number, number, number],
      pageIconSize: 10,
      pageTextStyle: { color: '#8c8c8c', fontSize: 11 },
      pageButtonItemGap: 4,
    },
  };
}

const chartLayout = computed(() =>
  resolveTrendChartLayout(filteredNodeSeries.value.length, props.viewMode),
);

const isVolumeMetric = computed(() => isTrendVolumeMetric(props.metricKey));
const isCpuMetric = computed(() => props.metricKey === 'cpu');

const metricHint = computed(() => {
  if (props.viewMode === 'cluster') {
    return NODE_DASHBOARD.trendClusterMetricHint;
  }
  if (isVolumeMetric.value) {
    return `${NODE_DASHBOARD.trendNodeVolumeHint}${metricLabels[props.metricKey]}`;
  }
  if (isCpuMetric.value) {
    return `${NODE_DASHBOARD.trendNodeVolumeHint}${metricLabels[props.metricKey]}（%）`;
  }
  return `${NODE_DASHBOARD.trendNodePercentHint}${metricLabels[props.metricKey]}`;
});

function getNodePointValue(point: NodeTrendPoint, key: TrendMetricKey): number | null {
  if (isTrendVolumeMetric(key)) {
    return getTrendVolumeBytes(point, key);
  }
  return getTrendMetricValue(point, key);
}

function buildTooltipFormatter(mode: 'cluster' | 'node') {
  return (params: unknown) => {
    const items = Array.isArray(params) ? params : [params];
    if (!items.length) return '';
    const header = (items[0] as { axisValue?: string }).axisValue ?? '';
    const lines = items
      .map((item) => {
        const row = item as {
          seriesName?: string;
          value?: number | null;
          marker?: string;
        };
        const value = row.value;
        if (value == null || Number.isNaN(Number(value))) {
          return `${row.marker ?? ''}${row.seriesName ?? ''}: -`;
        }
        if (mode === 'cluster') {
          const formatted = formatClusterTrendTooltipValue(Number(value), row.seriesName);
          return `${row.marker ?? ''}${row.seriesName ?? ''}: ${formatted}`;
        }
        return `${row.marker ?? ''}${row.seriesName ?? ''}: ${formatTrendTooltipValue(Number(value), props.metricKey)}`;
      })
      .join('<br/>');
    return `${header}<br/>${lines}`;
  };
}

function buildNodeChartOptions() {
  const seriesList = filteredNodeSeries.value;
  const timestamps = collectTrendTimestamps([], seriesList);
  const times = formatTrendTimestamps(timestamps);
  const volumeMetric = isVolumeMetric.value;
  const cpuMetric = isCpuMetric.value;
  const layout = chartLayout.value;

  return {
    ...chartAnimation,
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'cross' },
      formatter: buildTooltipFormatter('node'),
    },
    legend: layout.legend,
    grid: { left: 56, right: 16, top: layout.gridTop, bottom: 28 },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: times,
      axisLine: { lineStyle: { color: '#e8e8e8' } },
      axisLabel: { color: '#8c8c8c', fontSize: 11 },
    },
    yAxis: {
      type: 'value',
      min: 0,
      max: volumeMetric || cpuMetric ? undefined : 100,
      axisLabel: {
        color: '#8c8c8c',
        formatter: volumeMetric
          ? (value: number) => formatTrendAxisBytes(value)
          : '{value}%',
      },
      splitLine: { lineStyle: { color: '#f5f5f5', type: 'dashed' } },
    },
    series: seriesList.map((series, index) => {
      const pointMap = new Map(series.points.map((point) => [point.timestamp, point]));
      const palette = getNodeTrendPalette(index);
      const colorKey = props.metricKey === 'gpuMem' ? 'vram' : props.metricKey;
      const color =
        props.metricKey === 'gpuUtil'
          ? palette.cpu
          : palette[colorKey as keyof typeof palette] ?? palette.cpu;
      return {
        name: series.nodeName,
        type: 'line',
        smooth: true,
        showSymbol: false,
        connectNulls: true,
        lineStyle: { width: 2, color, type: 'solid' },
        itemStyle: { color },
        data: buildContinuousTrendData(timestamps, pointMap, (point) =>
          getNodePointValue(point, props.metricKey),
        ),
      };
    }),
  };
}

function buildClusterChartOptions(_points: ClusterTrendPoint[], nodeSeries: NodeTrendSeries[]) {
  const timestamps = collectTrendTimestamps([], nodeSeries);
  const times = formatTrendTimestamps(timestamps);
  const nodeTrendSeries = buildClusterNodeTrendSeries(nodeSeries, timestamps);
  const layout = chartLayout.value;

  return {
    ...chartAnimation,
    backgroundColor: 'transparent',
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'cross' },
      formatter: buildTooltipFormatter('cluster'),
    },
    legend: layout.legend,
    grid: { left: 56, right: 56, top: layout.gridTop, bottom: 28 },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: times,
      axisLine: { lineStyle: { color: '#e8e8e8' } },
      axisLabel: { color: '#8c8c8c', fontSize: 11 },
    },
    yAxis: [
      {
        type: 'value',
        min: 0,
        name: NODE_DASHBOARD.trendAxisPercent,
        nameTextStyle: { color: '#8c8c8c', fontSize: 11 },
        axisLabel: { color: '#8c8c8c', formatter: '{value}%' },
        splitLine: { lineStyle: { color: '#f5f5f5', type: 'dashed' } },
      },
      {
        type: 'value',
        min: 0,
        name: NODE_DASHBOARD.trendAxisVolume,
        nameTextStyle: { color: '#8c8c8c', fontSize: 11 },
        axisLabel: {
          color: '#8c8c8c',
          formatter: (value: number) => formatTrendAxisBytes(value),
        },
        splitLine: { show: false },
      },
    ],
    series: nodeTrendSeries.map((item) => ({
      name: item.name,
      type: 'line',
      smooth: true,
      showSymbol: false,
      connectNulls: true,
      yAxisIndex: item.yAxisIndex,
      lineStyle: { width: 2, color: item.color, type: 'solid' },
      itemStyle: { color: item.color },
      data: item.data,
    })),
  };
}

watch(
  () => [props.viewMode, props.metricKey, props.clusterData, props.nodeSeries, props.selectedNodeIds],
  () => {
    const selectedKey = (props.selectedNodeIds ?? []).join(',');
    const chartKey =
      props.viewMode === 'node'
        ? `${props.viewMode}:${props.metricKey}:${selectedKey}`
        : `${props.viewMode}:${selectedKey}`;
    const fullRebuild = chartKey !== lastChartKey;
    lastChartKey = chartKey;

    if (props.viewMode === 'node') {
      setOptions(buildNodeChartOptions(), fullRebuild);
      return;
    }
    setOptions(buildClusterChartOptions(props.clusterData, filteredNodeSeries.value), fullRebuild);
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <div class="trend-chart-wrap">
    <div class="trend-chart__metric-hint">{{ metricHint }}</div>
    <div ref="chartRef" class="trend-chart" />
  </div>
</template>

<style lang="less" scoped>
.trend-chart-wrap {
  width: 100%;
}

.trend-chart__metric-hint {
  margin-bottom: 6px;
  font-size: 12px;
  line-height: 1.4;
  color: #8c8c8c;
}

.trend-chart {
  width: 100%;
  height: 300px;
}
</style>

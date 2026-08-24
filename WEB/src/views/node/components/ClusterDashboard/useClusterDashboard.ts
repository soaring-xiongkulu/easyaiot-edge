import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { getNodeMetricTrend, getNodePage, type ComputeNodeVO } from '@/api/device/node';
import {
  appendLiveNodeTrendPoints,
  appendTrendPoint,
  buildClusterSnapshot,
  buildNodeDiskList,
  buildNodeLoadList,
  buildNodeTrendSeriesFromApi,
  collectGpuCards,
  groupGpusByNode,
  isComputeNode,
  mergeNodeTrendSeries,
  type ClusterSnapshot,
  type ClusterTrendPoint,
  type GpuCardMetric,
  type NodeDiskItem,
  type NodeGpuGroup,
  type NodeLoadItem,
  type NodeTrendSeries,
  type TrendMetricKey,
  type TrendViewMode,
} from '../../utils/clusterMetrics';
import {
  connectClusterMetricsWebSocket,
  disconnectClusterMetricsWebSocket,
  wsPayloadToComputeNode,
  type ClusterWsMessage,
  type ClusterWsStatus,
} from '../../utils/clusterMetricsWs';
import { NODE_TERM, TREND_SAMPLE_INTERVAL_DEFAULT } from '../../utils/constants';
import { useClusterNodeScope } from '../../utils/useClusterNodeScope';
import { sortNodesWithPlatformFirst } from '../../utils/platformNode';

export type { TrendViewMode };

const MAX_TREND_POINTS = 120;

function relativeDiff(a: number, b: number): number {
  const max = Math.max(a, b);
  if (max <= 0) return 0;
  return Math.abs(a - b) / max;
}

/** 冲突 Agent 会突然换一套硬件容量；保留已绑定容量，平台节点允许切换到显著更大的上报（宿主机优先） */
function sanitizeCapacityPatch(existing: ComputeNodeVO, patch: ComputeNodeVO): ComputeNodeVO {
  const prevMem = Number(existing.memTotalBytes || 0);
  const nextMem = Number(patch.memTotalBytes || 0);
  if (prevMem <= 0 || nextMem <= 0 || relativeDiff(prevMem, nextMem) <= 0.2) {
    return patch;
  }
  const preferLarger = Boolean(existing.isPlatform) && nextMem > prevMem;
  if (preferLarger) {
    return patch;
  }
  const cleaned: ComputeNodeVO = { ...patch };
  delete cleaned.memTotalBytes;
  delete cleaned.memUsedBytes;
  delete cleaned.memPercent;
  delete cleaned.diskTotalBytes;
  delete cleaned.diskUsedBytes;
  delete cleaned.diskPercent;
  return cleaned;
}

function mergeComputeNode(existing: ComputeNodeVO, patch: ComputeNodeVO): ComputeNodeVO {
  const safePatch = sanitizeCapacityPatch(existing, patch);
  const merged: ComputeNodeVO = { ...existing };
  (Object.keys(safePatch) as Array<keyof ComputeNodeVO>).forEach((key) => {
    const value = safePatch[key];
    if (value !== undefined && value !== null) {
      (merged as Record<string, unknown>)[key as string] = value;
    }
  });
  return merged;
}

const shared = {
  trendHistory: [] as ClusterTrendPoint[],
  nodeTrendSeries: [] as NodeTrendSeries[],
  trendSampleIntervalSec: TREND_SAMPLE_INTERVAL_DEFAULT,
  initialized: false,
};

export function useClusterDashboard() {
  const loading = ref(true);
  const wsStatus = ref<ClusterWsStatus>('connecting');
  const trendViewMode = ref<TrendViewMode>('cluster');
  const trendMetric = ref<TrendMetricKey>('cpu');
  const selectedNodeIds = ref<number[]>([]);
  const overviewFocusNodeId = ref<number | undefined>(undefined);
  const trendSampleIntervalSec = ref(shared.trendSampleIntervalSec);
  const nodes = ref<ComputeNodeVO[]>([]);
  const snapshot = ref<ClusterSnapshot>(buildClusterSnapshot([]));
  const trendHistory = ref<ClusterTrendPoint[]>([...shared.trendHistory]);
  const nodeTrendSeries = ref<NodeTrendSeries[]>([...shared.nodeTrendSeries]);
  const gpuCards = ref<GpuCardMetric[]>([]);
  const nodeGpuGroups = ref<NodeGpuGroup[]>([]);
  const nodeLoads = ref<NodeLoadItem[]>([]);
  const nodeDisks = ref<NodeDiskItem[]>([]);
  const lastUpdated = ref('');
  const {
    lanes,
    activeLaneKey,
    centralLaneOptions,
    scopeNodes,
    lanesReady,
    loadLanes,
    setActiveLaneKey: setScopeLaneKey,
  } = useClusterNodeScope();

  const scopedNodes = computed(() => {
    if (!lanesReady.value && activeLaneKey.value !== 'all') {
      return nodes.value;
    }
    return scopeNodes(nodes.value);
  });

  const focusNodes = computed(() => {
    if (!overviewFocusNodeId.value) {
      return scopedNodes.value;
    }
    const target = scopedNodes.value.find((node) => node.id === overviewFocusNodeId.value);
    return target ? [target] : scopedNodes.value;
  });

  const displaySnapshot = computed(() => buildClusterSnapshot(focusNodes.value));
  const displayGpuGroups = computed(() => groupGpusByNode(focusNodes.value));
  const displayNodeLoads = computed(() => buildNodeLoadList(focusNodes.value));
  const displayNodeDisks = computed(() => buildNodeDiskList(focusNodes.value));
  const displayNodeTrendSeries = computed(() => {
    if (!overviewFocusNodeId.value) {
      return nodeTrendSeries.value;
    }
    return nodeTrendSeries.value.filter((series) => series.nodeId === overviewFocusNodeId.value);
  });

  function syncSharedState() {
    shared.trendHistory = trendHistory.value;
    shared.nodeTrendSeries = nodeTrendSeries.value;
    shared.trendSampleIntervalSec = trendSampleIntervalSec.value;
  }

  function recomputeDerivedState() {
    snapshot.value = buildClusterSnapshot(nodes.value);
    gpuCards.value = collectGpuCards(nodes.value);
    nodeGpuGroups.value = groupGpusByNode(nodes.value);
    nodeLoads.value = buildNodeLoadList(nodes.value);
    nodeDisks.value = buildNodeDiskList(nodes.value);
    const intervalMs = trendSampleIntervalSec.value * 1000;
    trendHistory.value = appendTrendPoint(
      trendHistory.value,
      snapshot.value,
      MAX_TREND_POINTS,
      intervalMs,
    );
    nodeTrendSeries.value = appendLiveNodeTrendPoints(
      nodeTrendSeries.value,
      nodes.value,
      MAX_TREND_POINTS,
      intervalMs,
    );
    lastUpdated.value = new Date().toLocaleTimeString();
    syncSharedState();
  }

  watch(trendSampleIntervalSec, (seconds) => {
    shared.trendSampleIntervalSec = seconds;
  });

  function applySnapshot(currentNodes: ComputeNodeVO[]) {
    // 全量 snapshot 按 id 合并：入站缺容量等字段时保留本地已有值，避免 register/重连导致卡面跳动
    const prevById = new Map(
      nodes.value
        .filter((node) => node.id != null)
        .map((node) => [node.id!, node] as const),
    );
    const merged = currentNodes.map((incoming) => {
      if (!incoming.id) return incoming;
      const prev = prevById.get(incoming.id);
      return prev ? mergeComputeNode(prev, incoming) : incoming;
    });
    nodes.value = sortNodesWithPlatformFirst(merged);
    recomputeDerivedState();
    loading.value = false;
  }

  function applyNodeUpdate(update: ComputeNodeVO) {
    if (!update.id) return;
    const index = nodes.value.findIndex((node) => node.id === update.id);
    if (index >= 0) {
      nodes.value[index] = mergeComputeNode(nodes.value[index], update);
    } else {
      nodes.value.push(update);
    }
    nodes.value = sortNodesWithPlatformFirst(nodes.value);
    recomputeDerivedState();
    loading.value = false;
  }

  function handleWsMessage(message: ClusterWsMessage) {
    if (message.type === 'snapshot' && message.nodes?.length) {
      applySnapshot(message.nodes.map(wsPayloadToComputeNode));
      return;
    }
    if (message.type === 'node_update' && message.node) {
      applyNodeUpdate(wsPayloadToComputeNode(message.node));
    }
  }

  function setActiveLaneKey(laneKey: string) {
    setScopeLaneKey(laneKey);
    overviewFocusNodeId.value = undefined;
    selectedNodeIds.value = [];
  }

  watch(scopedNodes, (scoped) => {
    if (overviewFocusNodeId.value && !scoped.some((node) => node.id === overviewFocusNodeId.value)) {
      overviewFocusNodeId.value = undefined;
    }
    const allowedIds = new Set(scoped.map((node) => node.id).filter((id): id is number => id != null));
    selectedNodeIds.value = selectedNodeIds.value.filter((id) => allowedIds.has(id));
  });

  async function loadInitialData() {
    loading.value = nodes.value.length === 0;
    try {
      await loadLanes();
      const [pageRes] = await Promise.all([
        getNodePage({ pageNo: 1, pageSize: 200 }),
        loadMetricHistory(),
      ]);
      if (!nodes.value.length) {
        applySnapshot(pageRes?.data?.list ?? []);
      }
    } finally {
      loading.value = false;
    }
  }

  async function loadMetricHistory() {
    try {
      const res = await getNodeMetricTrend({ minutes: 30, maxPoints: MAX_TREND_POINTS });
      const fromApi = buildNodeTrendSeriesFromApi(res.series ?? []);
      if (fromApi.length) {
        nodeTrendSeries.value = mergeNodeTrendSeries(nodeTrendSeries.value, fromApi, MAX_TREND_POINTS);
        syncSharedState();
      }
    } catch {
      // 历史接口不可用时依赖 WebSocket 实时累积
    }
  }

  onMounted(async () => {
    if (!shared.initialized) {
      shared.initialized = true;
      await loadInitialData();
    } else {
      loading.value = false;
    }
    connectClusterMetricsWebSocket(handleWsMessage, (status) => {
      wsStatus.value = status;
    });
  });

  onUnmounted(() => {
    disconnectClusterMetricsWebSocket(handleWsMessage);
  });

  return {
    loading,
    wsStatus,
    trendViewMode,
    trendMetric,
    selectedNodeIds,
    overviewFocusNodeId,
    trendSampleIntervalSec,
    nodes,
    snapshot,
    displaySnapshot,
    trendHistory,
    nodeTrendSeries,
    displayNodeTrendSeries,
    gpuCards,
    nodeGpuGroups,
    displayGpuGroups,
    nodeLoads,
    displayNodeLoads,
    nodeDisks,
    displayNodeDisks,
    lastUpdated,
    computeNodeOptions: computed(() =>
      sortNodesWithPlatformFirst(scopedNodes.value.filter(isComputeNode)).map((node) => ({
        label: node.isPlatform ? `${node.name} [${NODE_TERM.controlPlaneNode}] (${node.host})` : `${node.name} (${node.host})`,
        value: node.id!,
      })),
    ),
    lanes,
    activeLaneKey,
    setActiveLaneKey,
    centralLaneOptions,
  };
}

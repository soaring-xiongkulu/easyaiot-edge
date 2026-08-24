import { ref } from 'vue';
import { getClusterLanes, type ClusterLaneVO, type ComputeNodeVO } from '@/api/device/node';
import {
  LOCAL_LANE_KEY,
  filterNodesByLane,
  findLaneByKey,
  flattenLaneNodes,
  laneLabel,
  mergeLaneNodesWithLive,
  readActiveLaneKey,
  writeActiveLaneKey,
} from './clusterLanes';
import { isPlatformNode } from './platformNode';
import { NODE_DASHBOARD } from './constants';

const lanes = ref<ClusterLaneVO[]>([]);
const lanesReady = ref(false);
const activeLaneKey = ref(readActiveLaneKey());
let loadPromise: Promise<void> | null = null;

export function scopeNodesByLane(allNodes: ComputeNodeVO[], laneList: ClusterLaneVO[], laneKey: string) {
  if (laneKey === 'all') {
    return allNodes;
  }
  const lane = findLaneByKey(laneList, laneKey);
  if (!lane) {
    const platform = allNodes.find((node) => isPlatformNode(node));
    if (!platform?.id) return allNodes;
    return allNodes.filter(
      (node) => isPlatformNode(node) || node.controlPlaneId === platform.id || node.controlPlaneId == null,
    );
  }
  if (lane.isLocal) {
    return filterNodesByLane(allNodes, lane);
  }
  return mergeLaneNodesWithLive(flattenLaneNodes(lane), allNodes);
}

export function useClusterNodeScope() {
  const centralLaneOptions = ref<Array<{ label: string; value: string }>>([]);

  function rebuildCentralLaneOptions() {
    centralLaneOptions.value = [
      ...lanes.value.map((lane) => ({
        label: laneLabel(lane),
        value: lane.laneKey || LOCAL_LANE_KEY,
      })),
      { label: NODE_DASHBOARD.overviewCentralNodeAll, value: 'all' },
    ];
  }

  function normalizeActiveLaneKey() {
    if (activeLaneKey.value === 'all') return;
    if (lanes.value.some((lane) => lane.laneKey === activeLaneKey.value)) return;
    const localLane = lanes.value.find((lane) => lane.isLocal);
    activeLaneKey.value = localLane?.laneKey || LOCAL_LANE_KEY;
    writeActiveLaneKey(activeLaneKey.value);
  }

  function scopeNodes(allNodes: ComputeNodeVO[]) {
    return scopeNodesByLane(allNodes, lanes.value, activeLaneKey.value);
  }

  async function loadLanes() {
    if (loadPromise) {
      await loadPromise;
      return;
    }
    loadPromise = (async () => {
      try {
        const res = await getClusterLanes({ pageNo: 1, pageSize: 1000 });
        lanes.value = res.data.list;
        normalizeActiveLaneKey();
        rebuildCentralLaneOptions();
      } catch {
        lanes.value = [];
        rebuildCentralLaneOptions();
      } finally {
        lanesReady.value = true;
        loadPromise = null;
      }
    })();
    await loadPromise;
  }

  function setActiveLaneKey(laneKey: string) {
    activeLaneKey.value = laneKey;
    writeActiveLaneKey(laneKey);
  }

  return {
    lanes,
    lanesReady,
    activeLaneKey,
    centralLaneOptions,
    rebuildCentralLaneOptions,
    scopeNodes,
    loadLanes,
    setActiveLaneKey,
  };
}

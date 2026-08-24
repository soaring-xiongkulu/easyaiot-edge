import type { ClusterLaneVO, ComputeNodeVO } from '@/api/device/node';
import { isPlatformNode } from './platformNode';

export const LOCAL_LANE_KEY = 'local';
export const ACTIVE_LANE_STORAGE_KEY = 'easyaiot_active_control_plane_lane';

export function readActiveLaneKey(): string {
  return sessionStorage.getItem(ACTIVE_LANE_STORAGE_KEY) || LOCAL_LANE_KEY;
}

export function writeActiveLaneKey(laneKey: string) {
  sessionStorage.setItem(ACTIVE_LANE_STORAGE_KEY, laneKey);
}

export function laneLabel(lane: ClusterLaneVO): string {
  const name = lane.centralNode?.name || lane.laneKey;
  if (lane.isLocal) return `${name}（本机）`;
  return name;
}

export function flattenLaneNodes(lane: ClusterLaneVO): ComputeNodeVO[] {
  const nodes: ComputeNodeVO[] = [];
  if (lane.centralNode) nodes.push(lane.centralNode);
  if (lane.workerNodes?.length) nodes.push(...lane.workerNodes);
  return nodes;
}

export function filterNodesByLane(nodes: ComputeNodeVO[], lane: ClusterLaneVO | null | undefined): ComputeNodeVO[] {
  if (!lane) return nodes;
  const allowedIds = new Set(
    flattenLaneNodes(lane)
      .map((node) => node.id)
      .filter((id): id is number => id != null),
  );
  return nodes.filter((node) => node.id != null && allowedIds.has(node.id));
}

/** 仅覆盖 patch 中非空字段，避免 undefined 抹掉已有容量等指标 */
function mergeDefinedNodeFields(base: ComputeNodeVO, patch: ComputeNodeVO): ComputeNodeVO {
  const merged: ComputeNodeVO = { ...base };
  (Object.keys(patch) as Array<keyof ComputeNodeVO>).forEach((key) => {
    const value = patch[key];
    if (value !== undefined && value !== null) {
      (merged as Record<string, unknown>)[key as string] = value;
    }
  });
  return merged;
}

/**
 * 将泳道节点定义与 WebSocket 实时节点合并，优先使用实时指标。
 * 远程对等中心节点可能与本地节点 ID 碰撞，禁止用本地实时数据覆盖。
 */
export function mergeLaneNodesWithLive(laneNodes: ComputeNodeVO[], liveNodes: ComputeNodeVO[]): ComputeNodeVO[] {
  const liveById = new Map(
    liveNodes
      .filter((node) => node.id != null)
      .map((node) => [node.id!, node] as const),
  );
  return laneNodes.map((laneNode) => {
    if (laneNode.id == null) return laneNode;
    if (laneNode.isRemote) {
      return laneNode;
    }
    const live = liveById.get(laneNode.id);
    return live ? mergeDefinedNodeFields(laneNode, live) : laneNode;
  });
}

export function findLaneByKey(lanes: ClusterLaneVO[], laneKey?: string | null): ClusterLaneVO | undefined {
  const key = laneKey || LOCAL_LANE_KEY;
  return lanes.find((lane) => lane.laneKey === key) || lanes.find((lane) => lane.isLocal) || lanes[0];
}

export function localLaneWorkers(lane: ClusterLaneVO): ComputeNodeVO[] {
  return (lane.workerNodes || []).filter((node) => !isPlatformNode(node) && !node.isRemote);
}

export function canManageLaneWorkers(lane: ClusterLaneVO): boolean {
  return lane.isLocal === true;
}

export function laneSyncStatusColor(status?: string): string {
  if (status === 'online' || status === 'synced') return 'success';
  if (status === 'offline') return 'error';
  return 'default';
}

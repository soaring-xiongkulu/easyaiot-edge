import type { TreeItem } from '@/components/Tree';
import type { MonitorTreeDeviceNode, MonitorTreeDirectoryNode } from '@/api/device/camera';
import { formatCameraDeviceLabel, isGb28181Device, parseGb28181Source } from './deviceLabel';
import { resolveWvpSipDeviceId } from './gb28181DeviceGroup';
import { findMonitorGbDeviceByChannel } from './monitorDeviceTree';
import type { GbChannelRef } from './gb28181Tree';

/** WVP 国标 SIP 设备 ID → 展示名（与设备列表 queryVideoList 一致） */
export function buildGbSipNameMap(wvpDevices: Record<string, any>[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const wvp of wvpDevices) {
    const sip = resolveWvpSipDeviceId(wvp);
    if (!sip) continue;
    const name = String(wvp.name || '').trim();
    if (name) map.set(sip, name);
  }
  return map;
}

/** 从目录监控树已同步的国标通道推导 SIP 展示名（首屏无需拉全量 WVP） */
export function buildGbSipNameMapFromDirectoryTree(
  directories: MonitorTreeDirectoryNode[],
): Map<string, string> {
  const map = new Map<string, string>();
  const walk = (dirs: MonitorTreeDirectoryNode[]) => {
    for (const dir of dirs) {
      for (const d of dir.devices || []) {
        if (!isGb28181Device(d.source, d.device_kind)) continue;
        const parsed = parseGb28181Source(d.source);
        if (!parsed || map.has(parsed.deviceId)) continue;
        const raw = (d.name || '').replace(/^\[GB28181\]\s*/, '').trim();
        if (raw) map.set(parsed.deviceId, raw);
      }
      if (dir.children?.length) walk(dir.children);
    }
  };
  walk(directories || []);
  return map;
}

/** 国标通道展示名：优先 device 表已同步记录，其次 WVP/树节点上的名称 */
export function resolveMonitorGbChannelDisplayName(
  sipDeviceId: string,
  channelId: string,
  treeNodes: TreeItem[],
  fallback?: string,
): string {
  const synced = findMonitorGbDeviceByChannel(treeNodes, sipDeviceId, channelId);
  if (synced) {
    return formatCameraDeviceLabel(synced);
  }
  const fb = (fallback || channelId).trim();
  if (fb.startsWith('[GB28181]')) return fb;
  return `[GB28181] ${fb}`;
}

function enrichGbChannelLeaf(node: TreeItem, treeData: TreeItem[]): TreeItem {
  const gb = (node as TreeItem & { gbChannel?: GbChannelRef }).gbChannel;
  if (!gb) return node;
  const synced = findMonitorGbDeviceByChannel(treeData, gb.sipDeviceId, gb.channelId);
  const title = resolveMonitorGbChannelDisplayName(
    gb.sipDeviceId,
    gb.channelId,
    treeData,
    gb.name,
  );
  const plainName = title.replace(/^\[GB28181\]\s*/, '').trim() || gb.channelId;
  return {
    ...node,
    title,
    gbChannel: { ...gb, name: plainName },
    device: synced ?? (node as TreeItem & { device?: MonitorTreeDeviceNode }).device,
  } as TreeItem;
}

/** 懒加载 WVP 通道树后，用 device 表名称覆盖通道展示名 */
export function enrichWvpChannelTreeNodes(nodes: TreeItem[], treeData: TreeItem[]): TreeItem[] {
  if (!nodes?.length) return [];
  return nodes.map((node) => {
    if (node.children?.length) {
      return {
        ...node,
        children: enrichWvpChannelTreeNodes(node.children as TreeItem[], treeData),
      };
    }
    return enrichGbChannelLeaf(node, treeData);
  });
}

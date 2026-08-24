import type { TreeItem } from '@/components/Tree';
import type { MonitorTreeDeviceNode } from '@/api/device/camera';
import { handleTree } from '@/utils/tree';
import { formatCameraDeviceLabel, parseGb28181Source, isGb28181Device } from './deviceLabel';

export interface GbChannelRef {
  sipDeviceId: string;
  channelId: string;
  name: string;
}

/** 按国标 SIP 设备 ID 分组已同步的通道记录 */
export function groupGb28181ChannelsBySip(
  devices: MonitorTreeDeviceNode[],
): Map<string, MonitorTreeDeviceNode[]> {
  const map = new Map<string, MonitorTreeDeviceNode[]>();
  for (const d of devices) {
    if (!isGb28181Device(d.source, d.device_kind)) continue;
    const parsed = parseGb28181Source(d.source);
    if (!parsed) continue;
    const list = map.get(parsed.deviceId) || [];
    list.push(d);
    map.set(parsed.deviceId, list);
  }
  return map;
}

export function buildGbChannelLeafNode(
  sipDeviceId: string,
  channelId: string,
  name: string,
  device?: MonitorTreeDeviceNode,
): TreeItem {
  return {
    key: `gb_ch_${sipDeviceId},${channelId}`,
    title: `[GB28181] ${name || channelId}`,
    isLeaf: true,
    selectable: true,
    icon: 'ant-design:video-camera-outlined',
    gbChannel: {
      sipDeviceId,
      channelId,
      name: name || channelId,
    } as GbChannelRef,
    device,
  } as TreeItem;
}

/** 从已同步的 device 记录生成通道叶子节点 */
export function buildGbChannelNodesFromSynced(
  channels: MonitorTreeDeviceNode[],
  sipDeviceId: string,
): TreeItem[] {
  const nodes: TreeItem[] = [];
  for (const ch of channels) {
    const parsed = parseGb28181Source(ch.source);
    if (!parsed || parsed.deviceId !== sipDeviceId) continue;
    const label = formatCameraDeviceLabel(ch);
    const plainName = label.replace(/^\[GB28181\]\s*/, '').trim() || parsed.channelId;
    nodes.push(buildGbChannelLeafNode(sipDeviceId, parsed.channelId, plainName, ch));
  }
  return nodes;
}

export function buildGbSipDeviceNode(
  sipDeviceId: string,
  channelNodes: TreeItem[],
  sipDisplayName?: string,
): TreeItem {
  const title = sipDisplayName
    ? `[GB28181] ${sipDisplayName}`
    : `[GB28181] ${sipDeviceId}`;
  return {
    key: `gb_dev_${sipDeviceId}`,
    title,
    isLeaf: false,
    selectable: false,
    icon: 'ant-design:cluster-outlined',
    sipDeviceId,
    children: channelNodes.length ? channelNodes : undefined,
  } as TreeItem;
}

function isGbChannelDirectory(item: Record<string, any>): boolean {
  const subRaw = item.subCount ?? item.SubCount ?? 0;
  const subCount = typeof subRaw === 'number' ? subRaw : Number(subRaw) || 0;
  const pRaw = item.parental ?? item.gbParental;
  const parentalNum = pRaw === undefined || pRaw === null || pRaw === '' ? null : Number(pRaw);
  return subCount > 0 || parentalNum === 1;
}

/** 将 WVP 通道列表转为树节点（支持多级目录，叶子才可点播） */
export function buildWvpChannelTreeNodes(
  channels: any[],
  sipDeviceId: string,
): TreeItem[] {
  const tmpLoop = handleTree(channels, 'deviceId');
  return mapWvpChannelNodes(tmpLoop, sipDeviceId);
}

function mapWvpChannelNodes(nodes: any[], sipDeviceId: string): TreeItem[] {
  if (!nodes?.length) return [];
  const result: TreeItem[] = [];
  for (const node of nodes) {
    if (node.children?.length) {
      const children = mapWvpChannelNodes(node.children, sipDeviceId);
      result.push({
        key: `gb_dir_${sipDeviceId}_${node.deviceId || node.id}`,
        title: node.name || node.deviceName || '目录',
        isLeaf: false,
        selectable: false,
        icon: 'ant-design:folder-outlined',
        children,
      } as TreeItem);
      continue;
    }
    if (isGbChannelDirectory(node)) {
      result.push({
        key: `gb_dir_${sipDeviceId}_${node.deviceId || node.id}`,
        title: node.name || node.deviceName || '目录',
        isLeaf: false,
        selectable: false,
        icon: 'ant-design:folder-outlined',
        children: undefined,
      } as TreeItem);
      continue;
    }
    const channelGbId = String(
      node.gbDeviceId || node.deviceId || node.channelId || node.id || '',
    ).trim();
    const parentSip = String(node.parentDeviceId || sipDeviceId).trim();
    if (!parentSip || !channelGbId) continue;
    result.push(
      buildGbChannelLeafNode(
        parentSip,
        channelGbId,
        node.name || node.channelName || channelGbId,
      ),
    );
  }
  return result;
}

export function parseGbChannelKey(key: string): GbChannelRef | null {
  if (!key.startsWith('gb_ch_')) return null;
  const rest = key.slice('gb_ch_'.length);
  const comma = rest.indexOf(',');
  if (comma <= 0) return null;
  const sipDeviceId = rest.slice(0, comma).trim();
  const channelId = rest.slice(comma + 1).trim();
  if (!sipDeviceId || !channelId) return null;
  return { sipDeviceId, channelId, name: channelId };
}

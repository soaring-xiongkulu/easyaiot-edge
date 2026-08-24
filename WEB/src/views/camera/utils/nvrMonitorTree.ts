import type { TreeItem } from '@/components/Tree';
import type { MonitorTreeDeviceNode } from '@/api/device/camera';
import type { NvrInfo } from './nvrDeviceGroup';
import {
  formatCameraDeviceLabel,
  formatNvrDisplayName,
  isNvrChannelDevice,
  isNvrRtspSource,
} from './deviceLabel';

function parseHostFromRtsp(source: string): string {
  const m = source.trim().match(/^rtsp:\/\/(?:[^@/]+@)?([^/:]+)/i);
  return (m?.[1] || '').trim();
}

/** 从 RTSP 源 + NVR IP 索引推断挂载关系（monitor-tree 未带 nvr_id 时前端补全） */
export function parseNvrLinkFromSource(
  source: string | null | undefined,
  ipToNvrId: Map<string, number>,
): { nvrId: number; nvrChannel: number } | null {
  const text = (source || '').trim();
  if (!isNvrRtspSource(text)) return null;
  const host = parseHostFromRtsp(text);
  const nvrId = ipToNvrId.get(host);
  if (!nvrId) return null;

  let nvrChannel = 0;
  const hik = text.match(/\/streaming\/channels\/(\d+)/i);
  if (hik) {
    const streamId = Number(hik[1]);
    nvrChannel = streamId >= 100 ? Math.floor(streamId / 100) : streamId;
  } else {
    const dahua = text.match(/[?&]channel=(\d+)/i);
    if (dahua) nvrChannel = Number(dahua[1]);
  }
  return { nvrId, nvrChannel };
}

export function buildNvrIpIndex(nvrs: NvrInfo[]): Map<string, number> {
  const map = new Map<string, number>();
  for (const nvr of nvrs) {
    const ip = (nvr.ip || '').trim();
    if (ip && nvr.id) map.set(ip, nvr.id);
  }
  return map;
}

/** 用 NVR 列表补全 monitor-tree 设备上的 nvr_id / nvr_channel */
export function enrichMonitorDevicesWithNvrs(
  devices: MonitorTreeDeviceNode[],
  nvrs: NvrInfo[],
): MonitorTreeDeviceNode[] {
  if (!nvrs.length) return devices;
  const ipToNvrId = buildNvrIpIndex(nvrs);
  return devices.map((d) => {
    if (resolveMonitorDeviceNvrId(d)) {
      if (d.device_kind === 'nvr_channel' || !isNvrRtspSource(d.source)) return d;
      return { ...d, device_kind: 'nvr_channel' as const };
    }
    const link = parseNvrLinkFromSource(d.source, ipToNvrId);
    if (!link) return d;
    return {
      ...d,
      nvr_id: link.nvrId,
      nvr_channel: link.nvrChannel || d.nvr_channel || 0,
      device_kind: 'nvr_channel',
    };
  });
}

/** 解析设备所属 NVR ID（兼容 monitor-tree 仅带 nvr 摘要的场景） */
export function resolveMonitorDeviceNvrId(device: MonitorTreeDeviceNode): number {
  const raw =
    device.nvr_id ??
    (device as MonitorTreeDeviceNode & { nvr?: { id?: number | null } }).nvr?.id;
  const nvrId = Number(raw);
  return Number.isFinite(nvrId) && nvrId > 0 ? nvrId : 0;
}

/** 按 NVR ID 分组目录/监控树中的挂载通道 */
export function groupNvrChannelsByNvr(
  devices: MonitorTreeDeviceNode[],
  nvrs: NvrInfo[] = [],
): Map<number, MonitorTreeDeviceNode[]> {
  const enriched = enrichMonitorDevicesWithNvrs(devices, nvrs);
  const map = new Map<number, MonitorTreeDeviceNode[]>();
  for (const d of enriched) {
    if (!isNvrChannelDevice(d, nvrs)) continue;
    const nvrId = resolveMonitorDeviceNvrId(d);
    if (!nvrId) continue;
    const list = map.get(nvrId) || [];
    list.push(d);
    map.set(nvrId, list);
  }
  for (const list of map.values()) {
    list.sort((a, b) => (a.nvr_channel ?? 0) - (b.nvr_channel ?? 0));
  }
  return map;
}

export function buildNvrNameMap(nvrs: NvrInfo[]): Map<number, string> {
  const map = new Map<number, string>();
  for (const nvr of nvrs) {
    if (nvr.id) {
      map.set(nvr.id, formatNvrDisplayName(nvr));
    }
  }
  return map;
}

export function buildNvrChannelLeafNode(device: MonitorTreeDeviceNode): TreeItem {
  return {
    key: `device_${device.id}`,
    title: formatCameraDeviceLabel(device),
    isLeaf: true,
    selectable: true,
    isDevice: true,
    icon: 'ant-design:video-camera-outlined',
    device,
  } as TreeItem;
}

/** 将 NVR 分组节点挂到目录 children（按 NVR 列表顺序，默认分组可补全空 NVR 父节点） */
export function appendNvrGroupedNodesToChildren(
  children: TreeItem[],
  devices: MonitorTreeDeviceNode[],
  options?: {
    nvrNameMap?: Map<number, string>;
    nvrs?: NvrInfo[];
    /** 默认分组下为尚未出现在目录中的 NVR 补父节点 */
    appendAllNvrs?: boolean;
  },
) {
  const nvrNameMap = options?.nvrNameMap;
  const nvrs = options?.nvrs ?? [];
  const nvrGrouped = groupNvrChannelsByNvr(devices, nvrs);
  const seen = new Set<number>();

  const pushNvrNode = (nvrId: number) => {
    if (!nvrId || seen.has(nvrId)) return;
    seen.add(nvrId);
    const channels = nvrGrouped.get(nvrId) || [];
    const channelNodes = channels.map((ch) => buildNvrChannelLeafNode(ch));
    children.push(buildNvrDeviceNode(nvrId, channelNodes, nvrNameMap?.get(nvrId)));
    nvrGrouped.delete(nvrId);
  };

  if (options?.appendAllNvrs) {
    for (const nvr of nvrs) {
      if (nvr.id) pushNvrNode(nvr.id);
    }
  }
  const restIds = [...nvrGrouped.keys()].sort((a, b) => a - b);
  for (const nvrId of restIds) pushNvrNode(nvrId);
}

export function buildNvrDeviceNode(
  nvrId: number,
  channelNodes: TreeItem[],
  nvrDisplayName?: string,
): TreeItem {
  const title = nvrDisplayName || formatNvrDisplayName({ id: nvrId, ip: `NVR-${nvrId}` });
  return {
    key: `nvr_${nvrId}`,
    title,
    isLeaf: false,
    selectable: false,
    icon: 'ant-design:hdd-outlined',
    nvrId,
    children: channelNodes,
  } as TreeItem;
}

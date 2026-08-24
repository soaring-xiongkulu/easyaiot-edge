import type { TreeItem } from '@/components/Tree';
import type { MonitorTreeDeviceNode, MonitorTreeDirectoryNode } from '@/api/device/camera';
import { formatCameraDeviceLabel, isGb28181Device, isNvrChannelDevice, parseGb28181Source } from './deviceLabel';
import { resolveWvpSipDeviceId } from './gb28181DeviceGroup';
import {
  buildGbChannelNodesFromSynced,
  buildGbSipDeviceNode,
  groupGb28181ChannelsBySip,
} from './gb28181Tree';
import {
  appendNvrGroupedNodesToChildren,
  buildNvrNameMap,
  enrichMonitorDevicesWithNvrs,
} from './nvrMonitorTree';
import type { NvrInfo } from './nvrDeviceGroup';

/** 监控树节点是否为 NVR 挂载通道叶子 */
export function isMonitorNvrChannelNode(node: TreeItem): boolean {
  const key = String(node.key ?? '');
  if (!key.startsWith('device_')) return false;
  const device = (node as { device?: MonitorTreeDeviceNode }).device;
  return !!device && isNvrChannelDevice(device);
}

/** 监控树节点是否为 NVR 父节点（其下挂通道） */
export function isMonitorNvrParentNode(node: TreeItem): boolean {
  return String(node.key ?? '').startsWith('nvr_');
}

export interface MonitorTreeBuildOptions {
  showDeviceCountInTitle?: boolean;
  sipNameMap?: Map<string, string>;
  nvrNameMap?: Map<number, string>;
  nvrs?: NvrInfo[];
  /** WVP 国标 SIP 列表：用于补全未同步通道但仍需展示的设备节点 */
  wvpDevices?: Record<string, any>[];
}

/** 将目录下设备挂到树 children：直连为叶子，NVR 通道归 NVR，国标按 SIP 分组 */
export function appendDevicesToMonitorTreeChildren(
  children: TreeItem[],
  devices: MonitorTreeDeviceNode[],
  options?: {
    sipNameMap?: Map<string, string>;
    nvrNameMap?: Map<number, string>;
    nvrs?: NvrInfo[];
    wvpDevices?: Record<string, any>[];
    /** 默认分组下补全 WVP 中尚未同步的国标 SIP 设备节点 */
    appendUnsyncedWvpGb?: boolean;
    /** 默认分组下补全尚未出现在目录中的 NVR 父节点 */
    appendAllNvrs?: boolean;
  },
) {
  const sipNameMap = options?.sipNameMap;
  const nvrNameMap = options?.nvrNameMap;
  const nvrs = options?.nvrs ?? [];
  const enrichedDevices = enrichMonitorDevicesWithNvrs(devices, nvrs);
  const direct: MonitorTreeDeviceNode[] = [];
  const gbChannels: MonitorTreeDeviceNode[] = [];

  for (const d of enrichedDevices) {
    if (isGb28181Device(d.source, d.device_kind)) {
      gbChannels.push(d);
    } else if (!isNvrChannelDevice(d, nvrs)) {
      direct.push(d);
    }
  }

  const gbGrouped = groupGb28181ChannelsBySip(gbChannels);

  direct.forEach((d) => {
    children.push({
      key: `device_${d.id}`,
      title: formatCameraDeviceLabel(d),
      isLeaf: true,
      isDevice: true,
      icon: 'ant-design:video-camera-outlined',
      device: d,
    } as TreeItem);
  });

  appendNvrGroupedNodesToChildren(children, enrichedDevices, {
    nvrNameMap,
    nvrs,
    appendAllNvrs: options?.appendAllNvrs,
  });

  const addedGbSip = new Set<string>();
  gbGrouped.forEach((channels, sipDeviceId) => {
    addedGbSip.add(sipDeviceId);
    const channelNodes = buildGbChannelNodesFromSynced(channels, sipDeviceId);
    children.push(buildGbSipDeviceNode(sipDeviceId, channelNodes, sipNameMap?.get(sipDeviceId)));
  });

  if (options?.appendUnsyncedWvpGb && options.wvpDevices?.length) {
    for (const wvp of options.wvpDevices) {
      const sipId = resolveWvpSipDeviceId(wvp);
      if (!sipId || addedGbSip.has(sipId)) continue;
      addedGbSip.add(sipId);
      children.push(
        buildGbSipDeviceNode(sipId, [], sipNameMap?.get(sipId) || String(wvp.name || '').trim() || undefined),
      );
    }
  }
}

/** 默认分组标题计数：未入库的 WVP 国标 SIP 也计入展示 */
function resolveDirectoryDisplayDeviceCount(
  dir: MonitorTreeDirectoryNode,
  wvpDevices?: Record<string, any>[],
): number {
  const base = dir.device_count ?? dir.devices?.length ?? 0;
  if (!dir.is_default || !wvpDevices?.length) return base;

  const syncedSips = new Set<string>();
  for (const d of dir.devices || []) {
    if (!isGb28181Device(d.source, d.device_kind)) continue;
    const parsed = parseGb28181Source(d.source);
    if (parsed?.deviceId) syncedSips.add(parsed.deviceId);
  }

  let unsyncedSipCount = 0;
  for (const wvp of wvpDevices) {
    const sipId = resolveWvpSipDeviceId(wvp);
    if (sipId && !syncedSips.has(sipId)) unsyncedSipCount++;
  }

  if (base === 0 && unsyncedSipCount > 0) return unsyncedSipCount;
  return base;
}

export function buildMonitorDirectoryTreeNodes(
  directories: MonitorTreeDirectoryNode[],
  options?: MonitorTreeBuildOptions,
): TreeItem[] {
  const showCount = options?.showDeviceCountInTitle !== false;
  const sipNameMap = options?.sipNameMap;
  const nvrNameMap = options?.nvrNameMap;
  const nvrs = options?.nvrs;
  const wvpDevices = options?.wvpDevices;

  const mapDirectory = (dir: MonitorTreeDirectoryNode): TreeItem => {
    const children: TreeItem[] = [];
    if (dir.children?.length) {
      children.push(...dir.children.map(mapDirectory));
    }
    const appendUnsyncedWvpGb = !!dir.is_default;
    if (dir.devices?.length) {
      appendDevicesToMonitorTreeChildren(children, dir.devices, {
        sipNameMap,
        nvrNameMap,
        nvrs,
        wvpDevices,
        appendUnsyncedWvpGb,
        appendAllNvrs: !!dir.is_default,
      });
    } else if (dir.is_default && (nvrs?.length || wvpDevices?.length)) {
      appendDevicesToMonitorTreeChildren(children, [], {
        sipNameMap,
        nvrNameMap,
        nvrs,
        wvpDevices,
        appendUnsyncedWvpGb,
        appendAllNvrs: !!nvrs?.length,
      });
    }
    const deviceCount = resolveDirectoryDisplayDeviceCount(dir, wvpDevices);
    return {
      key: `dir_${dir.id}`,
      title: showCount ? `${dir.name}（${deviceCount}）` : dir.name,
      isDirectory: true,
      selectable: false,
      icon: 'ant-design:folder-outlined',
      children: children.length ? children : undefined,
    } as TreeItem;
  };

  return (directories || []).map(mapDirectory);
}

/** 设备目录管理页：目录节点可选中（分屏监控侧目录仍为 selectable: false） */
export function withDirectoryTreeSelectable(items: TreeItem[]): TreeItem[] {
  return (items || []).map((item) => {
    const next: TreeItem = { ...item };
    if ((item as TreeItem & { isDirectory?: boolean }).isDirectory) {
      next.selectable = true;
    }
    if (item.children?.length) {
      next.children = withDirectoryTreeSelectable(item.children as TreeItem[]);
    }
    return next;
  });
}

export function buildMonitorTreeOptionsFromNvrList(nvrs: NvrInfo[]): {
  nvrNameMap: Map<number, string>;
  nvrs: NvrInfo[];
} {
  return { nvrNameMap: buildNvrNameMap(nvrs), nvrs };
}

/** 首屏展开目录、NVR 父节点及已有子节点的国标设备，便于看到挂载关系 */
export function collectMonitorTreeExpandedKeys(nodes: TreeItem[]): string[] {
  const keys: string[] = [];
  const walk = (list: TreeItem[]) => {
    list.forEach((n) => {
      const key = String(n.key);
      if (
        key.startsWith('dir_') ||
        key.startsWith('nvr_') ||
        (key.startsWith('gb_dev_') && n.children?.length)
      ) {
        keys.push(key);
      }
      if (n.children?.length) walk(n.children as TreeItem[]);
    });
  };
  walk(nodes);
  return keys;
}

export function findMonitorTreeNodeByKey(nodes: TreeItem[], key: string): TreeItem | null {
  for (const node of nodes) {
    if (node.key === key) return node;
    if (node.children?.length) {
      const found = findMonitorTreeNodeByKey(node.children as TreeItem[], key);
      if (found) return found;
    }
  }
  return null;
}

/** 按设备 ID 在监控树中查找直连设备节点 */
export function findMonitorDeviceById(
  nodes: TreeItem[],
  deviceId: string,
): MonitorTreeDeviceNode | null {
  for (const node of nodes) {
    const key = String(node.key ?? '');
    if (key === `device_${deviceId}` && (node as any).device) {
      return (node as any).device as MonitorTreeDeviceNode;
    }
    if (node.children?.length) {
      const found = findMonitorDeviceById(node.children as TreeItem[], deviceId);
      if (found) return found;
    }
  }
  return null;
}

/** 国标通道在目录树中对应的已同步 device 记录（含 ai_http_stream） */
export function findMonitorGbDeviceByChannel(
  nodes: TreeItem[],
  sipDeviceId: string,
  channelId: string,
): MonitorTreeDeviceNode | null {
  const targetSource = `gb28181://${sipDeviceId}/${channelId}`.toLowerCase();
  const walk = (list: TreeItem[]): MonitorTreeDeviceNode | null => {
    for (const node of list) {
      const device = (node as any).device as MonitorTreeDeviceNode | undefined;
      const gb = (node as any).gbChannel as { sipDeviceId: string; channelId: string } | undefined;
      if (gb?.sipDeviceId === sipDeviceId && gb?.channelId === channelId && device) {
        return device;
      }
      if (device?.source?.toLowerCase() === targetSource) {
        return device;
      }
      if (node.children?.length) {
        const found = walk(node.children as TreeItem[]);
        if (found) return found;
      }
    }
    return null;
  };
  return walk(nodes);
}

/** 从监控树节点 key 解析目录 ID */
export function parseMonitorDirectoryId(key: string): number | null {
  if (!key.startsWith('dir_')) return null;
  const id = Number(key.slice(4));
  return Number.isFinite(id) ? id : null;
}

/** 节点是否可移动到目录（直连设备或已入库的国标通道；NVR 挂载通道仅随 NVR 父节点批量移动） */
export function getMonitorNodeMoveableDeviceId(node: TreeItem): string | null {
  const key = String(node.key ?? '');
  if (key.startsWith('device_')) {
    const device = (node as any).device as MonitorTreeDeviceNode | undefined;
    if (device && isNvrChannelDevice(device)) return null;
    return device?.id ?? key.slice('device_'.length);
  }
  if (key.startsWith('gb_ch_')) {
    const device = (node as any).device as MonitorTreeDeviceNode | undefined;
    return device?.id ?? null;
  }
  return null;
}

/** 是否显示单设备「移动到目录」操作（NVR 挂载通道仅允许在 NVR 父节点批量移动） */
export function canShowMonitorDeviceMoveAction(node: TreeItem): boolean {
  if (isMonitorNvrChannelNode(node) || isMonitorNvrParentNode(node)) return false;
  return !!getMonitorNodeMoveableDeviceId(node);
}

/** 是否显示 NVR 父节点「批量移动到目录」/「移回默认分组」 */
export function canShowMonitorNvrBatchMoveAction(node: TreeItem): boolean {
  return isMonitorNvrParentNode(node);
}

/** 收集 NVR 父节点下全部挂载通道（用于批量移动/移回默认分组） */
export function collectNvrChannelDevicesUnderNode(node: TreeItem): MonitorTreeDeviceNode[] {
  if (!isMonitorNvrParentNode(node)) return [];
  const result: MonitorTreeDeviceNode[] = [];
  const seen = new Set<string>();

  const walk = (n: TreeItem) => {
    const key = String(n.key ?? '');
    const device = (n as { device?: MonitorTreeDeviceNode }).device;
    if (key.startsWith('device_') && device && isNvrChannelDevice(device)) {
      if (!seen.has(device.id)) {
        seen.add(device.id);
        result.push(device);
      }
    }
    if (n.children?.length) {
      (n.children as TreeItem[]).forEach(walk);
    }
  };

  walk(node);
  return result;
}

/** 是否显示目录「批量移动」操作 */
export function canShowMonitorDirectoryBatchMoveAction(node: TreeItem): boolean {
  return String(node.key ?? '').startsWith('dir_');
}

/** 收集目录节点下所有可移动设备（含子目录） */
export function collectMoveableDevicesUnderNode(node: TreeItem): MonitorTreeDeviceNode[] {
  const result: MonitorTreeDeviceNode[] = [];
  const seen = new Set<string>();

  const pushDevice = (device: MonitorTreeDeviceNode) => {
    if (!device?.id || seen.has(device.id)) return;
    seen.add(device.id);
    result.push(device);
  };

  const walk = (n: TreeItem) => {
    const deviceId = getMonitorNodeMoveableDeviceId(n);
    if (deviceId) {
      const device = (n as any).device as MonitorTreeDeviceNode | undefined;
      if (device) {
        pushDevice(device);
      } else {
        pushDevice({
          type: 'device',
          id: deviceId,
          name: String(n.title ?? deviceId),
        });
      }
    }
    if (n.children?.length) {
      (n.children as TreeItem[]).forEach(walk);
    }
  };

  walk(node);
  return result;
}

/** 统计可点播叶子（直连设备 + 国标通道） */
export function countMonitorTreePlayableLeaves(nodes: TreeItem[]): number {
  let count = 0;
  const walk = (list: TreeItem[]) => {
    list.forEach((node) => {
      const key = String(node.key ?? '');
      if (key.startsWith('device_') || key.startsWith('gb_ch_')) {
        count++;
      }
      if (node.children?.length) walk(node.children as TreeItem[]);
    });
  };
  walk(nodes);
  return count;
}

import {
  getDirectoryMonitorTree,
  type DeviceInfo,
  type DeviceDirectory,
  type MonitorTreeDeviceNode,
  type MonitorTreeDirectoryNode,
  type NvrInfo,
} from '@/api/device/camera';
import { queryAllVideoList } from '@/api/device/gb28181';
import type { TreeItem } from '@/components/Tree';
import { buildGbSipNameMap, buildGbSipNameMapFromDirectoryTree } from './monitorGbDisplay';
import {
  buildMonitorDirectoryTreeNodes,
  buildMonitorTreeOptionsFromNvrList,
} from './monitorDeviceTree';
import { fetchNvrListBrief } from './nvrDeviceGroup';
import {
  isGb28181ChannelRecord,
  resolveWvpSipDeviceId,
  wvpDeviceToTableRow,
} from './gb28181DeviceGroup';
import { parseGb28181Source } from './deviceLabel';
import {
  getCachedMonitorDirectoryTreeBundle,
  invalidateMonitorDirectoryTreeCache,
  setCachedMonitorDirectoryTreeBundle,
  type MonitorDirectoryTreeBundle,
} from './monitorDirectoryTreeCache';

export type { MonitorDirectoryTreeBundle };

export function normalizeMonitorTreePayload(res: unknown): MonitorTreeDirectoryNode[] {
  const payload =
    (res as { code?: number; data?: { tree?: unknown } })?.code !== undefined
      ? (res as { data?: { tree?: unknown } }).data
      : res;
  if (Array.isArray((payload as { tree?: unknown })?.tree)) {
    return (payload as { tree: MonitorTreeDirectoryNode[] }).tree;
  }
  if (Array.isArray(payload)) {
    return payload as MonitorTreeDirectoryNode[];
  }
  return [];
}

export interface FetchMonitorDirectoryTreeOptions {
  /** 为 false 时在 monitor-tree 请求中触发服务端 WVP 同步（仅手动全量刷新使用） */
  skipSync?: boolean;
}

/** 与分屏监控左侧树一致：monitor-tree + WVP 国标列表 + NVR 元数据 */
export async function fetchMonitorDirectoryTreeBundle(
  options?: FetchMonitorDirectoryTreeOptions,
): Promise<MonitorDirectoryTreeBundle> {
  const skipSync = options?.skipSync !== false;
  const [res, gbRes, nvrs] = await Promise.all([
    getDirectoryMonitorTree({ skipSync }),
    queryAllVideoList().catch((e) => {
      console.warn('拉取 WVP 国标设备列表失败，将仅使用目录树内国标数据', e);
      return { data: [] as Record<string, any>[] };
    }),
    fetchNvrListBrief().catch(() => [] as NvrInfo[]),
  ]);
  const rawTree = normalizeMonitorTreePayload(res);
  const wvpDevices = Array.isArray(gbRes?.data) ? gbRes.data : [];
  const nvrList = Array.isArray(nvrs) ? nvrs.filter((n) => n && n.id != null) : [];

  const sipNameMap = buildGbSipNameMap(wvpDevices);
  buildGbSipNameMapFromDirectoryTree(rawTree).forEach((name, sip) => {
    if (!sipNameMap.has(sip)) sipNameMap.set(sip, name);
  });

  const { nvrNameMap, nvrs: nvrArr } = buildMonitorTreeOptionsFromNvrList(nvrList);
  const treeItems = buildMonitorDirectoryTreeNodes(rawTree, {
    sipNameMap,
    nvrNameMap,
    nvrs: nvrArr,
    wvpDevices,
  });

  const bundle: MonitorDirectoryTreeBundle = {
    rawTree,
    wvpDevices,
    nvrs: nvrArr,
    treeItems,
    sipNameMap,
  };
  setCachedMonitorDirectoryTreeBundle(bundle);
  return bundle;
}

export interface LoadMonitorDirectoryTreeOptions {
  /** 强制跳过缓存、重新拉取 */
  force?: boolean;
  skipSync?: boolean;
  onBundle: (bundle: MonitorDirectoryTreeBundle, meta: { fromCache: boolean }) => void;
  onError?: (error: unknown) => void;
  onRefreshingChange?: (refreshing: boolean) => void;
}

/**
 * 缓存优先加载：有缓存则立即回调 onBundle，再在后台静默刷新。
 */
export async function loadMonitorDirectoryTreeWithCache(
  options: LoadMonitorDirectoryTreeOptions,
): Promise<MonitorDirectoryTreeBundle | null> {
  const { force, skipSync, onBundle, onError, onRefreshingChange } = options;

  if (!force) {
    const cached = getCachedMonitorDirectoryTreeBundle();
    if (cached?.treeItems?.length) {
      onBundle(cached, { fromCache: true });
      onRefreshingChange?.(true);
      try {
        const fresh = await fetchMonitorDirectoryTreeBundle({ skipSync });
        onBundle(fresh, { fromCache: false });
        return fresh;
      } catch (e) {
        console.warn('后台刷新设备目录树失败', e);
        onError?.(e);
        return cached;
      } finally {
        onRefreshingChange?.(false);
      }
    }
  }

  onRefreshingChange?.(true);
  try {
    const bundle = await fetchMonitorDirectoryTreeBundle({ skipSync });
    onBundle(bundle, { fromCache: false });
    return bundle;
  } catch (e) {
    console.error('加载设备目录树失败', e);
    onError?.(e);
    return null;
  } finally {
    onRefreshingChange?.(false);
  }
}

export { invalidateMonitorDirectoryTreeCache };

export function mapMonitorTreeToDeviceDirectories(
  dirs: MonitorTreeDirectoryNode[],
): DeviceDirectory[] {
  return (dirs || []).map((dir) => ({
    id: dir.id,
    name: dir.name,
    parent_id: dir.parent_id ?? null,
    sort_order: dir.sort_order ?? 0,
    is_default: dir.is_default,
    snap_save_time: dir.snap_save_time,
    record_save_time: dir.record_save_time,
    device_count: dir.device_count ?? dir.devices?.length ?? 0,
    children: mapMonitorTreeToDeviceDirectories(dir.children || []),
  }));
}

export function findMonitorDirectoryNode(
  dirs: MonitorTreeDirectoryNode[],
  directoryId: number,
): MonitorTreeDirectoryNode | null {
  for (const dir of dirs) {
    if (dir.id === directoryId) return dir;
    if (dir.children?.length) {
      const found = findMonitorDirectoryNode(dir.children, directoryId);
      if (found) return found;
    }
  }
  return null;
}

export function monitorTreeDeviceToDeviceInfo(d: MonitorTreeDeviceNode): DeviceInfo {
  return {
    id: d.id,
    name: d.name,
    online: d.online,
    source: d.source ?? undefined,
    device_kind: d.device_kind,
    nvr_id: d.nvr_id ?? undefined,
    nvr_channel: d.nvr_channel,
    nvr_label: d.nvr_label ?? undefined,
    directory_id: d.directory_id ?? undefined,
    http_stream: d.http_stream,
    rtmp_stream: d.rtmp_stream,
    ai_http_stream: d.ai_http_stream,
    ai_rtmp_stream: d.ai_rtmp_stream,
  } as DeviceInfo;
}

/** 目录下设备列表（含默认分组下 WVP 未入库的国标 SIP 行） */
export function buildDirectoryDevicesForTable(
  dirNode: MonitorTreeDirectoryNode,
  wvpDevices: Record<string, any>[] = [],
): DeviceInfo[] {
  const devices = (dirNode.devices || []).map(monitorTreeDeviceToDeviceInfo);
  if (!dirNode.is_default || !wvpDevices.length) {
    return devices;
  }
  const seenSip = new Set<string>();
  for (const d of devices) {
    if (!isGb28181ChannelRecord(d)) continue;
    const parsed = parseGb28181Source(d.source);
    if (parsed?.deviceId) seenSip.add(parsed.deviceId);
  }
  for (const wvp of wvpDevices) {
    const sipId = resolveWvpSipDeviceId(wvp);
    if (!sipId || seenSip.has(sipId)) continue;
    seenSip.add(sipId);
    devices.push(wvpDeviceToTableRow(wvp));
  }
  return devices;
}

/** 查找默认目录；若无标记则回退首个根目录 */
export function findDefaultMonitorDirectory(
  nodes: MonitorTreeDirectoryNode[],
): MonitorTreeDirectoryNode | null {
  for (const node of nodes) {
    if (node.is_default) return node;
    if (node.children?.length) {
      const found = findDefaultMonitorDirectory(node.children);
      if (found) return found;
    }
  }
  if (nodes.length) {
    return nodes.find((n) => n.name === '默认分组') ?? nodes[0];
  }
  return null;
}

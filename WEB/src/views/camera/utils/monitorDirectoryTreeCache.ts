import type { NvrInfo } from '@/api/device/camera';
import type { TreeItem } from '@/components/Tree';
import type { MonitorTreeDirectoryNode } from '@/api/device/camera';
import { createSessionStorage } from '@/utils/cache';

export interface MonitorDirectoryTreeBundle {
  rawTree: MonitorTreeDirectoryNode[];
  wvpDevices: Record<string, any>[];
  nvrs: NvrInfo[];
  treeItems: TreeItem[];
  sipNameMap: Map<string, string>;
}

const CACHE_KEY = 'MONITOR_DIRECTORY_TREE_BUNDLE_V1';
/** 缓存 30 分钟，进入分屏监控可先展示上次目录 */
const CACHE_TTL_SEC = 30 * 60;

const storage = createSessionStorage({ timeout: CACHE_TTL_SEC });

type SerializedBundle = Omit<MonitorDirectoryTreeBundle, 'sipNameMap'> & {
  sipNameMap: [string, string][];
};

interface CachedEntry {
  ts: number;
  bundle: SerializedBundle;
}

let memoryBundle: MonitorDirectoryTreeBundle | null = null;

function serializeBundle(bundle: MonitorDirectoryTreeBundle): SerializedBundle {
  return {
    ...bundle,
    sipNameMap: Array.from(bundle.sipNameMap.entries()),
  };
}

function deserializeBundle(data: SerializedBundle): MonitorDirectoryTreeBundle {
  return {
    ...data,
    sipNameMap: new Map(data.sipNameMap),
  };
}

export function getCachedMonitorDirectoryTreeBundle(): MonitorDirectoryTreeBundle | null {
  if (memoryBundle) return memoryBundle;
  const entry = storage.get(CACHE_KEY) as CachedEntry | null;
  if (!entry?.bundle?.treeItems?.length) return null;
  const bundle = deserializeBundle(entry.bundle);
  memoryBundle = bundle;
  return bundle;
}

export function setCachedMonitorDirectoryTreeBundle(bundle: MonitorDirectoryTreeBundle): void {
  memoryBundle = bundle;
  storage.set(CACHE_KEY, {
    ts: Date.now(),
    bundle: serializeBundle(bundle),
  });
}

export function invalidateMonitorDirectoryTreeCache(): void {
  memoryBundle = null;
  storage.remove(CACHE_KEY);
}

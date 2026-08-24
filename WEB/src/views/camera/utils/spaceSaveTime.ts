import type { DeviceInfo } from '@/api/device/camera';
import type { RecordSpace } from '@/api/device/record';
import type { SnapSpace } from '@/api/device/snap';
import { formatCameraDeviceLabel, isNvrListRow } from './deviceLabel';
import { isGb28181SipListRow } from './gb28181DeviceGroup';

export type SpaceKind = 'snap' | 'record';
/** 存储空间页子 Tab */
export type StorageTabKind = SpaceKind;
export type SpaceInfo = SnapSpace | RecordSpace;

/** 存储空间文件夹节点类型 */
export type SpaceFolderNodeType = 'space' | 'folder';
export type SpaceFolderType = 'nvr' | 'gb28181';
export type SpaceDeviceKind = 'direct' | 'nvr_channel' | 'gb28181';

export interface SpaceBreadcrumb {
  key: string;
  name: string;
}

/** 存储空间列表节点（叶子空间或 NVR/GB28181 分组文件夹） */
export interface SpaceFolderNode extends Partial<SpaceInfo> {
  node_type: SpaceFolderNodeType;
  node_key: string;
  name: string;
  space_name: string;
  folder_type?: SpaceFolderType;
  device_kind?: SpaceDeviceKind;
  group_save_time?: number;
  group_type?: 'nvr' | 'gb28181';
  group_key?: string;
  child_count?: number;
  nvr_id?: number;
  nvr_channel?: number;
  sip_device_id?: string;
  ip?: string;
  port?: number;
}

/** 节点展示用设备类型：分组文件夹或叶子空间的 device_kind */
export function resolveSpaceNodeDeviceKind(node: SpaceFolderNode): SpaceDeviceKind {
  if (isSpaceFolderNode(node)) {
    if (node.folder_type === 'nvr') return 'nvr_channel';
    if (node.folder_type === 'gb28181') return 'gb28181';
    return 'direct';
  }
  return node.device_kind || 'direct';
}

export function isSpaceFolderNode(node: SpaceFolderNode): boolean {
  return node.node_type === 'folder';
}

export function isSpaceLeafNode(node: SpaceFolderNode): node is SpaceFolderNode & SpaceInfo {
  return node.node_type === 'space' && typeof node.id === 'number';
}

export function getSpaceKindLabel(kind: SpaceKind): string {
  return kind === 'snap' ? '抓拍' : '录像';
}

export function buildSpaceTableColumns(kind: SpaceKind) {
  const label = getSpaceKindLabel(kind);
  return [
    { title: '设备名称', key: 'name', dataIndex: 'name', width: 180, ellipsis: true },
    { title: '类型', key: 'deviceType', width: 108 },
    { title: '设备 ID', dataIndex: 'id', width: 140, ellipsis: true },
    { title: `${label}保存时间`, key: 'saveTime', width: 200 },
    { title: `${label}存储模式`, key: 'saveMode', width: 108 },
  ];
}

/** 默认 1 小时 */
export const DEFAULT_SAVE_TIME = 1;
export const MIN_SAVE_TIME_HOURS = 1;
export const MAX_SAVE_TIME_DAYS = 3650;
export const MAX_SAVE_TIME_HOURS = MAX_SAVE_TIME_DAYS * 24;

export interface SaveTimeParts {
  days: number;
  hours: number;
}

/** 将总小时数拆分为天 + 小时 */
export function hoursToSaveTimeParts(totalHours: number): SaveTimeParts {
  if (totalHours <= 0) return { days: 0, hours: 0 };
  const days = Math.floor(totalHours / 24);
  const hours = totalHours % 24;
  return { days, hours };
}

/** 将天 + 小时合并为总小时数 */
export function saveTimePartsToHours(parts: SaveTimeParts): number {
  return parts.days * 24 + parts.hours;
}

/** 格式化保存时长（小时）为展示文案 */
export function formatSaveTimeLabel(totalHours?: number | null): string {
  if (totalHours == null) return '-';
  if (totalHours === 0) return '永久';
  const { days, hours } = hoursToSaveTimeParts(totalHours);
  if (days === 0) return `${hours} 小时`;
  if (hours === 0) return `${days} 天`;
  return `${days} 天 ${hours} 小时`;
}

/** 校验保存时长：0=永久，或总时长 >= 1 小时 */
export function isValidSaveTime(totalHours: number): boolean {
  return totalHours === 0 || totalHours >= MIN_SAVE_TIME_HOURS;
}

export function isSpaceGroupRow(record: DeviceInfo & { _isNvrGroup?: boolean }): boolean {
  return !!record._isNvrGroup || isGb28181SipListRow(record);
}

export function canCustomizeDeviceSaveTime(record: DeviceInfo & { _isNvrGroup?: boolean }): boolean {
  return !isSpaceGroupRow(record);
}

/** 存储空间页：排除 WVP 国标 SIP 聚合行、NVR 列表行（仅通道/直连设备可有空间） */
export function filterStorageSpaceDirectoryDevices(devices: DeviceInfo[]): DeviceInfo[] {
  return devices.filter((d) => !isGb28181SipListRow(d) && !isNvrListRow(d));
}

/** 按设备名称 / 设备 ID 过滤存储空间表格行（支持 NVR 树形子行） */
export function filterSpaceRowsByKeyword(rows: SpaceDeviceRow[], keyword: string): SpaceDeviceRow[] {
  const q = keyword.trim().toLowerCase();
  if (!q) return rows;

  const result: SpaceDeviceRow[] = [];
  for (const row of rows) {
    const children = row.children?.length
      ? filterSpaceRowsByKeyword(row.children, keyword)
      : undefined;
    const label = formatCameraDeviceLabel(row).toLowerCase();
    const idMatch = String(row.id || '').toLowerCase().includes(q);
    const nameMatch = label.includes(q) || row._space?.space_name?.toLowerCase().includes(q);
    if (nameMatch || idMatch || children?.length) {
      result.push({
        ...row,
        children: children?.length ? children : undefined,
      });
    }
  }
  return result;
}

export interface SpaceDeviceRow extends DeviceInfo {
  _space?: SpaceInfo;
  _effectiveSaveTime?: number;
  _saveTimeCustom?: boolean;
  children?: SpaceDeviceRow[];
}

export function buildSpaceMap(spaces: SpaceInfo[]): Map<string, SpaceInfo> {
  const map = new Map<string, SpaceInfo>();
  for (const space of spaces) {
    if (space.device_id) {
      map.set(space.device_id, space);
    }
  }
  return map;
}

export function attachSpaceToRows(
  rows: DeviceInfo[],
  spaceMap: Map<string, SpaceInfo>,
  directorySaveTime: number,
): SpaceDeviceRow[] {
  return rows.map((row) => {
    const children = (row as SpaceDeviceRow).children;
    if (children?.length) {
      return {
        ...row,
        children: attachSpaceToRows(children, spaceMap, directorySaveTime),
      } as SpaceDeviceRow;
    }
    const space = spaceMap.get(row.id);
    if (!space) {
      return { ...row } as SpaceDeviceRow;
    }
    return {
      ...row,
      _space: space,
      _effectiveSaveTime: space.effective_save_time ?? space.save_time ?? directorySaveTime,
      _saveTimeCustom: !!space.save_time_custom,
    } as SpaceDeviceRow;
  });
}

export const SPACE_FOLDER_ROOT_KEY = 'root';

/** 解析路由 query 中的 folder（存储空间钻取目录 key） */
export function parseSpaceFolderQuery(value: unknown): string {
  if (typeof value === 'string' && value) return value;
  if (Array.isArray(value) && typeof value[0] === 'string' && value[0]) return value[0];
  return SPACE_FOLDER_ROOT_KEY;
}

/** 构建返回存储空间列表页的路由 query */
export function buildCameraStorageQuery(
  spaceKind: SpaceKind,
  folder?: string,
): Record<string, string> {
  const query: Record<string, string> = { tab: '4', storage: spaceKind };
  const key = folder && folder !== SPACE_FOLDER_ROOT_KEY ? folder : undefined;
  if (key) query.folder = key;
  return query;
}

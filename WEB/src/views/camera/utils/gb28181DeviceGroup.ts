import type { DeviceInfo } from '@/api/device/camera';
import { getDeviceList } from '@/api/device/camera';
import { queryAllVideoList } from '@/api/device/gb28181';
import { isGb28181Device, parseGb28181Source } from './deviceLabel';
import {
  buildCardRowsWithNvr,
  fetchNvrListBrief,
  filterStandaloneDirectDevices,
  nvrToTableRow,
} from './nvrDeviceGroup';
import { formatGb28181DeviceDisplayName } from './gb28181DeviceLabel';
import type { Gb28181CardItem } from '@/views/camera/components/Gb28181DeviceCard/index.vue';

/** 国标 SIP 设备（WVP 或本地聚合） */
export interface GbSipDeviceSummary {
  sipDeviceId: string;
  name: string;
  channelCount: number;
  online: boolean;
  channels: DeviceInfo[];
}

export function isGb28181ChannelRecord(device: DeviceInfo): boolean {
  return isGb28181Device(device.source, device.device_kind);
}

export function isGb28181SipListRow(record: {
  device_kind?: string;
  id?: string;
  _isGbSip?: boolean;
}): boolean {
  if (record._isGbSip) return true;
  if (record.device_kind === 'gb28181_sip') return true;
  return String(record.id || '').startsWith('gb_sip_');
}

/** @deprecated 使用 filterStandaloneDirectDevices */
export function filterDirectDevices(devices: DeviceInfo[]): DeviceInfo[] {
  return filterStandaloneDirectDevices(devices.filter((d) => !isGb28181ChannelRecord(d)));
}

/** WVP 国标设备 → 卡片数据（与 gb28181/VideoCardList 字段一致） */
/** 从 WVP 设备记录解析 SIP 国标编号（兼容多种字段名） */
export function resolveWvpSipDeviceId(wvp: Record<string, any>): string {
  return String(
    wvp.deviceIdentification ?? wvp.deviceId ?? wvp.id ?? wvp.gbId ?? '',
  ).trim();
}

export function wvpDeviceToSummary(wvp: Record<string, any>): GbSipDeviceSummary {
  const sipDeviceId = resolveWvpSipDeviceId(wvp);
  return {
    sipDeviceId,
    name: String(wvp.name || sipDeviceId).trim(),
    channelCount: Number(wvp.channelCount ?? wvp.subCount ?? 0) || 0,
    online: !!(wvp.onLine ?? wvp.on_line ?? wvp.online),
    channels: [],
  };
}

export function wvpDeviceToCardItem(wvp: Record<string, any>): Gb28181CardItem {
  const summary = wvpDeviceToSummary(wvp);
  return {
    onLine: summary.online,
    name: formatGb28181DeviceDisplayName(summary.name),
    deviceIdentification: summary.sipDeviceId,
    ip: wvp.ip || wvp.localIp || '-',
    mediaServerId: wvp.mediaServerId != null ? String(wvp.mediaServerId) : '-',
    manufacturer: String(wvp.manufacturer ?? wvp.manufacture ?? '').trim(),
    _summary: summary,
    _wvpRaw: wvp,
  };
}

export function wvpDeviceToTableRow(wvp: Record<string, any>): DeviceInfo & {
  _isGbSip: boolean;
  sip_device_id: string;
} {
  const summary = wvpDeviceToSummary(wvp);
  return {
    id: `gb_sip_${summary.sipDeviceId}`,
    name: formatGb28181DeviceDisplayName(summary.name),
    device_kind: 'gb28181_sip',
    sip_device_id: summary.sipDeviceId,
    channel_count: summary.channelCount,
    online: summary.online,
    manufacturer: wvp.manufacturer ?? wvp.manufacture ?? 'GB28181',
    model: wvp.model ?? '-',
    ip: wvp.ip || wvp.localIp || '',
    source: '',
    _isGbSip: true,
  } as DeviceInfo & { _isGbSip: boolean; sip_device_id: string };
}

/** 合并直连（device 表）+ 国标（WVP）列表 */
export async function fetchMergedDeviceList(params: Record<string, any> = {}) {
  const search = params.search ?? params.deviceName;
  const online = params.online;

  const [devRes, gbRes, nvrs] = await Promise.all([
    getDeviceList({
      pageNo: 1,
      pageSize: 10000,
      search: search || undefined,
      online: online !== undefined && online !== '' ? online : undefined,
    }),
    queryAllVideoList({
      query: search || undefined,
      status: online === true || online === 'true' ? true : online === false || online === 'false' ? false : undefined,
    }),
    fetchNvrListBrief(),
  ]);

  const allDevices = devRes?.data ?? [];
  const direct = filterStandaloneDirectDevices(
    allDevices.filter((d) => !isGb28181ChannelRecord(d) && !isGb28181SipListRow(d)),
    nvrs,
  );
  const gbRows = (gbRes?.data ?? []).map((wvp) => wvpDeviceToTableRow(wvp));
  const nvrRows = nvrs.map((n) => nvrToTableRow(n));

  return {
    data: [...direct, ...nvrRows, ...gbRows],
    total: direct.length + nvrRows.length + gbRows.length,
    directCount: direct.length,
    nvrCount: nvrRows.length,
    gbCount: gbRows.length,
  };
}

export type DeviceListDisplayItem =
  | { kind: 'direct'; device: DeviceInfo }
  | { kind: 'gb_sip'; gbItem: Gb28181CardItem }
  | { kind: 'nvr'; nvrItem: import('./nvrDeviceGroup').NvrCardItem };

export function buildMergedCardRows(
  devices: DeviceInfo[],
  wvpDevices: Record<string, any>[],
  nvrs: import('./nvrDeviceGroup').NvrInfo[] = [],
): DeviceListDisplayItem[] {
  const gbItems: DeviceListDisplayItem[] = [];
  const seenSip = new Set<string>();
  for (const wvp of wvpDevices || []) {
    const sipId = resolveWvpSipDeviceId(wvp);
    if (!sipId || seenSip.has(sipId)) continue;
    seenSip.add(sipId);
    gbItems.push({ kind: 'gb_sip' as const, gbItem: wvpDeviceToCardItem(wvp) });
  }
  const directDevices = devices.filter(
    (d) => !isGb28181ChannelRecord(d) && !isGb28181SipListRow(d),
  );
  return buildCardRowsWithNvr(directDevices, nvrs, gbItems);
}

/** @deprecated 表格请用 fetchMergedDeviceList */
export function flattenDeviceListApiResponse(devices: DeviceInfo[]): DeviceInfo[] {
  return filterDirectDevices(devices);
}

/** 从 device 表通道记录分组（仅目录同步场景，不用于设备列表展示） */
export function groupGbSipDevicesFromChannelRecords(
  devices: DeviceInfo[],
): Map<string, DeviceInfo[]> {
  const map = new Map<string, DeviceInfo[]>();
  for (const d of devices) {
    if (!isGb28181ChannelRecord(d)) continue;
    const parsed = parseGb28181Source(d.source);
    const sipId = parsed?.deviceId || d.serial_number?.trim();
    if (!sipId) continue;
    const list = map.get(sipId) || [];
    list.push(d);
    map.set(sipId, list);
  }
  return map;
}

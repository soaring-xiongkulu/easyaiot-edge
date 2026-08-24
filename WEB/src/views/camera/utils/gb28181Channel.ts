import { gb28181VirtualDeviceId } from './deviceLabel';

const DEVICE_TYPE_PLACEHOLDERS = new Set([
  '-',
  '—',
  '－',
  '无',
  '未知',
  'null',
  'undefined',
  'n/a',
  'na',
]);

/** 国标 PTZType 编码（GB/T 28181）→ 展示文案，0/空 兜底 IPC */
const GB_PTZ_TYPE_LABELS: Record<string, string> = {
  '0': 'IPC',
  '1': '球机',
  '2': '半球',
  '3': '固定枪机',
  '4': '遥控枪机',
  '5': '遥控半球',
  '6': '全景通道',
  '7': '分割通道',
};

/** 国标通道设备类型展示；无有效值时兜底 IPC */
export function formatGbChannelDeviceType(item: Record<string, unknown>): string {
  const raw = item.ptzTypeText ?? item.ptzType ?? item.deviceType ?? item.channelType;
  if (raw === null || raw === undefined) return 'IPC';
  const type = String(raw).trim();
  if (!type || DEVICE_TYPE_PLACEHOLDERS.has(type.toLowerCase())) return 'IPC';
  if (/^\d+$/.test(type)) {
    return GB_PTZ_TYPE_LABELS[type] ?? 'IPC';
  }
  return type;
}

/**
 * WVP 国标通道列表字段归一化（与 gb28181 通道页、点播接口一致）
 */
export function normalizeWvpChannelItem(
  item: Record<string, any>,
  parentSipDeviceId?: string,
): Record<string, any> {
  const sipDeviceId = String(
    parentSipDeviceId ||
      item.parentDeviceId ||
      item.parentId ||
      item.gbParentId ||
      item.deviceIdentification ||
      '',
  ).trim();

  const channelGbId = String(
    item.channelId ||
      item.deviceChannelId ||
      item.gbDeviceId ||
      item.gbId ||
      '',
  ).trim();

  // WVP 通道行里 deviceId 常为通道国标编码，不能与 SIP 设备号混淆
  let resolvedChannelId = channelGbId;
  if (!resolvedChannelId && item.deviceId && String(item.deviceId) !== sipDeviceId) {
    resolvedChannelId = String(item.deviceId).trim();
  }
  if (!resolvedChannelId && item.id != null && String(item.id) !== sipDeviceId) {
    resolvedChannelId = String(item.id).trim();
  }

  const name =
    item.name || item.channelName || item.deviceName || item.gbName || resolvedChannelId || '-';

  return {
    ...item,
    deviceIdentification: sipDeviceId,
    /** 点播父设备：SIP 设备国标编号 */
    deviceId: sipDeviceId,
    /** 点播通道：通道国标编号 */
    channelId: resolvedChannelId,
    gbDeviceId: resolvedChannelId || item.gbDeviceId,
    name,
    manufacturer: item.manufacturer ?? item.manufacture ?? '',
    manufacture: item.manufacture ?? item.manufacturer ?? '',
    ptzTypeText: formatGbChannelDeviceType(item),
    createdTime: item.createdTime ?? item.createTime,
    updatedTime: item.updatedTime ?? item.updateTime,
  };
}

/** 从通道记录解析点播参数 */
export function resolveGbChannelPlayIds(
  record: Record<string, any>,
  parentSipDeviceId: string,
): { sipDeviceId: string; channelId: string } | null {
  const sip = String(parentSipDeviceId || record.deviceIdentification || record.deviceId || '').trim();
  const normalized = normalizeWvpChannelItem(record, sip);
  const channelId = String(normalized.channelId || '').trim();
  if (!sip || !channelId || channelId === sip) {
    return null;
  }
  return { sipDeviceId: sip, channelId };
}

/** 解析单个坐标值，空值或非数字返回 null */
function parseGbCoord(value: unknown): number | null {
  if (value == null || value === '') return null;
  const n = Number(value);
  return Number.isNaN(n) ? null : n;
}

/** 按坐标对提取：经纬度需同时有效且不为 (0,0)（WVP 未上报默认值），否则该来源视为无坐标 */
function extractGbCoordPair(
  channel: Record<string, any>,
  lngKey: string,
  latKey: string,
): [number, number] | null {
  const lng = parseGbCoord(channel[lngKey]);
  const lat = parseGbCoord(channel[latKey]);
  if (lng == null || lat == null) return null;
  if (lng === 0 && lat === 0) return null;
  return [lng, lat];
}

/**
 * 从 WVP 通道记录提取位置字段。
 * 坐标按对回退：优先 WVP 主坐标 gbLongitude/gbLatitude（WGS-84），缺失或为 (0,0)
 * 时取国标 Catalog 上报坐标 longitude/latitude，均无效视为未上报坐标。
 */
export function extractGbChannelLocation(channel: Record<string, any>): {
  longitude?: number | null;
  latitude?: number | null;
  address?: string | null;
  location_source?: string | null;
} {
  const pair =
    extractGbCoordPair(channel, 'gbLongitude', 'gbLatitude') ??
    extractGbCoordPair(channel, 'longitude', 'latitude');
  const rawAddr = channel.address ?? channel.gbAddress;
  const address =
    rawAddr != null && String(rawAddr).trim() ? String(rawAddr).trim() : null;
  if (!pair && !address) {
    return {};
  }
  return {
    longitude: pair ? pair[0] : null,
    latitude: pair ? pair[1] : null,
    address,
    location_source: pair ? 'gb28181' : undefined,
  };
}

/** 国标通道在 device 表中的虚拟设备 ID，用于设置地图坐标 */
export function buildGbChannelLocationDevice(
  channel: Record<string, any>,
  sipDeviceId: string,
): {
  id: string;
  name?: string;
  device_kind?: string;
  longitude?: number | null;
  latitude?: number | null;
  address?: string | null;
  location_source?: string | null;
} | null {
  const ids = resolveGbChannelPlayIds(channel, sipDeviceId);
  if (!ids) return null;
  const name =
    channel.name || channel.channelName || channel.deviceName || channel.gbName || ids.channelId;
  return {
    id: gb28181VirtualDeviceId(ids.sipDeviceId, ids.channelId),
    name: String(name || '').trim() || undefined,
    device_kind: 'gb28181',
    ...extractGbChannelLocation(channel),
  };
}

/** 摄像头位置信息（WGS84），供表单校验与地图场景复用 */

import { isGb28181SipListRow } from './gb28181DeviceGroup';
import { isNvrListRow } from './deviceLabel';

export interface DeviceLocationFields {
  longitude?: number | null;
  latitude?: number | null;
  altitude?: number | null;
  address?: string | null;
  /** 安装朝向(°)：0=正北，90=正东，顺时针 */
  heading?: number | null;
  location_source?: string | null;
  location_updated_at?: string | null;
  has_location?: boolean;
}

/** 坐标抽屉打开时传入的设备快照 */
export interface DeviceLocationDrawerRecord extends DeviceLocationFields {
  id: string;
  name?: string;
  device_kind?: string;
}

export const LOCATION_SOURCE_LABEL: Record<string, string> = {
  manual: '手动填写',
  gb28181: '国标同步',
  import: '批量导入',
};

const HEADING_COMPASS = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'] as const;

/** 是否可在地图上单独设置坐标（排除 NVR/国标 SIP 聚合行） */
export function canSetDeviceLocation(record: {
  id?: string;
  device_kind?: string;
  _isNvr?: boolean;
  _isGbSip?: boolean;
}): boolean {
  if (!record?.id) return false;
  if (isNvrListRow(record)) return false;
  if (isGb28181SipListRow(record)) return false;
  return true;
}

export function hasDeviceLocation(loc: Pick<DeviceLocationFields, 'longitude' | 'latitude' | 'has_location'>) {
  if (loc.has_location) return true;
  return loc.longitude != null && loc.latitude != null;
}

export function formatLocationSummary(loc: DeviceLocationFields): string {
  if (!hasDeviceLocation(loc)) return '未设置';
  const lng = Number(loc.longitude).toFixed(6);
  const lat = Number(loc.latitude).toFixed(6);
  const headingText = formatHeadingSummary(loc.heading);
  return headingText ? `${lng}, ${lat} · ${headingText}` : `${lng}, ${lat}`;
}

/** 格式化朝向：45°（东北） */
export function formatHeadingSummary(heading?: number | null): string {
  if (heading == null || Number.isNaN(Number(heading))) return '';
  const deg = Number(heading);
  const idx = Math.round(deg / 45) % 8;
  return `${deg.toFixed(0)}°（${HEADING_COMPASS[idx]}）`;
}

export function validateLongitude(_rule: unknown, value: unknown) {
  if (value === undefined || value === null || value === '') {
    return Promise.resolve();
  }
  const num = Number(value);
  if (Number.isNaN(num) || num < -180 || num > 180) {
    return Promise.reject('经度范围应在 -180 至 180 之间');
  }
  return Promise.resolve();
}

export function validateLatitude(_rule: unknown, value: unknown) {
  if (value === undefined || value === null || value === '') {
    return Promise.resolve();
  }
  const num = Number(value);
  if (Number.isNaN(num) || num < -90 || num > 90) {
    return Promise.reject('纬度范围应在 -90 至 90 之间');
  }
  return Promise.resolve();
}

export function validateLocationPair(longitude: unknown, latitude: unknown) {
  const hasLng = longitude !== undefined && longitude !== null && longitude !== '';
  const hasLat = latitude !== undefined && latitude !== null && latitude !== '';
  if (hasLng !== hasLat) {
    return Promise.reject('经纬度需同时填写或同时留空');
  }
  return Promise.resolve();
}

export function validateAltitude(_rule: unknown, value: unknown) {
  if (value === undefined || value === null || value === '') {
    return Promise.resolve();
  }
  const num = Number(value);
  if (Number.isNaN(num) || num < -500 || num > 9000) {
    return Promise.reject('海拔高度应在 -500 至 9000 米之间');
  }
  return Promise.resolve();
}

export function validateHeading(_rule: unknown, value: unknown) {
  if (value === undefined || value === null || value === '') {
    return Promise.resolve();
  }
  const num = Number(value);
  if (Number.isNaN(num) || num < 0 || num > 360) {
    return Promise.reject('朝向应在 0 至 360 度之间');
  }
  return Promise.resolve();
}

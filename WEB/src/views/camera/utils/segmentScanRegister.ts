import type { CredentialPair, SegmentScanDeviceRow } from '@/api/device/camera';
import { buildRtspUrl, detectBrandByRtspUrl } from '@/views/camera/utils/deviceCreateOptions';

/** 按品牌拼装 IPC 主码流 RTSP */
export function buildSegmentScanRtspUrl(
  record: SegmentScanDeviceRow,
  cred: CredentialPair,
  stream: 'main' | 'sub' = 'main',
): string | undefined {
  const ip = record.ip?.trim();
  if (!ip || !cred.username?.trim()) return undefined;

  const vendor = record.vendor || detectBrandByRtspUrl(record.rtsp_url || '');
  if (!vendor || vendor === 'custom') {
    return record.rtsp_url?.trim() || undefined;
  }

  return buildRtspUrl(
    vendor,
    ip,
    cred.username,
    cred.password || '',
    1,
    stream,
  ) || undefined;
}

export function resolveSegmentScanRtsp(
  record: SegmentScanDeviceRow,
  cred: CredentialPair,
): string | undefined {
  const fromScan = record.rtsp_url?.trim();
  if (fromScan) return fromScan;
  return buildSegmentScanRtspUrl(record, cred);
}

export function isSegmentScanRecognized(record: SegmentScanDeviceRow): boolean {
  return !!(record.is_nvr || record.is_recognized || record.vendor);
}

/** 扫描带回 auth_username，或已识别设备且表单有凭证 */
export function isSegmentScanCredentialAccessible(
  record: SegmentScanDeviceRow,
  mode: 'camera' | 'nvr',
  hasFormCredentials: boolean,
): boolean {
  if (record.auth_username && String(record.auth_username).trim()) return true;
  if (!hasFormCredentials || !isSegmentScanRecognized(record)) return false;
  if (mode === 'nvr') return true;
  return !record.is_nvr;
}

export function hasSegmentScanRegisterPayload(
  record: SegmentScanDeviceRow,
  mode: 'camera' | 'nvr',
  cred: CredentialPair,
  credentialAccessible: boolean,
): boolean {
  if (mode === 'nvr') return credentialAccessible;
  if (!credentialAccessible) return false;
  return !!resolveSegmentScanRtsp(record, cred);
}

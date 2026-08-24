import {
  isGb28181Device,
  isNvrChannelDevice,
  parseGb28181VirtualDeviceId,
  shouldPlayViaGb28181,
} from './deviceLabel';

export type DeviceTalkProtocol = 'gb28181' | 'onvif' | null;

function hasOnvifCredentials(record: Record<string, any>): boolean {
  const ip = String(record.ip ?? '').trim();
  const port = Number(record.port);
  const password = String(record.password ?? '').trim();
  return !!ip && !!port && !!password;
}

function isExcludedTalkDevice(record: Record<string, any>): boolean {
  if (shouldPlayViaGb28181(record)) return true;
  if (isGb28181Device(record.source, record.device_kind)) return true;
  if (parseGb28181VirtualDeviceId(record.id)) return true;
  if (record.device_kind === 'nvr' || record.device_kind === 'gb28181_sip') return true;

  const id = String(record.id ?? '').trim();
  if (!id || id.startsWith('gb28181_') || id.startsWith('nvr_')) return true;
  return false;
}

/** ONVIF 直连设备（预置点等管理面能力） */
export function isOnvifDevice(
  record: Record<string, any> | null | undefined,
): boolean {
  if (!record || isExcludedTalkDevice(record)) return false;
  if (isNvrChannelDevice(record)) return false;

  if (!hasOnvifCredentials(record)) return false;

  const kind = record.device_kind;
  if (kind && kind !== 'direct') return false;

  return true;
}

/** 是否可走 ONVIF Audio Back Channel 对讲（含 NVR 挂载通道） */
export function supportsOnvifTalk(
  record: Record<string, any> | null | undefined,
): boolean {
  if (!record || isExcludedTalkDevice(record)) return false;

  const id = String(record.id ?? '').trim();
  if (!id) return false;

  // NVR 通道与直连 IPC：列表可能不回传 password，凭据由后端按 device_id 查库
  if (isNvrChannelDevice(record)) return true;

  const kind = record.device_kind;
  if (kind && kind !== 'direct') return false;

  return true;
}

/** 解析设备支持的语音对讲协议；两者均不满足则返回 null */
export function resolveDeviceTalkProtocol(
  record: Record<string, any> | null | undefined,
): DeviceTalkProtocol {
  if (!record) return null;
  if (
    shouldPlayViaGb28181(record)
    || isGb28181Device(record.source, record.device_kind)
    || parseGb28181VirtualDeviceId(record.id)
  ) {
    return 'gb28181';
  }
  if (supportsOnvifTalk(record)) return 'onvif';
  return null;
}

/** 是否展示云台/预置点控制（录像回放等场景隐藏） */
export function supportsMonitorControl(
  record: Record<string, any> | null | undefined,
  vodMode = false,
): boolean {
  if (vodMode) return false;
  if (!record) return false;
  if (shouldPlayViaGb28181(record)) return true;
  if (isOnvifDevice(record)) return true;
  if (isNvrChannelDevice(record)) return true;
  const id = String(record.id ?? '').trim();
  return !!id && !id.startsWith('gb28181_');
}

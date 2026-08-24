/** 国标虚拟源前缀 */
const GB28181_SOURCE_PREFIX = 'gb28181://';

export function isGb28181Device(source?: string | null, deviceKind?: string): boolean {
  if (source?.trim().toLowerCase().startsWith(GB28181_SOURCE_PREFIX)) return true;
  if (deviceKind === 'gb28181' || deviceKind === 'gb28181_sip') return true;
  if (deviceKind === 'direct') return false;
  return false;
}

/** 字段是否为无意义的占位展示值 */
function isEmptyOrPlaceholder(value?: string | null, placeholders: string[] = ['-']): boolean {
  const v = (value ?? '').trim();
  if (!v) return true;
  return placeholders.some((p) => v.toLowerCase() === p.toLowerCase());
}

/** 设备型号是否有可复制的有效值（国标无型号或占位符时不展示复制按钮） */
export function hasCopyableDeviceModel(model?: string | null): boolean {
  if (isEmptyOrPlaceholder(model)) return false;
  if ((model ?? '').trim() === 'GB28181-Channel') return false;
  return true;
}

/** 制造商是否有可复制的有效值（国标默认「GB28181」占位时不展示复制按钮） */
export function hasCopyableManufacturer(manufacturer?: string | null): boolean {
  if (isEmptyOrPlaceholder(manufacturer)) return false;
  if ((manufacturer ?? '').trim() === 'GB28181') return false;
  return true;
}

/** IP 地址是否有可复制的有效值 */
export function hasCopyableDeviceIp(ip?: string | null): boolean {
  return !isEmptyOrPlaceholder(ip);
}

/** 国标通道在 device 表中的虚拟设备 ID（与 VIDEO gb28181_sync 一致） */
export function gb28181VirtualDeviceId(sipDeviceId: string, channelId: string): string {
  return `gb28181_${sipDeviceId}_${channelId}`;
}

/** 从虚拟设备 ID `gb28181_{sip}_{channel}` 解析点播参数 */
export function parseGb28181VirtualDeviceId(
  id?: string | null,
): { sipDeviceId: string; channelId: string } | null {
  const raw = String(id ?? '').trim();
  if (!raw.startsWith('gb28181_')) return null;
  const rest = raw.slice('gb28181_'.length);
  const sep = rest.indexOf('_');
  if (sep <= 0) return null;
  const sipDeviceId = rest.slice(0, sep).trim();
  const channelId = rest.slice(sep + 1).trim();
  if (!sipDeviceId || !channelId) return null;
  return { sipDeviceId, channelId };
}

/** 解析 gb28181://{deviceId}/{channelId} */
export function parseGb28181Source(source?: string | null): { deviceId: string; channelId: string } | null {
  if (!source?.trim().toLowerCase().startsWith(GB28181_SOURCE_PREFIX)) {
    return null;
  }
  const rest = source.trim().slice(GB28181_SOURCE_PREFIX.length);
  const slash = rest.indexOf('/');
  if (slash <= 0) return null;
  const deviceId = rest.slice(0, slash).trim();
  const channelId = rest.slice(slash + 1).replace(/^\/+/, '').trim();
  if (!deviceId || !channelId) return null;
  return { deviceId, channelId };
}

/** 是否应走 WVP 国标点播（含 device 表虚拟通道与通道列表页） */
export function shouldPlayViaGb28181(record: Record<string, any> | null | undefined): boolean {
  if (!record) return false;
  const parsed = parseGb28181Source(record.source);
  if (parsed) return true;
  if (parseGb28181VirtualDeviceId(record.id)) return true;
  const sip = String(record.deviceIdentification || '').trim();
  const ch = String(record.channelId || '').trim();
  if (sip && ch && sip !== ch) return true;
  if (record.deviceId && record.channelId && record.deviceId !== record.channelId) return true;
  return false;
}

/** 解析国标点播用的 SIP 设备 ID 与通道 ID */
export function getGb28181PlayIds(
  record: Record<string, any> | null | undefined,
): { sipDeviceId: string; channelId: string } | null {
  if (!record) return null;
  const parsed = parseGb28181Source(record.source);
  if (parsed) {
    return { sipDeviceId: parsed.deviceId, channelId: parsed.channelId };
  }
  const fromId = parseGb28181VirtualDeviceId(record.id);
  if (fromId) return fromId;
  const sipDeviceId = String(record.deviceIdentification || record.deviceId || '').trim();
  const channelId = String(record.channelId || '').trim();
  if (!sipDeviceId || !channelId || sipDeviceId === channelId) return null;
  return { sipDeviceId, channelId };
}

/** 海康/大华经 NVR 取流的 RTSP 路径特征 */
export function isNvrRtspSource(source?: string | null): boolean {
  const s = (source || '').trim().toLowerCase();
  if (!s.startsWith('rtsp://')) return false;
  return s.includes('/streaming/channels/') || s.includes('cam/realmonitor');
}

export function isNvrChannelDevice(
  device: {
    nvr_id?: number | null;
    device_kind?: string;
    source?: string | null;
  },
  nvrs?: Array<{ id?: number; ip?: string }>,
): boolean {
  if (device.device_kind === 'nvr_channel') return true;
  if (device.nvr_id && device.nvr_id > 0) return true;
  if (!isNvrRtspSource(device.source)) return false;
  // 未提供 NVR 列表时不能仅凭 RTSP 路径推断（单机 IPC 与海康/大华 NVR 通道 URL 相同）
  if (!nvrs?.length) return false;
  const host = (device.source || '').trim().match(/^rtsp:\/\/(?:[^@/]+@)?([^/:]+)/i)?.[1];
  if (!host) return false;
  return nvrs.some((n) => (n.ip || '').trim() === host);
}

export function isNvrListRow(record: {
  device_kind?: string;
  id?: string;
  _isNvr?: boolean;
}): boolean {
  if (record._isNvr) return true;
  if (record.device_kind === 'nvr') return true;
  return String(record.id || '').startsWith('nvr_');
}

export function formatNvrDisplayName(nvr: {
  name?: string | null;
  device_name?: string | null;
  ip?: string;
  port?: number;
  id?: number;
}): string {
  const base = (nvr.name || nvr.device_name || nvr.ip || `NVR-${nvr.id}`).trim();
  if (base.startsWith('[NVR]')) return base;
  return `[NVR] ${base}`;
}

export function formatCameraDeviceLabel(device: {
  name?: string | null;
  id?: string;
  source?: string | null;
  device_kind?: 'direct' | 'gb28181' | 'gb28181_sip' | 'nvr' | 'nvr_channel' | string;
  nvr_id?: number | null;
  nvr_channel?: number;
  nvr_label?: string | null;
}): string {
  const name = (device.name || device.id || '').trim();
  if (device.device_kind === 'nvr' || isNvrListRow(device)) {
    return formatNvrDisplayName({ name, ip: (device as { ip?: string }).ip, id: undefined });
  }
  if (isGb28181Device(device.source, device.device_kind)) {
    if (name.startsWith('[GB28181]')) return name;
    return name ? `[GB28181] ${name}` : '[GB28181]';
  }
  if (isNvrChannelDevice(device)) {
    const ch = device.nvr_channel ? `CH${device.nvr_channel} ` : '';
    const base = name.replace(/^\[NVR\]\s*/i, '').trim();
    return `[NVR] ${ch}${base}`.trim();
  }
  if (name.startsWith('[直连]') || name.startsWith('[NVR]')) return name;
  return `[直连] ${name}`;
}

const MONITOR_PATH_SEP = ' / ';

/** 监控画面用短名：去掉目录路径、[NVR]/[直连]/[GB28181] 前缀与 CH 号 */
export function formatCameraShortName(
  input?:
    | string
    | {
        name?: string | null;
        id?: string;
        source?: string | null;
        device_kind?: string;
        nvr_id?: number | null;
        nvr_channel?: number;
      }
    | null,
): string {
  let name = '';
  if (typeof input === 'string') {
    name = input.trim();
    if (name.includes(MONITOR_PATH_SEP)) {
      const parts = name.split(MONITOR_PATH_SEP).map((p) => p.trim()).filter(Boolean);
      name = parts[parts.length - 1] || name;
    }
  } else if (input) {
    name = formatCameraDeviceLabel(input);
  }
  name = name
    .replace(/^\[(?:NVR|直连|GB28181)\]\s*/i, '')
    .replace(/^CH\d+\s*/i, '')
    .trim();
  if (name) return name;
  if (input && typeof input === 'object' && input.id) return String(input.id).trim();
  return '';
}

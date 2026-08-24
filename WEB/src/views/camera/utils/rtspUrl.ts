/** RTSP URL 拼装（用户名/密码做百分号编码，避免特殊字符破坏 URL） */

export function encodeRtspUserinfo(value: string): string {
  return encodeURIComponent(value ?? '');
}

export function buildRtspAuthPrefix(username: string, password: string): string {
  const user = encodeRtspUserinfo(username.trim());
  const pw = encodeRtspUserinfo(password);
  return `${user}:${pw}@`;
}

export type BrandCameraType = 'hikvision' | 'dahua' | 'uniview';

/** 按品牌拼装 IPC RTSP（与 VideoModal / 网段扫描规则一致） */
export function buildBrandRtspUrl(params: {
  cameraType: BrandCameraType;
  ip: string;
  port: number;
  username: string;
  password: string;
  stream?: number;
}): string | undefined {
  const ip = params.ip?.trim();
  if (!ip || !params.username?.trim()) return undefined;
  const auth = buildRtspAuthPrefix(params.username, params.password);
  const port = params.port || 554;
  const stream = params.stream ?? 0;

  if (params.cameraType === 'hikvision') {
    const streamType = stream === 0 ? 1 : stream === 1 ? 2 : 1;
    return `rtsp://${auth}${ip}:${port}/Streaming/Channels/10${streamType}`;
  }
  if (params.cameraType === 'dahua') {
    const streamType = stream === 0 ? 0 : stream === 1 ? 1 : 0;
    return `rtsp://${auth}${ip}:${port}/cam/realmonitor?channel=1&subtype=${streamType}`;
  }
  if (params.cameraType === 'uniview') {
    const streamType = stream === 0 ? 0 : stream === 1 ? 1 : 0;
    return `rtsp://${auth}${ip}:${port}/unicast/c1/s${streamType}/live`;
  }
  return undefined;
}

/** 从 registerDevice 等已 transform 的响应中取出设备 ID */
export function resolveRegisteredDeviceId(response: unknown): string | undefined {
  if (response == null || typeof response !== 'object') return undefined;
  const r = response as Record<string, unknown>;
  if (typeof r.id === 'string' && r.id) return r.id;
  const nested = r.data;
  if (nested != null && typeof nested === 'object') {
    const id = (nested as Record<string, unknown>).id;
    if (typeof id === 'string' && id) return id;
  }
  return undefined;
}

import type { NvrRegisterChannelsResult } from '@/api/device/camera';

/** 从登记/同步 NVR 通道接口响应中提取用户可读提示（含枚举失败原因）。 */
export function formatNvrRegisterHint(
  res: NvrRegisterChannelsResult | { msg?: string },
  fallback = '未枚举到可登记通道',
): string {
  const raw = String((res as { msg?: string }).msg || '').trim();
  if (!raw) return fallback;
  const idx = raw.indexOf('（');
  if (idx > 0) return raw.slice(idx + 1).replace(/）$/, '') || raw;
  if (raw.includes('枚举失败') || raw.includes('锁定') || raw.includes('401')) return raw;
  return raw;
}

export function nvrRegisterRegisteredCount(res: NvrRegisterChannelsResult): number {
  return res.stats?.registered ?? res.camera_count ?? 0;
}

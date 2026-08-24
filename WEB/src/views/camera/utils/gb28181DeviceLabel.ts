/** 国标设备展示名（带 [GB28181] 前缀，避免重复） */
export function formatGb28181DeviceDisplayName(name?: string | null): string {
  const n = (name || '').trim();
  if (!n) return '[GB28181]';
  if (n.startsWith('[GB28181]')) return n;
  return `[GB28181] ${n}`;
}

/** 提交 WVP 前去掉展示前缀 */
export function stripGb28181DeviceDisplayPrefix(name?: string | null): string {
  const n = (name || '').trim();
  if (!n) return '';
  return n.replace(/^\[GB28181\]\s*/, '').trim();
}

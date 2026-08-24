export type SnapImageSource = 'snap' | 'frame' | 'algorithm' | string;

export const SNAP_IMAGE_SOURCE_OPTIONS = [
  { label: '全部来源', value: '' },
  { label: '抓拍任务', value: 'snap' },
  { label: '自动抽帧', value: 'frame' },
  { label: '算法告警', value: 'algorithm' },
] as const;

const SOURCE_LABEL_MAP: Record<string, string> = {
  snap: '抓拍任务',
  frame: '自动抽帧',
  algorithm: '算法告警',
};

const SOURCE_COLOR_MAP: Record<string, string> = {
  snap: 'blue',
  frame: 'cyan',
  algorithm: 'orange',
};

export function formatSnapImageSource(source?: string | null): string {
  if (!source) return '未知';
  return SOURCE_LABEL_MAP[source] ?? source;
}

export function snapImageSourceColor(source?: string | null): string {
  if (!source) return 'default';
  return SOURCE_COLOR_MAP[source] ?? 'default';
}

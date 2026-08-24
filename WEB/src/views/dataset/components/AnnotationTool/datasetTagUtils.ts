import {createDatasetTag, getDatasetImagePage, getDatasetTagPage} from '@/api/device/dataset';

/** 标签预设色板 */
export const TAG_COLOR_PALETTE = [
  '#FF5252',
  '#4CAF50',
  '#FFC107',
  '#2196F3',
  '#9C27B0',
  '#FF9800',
  '#00BCD4',
  '#E91E63',
  '#795548',
  '#607D8B',
];

export interface DatasetTagItem {
  id: number;
  name: string;
  color: string;
  shortcut: string;
  description?: string;
  datasetId?: number;
}

/** 解析 #RGB / #RRGGBB */
export function parseHexColor(color: string): { r: number; g: number; b: number } | null {
  const hex = color.trim();
  const m3 = /^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$/.exec(hex);
  if (m3) {
    return {
      r: parseInt(m3[1] + m3[1], 16),
      g: parseInt(m3[2] + m3[2], 16),
      b: parseInt(m3[3] + m3[3], 16),
    };
  }
  const m6 = /^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/.exec(hex);
  if (m6) {
    return {r: parseInt(m6[1], 16), g: parseInt(m6[2], 16), b: parseInt(m6[3], 16)};
  }
  return null;
}

/** 将标签色转为带透明度的 rgba，用于标注框填充 */
export function colorWithAlpha(color: string, alpha: number): string {
  const rgb = parseHexColor(color);
  if (!rgb) return `rgba(67, 97, 238, ${alpha})`;
  return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`;
}

export function mapTagRow(tag: Record<string, unknown>): DatasetTagItem {
  return {
    id: Number(tag.id),
    name: String(tag.name ?? ''),
    color: String(tag.color || TAG_COLOR_PALETTE[0]),
    shortcut: String(tag.shortcut ?? ''),
    description: tag.description as string | undefined,
    datasetId: tag.datasetId != null ? Number(tag.datasetId) : undefined,
  };
}

export async function fetchDatasetTags(datasetId: string | number): Promise<DatasetTagItem[]> {
  const res = await getDatasetTagPage({
    datasetId,
    pageNo: 1,
    pageSize: 100,
  });
  const list = res?.list ?? [];
  return list.map((t: Record<string, unknown>) => mapTagRow(t));
}

function parseAnnotationLabels(raw: unknown): string[] {
  if (!raw) return [];
  let arr: unknown[] = [];
  try {
    arr = typeof raw === 'string' ? JSON.parse(raw) : Array.isArray(raw) ? raw : [];
  } catch {
    return [];
  }
  const keys: string[] = [];
  for (const item of arr) {
    if (item && typeof item === 'object' && 'label' in item) {
      const v = String((item as { label: unknown }).label ?? '').trim();
      if (v) keys.push(v);
    }
  }
  return keys;
}

/** 从已导入图片的标注中提取类别名（去重） */
export async function collectLabelKeysFromImages(
  datasetId: string | number,
  maxPages = 5,
  pageSize = 500,
): Promise<string[]> {
  const found = new Set<string>();
  for (let page = 1; page <= maxPages; page++) {
    const res = await getDatasetImagePage({datasetId, pageNo: page, pageSize});
    const list = res?.list ?? [];
    if (!list.length) break;
    for (const img of list) {
      for (const key of parseAnnotationLabels(img.annotations)) {
        found.add(key);
      }
    }
    if (list.length < pageSize) break;
  }
  return Array.from(found);
}

function nextFreeShortcut(used: Set<number>): number | null {
  for (let i = 1; i <= 9; i++) {
    if (!used.has(i)) return i;
  }
  return null;
}

function resolveTagName(labelKey: string, existingByShortcut: Map<string, DatasetTagItem>): string {
  const byShortcut = existingByShortcut.get(labelKey);
  if (byShortcut) return byShortcut.name;
  if (/^\d+$/.test(labelKey)) return `类别${labelKey}`;
  return labelKey;
}

function isLabelAlreadyCovered(
  labelKey: string,
  existingNames: Set<string>,
  existingByShortcut: Map<string, DatasetTagItem>,
): boolean {
  if (existingNames.has(labelKey)) return true;
  if (existingByShortcut.has(labelKey)) return true;
  const byName = [...existingNames].some((n) => n === labelKey);
  return byName;
}

/**
 * 根据导入结果中的类别名或图片标注，自动创建数据集标签
 */
export async function syncTagsFromImport(
  datasetId: string | number,
  options?: {classNames?: string[]},
): Promise<number> {
  const existing = await fetchDatasetTags(datasetId);
  const existingNames = new Set(existing.map((t) => t.name));
  const existingByShortcut = new Map(existing.map((t) => [t.shortcut, t]));
  const usedShortcuts = new Set(existing.map((t) => Number(t.shortcut)));

  let candidates: string[] = [];
  if (options?.classNames?.length) {
    candidates = options.classNames.map((c) => String(c).trim()).filter(Boolean);
  } else {
    candidates = await collectLabelKeysFromImages(datasetId);
  }

  const toCreate: string[] = [];
  for (const key of candidates) {
    if (!isLabelAlreadyCovered(key, existingNames, existingByShortcut)) {
      toCreate.push(key);
    }
  }

  if (!toCreate.length) return 0;

  let created = 0;
  let colorIdx = existing.length;
  for (const labelKey of toCreate) {
    const shortcut = nextFreeShortcut(usedShortcuts);
    if (shortcut == null) break;
    const name = resolveTagName(labelKey, existingByShortcut);
    if (existingNames.has(name)) continue;

    await createDatasetTag({
      datasetId: Number(datasetId),
      name,
      shortcut,
      color: TAG_COLOR_PALETTE[colorIdx % TAG_COLOR_PALETTE.length],
      description: '',
    });
    existingNames.add(name);
    usedShortcuts.add(shortcut);
    colorIdx++;
    created++;
  }
  return created;
}

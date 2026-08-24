/** 人脸/车牌库匹配范围：与后端 library_matching_service 标签交集逻辑一致 */

export interface LibraryWithTags {
  id: number;
  name: string;
  code?: string;
  business_tags?: string[] | string | null;
  is_enabled?: boolean;
}

export type LibraryMatchingMode = 'single' | 'tags';

export function normalizeBusinessTags(tags: unknown): string[] {
  if (!tags) return [];
  if (Array.isArray(tags)) {
    return tags.map((t) => String(t).trim()).filter(Boolean);
  }
  if (typeof tags === 'string') {
    const text = tags.trim();
    if (!text) return [];
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return parsed.map((t) => String(t).trim()).filter(Boolean);
      }
    } catch {
      // fall through
    }
    return text.split(',').map((t) => t.trim()).filter(Boolean);
  }
  return [];
}

export function tagsOverlap(libTags: string[], filterTags: string[]): boolean {
  if (!filterTags.length) return true;
  if (!libTags.length) return false;
  const libSet = new Set(libTags.map((t) => t.toLowerCase()));
  return filterTags.some((t) => libSet.has(t.toLowerCase()));
}

export function filterLibrariesByTags<T extends LibraryWithTags>(
  libraries: T[],
  filterTags: string[],
): T[] {
  if (!filterTags.length) return [];
  return libraries.filter((lib) => {
    if (lib.is_enabled === false) return false;
    return tagsOverlap(normalizeBusinessTags(lib.business_tags), filterTags);
  });
}

export function collectLibraryTagSuggestions(libraries: LibraryWithTags[]): string[] {
  const set = new Set<string>();
  for (const lib of libraries) {
    for (const tag of normalizeBusinessTags(lib.business_tags)) {
      set.add(tag);
    }
  }
  return Array.from(set).sort((a, b) => a.localeCompare(b));
}

export function formatLibraryOptionLabel(lib: LibraryWithTags): string {
  const tags = normalizeBusinessTags(lib.business_tags);
  const base = lib.code ? `${lib.name} (${lib.code})` : lib.name;
  return tags.length ? `${base} · ${tags.join(', ')}` : base;
}

export function inferMatchingMode(tags: unknown): LibraryMatchingMode {
  return normalizeBusinessTags(tags).length > 0 ? 'tags' : 'single';
}

export function hasMatchingScope(libraryId: unknown, tags: unknown): boolean {
  if (libraryId) return true;
  return normalizeBusinessTags(tags).length > 0;
}

export interface MatchingPreviewItem {
  kind: 'face' | 'plate';
  kindLabel: string;
  mode: LibraryMatchingMode;
  libraries: LibraryWithTags[];
  emptyHint?: string;
}

export function buildMatchingPreviewItems(options: {
  faceMatchingEnabled: boolean;
  plateMatchingEnabled: boolean;
  mode: LibraryMatchingMode;
  filterTags: string[];
  faceLibraries: LibraryWithTags[];
  plateLibraries: LibraryWithTags[];
  faceLibraryId?: number | null;
  plateLibraryId?: number | null;
}): MatchingPreviewItem[] {
  const items: MatchingPreviewItem[] = [];
  const {
    faceMatchingEnabled,
    plateMatchingEnabled,
    mode,
    filterTags,
    faceLibraries,
    plateLibraries,
    faceLibraryId,
    plateLibraryId,
  } = options;

  const resolveLibraries = (
    all: LibraryWithTags[],
    primaryId?: number | null,
  ): LibraryWithTags[] => {
    if (mode === 'tags') {
      return filterLibrariesByTags(all, filterTags);
    }
    if (!primaryId) return [];
    const lib = all.find((item) => item.id === primaryId);
    return lib && lib.is_enabled !== false ? [lib] : [];
  };

  if (faceMatchingEnabled) {
    const libraries = resolveLibraries(faceLibraries, faceLibraryId);
    items.push({
      kind: 'face',
      kindLabel: '人脸',
      mode,
      libraries,
      emptyHint:
        mode === 'tags'
          ? filterTags.length
            ? '暂无启用的人脸库与所选标签相交，请检查标签或人脸库配置'
            : '请先填写匹配业务标签'
          : '请选择关联人脸库',
    });
  }

  if (plateMatchingEnabled) {
    const libraries = resolveLibraries(plateLibraries, plateLibraryId);
    items.push({
      kind: 'plate',
      kindLabel: '车牌',
      mode,
      libraries,
      emptyHint:
        mode === 'tags'
          ? filterTags.length
            ? '暂无启用的车牌库与所选标签相交，请检查标签或车牌库配置'
            : '请先填写匹配业务标签'
          : '请选择关联车牌库',
    });
  }

  return items;
}

function addTagsFromLibraryIds(
  libraries: LibraryWithTags[],
  libraryIds: number[] | undefined | null,
  tagSet: Set<string>,
) {
  if (!libraryIds?.length) return;
  for (const id of libraryIds) {
    const lib = libraries.find((item) => item.id === id);
    normalizeBusinessTags(lib?.business_tags).forEach((tag) => tagSet.add(tag));
  }
}

/** 从已选人脸/车牌/场景姿态库合并业务标签 */
export function collectMatchingTagsFromLibraries(
  faceLibraries: LibraryWithTags[],
  plateLibraries: LibraryWithTags[],
  faceLibraryIds?: number[] | null,
  plateLibraryIds?: number[] | null,
  poseLibraries?: LibraryWithTags[],
  poseLibraryIds?: number[] | null,
): string[] {
  const tagSet = new Set<string>();
  addTagsFromLibraryIds(faceLibraries, faceLibraryIds ?? undefined, tagSet);
  addTagsFromLibraryIds(plateLibraries, plateLibraryIds ?? undefined, tagSet);
  addTagsFromLibraryIds(poseLibraries ?? [], poseLibraryIds ?? undefined, tagSet);
  return Array.from(tagSet);
}

export function summarizeMatchingForList(record: {
  face_matching_enabled?: boolean;
  plate_matching_enabled?: boolean;
  matching_business_tags?: string[] | null;
  face_library_names?: string[];
  plate_library_names?: string[];
}): { mode: LibraryMatchingMode; text: string } | null {
  if (!record.face_matching_enabled && !record.plate_matching_enabled) {
    return null;
  }
  const tags = normalizeBusinessTags(record.matching_business_tags);
  const parts: string[] = [];
  if (record.face_matching_enabled && record.face_library_names?.length) {
    parts.push(`人脸:${record.face_library_names.join('、')}`);
  }
  if (record.plate_matching_enabled && record.plate_library_names?.length) {
    parts.push(`车牌:${record.plate_library_names.join('、')}`);
  }
  if (!parts.length) {
    return { mode: 'single', text: '已启用（未指定库）' };
  }
  const base = parts.join(' · ');
  return {
    mode: 'single',
    text: tags.length ? `${base} · ${tags.join(', ')}` : base,
  };
}

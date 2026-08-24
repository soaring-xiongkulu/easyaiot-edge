const DEFAULT_MODEL_VERSION = '1.0.0';
const SEMVER_PATTERN = /^(\d+)\.(\d+)\.(\d+)/;

/** 去掉前导 v/V，用于表单输入与 API 提交 */
export function normalizeModelVersion(version?: string | null): string {
  const raw = String(version ?? '').trim();
  if (!raw) return DEFAULT_MODEL_VERSION;
  const normalized = raw.replace(/^[vV]/, '').trim();
  return normalized || DEFAULT_MODEL_VERSION;
}

/** 补丁版本递增：1.0.0 → 1.0.1 */
export function incrementPatchVersion(version?: string | null): string {
  const normalized = normalizeModelVersion(version);
  const match = normalized.match(SEMVER_PATTERN);
  if (!match) return DEFAULT_MODEL_VERSION;
  const major = Number(match[1]);
  const minor = Number(match[2]);
  const patch = Number(match[3]);
  return `${major}.${minor}.${patch + 1}`;
}

/** 从多个版本字符串中取语义化最高版本 */
export function maxSemverVersion(versions: Array<string | null | undefined>): string | null {
  const parsed = versions
    .map((item) => normalizeModelVersion(item))
    .map((item) => {
      const match = item.match(SEMVER_PATTERN);
      if (!match) return null;
      return {
        version: item,
        tuple: [Number(match[1]), Number(match[2]), Number(match[3])] as [number, number, number],
      };
    })
    .filter(Boolean) as Array<{ version: string; tuple: [number, number, number] }>;

  if (!parsed.length) return null;
  parsed.sort((a, b) => {
    for (let i = 0; i < 3; i += 1) {
      if (a.tuple[i] !== b.tuple[i]) return a.tuple[i] - b.tuple[i];
    }
    return 0;
  });
  return parsed[parsed.length - 1].version;
}

/** 展示用：仅在没有 v/V 前缀时补一个 v */
export function formatModelVersionDisplay(version?: string | null): string {
  const raw = String(version ?? '').trim();
  if (!raw) return '';
  return /^[vV]/.test(raw) ? raw : `v${raw}`;
}

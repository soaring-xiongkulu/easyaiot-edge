import type { CredentialPair } from '@/api/device/camera';

export type SegmentScanHistoryMode = 'camera' | 'nvr';

export interface SegmentScanHistoryEntry {
  id: string;
  mode: SegmentScanHistoryMode;
  targets: string;
  ports: string;
  credentials: CredentialPair[];
  concurrency: number;
  timeout: number;
  only_hits: boolean;
  savedAt: number;
  /** 最近一次使用该参数扫描到的设备数 */
  lastDeviceCount?: number;
}

const STORAGE_KEY = 'easyaiot_segment_scan_history_v1';
const MAX_PER_MODE = 15;

function loadAll(): SegmentScanHistoryEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const list = JSON.parse(raw);
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function persist(list: SegmentScanHistoryEntry[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

function normalizeTargets(targets: string): string {
  return targets
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter(Boolean)
    .join('\n');
}

function entryFingerprint(entry: Pick<SegmentScanHistoryEntry, 'mode' | 'targets' | 'ports' | 'credentials'>): string {
  const creds = entry.credentials
    .map((c) => `${(c.username || '').trim()}:${c.password || ''}`)
    .sort()
    .join('|');
  return [entry.mode, normalizeTargets(entry.targets), (entry.ports || '').trim(), creds].join('\0');
}

export function loadSegmentScanHistory(mode: SegmentScanHistoryMode): SegmentScanHistoryEntry[] {
  return loadAll()
    .filter((e) => e.mode === mode)
    .sort((a, b) => b.savedAt - a.savedAt);
}

export function saveSegmentScanHistory(
  entry: Omit<SegmentScanHistoryEntry, 'id' | 'savedAt'> & { id?: string; savedAt?: number },
): SegmentScanHistoryEntry[] {
  const saved: SegmentScanHistoryEntry = {
    ...entry,
    targets: normalizeTargets(entry.targets),
    ports: (entry.ports || '80,443,8000,8443').trim(),
    credentials: entry.credentials.map((c) => ({
      username: (c.username || '').trim(),
      password: c.password || '',
    })),
    id: entry.id || `ss_${Date.now()}`,
    savedAt: entry.savedAt ?? Date.now(),
  };
  const fp = entryFingerprint(saved);
  const otherModes = loadAll().filter((e) => e.mode !== saved.mode);
  const sameMode = loadAll().filter((e) => e.mode === saved.mode && entryFingerprint(e) !== fp);
  const newSameMode = [saved, ...sameMode].slice(0, MAX_PER_MODE);
  persist([...otherModes, ...newSameMode]);
  return loadSegmentScanHistory(saved.mode);
}

export function removeSegmentScanHistory(id: string): void {
  persist(loadAll().filter((e) => e.id !== id));
}

export function formatSegmentScanHistoryTime(savedAt: number): string {
  const t = new Date(savedAt);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${t.getFullYear()}-${pad(t.getMonth() + 1)}-${pad(t.getDate())} ${pad(t.getHours())}:${pad(t.getMinutes())}`;
}

export function formatSegmentScanHistoryPrimary(entry: SegmentScanHistoryEntry): string {
  const lines = entry.targets.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  const first = lines[0] || '未填写目标';
  const more = lines.length > 1 ? ` 等 ${lines.length} 项` : '';
  return `${first}${more}`;
}

export function formatSegmentScanHistoryMeta(entry: SegmentScanHistoryEntry): string {
  const parts: string[] = [formatSegmentScanHistoryTime(entry.savedAt)];
  if (entry.lastDeviceCount != null) {
    parts.push(`发现 ${entry.lastDeviceCount} 台`);
  }
  parts.push(`端口 ${entry.ports || '80,443,8000,8443'}`);
  return parts.join(' · ');
}

export function formatSegmentScanHistoryLabel(entry: SegmentScanHistoryEntry): string {
  const kind = entry.mode === 'nvr' ? 'NVR' : 'IPC';
  const count =
    entry.lastDeviceCount != null ? ` · 上次${entry.lastDeviceCount}台` : '';
  const t = new Date(entry.savedAt);
  const time = `${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')} ${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}`;
  return `${kind} ${formatSegmentScanHistoryPrimary(entry)}${count} · ${time}`;
}

export function cloneCredentials(list: CredentialPair[]): CredentialPair[] {
  return list.map((c) => ({ username: c.username || '', password: c.password || '' }));
}

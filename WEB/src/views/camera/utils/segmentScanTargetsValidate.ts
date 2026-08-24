/** 与 VIDEO hiktools parse_targets / estimate_scan_tasks 对齐（IPv4） */

import type { SegmentScanParams } from '@/api/device/camera';

const IPV4_RE =
  /^(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$/;

export const MAX_SEGMENT_SCAN_TASKS = 4096;

const DEFAULT_PORTS = [80, 443, 8000, 8443];

export interface SegmentScanTargetsValidateResult {
  valid: boolean;
  message?: string;
  tokenCount?: number;
  estimatedTasks?: number;
}

function parsePortsSpec(spec?: string | null): number[] {
  const text = (spec || '').trim();
  if (!text) return [...DEFAULT_PORTS];
  const out: number[] = [];
  for (const part of text.replace(/;/g, ',').split(',')) {
    const p = part.trim();
    if (!p) continue;
    const n = Number(p);
    if (!Number.isInteger(n) || n < 1 || n > 65535) {
      throw new Error(`Web 端口无效：${p}`);
    }
    if (!out.includes(n)) out.push(n);
  }
  return out.length ? out : [...DEFAULT_PORTS];
}

function requireDottedIpv4(token: string, ctx = 'IP') {
  if (token.split('.').length !== 4) {
    throw new Error(
      `请使用完整 IPv4 ${ctx}（四段点分），例如 192.168.1.1；不能仅写「${token}」`,
    );
  }
}

function cidrHostCount(prefix: number): number {
  if (prefix >= 31) return Math.max(1, 2 ** (32 - prefix) - 2);
  return 2 ** (32 - prefix) - 2;
}

function countHostsInToken(token: string): { hosts: number; inlinePort: number | null } {
  let inlinePort: number | null = null;
  let host = token;
  if (
    host.includes(':') &&
    !host.includes('/') &&
    !host.split(':')[0].includes('-')
  ) {
    const idx = host.lastIndexOf(':');
    inlinePort = Number(host.slice(idx + 1));
    host = host.slice(0, idx);
    if (!Number.isInteger(inlinePort) || inlinePort < 1 || inlinePort > 65535) {
      throw new Error(`端口无效：${host.slice(idx + 1)}`);
    }
  }

  if (host.includes('/')) {
    const [netIp, prefixStr] = host.split('/', 2);
    requireDottedIpv4(netIp, '网段');
    const prefix = Number(prefixStr);
    if (!Number.isInteger(prefix) || prefix < 0 || prefix > 32) {
      throw new Error(`子网掩码长度无效：${prefixStr}（应为 0–32）`);
    }
    return { hosts: cidrHostCount(prefix), inlinePort };
  }

  if (host.includes('-')) {
    const [loS, hiS] = host.split('-', 2);
    if (!loS?.trim() || !hiS?.trim()) {
      throw new Error(`IP 范围格式无效：${token}`);
    }
    let lo = loS.trim();
    let hi = hiS.trim();
    if (!hi.includes('.')) {
      const base = lo.split('.');
      if (base.length !== 4) throw new Error(`IP 范围格式无效：${token}`);
      base[3] = hi;
      hi = base.join('.');
    }
    requireDottedIpv4(lo, '起始 IP');
    requireDottedIpv4(hi, '结束 IP');
    const loParts = lo.split('.').map(Number);
    const hiParts = hi.split('.').map(Number);
    const loNum =
      ((loParts[0] << 24) | (loParts[1] << 16) | (loParts[2] << 8) | loParts[3]) >>> 0;
    const hiNum =
      ((hiParts[0] << 24) | (hiParts[1] << 16) | (hiParts[2] << 8) | hiParts[3]) >>> 0;
    if (hiNum < loNum) throw new Error(`IP 范围起止颠倒：${token}`);
    return { hosts: hiNum - loNum + 1, inlinePort };
  }

  requireDottedIpv4(host);
  if (!IPV4_RE.test(host)) {
    throw new Error(`${host} 不是合法的 IPv4 地址`);
  }
  return { hosts: 1, inlinePort };
}

/** 估算 (ip,port) 探测点数量 */
export function estimateSegmentScanTasks(
  raw: string,
  portsSpec?: string | null,
): number {
  const ports = parsePortsSpec(portsSpec);
  let total = 0;
  for (const line of raw.split(/\r?\n/)) {
    const lineBody = line.split('#')[0]?.trim() ?? '';
    if (!lineBody) continue;
    for (const part of lineBody.replace(/;/g, ',').split(',')) {
      const token = part.trim();
      if (!token) continue;
      const { hosts, inlinePort } = countHostsInToken(token);
      const portCount = inlinePort != null ? 1 : ports.length;
      total += hosts * portCount;
    }
  }
  return total;
}

function validateToken(rawToken: string) {
  countHostsInToken(rawToken.trim());
}

/** 解析并校验扫描目标文本 */
export function validateSegmentScanTargets(
  raw: string | undefined | null,
  portsSpec?: string | null,
): SegmentScanTargetsValidateResult {
  const text = String(raw ?? '').trim();
  if (!text) {
    return { valid: false, message: '请填写目标网段或 IP' };
  }

  let tokenCount = 0;
  try {
    for (const line of text.split(/\r?\n/)) {
      const lineBody = line.split('#')[0]?.trim() ?? '';
      if (!lineBody) continue;
      for (const part of lineBody.replace(/;/g, ',').split(',')) {
        const token = part.trim();
        if (!token) continue;
        validateToken(token);
        tokenCount += 1;
      }
    }
    const estimatedTasks = estimateSegmentScanTasks(text, portsSpec);
    if (estimatedTasks > MAX_SEGMENT_SCAN_TASKS) {
      return {
        valid: false,
        message: `扫描目标过多（约 ${estimatedTasks} 个探测点），请缩小网段（单次上限 ${MAX_SEGMENT_SCAN_TASKS}）`,
        estimatedTasks,
      };
    }
    if (tokenCount === 0) {
      return { valid: false, message: '未解析到有效的扫描目标，请检查格式' };
    }
    return { valid: true, tokenCount, estimatedTasks };
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return { valid: false, message: msg };
  }
}

/** 按探测规模计算 HTTP 请求超时（毫秒） */
export function computeSegmentScanWallSeconds(data: SegmentScanParams): number {
  let tasks = 4;
  try {
    tasks = Math.max(1, estimateSegmentScanTasks(data.targets, data.ports));
  } catch {
    tasks = 4;
  }
  const probeSec = Math.min(30, Math.max(0.5, Number(data.timeout) || 3));
  const concurrency = Math.min(2000, Math.max(1, Number(data.concurrency) || 200));
  const batches = Math.ceil(tasks / concurrency);
  const perTaskSec = Math.min(20, Math.max(6, probeSec * 4));
  const wallSec = batches * perTaskSec + 8;
  if (tasks <= 32) return Math.min(60, Math.max(15, wallSec));
  if (tasks <= 512) return Math.min(180, Math.max(30, wallSec));
  return Math.min(300, Math.max(60, wallSec));
}

export function computeSegmentScanHttpTimeoutMs(data: SegmentScanParams): number {
  return computeSegmentScanWallSeconds(data) * 1000;
}

export function segmentScanTargetsFormRule(getPorts?: () => string | undefined) {
  return {
    validator: async (_rule: unknown, value: string) => {
      const res = validateSegmentScanTargets(value, getPorts?.());
      if (!res.valid) {
        return Promise.reject(res.message || '扫描目标格式无效');
      }
      return Promise.resolve();
    },
    trigger: ['blur', 'change'],
  };
}

import { getPlatformHost } from '@/api/device/node';

let cachedPlatformLanIp: string | undefined;
let pendingFetch: Promise<string | null> | null = null;

export function isLoopbackHost(host?: string): boolean {
  const h = host?.trim().toLowerCase();
  return !h || h === 'localhost' || h === '127.0.0.1';
}

/** 从平台 Gateway 探测宿主机 IPv4，结果会缓存供同步解析使用 */
export async function fetchPlatformLanIp(): Promise<string | null> {
  if (cachedPlatformLanIp) return cachedPlatformLanIp;
  if (pendingFetch) return pendingFetch;

  pendingFetch = (async () => {
    try {
      const res = await getPlatformHost();
      const ip = res?.host?.trim();
      if (ip && !isLoopbackHost(ip)) {
        cachedPlatformLanIp = ip;
        return ip;
      }
    } catch {
      /* ignore */
    }
    return null;
  })();

  try {
    return await pendingFetch;
  } finally {
    pendingFetch = null;
  }
}

export function getCachedPlatformLanIp(): string | undefined {
  return cachedPlatformLanIp;
}

export function needsPlatformLanIp(envBase?: string, windowBase?: string): boolean {
  if (!envBase) {
    if (!windowBase) return true;
    try {
      return isLoopbackHost(new URL(windowBase).hostname);
    } catch {
      return true;
    }
  }
  try {
    const env = new URL(envBase);
    if (!isLoopbackHost(env.hostname)) return false;
    if (!windowBase) return true;
    return isLoopbackHost(new URL(windowBase).hostname);
  } catch {
    return false;
  }
}

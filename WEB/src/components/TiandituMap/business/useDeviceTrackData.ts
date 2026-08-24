import { ref } from 'vue';
import {
  getDeviceTrackPoints,
  getDeviceTrackSessions,
  type DeviceTrackPointInfo,
  type DeviceTrackSessionInfo,
} from '@/api/device/camera';
import type { MapTrackSession } from '../types';

export function useDeviceTrackData() {
  const loading = ref(false);
  const sessions = ref<DeviceTrackSessionInfo[]>([]);
  const error = ref<string | null>(null);

  async function loadSessions(params?: {
    device_id?: string;
    begin_datetime?: string;
    end_datetime?: string;
    limit?: number;
  }) {
    loading.value = true;
    error.value = null;
    try {
      const res = await getDeviceTrackSessions(params) as
        | DeviceTrackSessionInfo[]
        | { data?: DeviceTrackSessionInfo[] };
      sessions.value = Array.isArray(res) ? res : (res?.data || []);
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载轨迹段失败';
      sessions.value = [];
    } finally {
      loading.value = false;
    }
  }

  async function loadSessionPoints(sessionId: number | string): Promise<DeviceTrackPointInfo[]> {
    try {
      const res = await getDeviceTrackPoints({ session_id: sessionId });
      const list = Array.isArray(res) ? res : (res as { data?: DeviceTrackPointInfo[] })?.data || [];
      return list;
    } catch (e) {
      console.warn(`[TiandituMap] 轨迹点位加载失败 session=${sessionId}：`, e);
      return [];
    }
  }

  async function toMapTrackSessions(sessionIds?: Array<number | string>): Promise<MapTrackSession[]> {
    const ids = sessionIds?.length
      ? sessionIds
      : sessions.value.map((s) => s.id);

    // 各段点位并发加载，避免逐段串行等待
    const loaded = await Promise.all(
      ids.map(async (id) => ({ id, points: await loadSessionPoints(id) })),
    );

    const result: MapTrackSession[] = [];
    for (const { id, points } of loaded) {
      // 过滤经纬度非法(NaN)的脏点，否则 toMercator 会产出 NaN 几何导致线段渲染异常
      const validPoints = points
        .map((p) => ({
          lng: Number(p.longitude),
          lat: Number(p.latitude),
          recordedAt: p.recorded_at,
          altitude: p.altitude ?? undefined,
          speed: p.speed ?? undefined,
          direction: p.direction ?? undefined,
        }))
        .filter((p) => Number.isFinite(p.lng) && Number.isFinite(p.lat));
      if (!validPoints.length) continue;

      const meta = sessions.value.find((s) => String(s.id) === String(id));
      result.push({
        id: String(id),
        deviceId: meta?.device_id || points[0]?.device_id || '',
        title: meta?.title || `轨迹 #${id}`,
        color: '#52c41a',
        points: validPoints,
      });
    }
    return result;
  }

  return {
    loading,
    sessions,
    error,
    loadSessions,
    loadSessionPoints,
    toMapTrackSessions,
  };
}

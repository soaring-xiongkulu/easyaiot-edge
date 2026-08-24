import type { Router } from 'vue-router';
import dayjs from 'dayjs';
import { getRecordSpaceByDeviceId, resolveAlertRecordSegment } from '@/api/device/record';

export interface AlertRecordNavigateInput {
  id?: number | string;
  device_id: string;
  time?: string;
  record_path?: string;
}

/**
 * 从告警跳转到录像回放内页，并定位到对应片段。
 * @returns 是否成功发起跳转
 */
export async function navigateToAlertRecord(
  router: Router,
  alert: AlertRecordNavigateInput,
): Promise<boolean> {
  if (!alert.device_id) return false;

  let spaceId: number | null = null;
  let date = alert.time ? dayjs(alert.time).format('YYYY-MM-DD') : dayjs().format('YYYY-MM-DD');
  let segmentId: number | string | undefined;

  if (alert.id) {
    try {
      const res = await resolveAlertRecordSegment(alert.device_id, alert.id);
      const data = (res as { data?: Record<string, unknown> })?.data ?? res;
      if (data && typeof data === 'object') {
        spaceId = Number((data as { space_id?: number }).space_id) || null;
        date = String((data as { date?: string }).date || date);
        const segment = (data as { segment?: { id?: number } }).segment;
        if (segment?.id) segmentId = segment.id;
      }
    } catch {
      // 回退到按设备查空间
    }
  }

  if (!spaceId) {
    try {
      const res = await getRecordSpaceByDeviceId(alert.device_id);
      const data = (res as { data?: { id?: number } })?.data ?? res;
      spaceId = Number((data as { id?: number })?.id) || null;
    } catch {
      return false;
    }
  }

  if (!spaceId) return false;

  const query: Record<string, string> = { view: 'replay', date };
  if (alert.id) query.alertId = String(alert.id);
  if (segmentId) query.segmentId = String(segmentId);

  await router.push({
    path: `/record-space-manage/${spaceId}`,
    query,
  });
  return true;
}

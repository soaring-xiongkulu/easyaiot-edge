import { computed, ref } from 'vue';
import { queryAlarmList } from '@/api/device/calculate';
import type { AlertMapItem, MapMarkerData } from '../types';
import { useDeviceMapData } from './useDeviceMapData';

export interface AlertMapQuery {
  pageNo?: number;
  pageSize?: number;
  device_id?: string;
  begin_datetime?: string;
  end_datetime?: string;
  event?: string;
  task_name?: string;
  object?: string;
  business_tags?: string;
}

/** 告警地图：通过 device_id 关联摄像头 WGS84 坐标 */
export function useAlertMapData() {
  const loading = ref(false);
  const alerts = ref<AlertMapItem[]>([]);
  const total = ref(0);
  const error = ref<string | null>(null);
  const deviceData = useDeviceMapData();

  // 同一查询并发去重：侧栏与地图常以相同参数同时触发加载，合并为一次网络请求
  let inFlight: Promise<void> | null = null;
  let inFlightKey = '';

  async function doLoad(params: AlertMapQuery) {
    loading.value = true;
    error.value = null;
    try {
      const res = await queryAlarmList({
        pageNo: params.pageNo ?? 1,
        pageSize: params.pageSize ?? 100,
        device_id: params.device_id,
        begin_datetime: params.begin_datetime,
        end_datetime: params.end_datetime,
        event: params.event,
        task_name: params.task_name,
        object: params.object,
        business_tags: params.business_tags,
      });
      const list = (res?.alert_list || res?.data?.alert_list || []) as AlertMapItem[];
      alerts.value = list;
      total.value = res?.total ?? res?.data?.total ?? list.length;

      await deviceData.load({ has_location: true });
      enrichAlertsWithLocation();
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载告警失败';
      alerts.value = [];
    } finally {
      loading.value = false;
    }
  }

  async function loadAlerts(params: AlertMapQuery = {}) {
    const key = JSON.stringify(params ?? {});
    if (inFlight && key === inFlightKey) return inFlight;
    inFlightKey = key;
    const run = doLoad(params);
    inFlight = run;
    try {
      await run;
    } finally {
      if (inFlight === run) inFlight = null;
    }
  }

  function enrichAlertsWithLocation() {
    // 先建索引，避免逐条 findById 造成 O(告警数 × 设备数) 扫描
    const byId = new Map(deviceData.devices.value.map((d) => [String(d.id), d]));
    alerts.value = alerts.value.map((alert) => {
      if (!alert.device_id) return alert;
      const device = byId.get(String(alert.device_id));
      if (!device) return alert;
      return { ...alert, lng: device.lng, lat: device.lat };
    });
  }

  const alertsWithLocation = computed(() =>
    alerts.value.filter((a) => a.lng != null && a.lat != null),
  );

  /** 按摄像头(device_id)分组的告警列表（时间倒序），供悬浮卡片查询明细 */
  const alertsByDevice = computed(() => {
    const map = new Map<string, AlertMapItem[]>();
    alertsWithLocation.value.forEach((a) => {
      if (!a.device_id) return;
      const id = String(a.device_id);
      const list = map.get(id);
      if (list) list.push(a);
      else map.set(id, [a]);
    });
    const toTs = (t?: string) => (t ? Date.parse(t) || 0 : 0);
    map.forEach((list) => list.sort((x, y) => toTs(y.time) - toTs(x.time)));
    return map;
  });

  function toAlertMarkers(): MapMarkerData[] {
    return alertsWithLocation.value.map((a) => ({
      id: String(a.id),
      lng: Number(a.lng),
      lat: Number(a.lat),
      title: a.event || '告警',
      subtitle: a.device_name || a.device_id,
      kind: 'alert' as const,
      payload: { ...a },
    }));
  }

  function toCameraMarkers(): MapMarkerData[] {
    return deviceData.toMarkers();
  }

  /** 按摄像头(device_id)统计已定位告警条数 */
  function alertCountByDevice(): Map<string, number> {
    const counts = new Map<string, number>();
    alertsWithLocation.value.forEach((a) => {
      if (!a.device_id) return;
      const id = String(a.device_id);
      counts.set(id, (counts.get(id) ?? 0) + 1);
    });
    return counts;
  }

  /**
   * 合并摄像头 + 告警：告警没有独立坐标（借用所在摄像头坐标），逐条上图会造成
   * 重叠/散开/与聚合圈混淆。改为按摄像头聚合——有告警的摄像头本体变红并显示告警
   * 数量徽标（count），无告警的摄像头保持蓝色。位置真实、无重复、不混淆。
   */
  function toCombinedMarkers(): MapMarkerData[] {
    const counts = alertCountByDevice();
    return toCameraMarkers().map((cam) => {
      const n = counts.get(cam.id) ?? 0;
      return n > 0 ? { ...cam, count: n } : cam;
    });
  }

  /** 仅告警视图：只显示有告警的摄像头（红色 + 数量徽标） */
  function toAlertedCameraMarkers(): MapMarkerData[] {
    const counts = alertCountByDevice();
    return toCameraMarkers()
      .filter((cam) => (counts.get(cam.id) ?? 0) > 0)
      .map((cam) => ({ ...cam, count: counts.get(cam.id) }));
  }

  return {
    loading,
    alerts,
    total,
    error,
    alertsWithLocation,
    alertsByDevice,
    deviceData,
    loadAlerts,
    toAlertMarkers,
    toCameraMarkers,
    toAlertedCameraMarkers,
    toCombinedMarkers,
  };
}

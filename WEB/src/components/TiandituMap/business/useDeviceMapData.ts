import { ref } from 'vue';
import { getDeviceLocations, type DeviceLocationInfo } from '@/api/device/camera';
import { formatHeadingSummary, hasDeviceLocation } from '@/views/camera/utils/deviceLocation';
import type { CameraStructure, DeviceMapItem, MapMarkerData } from '../types';

/**
 * 相机结构判定：优先 GB28181 ptzType（最准确），缺失时回退 PTZ 能力推断。
 * ptzType: 1球机 2半球 3固定枪机 4遥控枪机 5遥控半球 6/7多目。
 */
function classifyCameraStructure(
  ptzType?: number | null,
  supportMove?: boolean | null,
  supportZoom?: boolean | null,
): CameraStructure {
  switch (ptzType) {
    case 1: return 'dome';
    case 2: return 'hemisphere';
    case 3: return 'bullet';
    case 4: return 'bullet';
    case 5: return 'hemisphere';
    case 6:
    case 7: return 'multi';
    default: break;
  }
  if (supportMove === true) return supportZoom === true ? 'dome' : 'hemisphere';
  if (supportMove === false) return 'bullet';
  return 'unknown';
}

/** GB28181 8 方位枚举(光轴方向)→ 朝向角(度，0=正北顺时针)：固定相机无连续朝向时驱动视域扇形 */
const DIRECTION_TYPE_HEADING: Record<number, number> = {
  1: 90, // 东
  2: 270, // 西
  3: 180, // 南
  4: 0, // 北
  5: 135, // 东南
  6: 45, // 东北
  7: 225, // 西南
  8: 315, // 西北
};

function headingFrom(heading?: number | null, directionType?: number | null): number | null {
  if (heading != null && !Number.isNaN(Number(heading))) return Number(heading);
  if (directionType != null && DIRECTION_TYPE_HEADING[directionType] != null) {
    return DIRECTION_TYPE_HEADING[directionType];
  }
  return null;
}

export function useDeviceMapData() {
  const loading = ref(false);
  const devices = ref<DeviceMapItem[]>([]);
  const error = ref<string | null>(null);

  async function load(params?: { directory_id?: number; has_location?: boolean }) {
    loading.value = true;
    error.value = null;
    try {
      const res = await getDeviceLocations(params) as DeviceLocationInfo[] | { data?: DeviceLocationInfo[] };
      const list = Array.isArray(res) ? res : (res?.data || []);
      devices.value = (list || [])
        .filter((d) => hasDeviceLocation(d) && d.longitude != null && d.latitude != null)
        .map((d) => ({
          id: d.id,
          name: d.name,
          lng: Number(d.longitude),
          lat: Number(d.latitude),
          online: d.online,
          address: d.address,
          altitude: d.altitude,
          heading: d.heading ?? null,
          location_source: d.location_source,
          directory_id: d.directory_id,
          device_kind: (d as { device_kind?: string }).device_kind,
          support_move: d.support_move ?? null,
          support_zoom: d.support_zoom ?? null,
          ptz_type: d.ptz_type ?? null,
          direction_type: d.direction_type ?? null,
          position_type: d.position_type ?? null,
          room_type: d.room_type ?? null,
          use_type: d.use_type ?? null,
          supply_light_type: d.supply_light_type ?? null,
          resolution: d.resolution ?? null,
        }));
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载摄像头位置失败';
      devices.value = [];
    } finally {
      loading.value = false;
    }
  }

  function toMarkers(filterOnline?: boolean | null): MapMarkerData[] {
    return devices.value
      .filter((d) => filterOnline == null || d.online === filterOnline)
      .map((d) => {
        const subtitleParts = [d.address, formatHeadingSummary(d.heading)].filter(Boolean);
        return {
          id: d.id,
          lng: d.lng,
          lat: d.lat,
          title: d.name,
          subtitle: subtitleParts.length ? subtitleParts.join(' · ') : undefined,
          kind: 'camera' as const,
          online: d.online,
          deviceKind: d.device_kind,
          cameraStructure: classifyCameraStructure(d.ptz_type, d.support_move, d.support_zoom),
          heading: headingFrom(d.heading, d.direction_type),
          positionType: d.position_type ?? null,
          useType: d.use_type ?? null,
          roomType: d.room_type ?? null,
          supplyLightType: d.supply_light_type ?? null,
          resolution: d.resolution ?? null,
          payload: { ...d },
        };
      });
  }

  function findById(deviceId: string): DeviceMapItem | undefined {
    return devices.value.find((d) => d.id === deviceId);
  }

  return { loading, devices, error, load, toMarkers, findById };
}

import { ref } from 'vue';
import {
  getIotDeviceLocations,
  type IotDeviceMapLocation,
} from '@/api/device/devices';
import type { DeviceMapItem, MapMarkerData } from '../types';

function hasLocation(d: IotDeviceMapLocation): boolean {
  return (
    d.longitude != null &&
    d.latitude != null &&
    !Number.isNaN(Number(d.longitude)) &&
    !Number.isNaN(Number(d.latitude))
  );
}

export function useIotDeviceMapData() {
  const loading = ref(false);
  const devices = ref<DeviceMapItem[]>([]);
  const error = ref<string | null>(null);

  async function load(params?: { has_location?: boolean }) {
    loading.value = true;
    error.value = null;
    try {
      const res = (await getIotDeviceLocations(params)) as
        | IotDeviceMapLocation[]
        | { data?: IotDeviceMapLocation[] };
      const list = Array.isArray(res) ? res : res?.data || [];
      devices.value = (list || [])
        .filter((d) => hasLocation(d))
        .map((d) => ({
          id: String(d.id),
          name: d.deviceName || d.deviceIdentification || String(d.id),
          lng: Number(d.longitude),
          lat: Number(d.latitude),
          online: d.online ?? d.connectStatus === 'ONLINE',
          address: d.address,
          device_kind: d.deviceType,
        }));
    } catch (e: unknown) {
      error.value = e instanceof Error ? e.message : '加载设备位置失败';
      devices.value = [];
    } finally {
      loading.value = false;
    }
  }

  function toMarkers(filterOnline?: boolean | null): MapMarkerData[] {
    return devices.value
      .filter((d) => filterOnline == null || d.online === filterOnline)
      .map((d) => ({
        id: d.id,
        lng: d.lng,
        lat: d.lat,
        title: d.name,
        subtitle: d.address || undefined,
        kind: 'device' as const,
        online: d.online,
        deviceKind: d.device_kind,
        payload: { ...d },
      }));
  }

  function findById(deviceId: string): DeviceMapItem | undefined {
    return devices.value.find((d) => d.id === deviceId);
  }

  return { loading, devices, error, load, toMarkers, findById };
}

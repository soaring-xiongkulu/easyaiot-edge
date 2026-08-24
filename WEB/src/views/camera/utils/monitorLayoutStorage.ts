import type { MonitorTreeDeviceNode } from '@/api/device/camera'
import { getLocalStorage, setLocalStorage } from '@/utils/storage'

export const CAMERA_MONITOR_LAYOUT_STORAGE_KEY = 'CAMERA_SPLIT_MONITOR_LAYOUT_PRESETS'
export const MAX_CAMERA_MONITOR_LAYOUT_PRESETS = 15

export interface CameraMonitorLayoutSlot {
  deviceId: string
  name: string
  device?: MonitorTreeDeviceNode
}

export interface CameraMonitorLayoutPreset {
  id: number
  name?: string
  layout: string
  enableAi: boolean
  slots: CameraMonitorLayoutSlot[]
  updatedAt: number
}

export interface CameraMonitorLayoutStorageData {
  presets: Record<string, CameraMonitorLayoutPreset>
  activePresetId: number | null
}

function emptyStorage(): CameraMonitorLayoutStorageData {
  return { presets: {}, activePresetId: null }
}

export function loadCameraMonitorLayoutStorage(): CameraMonitorLayoutStorageData {
  const raw = getLocalStorage(CAMERA_MONITOR_LAYOUT_STORAGE_KEY)
  if (!raw || typeof raw !== 'object') return emptyStorage()
  const data = raw as CameraMonitorLayoutStorageData
  return {
    presets: data.presets && typeof data.presets === 'object' ? data.presets : {},
    activePresetId:
      typeof data.activePresetId === 'number' &&
      data.activePresetId >= 1 &&
      data.activePresetId <= MAX_CAMERA_MONITOR_LAYOUT_PRESETS
        ? data.activePresetId
        : null,
  }
}

export function saveCameraMonitorLayoutStorage(data: CameraMonitorLayoutStorageData): void {
  setLocalStorage(CAMERA_MONITOR_LAYOUT_STORAGE_KEY, data)
}

export function serializeDeviceSnapshot(
  dev: MonitorTreeDeviceNode | undefined,
): MonitorTreeDeviceNode | undefined {
  if (!dev) return undefined
  return {
    type: 'device',
    id: dev.id,
    name: dev.name,
    http_stream: dev.http_stream,
    rtmp_stream: dev.rtmp_stream,
    ai_http_stream: dev.ai_http_stream,
    ai_rtmp_stream: dev.ai_rtmp_stream,
    online: dev.online,
    directory_id: dev.directory_id,
    device_kind: dev.device_kind,
    source: dev.source,
    nvr_id: dev.nvr_id,
    nvr_channel: dev.nvr_channel,
    nvr_label: dev.nvr_label,
  }
}

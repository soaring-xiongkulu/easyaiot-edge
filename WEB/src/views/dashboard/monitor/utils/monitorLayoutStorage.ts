import type { MonitorTreeDeviceNode } from '@/api/device/camera'
import { getLocalStorage, setLocalStorage } from '@/utils/storage'

export const MONITOR_LAYOUT_STORAGE_KEY = 'MONITOR_DASHBOARD_LAYOUT_PRESETS'
export const MAX_MONITOR_LAYOUT_PRESETS = 15

export interface MonitorLayoutSlot {
  deviceId: string
  name: string
  location?: string
  device?: MonitorTreeDeviceNode
}

export interface MonitorLayoutPreset {
  id: number
  name?: string
  layout: string
  enableAi: boolean
  slots: MonitorLayoutSlot[]
  updatedAt: number
}

export interface MonitorLayoutStorageData {
  presets: Record<string, MonitorLayoutPreset>
  activePresetId: number | null
}

function emptyStorage(): MonitorLayoutStorageData {
  return { presets: {}, activePresetId: null }
}

export function loadMonitorLayoutStorage(): MonitorLayoutStorageData {
  const raw = getLocalStorage(MONITOR_LAYOUT_STORAGE_KEY)
  if (!raw || typeof raw !== 'object') return emptyStorage()
  const data = raw as MonitorLayoutStorageData
  return {
    presets: data.presets && typeof data.presets === 'object' ? data.presets : {},
    activePresetId:
      typeof data.activePresetId === 'number' && data.activePresetId >= 1 && data.activePresetId <= MAX_MONITOR_LAYOUT_PRESETS
        ? data.activePresetId
        : null,
  }
}

export function saveMonitorLayoutStorage(data: MonitorLayoutStorageData): void {
  setLocalStorage(MONITOR_LAYOUT_STORAGE_KEY, data)
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

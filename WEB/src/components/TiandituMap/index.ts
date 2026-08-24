export * from './types';
export * from './constants';
export { createTiandituBaseLayers } from './core/tiandituLayers';
export { searchPoi, reverseGeocode } from './core/tiandituApi';
export * from './core/coordUtils';
export * from './core/markerStyles';
export { useOpenLayersMap } from './composables/useOpenLayersMap';
export { useMapMarkers } from './composables/useMapMarkers';
export { useMapTracks } from './composables/useMapTracks';
export { useMapPicker } from './composables/useMapPicker';
export { useDeviceMapData } from './business/useDeviceMapData';
export { useIotDeviceMapData } from './business/useIotDeviceMapData';
export { useAlertMapData } from './business/useAlertMapData';
export type { AlertMapQuery } from './business/useAlertMapData';
export { useDeviceTrackData } from './business/useDeviceTrackData';

export { default as BasicTiandituMap } from './src/BasicTiandituMap.vue';
export { default as MapToolbar } from './src/MapToolbar.vue';
export { default as MapLocationPicker } from './src/MapLocationPicker.vue';
export { default as DeviceMonitorMap } from './src/DeviceMonitorMap.vue';
export { default as IotDeviceMap } from './src/IotDeviceMap.vue';
export { default as AlertDeviceMap } from './src/AlertDeviceMap.vue';
export { default as TrackPlaybackMap } from './src/TrackPlaybackMap.vue';
// GisMapConsole 目前无任何页面/路由引用：从 barrel 移除以免其 scoped CSS 分块被打进
// 预加载图（重新部署后旧哈希 404 → "Unable to preload CSS" 报错）。如需使用请直接
// 从 './src/GisMapConsole.vue' 导入。
// export { default as GisMapConsole } from './src/GisMapConsole.vue';

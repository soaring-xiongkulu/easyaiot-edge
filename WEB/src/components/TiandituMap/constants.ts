import type { MapMarkerKind, TiandituBaseMapType } from './types';

/** 默认地图中心：深圳（市民中心附近） */
export const DEFAULT_MAP_CENTER: [number, number] = [114.057868, 22.543099];
export const DEFAULT_MAP_ZOOM = 10;

/**
 * 天地图 WMTS 瓦片层级：矢量/影像原生最高 18 级、地形最高 14 级。
 * 超出原生级别官方无瓦片——做法是给瓦片 source 设 maxZoom(原生上限)，
 * 同时把 View 的 maxZoom 放更高，让客户端用最高级瓦片"插值放大"而非空白。
 */
export const TIANDITU_MIN_ZOOM = 3;
/** View 允许的最大缩放（超原生级用插值放大） */
export const TIANDITU_VIEW_MAX_ZOOM = 20;
/** 各底图类型的瓦片原生最高级别 */
export const TIANDITU_NATIVE_MAX_ZOOM: Record<TiandituBaseMapType, number> = {
  vec: 18,
  img: 18,
  ter: 14,
};

export const MAP_LAYER_ZINDEX = {
  base: 0,
  heat: 5,
  track: 10,
  marker: 20,
  picker: 30,
  overlay: 40,
} as const;

export const MARKER_COLORS: Record<MapMarkerKind, string> = {
  camera: '#1677ff',
  device: '#13c2c2',
  alert: '#ff4d4f',
  track: '#52c41a',
  picker: '#e63946',
  custom: '#722ed1',
};

export const MARKER_OFFLINE_COLOR = '#bfbfbf';

export function getTiandituKey(): string {
  return import.meta.env.VITE_TIANDITU_KEY || '';
}

/** 天地图公共组件类型定义 */

export type TiandituBaseMapType = 'vec' | 'img' | 'ter';

/** 通用 GIS 地图控制台模式 */
export type GisMapMode = 'markers' | 'picker' | 'track';

/** 通用 GIS 点位数据 */
export interface GisMarkerRow {
  key: string;
  name: string;
  lng: number;
  lat: number;
  remark?: string;
}

export interface LngLat {
  lng: number;
  lat: number;
}

export interface MapMarkerStyle {
  color?: string;
  radius?: number;
  strokeColor?: string;
  strokeWidth?: number;
  icon?: string;
}

export type MapMarkerKind = 'camera' | 'device' | 'alert' | 'track' | 'picker' | 'custom';

/**
 * 相机结构类型（用于地图图标区分）：
 * dome=球机、hemisphere=半球、bullet=枪机(固定/遥控)、multi=多目、unknown=未知/通用。
 * 优先由 GB28181 ptzType 判定；缺失时回退 PTZ 能力(support_move/support_zoom)推断。
 */
export type CameraStructure = 'dome' | 'hemisphere' | 'bullet' | 'multi' | 'unknown';

export interface MapMarkerData {
  id: string;
  lng: number;
  lat: number;
  title?: string;
  subtitle?: string;
  kind?: MapMarkerKind;
  online?: boolean;
  /** 设备来源类型(direct/gb28181/nvr...)，用于图标区分 */
  deviceKind?: string;
  /** 相机结构(球机/枪机/半球/多目)，用于图标区分 */
  cameraStructure?: CameraStructure;
  /** GB28181 业务属性(用于分类筛选 / popup 详情) */
  positionType?: number | null;
  useType?: number | null;
  roomType?: number | null;
  supplyLightType?: number | null;
  resolution?: string | null;
  /** 是否为"最近新告警"，用于地图脉冲高亮 */
  isNew?: boolean;
  /** 关联告警数量：>0 时摄像头标记变红并在圆内显示数字徽标 */
  count?: number;
  /** 安装朝向(°)：0=正北，顺时针；枪机地图扇形指示 */
  heading?: number | null;
  style?: MapMarkerStyle;
  payload?: Record<string, unknown>;
}

/** 悬浮命中信息：单个摄像头 或 聚合簇（用于外部渲染不同的悬浮提示） */
export type MapHoverInfo =
  | { type: 'camera'; marker: MapMarkerData }
  | { type: 'cluster'; count: number; alertCount: number; canZoom: boolean };

export interface MapTrackPoint extends LngLat {
  recordedAt?: string | number;
  speed?: number;
  direction?: number;
  altitude?: number;
}

export interface MapTrackSession {
  id: string;
  deviceId: string;
  title?: string;
  points: MapTrackPoint[];
  color?: string;
}

export interface PoiSearchResult {
  id: string;
  name: string;
  address: string;
  lng: number | null;
  lat: number | null;
  province?: string;
  city?: string;
  phone?: string;
}

export interface MapPickResult extends LngLat {
  address?: string;
}

export interface AlertMapItem {
  id: string | number;
  device_id?: string;
  device_name?: string;
  event?: string;
  time?: string;
  image_url?: string;
  lng?: number | null;
  lat?: number | null;
}

export interface DeviceMapItem {
  id: string;
  name: string;
  lng: number;
  lat: number;
  online?: boolean;
  address?: string | null;
  altitude?: number | null;
  heading?: number | null;
  location_source?: string | null;
  directory_id?: number | null;
  device_kind?: string;
  /** 是否支持云台转动(PTZ pan/tilt)，用于推断球机/枪机 */
  support_move?: boolean | null;
  /** 是否支持变倍(zoom) */
  support_zoom?: boolean | null;
  /** GB28181 通道目录属性 */
  ptz_type?: number | null;
  direction_type?: number | null;
  position_type?: number | null;
  room_type?: number | null;
  use_type?: number | null;
  supply_light_type?: number | null;
  resolution?: string | null;
}

export interface BasicTiandituMapProps {
  /** 初始中心 [lng, lat]，默认深圳 */
  center?: [number, number];
  zoom?: number;
  baseMapType?: TiandituBaseMapType;
  showToolbar?: boolean;
  showScaleLine?: boolean;
  /** 缩放 +/- 按钮（默认开） */
  showZoom?: boolean;
  /** 全屏按钮（默认开） */
  showFullScreen?: boolean;
  /** 鹰眼/缩略图（默认关） */
  showOverview?: boolean;
  /** 是否允许点击地图（选址模式） */
  clickable?: boolean;
}

export interface MapToolbarProps {
  baseMapType: TiandituBaseMapType;
  markerCount?: number;
  trackCount?: number;
}

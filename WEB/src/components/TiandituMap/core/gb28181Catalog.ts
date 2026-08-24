/**
 * GB28181 通道目录属性的中文标签与分类工具（供地图分类筛选、popup 详情、图例复用）。
 * 取值定义见国标 DeviceChannel：PTZType / PositionType / RoomType / UseType / SupplyLightType。
 */

// 注：相机结构(PTZType)在地图上以 CAMERA_STRUCTURE_LABEL 展示，故此处不再单列 PTZ_TYPE_LABEL。

export const POSITION_TYPE_LABEL: Record<number, string> = {
  1: '省际检查站',
  2: '党政机关',
  3: '车站码头',
  4: '中心广场',
  5: '体育场馆',
  6: '商业中心',
  7: '宗教场所',
  8: '校园周边',
  9: '治安复杂区域',
  10: '交通干线',
};

export const ROOM_TYPE_LABEL: Record<number, string> = {
  1: '室外',
  2: '室内',
};

export const USE_TYPE_LABEL: Record<number, string> = {
  1: '治安',
  2: '交通',
  3: '重点',
};

/** 相机结构枚举 → 中文（与 CameraStructure 对应） */
export const CAMERA_STRUCTURE_LABEL: Record<string, string> = {
  dome: '球机',
  hemisphere: '半球',
  bullet: '枪机',
  multi: '多目',
  unknown: '',
};

export const SUPPLY_LIGHT_LABEL: Record<number, string> = {
  1: '无补光',
  2: '红外补光',
  3: '白光补光',
  4: '激光补光',
  9: '其他补光',
};

/** 是否具备夜视补光能力（红外/白光/激光） */
export function hasNightVision(supplyLightType?: number | null): boolean {
  return supplyLightType === 2 || supplyLightType === 3 || supplyLightType === 4;
}

/** 标签取值器工厂：值为空或无对应项时返回空串 */
const labelOf = (map: Record<number, string>) => (v?: number | null): string =>
  (v != null ? map[v] ?? '' : '');

export const positionTypeText = labelOf(POSITION_TYPE_LABEL);
export const roomTypeText = labelOf(ROOM_TYPE_LABEL);
export const useTypeText = labelOf(USE_TYPE_LABEL);
export const supplyLightText = labelOf(SUPPLY_LIGHT_LABEL);

/** 地图设备分类筛选条件 */
export interface MapCategoryFilterValue {
  /** 用途(治安/交通/重点)，空=不限 */
  useTypes: number[];
  /** 位置类型，空=不限 */
  positionTypes: number[];
  /** 仅室外 */
  outdoorOnly: boolean;
  /** 仅夜视(有补光) */
  nightVisionOnly: boolean;
}

export function emptyCategoryFilter(): MapCategoryFilterValue {
  return { useTypes: [], positionTypes: [], outdoorOnly: false, nightVisionOnly: false };
}

export function isCategoryFilterActive(f: MapCategoryFilterValue): boolean {
  return f.useTypes.length > 0 || f.positionTypes.length > 0 || f.outdoorOnly || f.nightVisionOnly;
}

/** 判断一个设备（含 useType/positionType/roomType/supplyLightType）是否通过分类筛选 */
export function matchCategoryFilter(
  d: {
    useType?: number | null;
    positionType?: number | null;
    roomType?: number | null;
    supplyLightType?: number | null;
  },
  f: MapCategoryFilterValue,
): boolean {
  if (f.useTypes.length && (d.useType == null || !f.useTypes.includes(d.useType))) return false;
  if (f.positionTypes.length && (d.positionType == null || !f.positionTypes.includes(d.positionType))) return false;
  if (f.outdoorOnly && d.roomType !== 1) return false;
  if (f.nightVisionOnly && !hasNightVision(d.supplyLightType)) return false;
  return true;
}

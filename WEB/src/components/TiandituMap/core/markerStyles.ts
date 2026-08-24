import Style from 'ol/style/Style';
import Circle from 'ol/style/Circle';
import Fill from 'ol/style/Fill';
import Stroke from 'ol/style/Stroke';
import Text from 'ol/style/Text';
import Icon from 'ol/style/Icon';
import RegularShape from 'ol/style/RegularShape';
import type { CameraStructure, MapMarkerKind, MapMarkerStyle } from '../types';
import { MARKER_COLORS, MARKER_OFFLINE_COLOR } from '../constants';

/**
 * 摄像头水滴形定位图标：白色相机字形按结构区分（球机/半球/枪机/通用）+ 状态色填充。
 * 结构由设备 PTZ 能力推断；缺失则用通用相机字形。按 颜色|结构 缓存复用。
 */
const cameraIconCache = new Map<string, Style>();

/** 水滴外框（pin 主体），内部字形由各结构填充 */
function cameraPin(color: string, inner: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="30" height="38" viewBox="0 0 30 38">`
    + `<path d="M15 1C7.3 1 1 7.3 1 15c0 9 12.4 21 13.6 21.8a.8.8 0 0 0 .8 0C16.6 36 29 24 29 15 29 7.3 22.7 1 15 1z" fill="${color}" stroke="#fff" stroke-width="1.5"/>`
    + inner
    + `</svg>`;
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

/** 各结构的白色内部字形（围绕 cx≈15 cy≈15） */
function cameraInnerGlyph(color: string, structure: CameraStructure): string {
  switch (structure) {
    case 'dome': // 球机：球体 + 镜头
      return `<circle cx="15" cy="15" r="6.6" fill="#fff"/>`
        + `<path d="M8.7 14.2h12.6" stroke="${color}" stroke-width="1" opacity="0.5"/>`
        + `<circle cx="15" cy="15.4" r="2.8" fill="${color}"/>`;
    case 'hemisphere': // 半球：半圆 + 镜头
      return `<path d="M8.4 17.6a6.6 6.6 0 0 1 13.2 0z" fill="#fff"/>`
        + `<circle cx="15" cy="16.6" r="2.3" fill="${color}"/>`;
    case 'bullet': // 枪机：横向筒身 + 顶部支架 + 前端镜头
      return `<rect x="7.5" y="12.4" width="14" height="6.2" rx="3.1" fill="#fff"/>`
        + `<rect x="12" y="9.4" width="2.4" height="3.2" rx="0.6" fill="#fff"/>`
        + `<circle cx="19.4" cy="15.5" r="1.9" fill="${color}"/>`;
    case 'multi': // 多目：宽机身 + 双镜头
      return `<rect x="6.8" y="11.6" width="16.4" height="7.6" rx="1.8" fill="#fff"/>`
        + `<circle cx="11.6" cy="15.4" r="2.1" fill="${color}"/>`
        + `<circle cx="18.4" cy="15.4" r="2.1" fill="${color}"/>`;
    default: // 通用相机字形
      return `<rect x="8.5" y="11" width="13" height="9" rx="1.6" fill="#fff"/>`
        + `<rect x="11.5" y="8.8" width="4.5" height="2.6" rx="0.8" fill="#fff"/>`
        + `<circle cx="15" cy="15.5" r="2.7" fill="${color}"/>`;
  }
}

/** 摄像头图标的 data-URI（供图例等 <img> 直接使用） */
export function cameraIconUri(color: string, structure: CameraStructure = 'unknown'): string {
  return cameraPin(color, cameraInnerGlyph(color, structure));
}

export function createCameraIconStyle(color: string, structure: CameraStructure = 'unknown'): Style {
  const cacheKey = `${color}|${structure}`;
  let style = cameraIconCache.get(cacheKey);
  if (!style) {
    style = new Style({
      image: new Icon({
        src: cameraPin(color, cameraInnerGlyph(color, structure)),
        anchor: [0.5, 1],
        scale: 1,
      }),
    });
    cameraIconCache.set(cacheKey, style);
  }
  return style;
}

/** IoT 设备水滴图标：芯片字形 */
const deviceIconCache = new Map<string, Style>();

function devicePin(color: string): string {
  const inner = `<rect x="9" y="10.5" width="12" height="10" rx="1.6" fill="#fff"/>`
    + `<rect x="11" y="12.5" width="3.2" height="2.4" rx="0.4" fill="${color}"/>`
    + `<rect x="15.8" y="12.5" width="3.2" height="2.4" rx="0.4" fill="${color}"/>`
    + `<rect x="11" y="16.2" width="8" height="2.2" rx="0.4" fill="${color}" opacity="0.55"/>`
    + `<rect x="13.4" y="8.2" width="3.2" height="2.4" rx="0.5" fill="#fff"/>`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="30" height="38" viewBox="0 0 30 38">`
    + `<path d="M15 1C7.3 1 1 7.3 1 15c0 9 12.4 21 13.6 21.8a.8.8 0 0 0 .8 0C16.6 36 29 24 29 15 29 7.3 22.7 1 15 1z" fill="${color}" stroke="#fff" stroke-width="1.5"/>`
    + inner
    + `</svg>`;
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

export function deviceIconUri(color: string): string {
  return devicePin(color);
}

export function createDeviceIconStyle(color: string): Style {
  let style = deviceIconCache.get(color);
  if (!style) {
    style = new Style({
      image: new Icon({
        src: devicePin(color),
        anchor: [0.5, 1],
        scale: 1,
      }),
    });
    deviceIconCache.set(color, style);
  }
  return style;
}

export function createCircleMarkerStyle(options: MapMarkerStyle & { label?: string } = {}): Style {
  const {
    color = MARKER_COLORS.custom,
    radius = 8,
    strokeColor = '#ffffff',
    strokeWidth = 2,
    label,
  } = options;

  return new Style({
    image: new Circle({
      radius,
      fill: new Fill({ color }),
      stroke: new Stroke({ color: strokeColor, width: strokeWidth }),
    }),
    text: label
      ? new Text({
          text: label,
          offsetY: -radius - 8,
          font: '12px sans-serif',
          fill: new Fill({ color: '#333' }),
          stroke: new Stroke({ color: '#fff', width: 3 }),
        })
      : undefined,
  });
}

/** OpenLayers 旋转角：从正北顺时针朝向角转换为弧度（图标默认指向东） */
export function headingToRotationRad(heading: number): number {
  return ((90 - heading) * Math.PI) / 180;
}

/** 枪机朝向扇形（叠加在圆点之上） */
export function createHeadingWedgeStyle(color: string, heading: number): Style {
  return new Style({
    image: new RegularShape({
      fill: new Fill({ color: `${color}55` }),
      stroke: new Stroke({ color, width: 1.5 }),
      points: 3,
      radius: 24,
      radius2: 3,
      angle: Math.PI / 2,
      rotation: headingToRotationRad(heading),
    }),
  });
}

/** 有告警的摄像头：红色圆点 + 圆内白色告警数量徽标 */
export function createAlertBadgeStyle(count: number): Style {
  const radius = count >= 100 ? 15 : count >= 10 ? 13 : 11;
  return new Style({
    image: new Circle({
      radius,
      fill: new Fill({ color: MARKER_COLORS.alert }),
      stroke: new Stroke({ color: '#ffffff', width: 2 }),
    }),
    text: new Text({
      text: count > 99 ? '99+' : String(count),
      font: 'bold 11px sans-serif',
      fill: new Fill({ color: '#ffffff' }),
    }),
  });
}

export function styleForMarkerKind(
  kind: MapMarkerKind = 'custom',
  online?: boolean,
  label?: string,
  heading?: number | null,
  count?: number,
  structure: CameraStructure = 'unknown',
): Style | Style[] {
  // 关联告警的摄像头：整体变红并显示数量徽标（不再单独绘制告警点）
  if ((count ?? 0) > 0) {
    return createAlertBadgeStyle(count as number);
  }

  // 摄像头：水滴形相机图标（按结构区分 + 按在线/离线着色）+ 朝向扇形
  if (kind === 'camera') {
    const color = online === false ? MARKER_OFFLINE_COLOR : MARKER_COLORS.camera;
    const icon = createCameraIconStyle(color, structure);
    const styles: Style[] = [];
    if (heading != null && !Number.isNaN(Number(heading))) {
      styles.push(createHeadingWedgeStyle(color, Number(heading)));
    }
    styles.push(icon);
    if (label) {
      styles.push(new Style({
        text: new Text({
          text: label,
          offsetY: 8,
          font: '12px sans-serif',
          fill: new Fill({ color: '#333' }),
          stroke: new Stroke({ color: '#fff', width: 3 }),
        }),
      }));
    }
    return styles.length === 1 ? styles[0] : styles;
  }

  // IoT 设备：水滴形芯片图标
  if (kind === 'device') {
    const color = online === false ? MARKER_OFFLINE_COLOR : MARKER_COLORS.device;
    const icon = createDeviceIconStyle(color);
    if (!label) return icon;
    return [
      icon,
      new Style({
        text: new Text({
          text: label,
          offsetY: 8,
          font: '12px sans-serif',
          fill: new Fill({ color: '#333' }),
          stroke: new Stroke({ color: '#fff', width: 3 }),
        }),
      }),
    ];
  }

  const color = MARKER_COLORS[kind] || MARKER_COLORS.custom;
  return createCircleMarkerStyle({
    color,
    radius: kind === 'alert' ? 10 : 8,
    label,
  });
}

/**
 * 脉冲高亮样式（最近新告警）。传入 0~1 的动画相位，返回扩散的半透明圆环。
 * 由地图 postrender 动画循环驱动，叠加在摄像头图标之下。
 */
export function createPulseStyle(phase: number, color = MARKER_COLORS.alert): Style {
  const radius = 8 + phase * 22;
  const opacity = (1 - phase) * 0.5;
  return new Style({
    image: new Circle({
      radius,
      stroke: new Stroke({ color, width: 2 }),
      fill: new Fill({ color: hexToRgba(color, opacity) }),
    }),
  });
}

function hexToRgba(hex: string, alpha: number): string {
  const m = hex.replace('#', '');
  const r = parseInt(m.slice(0, 2), 16);
  const g = parseInt(m.slice(2, 4), 16);
  const b = parseInt(m.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

/**
 * 聚合簇样式。alertCount>0 时整簇红描边 + 右上角红色告警数量徽标，
 * 让"含告警的聚合点"在收拢状态下也能一眼看出（否则只剩一个数字、告警被淹没）。
 */
export function styleForCluster(size: number, alertCount = 0): Style | Style[] {
  const radius = Math.min(22, 10 + Math.log2(size + 1) * 4);
  const base = new Style({
    image: new Circle({
      radius,
      fill: new Fill({ color: 'rgba(66, 135, 252, 0.85)' }),
      stroke: new Stroke({ color: alertCount > 0 ? MARKER_COLORS.alert : '#ffffff', width: alertCount > 0 ? 3 : 2 }),
    }),
    text: new Text({
      text: String(size),
      font: 'bold 12px sans-serif',
      fill: new Fill({ color: '#fff' }),
    }),
  });
  if (alertCount <= 0) return base;

  // 徽标按文字位数自适应大小，避免 "99+" 溢出圆圈
  const badgeText = alertCount > 99 ? '99+' : String(alertCount);
  const badgeRadius = badgeText.length >= 3 ? 11 : badgeText.length === 2 ? 9.5 : 8;
  const badgeFont = `bold ${badgeText.length >= 3 ? 9 : 10}px sans-serif`;
  const dispX = radius * 0.82;
  const dispY = radius * 0.82;
  const badge = new Style({
    image: new Circle({
      radius: badgeRadius,
      fill: new Fill({ color: MARKER_COLORS.alert }),
      stroke: new Stroke({ color: '#ffffff', width: 1.5 }),
      displacement: [dispX, dispY],
    }),
    text: new Text({
      text: badgeText,
      font: badgeFont,
      fill: new Fill({ color: '#ffffff' }),
      offsetX: dispX,
      offsetY: -dispY,
    }),
  });
  return [base, badge];
}

/** 聚合点展开(spiderfy)时，中心到各叶子的引导线样式 */
export function createClusterLeaderLineStyle(): Style {
  return new Style({
    stroke: new Stroke({ color: 'rgba(38, 108, 251, 0.45)', width: 1 }),
  });
}

export function createTrackLineStyle(color = '#52c41a', width = 3): Style {
  return new Style({
    stroke: new Stroke({ color, width }),
  });
}

export function createTrackPlayedStyle(color = '#1677ff', width = 4): Style {
  return new Style({
    stroke: new Stroke({ color, width }),
  });
}

import TileLayer from 'ol/layer/Tile';
import XYZ from 'ol/source/XYZ';
import type { TiandituBaseMapType } from '../types';
import { getTiandituKey, TIANDITU_NATIVE_MAX_ZOOM } from '../constants';

function wmtsUrl(server: string, layer: string, key: string): string {
  return `https://${server}.tianditu.gov.cn/${layer}/wmts?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=${layer.split('_')[0]}&STYLE=default&TILEMATRIXSET=w&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&FORMAT=tiles&tk=${key}`;
}

function labelUrl(server: string, layer: string, key: string): string {
  return `https://${server}.tianditu.gov.cn/${layer}/wmts?tk=${key}&layer=${layer.split('_')[0]}&style=default&tilematrixset=w&Service=WMTS&Request=GetTile&Version=1.0.0&Format=tiles&TileMatrix={z}&TileCol={x}&TileRow={y}`;
}

/** 各底图类型对应的 天地图底图层 / 注记层 代码 */
const LAYER_CODES: Record<TiandituBaseMapType, { base: string; label: string }> = {
  vec: { base: 'vec_w', label: 'cva_w' },
  img: { base: 'img_w', label: 'cia_w' },
  ter: { base: 'ter_w', label: 'cta_w' },
};

/**
 * 创建天地图底图图层组（矢量/影像/地形 + 注记）。
 * 给 source 设 maxZoom 为该类型原生最高级（vec/img=18, ter=14），
 * 超出后 OpenLayers 用最高级瓦片插值放大，避免请求不存在的瓦片导致空白/全黄。
 */
export function createTiandituBaseLayers(
  type: TiandituBaseMapType = 'vec',
  key: string = getTiandituKey(),
): TileLayer<XYZ>[] {
  if (!key) {
    console.warn('[TiandituMap] VITE_TIANDITU_KEY 未配置，瓦片可能无法加载');
  }

  const codes = LAYER_CODES[type] ?? LAYER_CODES.vec;
  const maxZoom = TIANDITU_NATIVE_MAX_ZOOM[type] ?? 18;

  const baseLayer = new TileLayer({
    source: new XYZ({
      url: wmtsUrl('t0', codes.base, key),
      projection: 'EPSG:3857',
      maxZoom,
    }),
  });

  const labelLayer = new TileLayer({
    source: new XYZ({
      url: labelUrl('t1', codes.label, key),
      projection: 'EPSG:3857',
      maxZoom,
    }),
  });
  // 标注层打标记，供"注记开关"控制显隐
  labelLayer.set('tdtRole', 'label');
  baseLayer.set('tdtRole', 'base');

  return [baseLayer, labelLayer];
}

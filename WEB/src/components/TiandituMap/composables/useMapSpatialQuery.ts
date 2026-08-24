import { onBeforeUnmount, ref, shallowRef, watch, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Draw, { createBox } from 'ol/interaction/Draw';
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';
import type Geometry from 'ol/geom/Geometry';
import type Map from 'ol/Map';
import { toMercator } from '../core/coordUtils';
import { MAP_LAYER_ZINDEX } from '../constants';

export type SpatialQueryType = 'circle' | 'rect' | 'polygon';

export interface SpatialPoint {
  id: string;
  lng: number;
  lat: number;
}

export interface UseMapSpatialQueryOptions {
  map: Ref<Map | null>;
  /** 返回当前可筛选的点（摄像头/告警） */
  getPoints: () => SpatialPoint[];
  /** 选区变化回调（ids 为范围内点 id；清除时为 null） */
  onResult?: (ids: string[] | null) => void;
}

/** 框选/周边空间查询：Draw 圆/矩形/多边形，过滤范围内已加载点 */
export function useMapSpatialQuery(options: UseMapSpatialQueryOptions) {
  const active = ref<SpatialQueryType | null>(null);
  const selectedIds = ref<string[]>([]);
  const source = new VectorSource();
  const layer = new VectorLayer({
    source,
    zIndex: MAP_LAYER_ZINDEX.overlay - 1,
    style: new Style({
      stroke: new Stroke({ color: '#266cfb', width: 2, lineDash: [5, 5] }),
      fill: new Fill({ color: 'rgba(38, 108, 251, 0.08)' }),
    }),
  });

  let draw: Draw | null = null;

  function ensureLayer(map: Map) {
    if (!map.getLayers().getArray().includes(layer)) map.addLayer(layer);
  }

  function stopDraw() {
    const map = options.map.value;
    if (draw && map) map.removeInteraction(draw);
    draw = null;
    active.value = null;
  }

  function computeInside(geom: Geometry) {
    const ids = options.getPoints()
      .filter((p) => Number.isFinite(p.lng) && Number.isFinite(p.lat))
      .filter((p) => geom.intersectsCoordinate(toMercator(p.lng, p.lat)))
      .map((p) => p.id);
    selectedIds.value = ids;
    options.onResult?.(ids);
  }

  function start(type: SpatialQueryType) {
    const map = options.map.value;
    if (!map) return;
    stopDraw();
    ensureLayer(map);
    source.clear();
    active.value = type;

    draw = new Draw({
      source,
      type: type === 'polygon' ? 'Polygon' : 'Circle',
      geometryFunction: type === 'rect' ? createBox() : undefined,
    });
    map.addInteraction(draw);

    draw.on('drawend', (e) => {
      const geom = e.feature.getGeometry();
      if (geom) computeInside(geom);
      stopDraw();
    });
  }

  function clear() {
    stopDraw();
    source.clear();
    selectedIds.value = [];
    options.onResult?.(null);
  }

  watch(() => options.map.value, (m) => { if (m) ensureLayer(m); });

  onBeforeUnmount(() => {
    stopDraw();
    const map = options.map.value;
    if (map) map.removeLayer(layer);
  });

  return { layer: shallowRef(layer), active, selectedIds, start, clear };
}

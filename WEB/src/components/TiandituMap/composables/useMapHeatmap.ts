import { onBeforeUnmount, shallowRef, watch, type Ref } from 'vue';
import Heatmap from 'ol/layer/Heatmap';
import VectorSource from 'ol/source/Vector';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import type Map from 'ol/Map';
import { toMercator } from '../core/coordUtils';
import { MAP_LAYER_ZINDEX } from '../constants';

export interface HeatPoint {
  lng: number;
  lat: number;
  /** 权重(0~1)，缺省按 1 计 */
  weight?: number;
}

export interface UseMapHeatmapOptions {
  map: Ref<Map | null>;
  /** 是否显示热力层 */
  enabled: Ref<boolean>;
  blur?: number;
  radius?: number;
}

/** 告警密度热力图层：包 ol/layer/Heatmap，按需显隐，喂入告警点 */
export function useMapHeatmap(options: UseMapHeatmapOptions) {
  const source = new VectorSource();
  const layer = new Heatmap({
    source,
    zIndex: MAP_LAYER_ZINDEX.heat,
    blur: options.blur ?? 18,
    radius: options.radius ?? 12,
    weight: (feature) => (feature.get('weight') as number | undefined) ?? 1,
  });
  layer.setVisible(false);

  let attached: Map | null = null;

  function setPoints(points: HeatPoint[]) {
    source.clear();
    source.addFeatures(
      points
        .filter((p) => Number.isFinite(p.lng) && Number.isFinite(p.lat))
        .map((p) => {
          const f = new Feature({ geometry: new Point(toMercator(p.lng, p.lat)) });
          if (p.weight != null) f.set('weight', p.weight);
          return f;
        }),
    );
  }

  function attach() {
    const m = options.map.value;
    if (!m || attached === m) return;
    if (attached) attached.removeLayer(layer);
    m.addLayer(layer);
    attached = m;
  }

  function detach() {
    if (attached) {
      attached.removeLayer(layer);
      attached = null;
    }
  }

  watch(() => options.map.value, (m) => { if (m) attach(); }, { immediate: true });
  watch(() => options.enabled.value, (v) => layer.setVisible(!!v), { immediate: true });

  onBeforeUnmount(detach);

  return { layer: shallowRef(layer), setPoints, attach, detach };
}

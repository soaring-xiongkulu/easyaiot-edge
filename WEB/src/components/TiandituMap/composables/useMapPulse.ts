import { onBeforeUnmount, shallowRef, watch, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import type Map from 'ol/Map';
import type { EventsKey } from 'ol/events';
import { unByKey } from 'ol/Observable';
import { toMercator } from '../core/coordUtils';
import { createPulseStyle } from '../core/markerStyles';
import { MAP_LAYER_ZINDEX } from '../constants';

const PERIOD_MS = 1600;

/** 最新告警脉冲高亮：在告警点下方叠加扩散圆环动画（postrender 驱动） */
export function useMapPulse(options: { map: Ref<Map | null> }) {
  const source = new VectorSource();
  let phase = 0;
  const layer = new VectorLayer({
    source,
    zIndex: MAP_LAYER_ZINDEX.marker - 1,
    style: () => createPulseStyle(phase),
  });

  let attached: Map | null = null;
  let t0 = 0;
  let preKey: EventsKey | null = null;
  let postKey: EventsKey | null = null;

  function setPoints(points: Array<{ lng: number; lat: number }>) {
    source.clear();
    source.addFeatures(
      points
        .filter((p) => Number.isFinite(p.lng) && Number.isFinite(p.lat))
        .map((p) => new Feature({ geometry: new Point(toMercator(p.lng, p.lat)) })),
    );
    options.map.value?.render();
  }

  function attach() {
    const m = options.map.value;
    if (!m || attached === m) return;
    if (attached) detach();
    m.addLayer(layer);
    t0 = (typeof performance !== 'undefined' ? performance.now() : 0);
    preKey = layer.on('prerender', () => {
      const now = typeof performance !== 'undefined' ? performance.now() : t0;
      phase = ((now - t0) % PERIOD_MS) / PERIOD_MS;
    });
    // 仅在「有脉冲点 且 页面可见」时持续重绘：无点→自然停止，后台标签页→暂停，避免空转占 CPU
    postKey = m.on('postrender', () => {
      if (!document.hidden && source.getFeatures().length) m.render();
    });
    attached = m;
  }

  function detach() {
    if (preKey) { unByKey(preKey); preKey = null; }
    if (postKey) { unByKey(postKey); postKey = null; }
    if (attached) { attached.removeLayer(layer); attached = null; }
  }

  watch(() => options.map.value, (m) => { if (m) attach(); }, { immediate: true });

  onBeforeUnmount(detach);

  return { layer: shallowRef(layer), setPoints, attach, detach };
}

import { onBeforeUnmount, ref, shallowRef, watch, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Draw from 'ol/interaction/Draw';
import Overlay from 'ol/Overlay';
import Style from 'ol/style/Style';
import Stroke from 'ol/style/Stroke';
import Fill from 'ol/style/Fill';
import CircleStyle from 'ol/style/Circle';
import { getArea, getLength } from 'ol/sphere';
import { LineString, Polygon } from 'ol/geom';
import type Geometry from 'ol/geom/Geometry';
import type Map from 'ol/Map';
import type { EventsKey } from 'ol/events';
import { unByKey } from 'ol/Observable';
import { MAP_LAYER_ZINDEX } from '../constants';

export type MeasureType = 'line' | 'area';

function formatLength(line: LineString): string {
  const len = getLength(line, { projection: 'EPSG:3857' });
  return len >= 1000 ? `${(len / 1000).toFixed(2)} km` : `${len.toFixed(1)} m`;
}

function formatArea(poly: Polygon): string {
  const area = getArea(poly, { projection: 'EPSG:3857' });
  return area >= 1_000_000 ? `${(area / 1_000_000).toFixed(2)} km²` : `${area.toFixed(0)} m²`;
}

/** 测距 / 测面工具：Draw 线/面 + 实时 tooltip（ol/sphere 测地距离/面积） */
export function useMapMeasure(options: { map: Ref<Map | null> }) {
  const active = ref<MeasureType | null>(null);
  const source = new VectorSource();
  const layer = new VectorLayer({
    source,
    zIndex: MAP_LAYER_ZINDEX.overlay,
    style: new Style({
      stroke: new Stroke({ color: '#fa8c16', width: 2.5, lineDash: [6, 6] }),
      fill: new Fill({ color: 'rgba(250, 140, 22, 0.12)' }),
      image: new CircleStyle({ radius: 4, fill: new Fill({ color: '#fa8c16' }) }),
    }),
  });

  let draw: Draw | null = null;
  let tipEl: HTMLDivElement | null = null;
  let tipOverlay: Overlay | null = null;
  let changeKey: EventsKey | null = null;

  function ensureLayer(map: Map) {
    if (!map.getLayers().getArray().includes(layer)) map.addLayer(layer);
  }

  function ensureTip(map: Map) {
    if (tipOverlay) return;
    tipEl = document.createElement('div');
    tipEl.className = 'tianditu-measure-tip';
    tipOverlay = new Overlay({ element: tipEl, offset: [0, -12], positioning: 'bottom-center', stopEvent: false });
    map.addOverlay(tipOverlay);
  }

  function describe(geom: Geometry): { text: string; anchor: number[] } | null {
    if (geom instanceof Polygon) {
      return { text: formatArea(geom), anchor: geom.getInteriorPoint().getCoordinates() };
    }
    if (geom instanceof LineString) {
      return { text: formatLength(geom), anchor: geom.getLastCoordinate() };
    }
    return null;
  }

  function stopDraw() {
    const map = options.map.value;
    if (draw && map) map.removeInteraction(draw);
    draw = null;
    if (changeKey) { unByKey(changeKey); changeKey = null; }
    active.value = null;
  }

  function start(type: MeasureType) {
    const map = options.map.value;
    if (!map) return;
    stopDraw();
    ensureLayer(map);
    ensureTip(map);
    // 每次开始新测量先清掉上一段图形与数值气泡，避免旧结果与新测量并存造成混淆
    source.clear();
    tipOverlay?.setPosition(undefined);
    active.value = type;

    draw = new Draw({ source, type: type === 'line' ? 'LineString' : 'Polygon' });
    map.addInteraction(draw);

    draw.on('drawstart', (e) => {
      const geom = e.feature.getGeometry();
      if (!geom) return;
      changeKey = geom.on('change', () => {
        const d = describe(geom);
        if (d && tipEl && tipOverlay) {
          tipEl.innerHTML = d.text;
          tipOverlay.setPosition(d.anchor);
        }
      });
    });

    draw.on('drawend', () => {
      if (changeKey) { unByKey(changeKey); changeKey = null; }
      stopDraw();
    });
  }

  function clear() {
    stopDraw();
    source.clear();
    tipOverlay?.setPosition(undefined);
  }

  watch(() => options.map.value, (m) => { if (m) ensureLayer(m); });

  onBeforeUnmount(() => {
    clear();
    const map = options.map.value;
    if (map) {
      map.removeLayer(layer);
      if (tipOverlay) map.removeOverlay(tipOverlay);
    }
  });

  return { layer: shallowRef(layer), active, start, clear };
}

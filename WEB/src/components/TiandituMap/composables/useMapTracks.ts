import { onBeforeUnmount, ref, shallowRef, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import LineString from 'ol/geom/LineString';
import type Map from 'ol/Map';
import { toMercator } from '../core/coordUtils';
import { createTrackLineStyle, createTrackPlayedStyle, createCircleMarkerStyle } from '../core/markerStyles';
import { MAP_LAYER_ZINDEX } from '../constants';
import type { MapTrackSession } from '../types';

export interface UseMapTracksOptions {
  map: Ref<Map | null>;
}

export function useMapTracks(options: UseMapTracksOptions) {
  const sessions = ref<MapTrackSession[]>([]);
  const playing = ref(false);
  const playProgress = ref(0);
  const currentIndex = ref(0);

  const source = new VectorSource();
  const layer = new VectorLayer({
    source,
    zIndex: MAP_LAYER_ZINDEX.track,
  });

  let playTimer: ReturnType<typeof requestAnimationFrame> | null = null;
  let playStartTime = 0;
  let playDurationMs = 0;
  let activeSession: MapTrackSession | null = null;
  let headFeature: Feature<Point> | null = null;
  let fullLineFeature: Feature<LineString> | null = null;
  let playedLineFeature: Feature<LineString> | null = null;

  function clearTrackLayers() {
    source.clear();
    headFeature = null;
    fullLineFeature = null;
    playedLineFeature = null;
  }

  function renderSession(session: MapTrackSession) {
    clearTrackLayers();
    if (session.points.length === 0) return;

    const coords = session.points.map((p) => toMercator(p.lng, p.lat));
    fullLineFeature = new Feature({ geometry: new LineString(coords) });
    fullLineFeature.setStyle(createTrackLineStyle(session.color));

    playedLineFeature = new Feature({ geometry: new LineString([coords[0]]) });
    playedLineFeature.setStyle(createTrackPlayedStyle('#1677ff'));

    headFeature = new Feature({ geometry: new Point(coords[0]) });
    headFeature.setStyle(createCircleMarkerStyle({ color: '#1677ff', radius: 10 }));

    source.addFeatures([fullLineFeature, playedLineFeature, headFeature]);
  }

  function setSessions(list: MapTrackSession[]) {
    sessions.value = list;
    stopPlayback();
    if (list.length > 0) {
      activeSession = list[0];
      renderSession(list[0]);
    } else {
      activeSession = null;
      clearTrackLayers();
    }
  }

  function selectSession(sessionId: string) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session) return;
    stopPlayback();
    activeSession = session;
    renderSession(session);
  }

  function stopPlayback() {
    playing.value = false;
    playProgress.value = 0;
    currentIndex.value = 0;
    if (playTimer != null) {
      cancelAnimationFrame(playTimer);
      playTimer = null;
    }
  }

  function startPlayback(speed = 1) {
    if (!activeSession || activeSession.points.length < 2) return;
    stopPlayback();
    playing.value = true;

    const points = activeSession.points;
    playDurationMs = Math.max(3000, points.length * 200) / speed;
    playStartTime = performance.now();

    const tick = (now: number) => {
      if (!playing.value || !activeSession || !headFeature || !playedLineFeature) return;

      const elapsed = now - playStartTime;
      const ratio = Math.min(1, elapsed / playDurationMs);
      playProgress.value = ratio;

      const floatIndex = ratio * (points.length - 1);
      const idx = Math.floor(floatIndex);
      currentIndex.value = idx;

      const playedCoords = points.slice(0, idx + 1).map((p) => toMercator(p.lng, p.lat));
      if (idx < points.length - 1) {
        const a = points[idx];
        const b = points[idx + 1];
        const t = floatIndex - idx;
        const interpLng = a.lng + (b.lng - a.lng) * t;
        const interpLat = a.lat + (b.lat - a.lat) * t;
        playedCoords.push(toMercator(interpLng, interpLat));
        headFeature.getGeometry()?.setCoordinates(toMercator(interpLng, interpLat));
      } else {
        const last = points[points.length - 1];
        headFeature.getGeometry()?.setCoordinates(toMercator(last.lng, last.lat));
      }

      playedLineFeature.getGeometry()?.setCoordinates(playedCoords);

      if (ratio >= 1) {
        playing.value = false;
        return;
      }
      playTimer = requestAnimationFrame(tick);
    };

    playTimer = requestAnimationFrame(tick);
  }

  function attach() {
    options.map.value?.addLayer(layer);
  }

  function detach() {
    stopPlayback();
    options.map.value?.removeLayer(layer);
  }

  // 与 useMapMarkers 一致：组件卸载时停止回放并移除图层，避免 rAF 循环泄漏
  onBeforeUnmount(detach);

  return {
    layer: shallowRef(layer),
    sessions,
    playing,
    playProgress,
    currentIndex,
    setSessions,
    selectSession,
    startPlayback,
    stopPlayback,
    attach,
    detach,
  };
}

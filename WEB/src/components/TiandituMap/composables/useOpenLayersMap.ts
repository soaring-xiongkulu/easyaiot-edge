import { onBeforeUnmount, ref, shallowRef, type Ref } from 'vue';
import Map from 'ol/Map';
import View from 'ol/View';
import { FullScreen, OverviewMap, ScaleLine, Zoom } from 'ol/control';
import { fromLonLat } from 'ol/proj';
import type { MapBrowserEvent } from 'ol';
import type BaseLayer from 'ol/layer/Base';
import { createTiandituBaseLayers } from '../core/tiandituLayers';
import { toWgs84 } from '../core/coordUtils';
import {
  DEFAULT_MAP_CENTER,
  DEFAULT_MAP_ZOOM,
  TIANDITU_MIN_ZOOM,
  TIANDITU_VIEW_MAX_ZOOM,
} from '../constants';
import type { LngLat, TiandituBaseMapType } from '../types';

const MIN_MAP_PX = 8;

export interface UseOpenLayersMapOptions {
  center?: [number, number];
  zoom?: number;
  baseMapType?: TiandituBaseMapType;
  showScaleLine?: boolean;
  /** 缩放 +/- 按钮（默认开） */
  showZoom?: boolean;
  /** 全屏按钮（默认开） */
  showFullScreen?: boolean;
  /** 鹰眼/缩略图（默认关，弹窗等小地图不建议开） */
  showOverview?: boolean;
  onClick?: (payload: LngLat & { mercator: [number, number] }) => void;
  onReady?: () => void;
}

export function useOpenLayersMap(
  containerRef: Ref<HTMLElement | null | undefined>,
  options: UseOpenLayersMapOptions = {},
) {
  const map = shallowRef<Map | null>(null);
  const baseMapType = ref<TiandituBaseMapType>(options.baseMapType ?? 'vec');
  let baseLayers: BaseLayer[] = [];
  const overlayLayers: BaseLayer[] = [];
  let resizeObserver: ResizeObserver | null = null;
  let readyNotified = false;

  function mapShellEl(): HTMLElement | null {
    const el = containerRef.value;
    if (!el) return null;
    return (el.closest('.basic-tianditu-map') as HTMLElement | null) ?? el.parentElement;
  }

  /** 弹窗地图区（与 DeviceLocationDrawer geo-loc__map-area 一致） */
  function mapHostEl(): HTMLElement | null {
    const el = containerRef.value;
    if (!el) return null;
    return (
      el.closest('.geo-loc__map-area')
      ?? el.closest('.map-location-picker__map')
      ?? el.closest('.alert-device-map__map')
      ?? mapShellEl()
    );
  }

  function readContainerSize(): { width: number; height: number } {
    const el = containerRef.value;
    if (!el) return { width: 0, height: 0 };

    const host = mapHostEl();
    const hostRect = host?.getBoundingClientRect();
    if (hostRect && hostRect.width > MIN_MAP_PX && hostRect.height > MIN_MAP_PX) {
      return { width: hostRect.width, height: hostRect.height };
    }

    const shell = mapShellEl();
    const shellRect = shell?.getBoundingClientRect();
    if (shellRect && shellRect.width > MIN_MAP_PX && shellRect.height > MIN_MAP_PX) {
      return { width: shellRect.width, height: shellRect.height };
    }

    const rect = el.getBoundingClientRect();
    return { width: rect.width, height: rect.height };
  }

  function isContainerReady(): boolean {
    const { width, height } = readContainerSize();
    return width > MIN_MAP_PX && height > MIN_MAP_PX;
  }

  /** 画布随外壳 100% 伸缩，勿写死 px（否则弹窗未撑满时只出一角瓦片、其余灰底） */
  function syncContainerPixels() {
    const el = containerRef.value;
    if (!el) return;
    el.style.width = '100%';
    el.style.height = '100%';
    el.style.minWidth = '0';
    el.style.minHeight = '0';
  }

  function notifyReadyOnce() {
    if (readyNotified) return;
    readyNotified = true;
    options.onReady?.();
  }

  function updateSize() {
    if (!map.value || !isContainerReady()) return;
    syncContainerPixels();
    map.value.updateSize();
  }

  function bindResizeObserver() {
    const el = containerRef.value;
    if (!el || resizeObserver) return;

    resizeObserver = new ResizeObserver(() => {
      if (!map.value) {
        tryInitMap();
        return;
      }
      updateSize();
    });

    resizeObserver.observe(el);
    const shell = mapShellEl();
    if (shell && shell !== el) resizeObserver.observe(shell);

    const host = mapHostEl();
    if (host && host !== el && host !== shell) resizeObserver.observe(host);

    let parent = host?.parentElement ?? shell?.parentElement;
    for (let i = 0; i < 6 && parent; i += 1) {
      resizeObserver.observe(parent);
      parent = parent.parentElement;
    }
  }

  function buildControls() {
    const controls: Array<ScaleLine | Zoom | FullScreen | OverviewMap> = [];
    if (options.showZoom !== false) controls.push(new Zoom());
    if (options.showScaleLine !== false) controls.push(new ScaleLine());
    if (options.showFullScreen !== false) {
      controls.push(new FullScreen({ tipLabel: '全屏 / 退出全屏' }));
    }
    if (options.showOverview) {
      controls.push(new OverviewMap({
        collapsed: true,
        tipLabel: '鹰眼',
        layers: createTiandituBaseLayers('vec').slice(0, 1),
      }));
    }
    return controls;
  }

  function initMap() {
    if (!containerRef.value || map.value) return false;
    if (!isContainerReady()) return false;

    syncContainerPixels();

    baseLayers = createTiandituBaseLayers(baseMapType.value);
    const olMap = new Map({
      target: containerRef.value,
      layers: [...baseLayers],
      view: new View({
        center: fromLonLat(options.center ?? DEFAULT_MAP_CENTER),
        zoom: options.zoom ?? DEFAULT_MAP_ZOOM,
        projection: 'EPSG:3857',
        minZoom: TIANDITU_MIN_ZOOM,
        maxZoom: TIANDITU_VIEW_MAX_ZOOM,
      }),
      controls: buildControls(),
    });

    if (options.onClick) {
      olMap.on('singleclick', (evt: MapBrowserEvent<UIEvent>) => {
        const mercator = evt.coordinate as [number, number];
        const wgs = toWgs84(mercator);
        options.onClick?.({ ...wgs, mercator });
      });
    }

    map.value = olMap;
    bindResizeObserver();
    requestAnimationFrame(() => {
      updateSize();
      requestAnimationFrame(() => {
        updateSize();
        notifyReadyOnce();
      });
    });
    return true;
  }

  function tryInitMap() {
    if (map.value) {
      updateSize();
      return true;
    }
    return initMap();
  }

  let labelVisible = true;

  function switchBaseMap(type: TiandituBaseMapType) {
    if (!map.value) return;
    baseMapType.value = type;

    baseLayers.forEach((layer) => map.value!.removeLayer(layer));
    baseLayers = createTiandituBaseLayers(type);
    baseLayers.forEach((layer, index) => {
      if (layer.get('tdtRole') === 'label') layer.setVisible(labelVisible);
      map.value!.getLayers().insertAt(index, layer);
    });
  }

  /** 注记层显隐（地名/道路注记开关） */
  function setLabelVisible(visible: boolean) {
    labelVisible = visible;
    baseLayers.forEach((layer) => {
      if (layer.get('tdtRole') === 'label') layer.setVisible(visible);
    });
  }

  /** 复位到默认中心/缩放 */
  function resetView(duration = 400) {
    map.value?.getView().animate({
      center: fromLonLat(options.center ?? DEFAULT_MAP_CENTER),
      zoom: options.zoom ?? DEFAULT_MAP_ZOOM,
      duration,
    });
  }

  function addOverlayLayer(layer: BaseLayer) {
    if (!map.value) return;
    overlayLayers.push(layer);
    map.value.addLayer(layer);
  }

  function removeOverlayLayer(layer: BaseLayer) {
    if (!map.value) return;
    map.value.removeLayer(layer);
    const idx = overlayLayers.indexOf(layer);
    if (idx >= 0) overlayLayers.splice(idx, 1);
  }

  function flyTo(lng: number, lat: number, zoom = 15, duration = 500) {
    map.value?.getView().animate({
      center: fromLonLat([lng, lat]),
      zoom,
      duration,
    });
  }

  function fitExtent(extent: [number, number, number, number], padding = 60) {
    map.value?.getView().fit(extent, { padding: [padding, padding, padding, padding], duration: 400, maxZoom: 16 });
  }

  onBeforeUnmount(() => {
    resizeObserver?.disconnect();
    resizeObserver = null;
    map.value?.setTarget(undefined);
    map.value = null;
    readyNotified = false;
  });

  return {
    map,
    baseMapType,
    initMap,
    tryInitMap,
    updateSize,
    switchBaseMap,
    setLabelVisible,
    resetView,
    addOverlayLayer,
    removeOverlayLayer,
    flyTo,
    fitExtent,
  };
}

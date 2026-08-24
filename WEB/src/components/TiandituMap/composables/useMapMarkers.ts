import { onBeforeUnmount, ref, shallowRef, watch, type Ref } from 'vue';
import VectorLayer from 'ol/layer/Vector';
import VectorSource from 'ol/source/Vector';
import Cluster from 'ol/source/Cluster';
import Feature from 'ol/Feature';
import Point from 'ol/geom/Point';
import LineString from 'ol/geom/LineString';
import Overlay from 'ol/Overlay';
import type Map from 'ol/Map';
import type { EventsKey } from 'ol/events';
import { unByKey } from 'ol/Observable';
import { boundingExtent } from 'ol/extent';
import { fromLonLat } from 'ol/proj';
import { toMercator } from '../core/coordUtils';
import { createClusterLeaderLineStyle, styleForCluster, styleForMarkerKind } from '../core/markerStyles';
import {
  CAMERA_STRUCTURE_LABEL,
  positionTypeText,
  roomTypeText,
  supplyLightText,
  useTypeText,
} from '../core/gb28181Catalog';
import { DEFAULT_MAP_CENTER, DEFAULT_MAP_ZOOM, MAP_LAYER_ZINDEX } from '../constants';
import type { MapHoverInfo, MapMarkerData } from '../types';

export interface UseMapMarkersOptions {
  map: Ref<Map | null>;
  onMarkerClick?: (marker: MapMarkerData) => void;
  /** 启用点聚合（默认 true） */
  enableCluster?: boolean | Ref<boolean>;
  /** 聚合像素距离 */
  clusterDistance?: number;
  /** 是否在标记旁显示文字标题（默认 true；告警地图关闭以保持清爽，详情走点击气泡） */
  showLabels?: boolean;
  /** 点击展开(spiderfy)的叶子后是否自动收起：true=选完即收起；false(默认)=保持展开便于连续查看 */
  collapseSpiderOnSelect?: boolean | Ref<boolean>;
  /** 悬浮命中(摄像头/聚合簇)/离开的回调（info=null 表示离开），用于外部渲染悬浮提示 */
  onHover?: (info: MapHoverInfo | null, coord: number[] | null) => void;
  /** 禁用点击文字气泡（告警图改用悬浮卡片，点击仅选中） */
  disableClickPopup?: boolean;
}

function resolveBool(option: boolean | Ref<boolean> | undefined, fallback: boolean): boolean {
  if (option == null) return fallback;
  return typeof option === 'boolean' ? option : option.value;
}

function resolveClusterEnabled(option?: boolean | Ref<boolean>): boolean {
  if (option == null) return true;
  if (typeof option === 'boolean') return option;
  return option.value;
}

function layerOnMap(olMap: Map, targetLayer: VectorLayer<VectorSource>) {
  return olMap.getLayers().getArray().includes(targetLayer);
}

/** 展开叶子从原要素复制的属性（供图标样式与 featureToMarker 解析） */
const SPIDER_LEAF_PROPS = ['id', 'kind', 'online', 'title', 'heading', 'count', 'cameraStructure'] as const;

export function useMapMarkers(options: UseMapMarkersOptions) {
  const markers = ref<MapMarkerData[]>([]);
  const selectedId = ref<string | null>(null);
  const vectorSource = new VectorSource();
  const clusterSource = new Cluster({
    distance: options.clusterDistance ?? 40,
    source: vectorSource,
  });

  function activeSource(): VectorSource | Cluster {
    return resolveClusterEnabled(options.enableCluster) ? clusterSource : vectorSource;
  }

  /** 单个要素(摄像头/告警/展开后的叶子)的图标样式 */
  function styleSingleFeature(target: Feature) {
    const kind = target.get('kind') as MapMarkerData['kind'];
    const online = target.get('online') as boolean | undefined;
    const title = target.get('title') as string | undefined;
    const heading = target.get('heading') as number | null | undefined;
    const count = target.get('count') as number | undefined;
    const structure = target.get('cameraStructure') as MapMarkerData['cameraStructure'];
    const label = options.showLabels === false ? undefined : title;
    return styleForMarkerKind(kind, online, label, heading, count, structure ?? 'unknown');
  }

  const layer = new VectorLayer({
    source: activeSource(),
    zIndex: MAP_LAYER_ZINDEX.marker,
    style: (feature) => {
      const innerFeatures = feature.get('features') as Feature[] | undefined;
      if (innerFeatures && innerFeatures.length > 1) {
        // 簇内告警总数：让含告警的聚合点在收拢时也显红色徽标
        const alertSum = innerFeatures.reduce((s, f) => s + (Number(f.get('count')) || 0), 0);
        return styleForCluster(innerFeatures.length, alertSum);
      }
      return styleSingleFeature(innerFeatures?.[0] ?? feature);
    },
  });

  // 展开层(spiderfy)：同坐标聚合点点击后，把成员沿环形铺开成真实图标 + 引导线
  const spiderSource = new VectorSource();
  const leaderLineStyle = createClusterLeaderLineStyle();
  const spiderLayer = new VectorLayer({
    source: spiderSource,
    zIndex: MAP_LAYER_ZINDEX.marker + 1,
    style: (f) => (f.getGeometry()?.getType() === 'LineString' ? leaderLineStyle : styleSingleFeature(f)),
  });
  let spiderActive = false;
  let moveEndKey: EventsKey | null = null;

  let attachedMap: Map | null = null;
  let popupOverlay: Overlay | null = null;
  let popupEl: HTMLDivElement | null = null;
  let clickListenerKey: EventsKey | null = null;
  let pointerMoveKey: EventsKey | null = null;
  let lastHoverKey: string | null = null;

  function syncClusterSource() {
    const useCluster = resolveClusterEnabled(options.enableCluster);
    layer.setSource(useCluster ? clusterSource : vectorSource);
  }

  function featureToMarker(feature: Feature): MapMarkerData | undefined {
    const id = feature.get('id') as string;
    return markers.value.find((m) => m.id === id);
  }

  function teardownOnMap(olMap: Map) {
    hidePopup();
    unspiderfy();
    if (layerOnMap(olMap, layer)) {
      olMap.removeLayer(layer);
    }
    if (olMap.getLayers().getArray().includes(spiderLayer)) {
      olMap.removeLayer(spiderLayer);
    }
    if (popupOverlay) {
      olMap.removeOverlay(popupOverlay);
      popupOverlay = null;
      popupEl = null;
    }
    if (clickListenerKey) {
      unByKey(clickListenerKey);
      clickListenerKey = null;
    }
    if (moveEndKey) {
      unByKey(moveEndKey);
      moveEndKey = null;
    }
    if (pointerMoveKey) {
      unByKey(pointerMoveKey);
      pointerMoveKey = null;
    }
    lastHoverKey = null;
  }

  function ensurePopup(olMap: Map) {
    if (popupOverlay) return;
    popupEl = document.createElement('div');
    popupEl.className = 'tianditu-map-popup';
    popupOverlay = new Overlay({
      element: popupEl,
      positioning: 'bottom-center',
      offset: [0, -12],
      stopEvent: false,
    });
    olMap.addOverlay(popupOverlay);
    clickListenerKey = olMap.on('singleclick', handleMapClick);
    // 视图移动/缩放后展开的叶子会与真实位置错位，收起即可
    moveEndKey = olMap.on('moveend', unspiderfy);
    // 悬浮检测：命中单个标记/叶子 → onHover(marker, 坐标)；离开 → onHover(null)
    if (options.onHover) {
      pointerMoveKey = olMap.on('pointermove', handlePointerMove);
    }
  }

  function emitHoverLeave() {
    if (lastHoverKey !== null) {
      lastHoverKey = null;
      options.onHover?.(null, null);
    }
  }

  function handlePointerMove(evt: { pixel: number[]; dragging?: boolean }) {
    const olMap = options.map.value;
    if (!olMap || evt.dragging) return;
    const feature = olMap.forEachFeatureAtPixel(evt.pixel, (f) => f) as Feature | undefined;
    // 命中任何标记/聚合簇(都可点)即变手型
    olMap.getViewport().style.cursor = feature ? 'pointer' : '';
    if (!options.onHover) return;
    if (!feature) { emitHoverLeave(); return; }

    const inner = feature.get('features') as Feature[] | undefined;

    // 聚合簇：报数量+告警数+本次点击是"放大"还是"展开"，供外部提示，消除点击歧义
    if (inner && inner.length > 1 && !feature.get('__spiderLeaf')) {
      const count = inner.length;
      const alertCount = inner.reduce((s, f) => s + (Number(f.get('count')) || 0), 0);
      const coords = inner
        .map((f) => (f.getGeometry() as Point | undefined)?.getCoordinates())
        .filter(Boolean) as number[][];
      const ext = boundingExtent(coords);
      const view = olMap.getView();
      const sameSpot = ext[2] - ext[0] < 1 && ext[3] - ext[1] < 1;
      const nearMax = (view.getZoom() ?? 0) >= view.getMaxZoom() - 0.5;
      const coord = (feature.getGeometry() as Point | undefined)?.getCoordinates() ?? null;
      const key = `c:${count}:${coord ? `${Math.round(coord[0])},${Math.round(coord[1])}` : ''}`;
      if (key !== lastHoverKey) {
        lastHoverKey = key;
        options.onHover({ type: 'cluster', count, alertCount, canZoom: !sameSpot && !nearMax }, coord);
      }
      return;
    }

    // 单个标记 / spider 叶子
    const target = feature.get('__spiderLeaf') ? feature : (inner?.[0] ?? feature);
    const marker = featureToMarker(target);
    if (!marker) { emitHoverLeave(); return; }
    const key = `m:${marker.id}`;
    if (key === lastHoverKey) return; // 同一标记内移动不重复触发
    lastHoverKey = key;
    const coord = (target.getGeometry() as Point | undefined)?.getCoordinates() ?? null;
    options.onHover({ type: 'camera', marker }, coord);
  }

  /** 收起 spiderfy 展开 */
  function unspiderfy() {
    if (!spiderActive) return;
    spiderSource.clear();
    spiderActive = false;
  }

  /**
   * 计算各叶子相对中心的像素偏移：
   * 成员少时为单环；多时自动按「多层同心环」由内向外铺开（每环容量随半径增大），
   * 避免一圈塞太多互相压盖。每环带角度偏移，叶子不会沿径向对齐。
   */
  function computeSpiderOffsets(n: number): Array<[number, number]> {
    const RING_STEP = 46; // 相邻环半径间距(px)
    const LEAF_SPACING = 38; // 同环相邻叶子最小弧距(px)
    const offsets: Array<[number, number]> = [];
    let placed = 0;
    let ring = 1;
    while (placed < n) {
      const radius = RING_STEP * ring;
      const capacity = Math.max(1, Math.floor((2 * Math.PI * radius) / LEAF_SPACING));
      const take = Math.min(capacity, n - placed);
      const ringOffset = ring * 0.5; // 每环错开一点，视觉更舒展
      for (let i = 0; i < take; i += 1) {
        const angle = (i / take) * 2 * Math.PI - Math.PI / 2 + ringOffset;
        offsets.push([radius * Math.cos(angle), radius * Math.sin(angle)]);
      }
      placed += take;
      ring += 1;
    }
    return offsets;
  }

  /** 把同坐标聚合点的成员铺开成可点选的真实图标(含引导线) */
  function spiderfy(center: number[], inner: Feature[]) {
    const olMap = options.map.value;
    if (!olMap) return;
    unspiderfy();
    const px = olMap.getPixelFromCoordinate(center);
    if (!px) return;
    const offsets = computeSpiderOffsets(inner.length);
    const feats: Feature[] = [];
    inner.forEach((src, i) => {
      const [dx, dy] = offsets[i];
      const leafCoord = olMap.getCoordinateFromPixel([px[0] + dx, px[1] + dy]);
      feats.push(new Feature({ geometry: new LineString([center, leafCoord]) }));
      const leaf = new Feature({ geometry: new Point(leafCoord) });
      SPIDER_LEAF_PROPS.forEach((k) => leaf.set(k, src.get(k)));
      leaf.set('__spiderLeaf', true);
      feats.push(leaf);
    });
    spiderSource.addFeatures(feats);
    spiderActive = true;
  }

  function selectFeatureMarker(target: Feature) {
    const marker = featureToMarker(target);
    if (!marker) return;
    selectedId.value = marker.id;
    if (!options.disableClickPopup) showPopup(marker);
    options.onMarkerClick?.(marker);
  }

  function handleMapClick(evt: { pixel: number[] }) {
    const olMap = options.map.value;
    if (!olMap) return;
    const feature = olMap.forEachFeatureAtPixel(evt.pixel, (f) => f) as Feature | undefined;
    if (!feature) {
      unspiderfy();
      hidePopup();
      return;
    }

    // 点中展开出来的叶子 → 直接选中其对应设备；按配置决定是否随即收起
    if (feature.get('__spiderLeaf')) {
      selectFeatureMarker(feature);
      if (resolveBool(options.collapseSpiderOnSelect, false)) unspiderfy();
      return;
    }

    const innerFeatures = feature.get('features') as Feature[] | undefined;
    if (innerFeatures && innerFeatures.length > 1) {
      const coords = innerFeatures
        .map((f) => (f.getGeometry() as Point | undefined)?.getCoordinates())
        .filter(Boolean) as number[][];
      if (!coords.length) return;
      const extent = boundingExtent(coords);
      const view = olMap.getView();
      // 同坐标(范围≈0) 或已接近最大缩放 → 放大也分不开，改为环形展开
      const sameSpot = extent[2] - extent[0] < 1 && extent[3] - extent[1] < 1;
      const nearMaxZoom = (view.getZoom() ?? 0) >= view.getMaxZoom() - 0.5;
      if (sameSpot || nearMaxZoom) {
        spiderfy((feature.getGeometry() as Point).getCoordinates(), innerFeatures);
      } else {
        unspiderfy();
        view.fit(extent, {
          padding: [80, 80, 80, 80],
          duration: 350,
          maxZoom: (view.getZoom() ?? 10) + 2,
        });
      }
      return;
    }

    unspiderfy();
    selectFeatureMarker(innerFeatures?.[0] ?? feature);
  }

  function escapeHtml(s: string): string {
    return s.replace(/[&<>"']/g, (c) => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', '\'': '&#39;' }[c] as string
    ));
  }

  /** 摄像头 popup 的 GB28181 属性标签行（结构/室内外/补光/分辨率 + 用途/位置类型） */
  function popupMetaHtml(marker: MapMarkerData): string {
    if (marker.kind !== 'camera') return '';
    const line1 = [
      CAMERA_STRUCTURE_LABEL[marker.cameraStructure ?? 'unknown'],
      roomTypeText(marker.roomType),
      supplyLightText(marker.supplyLightType),
      marker.resolution || '',
    ].filter(Boolean);
    const line2 = [useTypeText(marker.useType), positionTypeText(marker.positionType)].filter(Boolean);
    const rows: string[] = [];
    if (line1.length) rows.push(`<div class="tianditu-map-popup__meta">${escapeHtml(line1.join(' · '))}</div>`);
    if (line2.length) rows.push(`<div class="tianditu-map-popup__tags">${escapeHtml(line2.join(' / '))}</div>`);
    return rows.join('');
  }

  function showPopup(marker: MapMarkerData) {
    const olMap = options.map.value;
    if (!olMap) return;
    ensurePopup(olMap);
    if (!popupEl || !popupOverlay) return;
    // 设备名/地址来自后端，转义后再插入，避免内容含 < 等字符破坏结构或注入
    const title = escapeHtml(String(marker.title || marker.id));
    const sub = marker.subtitle ? escapeHtml(String(marker.subtitle)) : '';
    popupEl.innerHTML = `
      <div class="tianditu-map-popup__title">${title}</div>
      ${sub ? `<div class="tianditu-map-popup__sub">${sub}</div>` : ''}
      ${popupMetaHtml(marker)}
    `;
    popupOverlay.setPosition(toMercator(marker.lng, marker.lat));
  }

  function hidePopup() {
    popupOverlay?.setPosition(undefined);
    selectedId.value = null;
  }

  function setMarkers(list: MapMarkerData[]) {
    markers.value = list;
    vectorSource.clear();
    const features = list.map((item) => {
      const feature = new Feature({
        geometry: new Point(toMercator(item.lng, item.lat)),
      });
      feature.set('id', item.id);
      feature.set('kind', item.kind ?? 'custom');
      feature.set('online', item.online);
      feature.set('title', item.title);
      feature.set('heading', item.heading ?? null);
      feature.set('count', item.count ?? 0);
      feature.set('cameraStructure', item.cameraStructure ?? 'unknown');
      return feature;
    });
    vectorSource.addFeatures(features);
    syncClusterSource();
    unspiderfy(); // 数据刷新后旧的展开叶子已失效
    // 选中点被新集合过滤掉时，关闭其残留 popup，避免悬空显示旧内容
    if (selectedId.value && !list.some((m) => m.id === selectedId.value)) {
      hidePopup();
    }
  }

  function fitToMarkers(padding = 60) {
    const olMap = options.map.value;
    if (!olMap) return;
    const view = olMap.getView();

    if (markers.value.length === 0) {
      view.animate({
        center: fromLonLat(DEFAULT_MAP_CENTER),
        zoom: DEFAULT_MAP_ZOOM,
        duration: 400,
      });
      return;
    }

    if (markers.value.length === 1) {
      const m = markers.value[0];
      view.animate({
        center: fromLonLat([m.lng, m.lat]),
        zoom: 15,
        duration: 400,
      });
      return;
    }

    const coords = markers.value.map((m) => toMercator(m.lng, m.lat));
    const extent = boundingExtent(coords);
    const w = extent[2] - extent[0];
    const h = extent[3] - extent[1];
    if (w < 10 || h < 10) {
      view.animate({
        center: [(extent[0] + extent[2]) / 2, (extent[1] + extent[3]) / 2],
        zoom: 15,
        duration: 400,
      });
      return;
    }
    view.fit(extent, { padding: [padding, padding, padding, padding], duration: 400, maxZoom: 16 });
  }

  function attach() {
    const olMap = options.map.value;
    if (!olMap) return;

    if (attachedMap === olMap && layerOnMap(olMap, layer)) {
      syncClusterSource();
      return;
    }

    if (attachedMap && attachedMap !== olMap) {
      teardownOnMap(attachedMap);
    }

    syncClusterSource();
    if (!layerOnMap(olMap, layer)) {
      olMap.addLayer(layer);
    }
    if (!olMap.getLayers().getArray().includes(spiderLayer)) {
      olMap.addLayer(spiderLayer);
    }
    attachedMap = olMap;
    ensurePopup(olMap);
  }

  function detach() {
    if (attachedMap) {
      teardownOnMap(attachedMap);
      attachedMap = null;
    }
  }

  watch(
    () => options.map.value,
    (olMap, prevMap) => {
      if (olMap) {
        attach();
      } else if (prevMap) {
        teardownOnMap(prevMap);
        attachedMap = null;
      }
    },
    { immediate: true },
  );

  if (options.enableCluster && typeof options.enableCluster !== 'boolean') {
    watch(options.enableCluster, syncClusterSource);
  }

  onBeforeUnmount(detach);

  return {
    layer: shallowRef(layer),
    markers,
    selectedId,
    setMarkers,
    fitToMarkers,
    showPopup,
    hidePopup,
    attach,
    detach,
  };
}

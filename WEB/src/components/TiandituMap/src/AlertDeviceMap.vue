<script setup lang="ts">
import { Spin } from 'ant-design-vue';
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import dayjs from 'dayjs';
import Overlay from 'ol/Overlay';
import BasicTiandituMap from './BasicTiandituMap.vue';
import AlertMapFloatLayer from './components/AlertMapFloatLayer.vue';
import CameraAlertCard from './components/CameraAlertCard.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useMapHeatmap } from '../composables/useMapHeatmap';
import { useMapMeasure } from '../composables/useMapMeasure';
import { useMapSpatialQuery } from '../composables/useMapSpatialQuery';
import { useMapPulse } from '../composables/useMapPulse';
import { useMapDisplayFilters } from '../composables/useMapDisplayFilters';
import { useAlertMapData, type AlertMapQuery } from '../business/useAlertMapData';
import { useMessage } from '@/hooks/web/useMessage';
import type { AlertMapItem, MapHoverInfo, MapMarkerData, TiandituBaseMapType } from '../types';

const props = withDefaults(defineProps<{
  query?: AlertMapQuery;
  showCameras?: boolean;
  showAlerts?: boolean;
  height?: string;
  enableCluster?: boolean;
  /** 显示告警热力图层 */
  showHeat?: boolean;
  /** 同坐标聚合点展开后，点击叶子是否自动收起（默认 false=保持展开便于连续查看） */
  spiderfyCollapseOnSelect?: boolean;
  /** 嵌入全屏弹窗：去掉 Card 外壳，铺满地图区域 */
  embedded?: boolean;
}>(), {
  showCameras: true,
  showAlerts: true,
  height: '100%',
  enableCluster: true,
  showHeat: false,
  spiderfyCollapseOnSelect: false,
  embedded: false,
});

const cardBodyStyle = computed(() => ({
  padding: 0,
  height: props.height,
  minHeight: 0,
}));

const emit = defineEmits<{
  (e: 'marker-click', marker: MapMarkerData): void;
  (e: 'alert-click', alert: Record<string, unknown>): void;
}>();

const { createMessage } = useMessage();
const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const mapInstance = computed(() => mapRef.value?.map ?? null);
const baseMapType = ref<TiandituBaseMapType>('vec');
const alertData = useAlertMapData();

const markers = useMapMarkers({
  map: mapInstance,
  onMarkerClick: (m) => {
    emit('marker-click', m);
    if (m.kind === 'alert') emit('alert-click', m.payload || {});
  },
  enableCluster: computed(() => props.enableCluster),
  showLabels: false,
  collapseSpiderOnSelect: computed(() => props.spiderfyCollapseOnSelect),
  onHover: onMarkerHover,
  disableClickPopup: true, // 告警图用悬浮卡片替代点击文字气泡
});

// 悬浮提示：摄像头→告警卡片；聚合簇→数量/告警/操作提示。hover 打开、可悬停进卡片、移出延时关闭
const hoverCardEl = ref<HTMLElement | null>(null);
const hoverInfo = ref<MapHoverInfo | null>(null);
let hoverOverlay: Overlay | null = null;
let hideTimer: ReturnType<typeof setTimeout> | null = null;

const hoverCamera = computed<MapMarkerData | null>(() =>
  hoverInfo.value?.type === 'camera' ? hoverInfo.value.marker : null,
);
const hoverCluster = computed(() => (hoverInfo.value?.type === 'cluster' ? hoverInfo.value : null));
const hoverAlerts = computed<AlertMapItem[]>(() =>
  hoverCamera.value ? (alertData.alertsByDevice.value.get(hoverCamera.value.id) ?? []) : [],
);

function ensureHoverOverlay() {
  const m = mapInstance.value;
  if (!m || hoverOverlay || !hoverCardEl.value) return;
  hoverOverlay = new Overlay({
    element: hoverCardEl.value,
    positioning: 'bottom-center',
    offset: [0, -18],
    stopEvent: true,
  });
  m.addOverlay(hoverOverlay);
}

function clearHideTimer() {
  if (hideTimer) { clearTimeout(hideTimer); hideTimer = null; }
}
function scheduleHideHover() {
  clearHideTimer();
  hideTimer = setTimeout(() => {
    hoverInfo.value = null;
    hoverOverlay?.setPosition(undefined);
  }, 160);
}
function onMarkerHover(info: MapHoverInfo | null, coord: number[] | null) {
  if (info && coord) {
    clearHideTimer();
    hoverInfo.value = info;
    ensureHoverOverlay();
    placeHoverCard(coord);
  } else {
    scheduleHideHover();
  }
}

/** 按摄像头在视口中的位置自动选边：靠顶翻到下方、靠左右改对齐，避免卡片被裁剪；间隙取小贴近标记 */
function placeHoverCard(coord: number[]) {
  if (!hoverOverlay) return;
  const m = mapInstance.value;
  const px = m?.getPixelFromCoordinate(coord);
  const size = m?.getSize();
  if (!px || !size) {
    hoverOverlay.setPositioning('bottom-center');
    hoverOverlay.setOffset([0, -12]);
    hoverOverlay.setPosition(coord);
    return;
  }
  const [w] = size;
  const CARD_W = 260;
  const CARD_H = 300;
  const vert = px[1] < CARD_H + 16 ? 'top' : 'bottom';
  const horiz = px[0] > w - CARD_W / 2 - 8 ? 'right' : px[0] < CARD_W / 2 + 8 ? 'left' : 'center';
  const positioning = vert === 'bottom'
    ? (horiz === 'right' ? 'bottom-right' : horiz === 'left' ? 'bottom-left' : 'bottom-center')
    : (horiz === 'right' ? 'top-right' : horiz === 'left' ? 'top-left' : 'top-center');
  hoverOverlay.setPositioning(positioning);
  hoverOverlay.setOffset([0, vert === 'bottom' ? -12 : 18]); // 上方留小间隙；下方避开图标
  hoverOverlay.setPosition(coord);
}

const heatEnabled = ref(props.showHeat);
const showLabel = ref(true);
const { offlineOnly, categoryFilter, apply: applyDisplayFilters } = useMapDisplayFilters();
const heat = useMapHeatmap({ map: mapInstance, enabled: heatEnabled });
const measure = useMapMeasure({ map: mapInstance });
const pulse = useMapPulse({ map: mapInstance });
const spatialFilterIds = ref<string[] | null>(null);
const spatial = useMapSpatialQuery({
  map: mapInstance,
  getPoints: () => markerList.value.map((m) => ({ id: m.id, lng: m.lng, lat: m.lat })),
  onResult: (ids) => {
    spatialFilterIds.value = ids;
    applyMarkers();
    if (ids) createMessage.success(`框选范围内 ${ids.length} 个点位`);
  },
});

const activeTool = computed<string | null>(() => measure.active.value ?? spatial.active.value ?? null);

const markerList = computed(() => {
  if (props.showCameras && props.showAlerts) return alertData.toCombinedMarkers();
  if (props.showAlerts) return alertData.toAlertedCameraMarkers();
  if (props.showCameras) return alertData.toCameraMarkers();
  return [];
});

function parseAlertTime(t?: string): number {
  if (!t) return 0;
  const d = dayjs(t);
  return d.isValid() ? d.valueOf() : 0;
}

/** 时间最新的一条告警（用于"定位最新告警"，无论是否在近期窗口内） */
const latestAlert = computed(() => {
  const list = alertData.alertsWithLocation.value;
  if (!list.length) return null;
  return list.reduce((a, b) => (parseAlertTime(b.time) > parseAlertTime(a.time) ? b : a));
});

/**
 * 用于脉冲高亮的"近期"告警：相对当前时间 30 分钟内。
 * nowTick 每分钟推进一次，驱动该集合随时间收缩——过期告警自动停止脉冲，
 * 集合空后脉冲层无要素、动画循环自然停止，不会永久空转占 CPU。
 */
const RECENT_WINDOW_MS = 30 * 60 * 1000;
const nowTick = ref(dayjs().valueOf());
let pulseTimer: ReturnType<typeof setInterval> | null = null;

const pulseAlerts = computed(() => {
  const now = nowTick.value;
  return alertData.alertsWithLocation.value.filter(
    (a) => parseAlertTime(a.time) > 0 && now - parseAlertTime(a.time) <= RECENT_WINDOW_MS,
  );
});

watch(
  pulseAlerts,
  (list) => pulse.setPoints(list.map((a) => ({ lng: Number(a.lng), lat: Number(a.lat) }))),
  { immediate: true },
);

pulseTimer = setInterval(() => { nowTick.value = dayjs().valueOf(); }, 60 * 1000);
onBeforeUnmount(() => {
  if (pulseTimer) { clearInterval(pulseTimer); pulseTimer = null; }
  clearHideTimer();
});

function displayMarkers(): MapMarkerData[] {
  let list = markerList.value;
  const ids = spatialFilterIds.value;
  if (ids) {
    const idSet = new Set(ids); // includes() 在 filter 内是 O(n²)，用 Set 降到 O(n)
    list = list.filter((m) => idSet.has(m.id));
  }
  return applyDisplayFilters(list);
}

const offlineCount = computed(
  () => alertData.deviceData.devices.value.filter((d) => d.online === false).length,
);

watch([offlineOnly, categoryFilter], () => markers.setMarkers(displayMarkers()), { deep: true });

function applyMarkers() {
  markers.setMarkers(displayMarkers());
  // 热力点由 watch(heatEnabled) 驱动（仅热力开启时才重建要素，避免隐藏时空跑）
  // 脉冲点由 watch(pulseAlerts) 驱动（随时间收缩），此处无需重复设置
}

// 仅在热力层开启时喂点；告警集合变化时若已开启则刷新
watch(
  [heatEnabled, () => alertData.alertsWithLocation.value],
  () => {
    if (!heatEnabled.value) return;
    heat.setPoints(
      alertData.alertsWithLocation.value.map((a) => ({ lng: Number(a.lng), lat: Number(a.lat) })),
    );
  },
  { immediate: true },
);

async function refresh() {
  await alertData.loadAlerts(props.query);
  spatialFilterIds.value = null; // 重新加载数据时清除框选过滤
  applyMarkers();
  markers.fitToMarkers();
  await nextTick();
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
  requestAnimationFrame(() => {
    mapRef.value?.tryInitMap?.();
    mapRef.value?.updateSize?.();
  });
}

async function onMapReady() {
  await nextTick();
  mapRef.value?.updateSize?.();
  void refresh();
  requestAnimationFrame(() => mapRef.value?.updateSize?.());
  window.setTimeout(() => mapRef.value?.updateSize?.(), 200);
  window.setTimeout(() => mapRef.value?.updateSize?.(), 500);
}

function updateMapSize() {
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
}

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

watch(showLabel, (v) => {
  mapRef.value?.setLabelVisible?.(v);
});

// 数据加载由父级(AlertMapPanel)通过 refresh() 显式驱动，便于「相同查询强制刷新」
// 且避免与显式 refresh 重复触发；故不再监听 props.query 自动加载。
watch(() => [props.showCameras, props.showAlerts], () => {
  // 切换图层会改变 markerList，旧框选 id 可能已不在新集合中导致空屏，故先清掉框选
  spatial.clear();
  applyMarkers();
});

function flyTo(lng: number, lat: number, zoom = 16) {
  mapRef.value?.flyTo(lng, lat, zoom);
}

function handleFitAll() {
  markers.fitToMarkers();
}

function handleReset() {
  mapRef.value?.resetView?.();
}

function handleSearchSelect(p: { lng: number; lat: number }) {
  mapRef.value?.flyTo(p.lng, p.lat, 16);
}

function handleLocateLatest() {
  const latest = latestAlert.value;
  if (!latest || latest.lng == null || latest.lat == null) {
    createMessage.info('暂无可定位的告警');
    return;
  }
  mapRef.value?.flyTo(Number(latest.lng), Number(latest.lat), 17);
}

function handleTool(key: string) {
  switch (key) {
    case 'measure-line': measure.start('line'); break;
    case 'measure-area': measure.start('area'); break;
    case 'select-circle': spatial.start('circle'); break;
    case 'select-rect': spatial.start('rect'); break;
    case 'select-polygon': spatial.start('polygon'); break;
    case 'clear':
      measure.clear();
      spatial.clear();
      break;
    default: break;
  }
}

defineExpose({ refresh, alerts: alertData.alertsWithLocation, flyTo, updateMapSize, alertData });
</script>

<template>
  <div
    class="alert-device-map"
    :class="{ 'alert-device-map--embedded': embedded }"
    :style="embedded ? { height } : undefined"
  >
    <!-- 悬浮提示（OL Overlay 会把此元素移入地图覆盖层并定位）：摄像头→告警卡片，聚合簇→数量+操作提示 -->
    <div ref="hoverCardEl" class="alert-device-map__hovercard" @mouseenter="clearHideTimer" @mouseleave="scheduleHideHover">
      <CameraAlertCard
        v-if="hoverCamera"
        :name="hoverCamera.title"
        :online="hoverCamera.online"
        :alerts="hoverAlerts"
      />
      <div v-else-if="hoverCluster" class="cluster-tip">
        <div class="cluster-tip__line">
          <b>{{ hoverCluster.count }}</b> 台摄像头
          <template v-if="hoverCluster.alertCount">
            · <span class="cluster-tip__alert">{{ hoverCluster.alertCount }}</span> 条告警
          </template>
        </div>
        <div class="cluster-tip__hint">
          {{ hoverCluster.canZoom ? '点击放大查看' : `点击展开 ${hoverCluster.count} 个点位` }}
        </div>
      </div>
    </div>

    <Spin
      :spinning="alertData.loading.value"
      :wrapper-class-name="embedded ? 'alert-device-map__spin' : undefined"
    >
      <a-card
        v-if="!embedded"
        :bordered="false"
        :body-style="cardBodyStyle"
        class="alert-device-map__card"
      >
        <BasicTiandituMap ref="mapRef" :show-toolbar="false" show-overview @ready="onMapReady">
          <AlertMapFloatLayer
            v-model:base-map-type="baseMapType"
            v-model:show-label="showLabel"
            v-model:show-heat="heatEnabled"
            v-model:offline-only="offlineOnly"
            v-model:category-filter="categoryFilter"
            :loading="alertData.loading.value"
            :camera-count="alertData.deviceData.devices.value.length"
            :alert-count="alertData.alertsWithLocation.value.length"
            :offline-count="offlineCount"
            :map="mapInstance"
            :show-heat-legend="heatEnabled"
            :active-tool="activeTool"
            @refresh="refresh"
            @fit="handleFitAll"
            @reset="handleReset"
            @search="handleSearchSelect"
            @locate-latest="handleLocateLatest"
            @tool="handleTool"
          />
        </BasicTiandituMap>
      </a-card>
      <div v-else class="alert-device-map__map" :style="{ height }">
        <BasicTiandituMap ref="mapRef" :show-toolbar="false" show-overview @ready="onMapReady">
          <AlertMapFloatLayer
            v-model:base-map-type="baseMapType"
            v-model:show-label="showLabel"
            v-model:show-heat="heatEnabled"
            v-model:offline-only="offlineOnly"
            v-model:category-filter="categoryFilter"
            :loading="alertData.loading.value"
            :camera-count="alertData.deviceData.devices.value.length"
            :alert-count="alertData.alertsWithLocation.value.length"
            :offline-count="offlineCount"
            :map="mapInstance"
            :show-heat-legend="heatEnabled"
            :active-tool="activeTool"
            @refresh="refresh"
            @fit="handleFitAll"
            @reset="handleReset"
            @search="handleSearchSelect"
            @locate-latest="handleLocateLatest"
            @tool="handleTool"
          />
        </BasicTiandituMap>
      </div>
    </Spin>
  </div>
</template>

<style scoped lang="less">
.cluster-tip {
  padding: 8px 12px;
  background: #fff;
  border-radius: 10px;
  border: 1px solid #e8ecf4;
  box-shadow: 0 8px 28px rgb(15 23 42 / 16%);
  pointer-events: auto;
  white-space: nowrap;

  &__line {
    font-size: 13px;
    color: rgba(0, 0, 0, 0.82);

    b { font-size: 15px; color: #266cfb; }
  }

  &__alert {
    font-weight: 700;
    color: #ff4d4f;
  }

  &__hint {
    margin-top: 3px;
    font-size: 11px;
    color: rgba(0, 0, 0, 0.45);
  }
}

.alert-device-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgb(0 0 0 / 4%);

  &--embedded {
    width: 100%;
    height: 100%;
    min-height: 0;
    border-radius: 0;
    box-shadow: none;
    background: transparent;
  }

  &__map {
    flex: 1;
    width: 100%;
    min-width: 0;
    min-height: 0;
    padding: 0;
    background: #e8ebf2;
    position: relative;
    overflow: hidden;

    :deep(.basic-tianditu-map) {
      position: absolute;
      inset: 0;
      width: 100%;
      height: auto;
      min-height: 0;
      border-radius: 0;
    }
  }

  &__card:deep(.ant-card) {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &__card:deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &--embedded :deep(.alert-device-map__spin),
  &--embedded :deep(.ant-spin-nested-loading),
  &--embedded :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &--embedded :deep(.basic-tianditu-map) {
    position: absolute;
    inset: 0;
    width: 100%;
    height: auto;
    min-height: 0;
  }

  :deep(.basic-tianditu-map) {
    flex: 1;
    width: 100%;
    min-height: 0;
    height: 100%;
  }

  &--embedded :deep(.basic-tianditu-map__canvas) {
    width: 100%;
    height: 100%;
  }
}
</style>

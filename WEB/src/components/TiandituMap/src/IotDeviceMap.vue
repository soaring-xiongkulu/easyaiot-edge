<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { Checkbox } from 'ant-design-vue';
import BasicTiandituMap from './BasicTiandituMap.vue';
import MapFloatToolbar from './components/MapFloatToolbar.vue';
import MapToolbarStat from './components/MapToolbarStat.vue';
import MapSearchBox from './components/MapSearchBox.vue';
import MapLegend from './components/MapLegend.vue';
import MapCursorInfo from './components/MapCursorInfo.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useIotDeviceMapData } from '../business/useIotDeviceMapData';
import { MARKER_COLORS, MARKER_OFFLINE_COLOR } from '../constants';
import type { MapMarkerData, TiandituBaseMapType } from '../types';

const props = withDefaults(
  defineProps<{
    filterOnline?: boolean | null;
    height?: string;
    autoFit?: boolean;
    enableCluster?: boolean;
    /** 设备目录总数（含未定位），用于工具栏展示「已定位/全部」 */
    totalDeviceCount?: number;
  }>(),
  {
    filterOnline: null,
    height: '100%',
    autoFit: true,
    enableCluster: true,
    totalDeviceCount: 0,
  },
);

const emit = defineEmits<{
  (e: 'marker-click', marker: MapMarkerData): void;
}>();

const cardBodyStyle = computed(() => ({
  padding: 0,
  height: props.height,
  minHeight: 0,
}));

const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const mapInstance = computed(() => mapRef.value?.map ?? null);
const baseMapType = ref<TiandituBaseMapType>('vec');
const showLabel = ref(true);
const offlineOnly = ref(false);
const deviceData = useIotDeviceMapData();

const legendItems = [
  { type: 'camera' as const, label: '设备（在线）', color: MARKER_COLORS.device },
  { type: 'offline' as const, label: '设备（离线）', color: MARKER_OFFLINE_COLOR },
  { type: 'cluster' as const, label: '聚合点（数字为数量）', color: '#4287fc' },
];

const markers = useMapMarkers({
  map: mapInstance,
  onMarkerClick: (m) => emit('marker-click', m),
  enableCluster: computed(() => props.enableCluster),
});

function handleSearchSelect(p: { lng: number; lat: number }) {
  mapRef.value?.flyTo(p.lng, p.lat, 16);
}

const mapLoading = computed(() => deviceData.loading.value);
const mapError = computed(() => deviceData.error.value);
const markerCount = computed(() => markers.markers.value.length);
const offlineCount = computed(() => deviceData.devices.value.filter((d) => d.online === false).length);
const markerStatLabel = computed(() =>
  props.totalDeviceCount > 0 ? `已上图/${props.totalDeviceCount}` : '已上图',
);

function displayMarkers(): MapMarkerData[] {
  const list = deviceData.toMarkers(props.filterOnline);
  if (!offlineOnly.value) return list;
  return list.filter((m) => m.online === false);
}

async function refresh() {
  // 先让容器完成布局再拉数，避免 OpenLayers 在错误尺寸下渲染后被 CSS 拉伸发灰
  await nextTick();
  mapRef.value?.updateSize?.();
  await deviceData.load({ has_location: true });
  markers.setMarkers(displayMarkers());
  if (props.autoFit) markers.fitToMarkers();
  await nextTick();
  mapRef.value?.updateSize?.();
  requestAnimationFrame(() => {
    mapRef.value?.updateSize?.();
    requestAnimationFrame(() => mapRef.value?.updateSize?.());
  });
}

watch(offlineOnly, () => markers.setMarkers(displayMarkers()));

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

watch(showLabel, (v) => {
  mapRef.value?.setLabelVisible?.(v);
});

onMounted(() => {
  if (mapRef.value?.map) refresh();
});
watch(() => props.filterOnline, refresh);

function flyTo(lng: number, lat: number, zoom = 16) {
  mapRef.value?.flyTo(lng, lat, zoom);
}

function updateMapSize() {
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
}

defineExpose({
  refresh,
  devices: deviceData.devices,
  flyTo,
  updateMapSize,
  fitToMarkers: () => markers.fitToMarkers(),
  findById: deviceData.findById,
});
</script>

<template>
  <a-card :bordered="false" :body-style="cardBodyStyle" class="iot-device-map">
    <BasicTiandituMap ref="mapRef" :show-toolbar="false" show-overview @ready="refresh">
      <MapFloatToolbar
        v-model:base-map-type="baseMapType"
        v-model:show-label="showLabel"
        :loading="mapLoading"
        @refresh="refresh"
        @fit="markers.fitToMarkers()"
        @reset="mapRef?.resetView?.()"
      >
        <template #tags>
          <MapSearchBox @select="handleSearchSelect" />
          <MapToolbarStat variant="marker" :label="markerStatLabel" :count="markerCount" />
          <MapToolbarStat v-if="mapError" variant="error" :value="mapError" />
        </template>
        <template #extra>
          <Checkbox v-model:checked="offlineOnly" class="iot-device-map__offline">
            只看离线<span v-if="offlineCount" class="iot-device-map__muted">({{ offlineCount }})</span>
          </Checkbox>
        </template>
      </MapFloatToolbar>
      <MapLegend :items="legendItems" :show-alert="false" :show-structure="false" />
      <MapCursorInfo :map="mapInstance" />
    </BasicTiandituMap>
  </a-card>
</template>

<style scoped lang="less">
.iot-device-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 0;
  overflow: hidden;
  box-shadow: none;

  &__muted {
    margin-left: 2px;
    color: rgba(0, 0, 0, 0.4);
  }

  :deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    height: 100%;
    padding: 0 !important;
    display: flex;
    flex-direction: column;
  }

  :deep(.basic-tianditu-map) {
    flex: 1;
    width: 100%;
    min-height: 0;
    height: 100%;
  }
}
</style>

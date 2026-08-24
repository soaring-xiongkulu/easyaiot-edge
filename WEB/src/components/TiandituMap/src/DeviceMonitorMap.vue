<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import BasicTiandituMap from './BasicTiandituMap.vue';
import MapFloatToolbar from './components/MapFloatToolbar.vue';
import MapToolbarStat from './components/MapToolbarStat.vue';
import { Checkbox } from 'ant-design-vue';
import MapSearchBox from './components/MapSearchBox.vue';
import MapLegend from './components/MapLegend.vue';
import MapCursorInfo from './components/MapCursorInfo.vue';
import MapCategoryFilter from './components/MapCategoryFilter.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useMapDisplayFilters } from '../composables/useMapDisplayFilters';
import { useDeviceMapData } from '../business/useDeviceMapData';
import type { MapMarkerData, TiandituBaseMapType } from '../types';

const props = withDefaults(defineProps<{
  directoryId?: number;
  filterOnline?: boolean | null;
  height?: string;
  autoFit?: boolean;
  enableCluster?: boolean;
  /** 同坐标聚合点展开后，点击叶子是否自动收起（默认 false=保持展开） */
  spiderfyCollapseOnSelect?: boolean;
}>(), {
  filterOnline: null,
  height: '100%',
  autoFit: true,
  enableCluster: true,
  spiderfyCollapseOnSelect: false,
});

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
const { offlineOnly, categoryFilter, apply: applyDisplayFilters } = useMapDisplayFilters();
const deviceData = useDeviceMapData();

const markers = useMapMarkers({
  map: mapInstance,
  onMarkerClick: (m) => emit('marker-click', m),
  enableCluster: computed(() => props.enableCluster),
  collapseSpiderOnSelect: computed(() => props.spiderfyCollapseOnSelect),
});

function handleSearchSelect(p: { lng: number; lat: number }) {
  mapRef.value?.flyTo(p.lng, p.lat, 16);
}

const markerCount = computed(() => markers.markers.value.length);
const offlineCount = computed(() => deviceData.devices.value.filter((d) => d.online === false).length);

function displayMarkers(): MapMarkerData[] {
  return applyDisplayFilters(deviceData.toMarkers(props.filterOnline));
}

async function refresh() {
  await deviceData.load({
    directory_id: props.directoryId,
    has_location: true,
  });
  markers.setMarkers(displayMarkers());
  if (props.autoFit) markers.fitToMarkers();
  await nextTick();
  mapRef.value?.updateSize?.();
  requestAnimationFrame(() => mapRef.value?.updateSize?.());
}

watch([offlineOnly, categoryFilter], () => markers.setMarkers(displayMarkers()), { deep: true });

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

watch(showLabel, (v) => {
  mapRef.value?.setLabelVisible?.(v);
});

onMounted(() => {
  if (mapRef.value?.map) refresh();
});
watch(() => [props.directoryId, props.filterOnline], refresh);

function flyTo(lng: number, lat: number, zoom = 16) {
  mapRef.value?.flyTo(lng, lat, zoom);
}

function updateMapSize() {
  mapRef.value?.tryInitMap?.();
  mapRef.value?.updateSize?.();
}

function handleFitAll() {
  markers.fitToMarkers();
}

function handleReset() {
  mapRef.value?.resetView?.();
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
  <a-card
    :bordered="false"
    :body-style="cardBodyStyle"
    class="device-monitor-map"
  >
    <a-spin :spinning="deviceData.loading.value" wrapper-class-name="device-monitor-map__spin">
      <BasicTiandituMap ref="mapRef" :show-toolbar="false" show-overview @ready="refresh">
        <MapFloatToolbar
          v-model:base-map-type="baseMapType"
          v-model:show-label="showLabel"
          :loading="deviceData.loading.value"
          @refresh="refresh"
          @fit="handleFitAll"
          @reset="handleReset"
        >
          <template #tags>
            <MapSearchBox @select="handleSearchSelect" />
            <MapToolbarStat variant="camera" label="摄像头" :count="markerCount" />
            <MapToolbarStat v-if="deviceData.error.value" variant="error" :value="deviceData.error.value" />
          </template>
          <template #extra>
            <Checkbox v-model:checked="offlineOnly" class="device-monitor-map__offline">
              只看离线<span v-if="offlineCount" class="device-monitor-map__muted">({{ offlineCount }})</span>
            </Checkbox>
            <MapCategoryFilter v-model="categoryFilter" />
          </template>
        </MapFloatToolbar>
        <MapLegend :show-alert="false" />
        <MapCursorInfo :map="mapInstance" />
      </BasicTiandituMap>
    </a-spin>
  </a-card>
</template>

<style scoped lang="less">
.device-monitor-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgb(0 0 0 / 4%);

  &__muted {
    margin-left: 2px;
    color: rgba(0, 0, 0, 0.4);
  }

  &:deep(.ant-card) {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  &__spin,
  :deep(.device-monitor-map__spin),
  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    height: 100%;
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

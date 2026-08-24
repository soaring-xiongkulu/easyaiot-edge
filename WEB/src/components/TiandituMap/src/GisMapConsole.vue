<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import dayjs from 'dayjs';
import BasicTiandituMap from './BasicTiandituMap.vue';
import GisModeBar from './components/GisModeBar.vue';
import GisMapFloatBar from './components/GisMapFloatBar.vue';
import { useMapMarkers } from '../composables/useMapMarkers';
import { useMapTracks } from '../composables/useMapTracks';
import { reverseGeocode, searchPoi } from '../core/tiandituApi';
import { formatLngLat, isValidLngLat } from '../core/coordUtils';
import { DEFAULT_MAP_CENTER } from '../constants';
import type {
  GisMapMode,
  GisMarkerRow,
  MapMarkerData,
  MapPickResult,
  MapTrackSession,
  TiandituBaseMapType,
} from '../types';
import { Button } from '@/components/Button';
import { CollapseContainer, ScrollContainer } from '@/components/Container';
import { useMessage } from '@/hooks/web/useMessage';
import type Map from 'ol/Map';
import { toLonLat } from 'ol/proj';

defineOptions({ name: 'GisMapConsole' });

const props = withDefaults(
  defineProps<{
    /** 容器高度，默认占满父级 */
    height?: string;
    /** 初始模式 */
    initialMode?: GisMapMode;
  }>(),
  {
    height: 'calc(100vh - 168px)',
    initialMode: 'markers',
  },
);

const emit = defineEmits<{
  (e: 'mode-change', mode: GisMapMode): void;
  (e: 'marker-select', payload: { key: string; lng: number; lat: number } | null): void;
  (e: 'pick-change', payload: MapPickResult): void;
}>();

interface TrackRow {
  key: string;
  lng: number;
  lat: number;
  recordedAt: string;
}

interface ListRowItem {
  key: string;
  name: string;
  lng: number | null;
  lat: number | null;
  extra?: string;
}

const { createMessage } = useMessage();

const mode = ref<GisMapMode>(props.initialMode);
const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const mapInstance = computed(() => mapRef.value?.map ?? null);
const baseMapType = ref<TiandituBaseMapType>('vec');

const cursorLng = ref<number | null>(null);
const cursorLat = ref<number | null>(null);
const mapZoom = ref(10);
const selectedRowKey = ref<string | null>(null);
const listFilter = ref('');

const gotoLng = ref<number | null>(DEFAULT_MAP_CENTER[0]);
const gotoLat = ref<number | null>(DEFAULT_MAP_CENTER[1]);

const markerRows = ref<GisMarkerRow[]>([
  { key: '1', name: '点位 A', lng: 114.057868, lat: 22.543099, remark: '示例' },
  { key: '2', name: '点位 B', lng: 114.06512, lat: 22.54832 },
  { key: '3', name: '点位 C', lng: 114.05124, lat: 22.53688 },
]);

const pickResult = ref<MapPickResult>({
  lng: DEFAULT_MAP_CENTER[0],
  lat: DEFAULT_MAP_CENTER[1],
  address: '',
});
const poiKeyword = ref('');
const poiResults = ref<Array<{ id: string; name: string; address: string; lng: number | null; lat: number | null }>>([]);
const poiSearching = ref(false);

const trackRows = ref<TrackRow[]>([
  { key: '1', lng: 114.055, lat: 22.545, recordedAt: '2026-06-03 08:00:00' },
  { key: '2', lng: 114.058, lat: 22.542, recordedAt: '2026-06-03 08:05:00' },
  { key: '3', lng: 114.062, lat: 22.539, recordedAt: '2026-06-03 08:10:00' },
  { key: '4', lng: 114.066, lat: 22.536, recordedAt: '2026-06-03 08:15:00' },
]);
const trackSpeed = ref(1);
const trackSession = computed<MapTrackSession>(() => ({
  id: 'gis-track',
  deviceId: 'demo',
  title: '轨迹',
  color: '#52c41a',
  points: trackRows.value.map((r) => ({ lng: r.lng, lat: r.lat, recordedAt: r.recordedAt })),
}));

const markersCtl = useMapMarkers({
  map: mapInstance,
  onMarkerClick: (m) => selectByKey(m.id, m.lng, m.lat),
});
const tracksCtl = useMapTracks({ map: mapInstance });

const markerMapData = computed<MapMarkerData[]>(() =>
  markerRows.value.map((r) => ({
    id: r.key,
    lng: r.lng,
    lat: r.lat,
    title: r.name,
    subtitle: r.remark || formatLngLat(r.lng, r.lat),
    kind: 'custom',
  })),
);

const pickerMarkers = computed<MapMarkerData[]>(() => [{
  id: 'pick-point',
  lng: pickResult.value.lng,
  lat: pickResult.value.lat,
  title: '选址点',
  subtitle: pickResult.value.address || formatLngLat(pickResult.value.lng, pickResult.value.lat),
  kind: 'picker',
}]);

const listRows = computed((): ListRowItem[] => {
  if (mode.value === 'markers') {
    return markerRows.value.map((r) => ({
      key: r.key,
      name: r.name,
      lng: r.lng,
      lat: r.lat,
      extra: r.remark,
    }));
  }
  if (mode.value === 'picker') {
    return [{
      key: 'pick',
      name: '当前选址',
      lng: pickResult.value.lng,
      lat: pickResult.value.lat,
      extra: pickResult.value.address || '',
    }];
  }
  return trackRows.value.map((r) => ({
    key: r.key,
    name: '轨迹点',
    lng: r.lng,
    lat: r.lat,
    extra: r.recordedAt,
  }));
});

const filteredListRows = computed(() => {
  const q = listFilter.value.trim().toLowerCase();
  if (!q) return listRows.value;
  return listRows.value.filter((r) =>
    String(r.name || '').toLowerCase().includes(q)
    || String(r.extra || '').toLowerCase().includes(q),
  );
});

const selectedRow = computed(() =>
  listRows.value.find((r) => r.key === selectedRowKey.value) ?? null,
);

const selectedMarkerRow = computed(() => {
  if (mode.value !== 'markers' || !selectedRowKey.value) return null;
  return markerRows.value.find((r) => r.key === selectedRowKey.value) ?? null;
});

const modeOptions = computed(() => [
  { key: 'markers', label: '点位标注', icon: 'ant-design:pushpin-outlined', count: markerRows.value.length },
  { key: 'picker', label: '坐标选址', icon: 'ant-design:environment-outlined', count: '' },
  { key: 'track', label: '轨迹回放', icon: 'ant-design:node-index-outlined', count: trackRows.value.length },
]);

let pointerListener: ((e: { coordinate: number[] }) => void) | null = null;
let moveEndListener: (() => void) | null = null;

function uid() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
}

function selectByKey(key: string, lng?: number, lat?: number) {
  selectedRowKey.value = key;
  if (lng != null && lat != null) {
    gotoLng.value = lng;
    gotoLat.value = lat;
    emit('marker-select', { key, lng, lat });
  } else {
    emit('marker-select', null);
  }
}

function bindMapEvents(map: Map) {
  pointerListener = (evt) => {
    const [lng, lat] = toLonLat(evt.coordinate);
    cursorLng.value = lng;
    cursorLat.value = lat;
  };
  moveEndListener = () => {
    mapZoom.value = Math.round(map.getView().getZoom() ?? 10);
  };
  map.on('pointermove', pointerListener);
  map.on('moveend', moveEndListener);
  mapZoom.value = Math.round(map.getView().getZoom() ?? 10);
}

function unbindMapEvents(map: Map) {
  if (pointerListener) map.un('pointermove', pointerListener);
  if (moveEndListener) map.un('moveend', moveEndListener);
}

function onMapReady() {
  markersCtl.attach();
  tracksCtl.attach();
  if (mapInstance.value) bindMapEvents(mapInstance.value);
  syncMapLayers();
}

function syncMapLayers() {
  if (mode.value === 'track') {
    markersCtl.setMarkers([]);
    tracksCtl.setSessions([trackSession.value]);
  } else if (mode.value === 'markers') {
    tracksCtl.stopPlayback();
    tracksCtl.setSessions([]);
    markersCtl.setMarkers(markerMapData.value);
  } else {
    tracksCtl.stopPlayback();
    tracksCtl.setSessions([]);
    markersCtl.setMarkers(pickerMarkers.value);
  }
}

function fitView() {
  if (mode.value === 'track' && trackRows.value.length) {
    markersCtl.setMarkers(trackRows.value.map((r, i) => ({
      id: r.key, lng: r.lng, lat: r.lat, title: `P${i + 1}`, kind: 'track' as const,
    })));
    markersCtl.fitToMarkers();
    markersCtl.setMarkers([]);
    tracksCtl.setSessions([trackSession.value]);
    return;
  }
  markersCtl.fitToMarkers();
}

function flyToCoord(lng?: number | null, lat?: number | null, zoom = 16) {
  if (!isValidLngLat(lng, lat)) {
    createMessage.warning('坐标无效');
    return;
  }
  mapRef.value?.flyTo(Number(lng), Number(lat), zoom);
}

function onGoto() {
  flyToCoord(gotoLng.value, gotoLat.value);
}

async function onMapClick({ lng, lat }: { lng: number; lat: number }) {
  if (mode.value !== 'picker') return;
  gotoLng.value = lng;
  gotoLat.value = lat;
  pickResult.value = { lng, lat, address: await reverseGeocode({ lng, lat }) };
  selectedRowKey.value = 'pick';
  emit('pick-change', pickResult.value);
  syncMapLayers();
}

async function searchPoiHandler() {
  if (!poiKeyword.value.trim()) return;
  poiSearching.value = true;
  try {
    poiResults.value = (await searchPoi({ keyword: poiKeyword.value, pageSize: 6 })).items;
  } finally {
    poiSearching.value = false;
  }
}

async function selectPoi(item: (typeof poiResults.value)[0]) {
  if (item.lng == null || item.lat == null) return;
  pickResult.value = {
    lng: item.lng,
    lat: item.lat,
    address: item.address || await reverseGeocode({ lng: item.lng, lat: item.lat }),
  };
  gotoLng.value = item.lng;
  gotoLat.value = item.lat;
  selectedRowKey.value = 'pick';
  emit('pick-change', pickResult.value);
  syncMapLayers();
  mapRef.value?.flyTo(item.lng, item.lat, 16);
}

function applySelectionToMap() {
  if (!isValidLngLat(gotoLng.value, gotoLat.value)) {
    createMessage.warning('请输入有效经纬度');
    return;
  }
  const lng = Number(gotoLng.value);
  const lat = Number(gotoLat.value);
  if (mode.value === 'picker') {
    pickResult.value = { ...pickResult.value, lng, lat };
    emit('pick-change', pickResult.value);
  } else if (mode.value === 'markers' && selectedRowKey.value) {
    const row = markerRows.value.find((r) => r.key === selectedRowKey.value);
    if (row) { row.lng = lng; row.lat = lat; }
  } else if (mode.value === 'track' && selectedRowKey.value) {
    const row = trackRows.value.find((r) => r.key === selectedRowKey.value);
    if (row) { row.lng = lng; row.lat = lat; }
  }
  syncMapLayers();
  flyToCoord(lng, lat);
}

function addMarkerRow() {
  const row: GisMarkerRow = {
    key: uid(),
    name: `点位-${markerRows.value.length + 1}`,
    lng: gotoLng.value ?? DEFAULT_MAP_CENTER[0],
    lat: gotoLat.value ?? DEFAULT_MAP_CENTER[1],
  };
  markerRows.value.push(row);
  selectByKey(row.key, row.lng, row.lat);
  syncMapLayers();
}

function removeSelectedMarker() {
  if (mode.value !== 'markers' || !selectedRowKey.value) return;
  markerRows.value = markerRows.value.filter((r) => r.key !== selectedRowKey.value);
  selectedRowKey.value = null;
  syncMapLayers();
}

function addTrackRow() {
  const last = trackRows.value.at(-1);
  const row: TrackRow = {
    key: uid(),
    lng: last ? last.lng + 0.002 : DEFAULT_MAP_CENTER[0],
    lat: last ? last.lat - 0.001 : DEFAULT_MAP_CENTER[1],
    recordedAt: dayjs().format('YYYY-MM-DD HH:mm:ss'),
  };
  trackRows.value.push(row);
  selectByKey(row.key, row.lng, row.lat);
  syncMapLayers();
}

watch(baseMapType, (type) => {
  mapRef.value?.switchBaseMap(type);
});

function copyCoords() {
  if (!isValidLngLat(gotoLng.value, gotoLat.value)) return;
  navigator.clipboard?.writeText(formatLngLat(Number(gotoLng.value), Number(gotoLat.value)));
  createMessage.success('已复制坐标');
}

function onListItemClick(record: ListRowItem) {
  selectByKey(record.key, record.lng ?? undefined, record.lat ?? undefined);
  if (record.lng != null && record.lat != null) flyToCoord(record.lng, record.lat);
}

function setMarkers(rows: GisMarkerRow[]) {
  markerRows.value = rows;
  if (mode.value === 'markers') syncMapLayers();
}

function getMarkers(): GisMarkerRow[] {
  return markerRows.value.map((r) => ({ ...r }));
}

function getPickResult(): MapPickResult {
  return { ...pickResult.value };
}

watch(mode, (m) => {
  selectedRowKey.value = null;
  listFilter.value = '';
  syncMapLayers();
  emit('mode-change', m);
});

watch(markerRows, () => { if (mode.value === 'markers') syncMapLayers(); }, { deep: true });
watch(trackRows, () => { if (mode.value === 'track') syncMapLayers(); }, { deep: true });
watch(pickResult, () => { if (mode.value === 'picker') syncMapLayers(); }, { deep: true });

onMounted(() => {
  syncMapLayers();
  if (markerRows.value[0]) selectByKey(markerRows.value[0].key, markerRows.value[0].lng, markerRows.value[0].lat);
});

onBeforeUnmount(() => {
  if (mapInstance.value) unbindMapEvents(mapInstance.value);
});

defineExpose({
  setMarkers,
  getMarkers,
  getPickResult,
  fitView,
  flyTo: flyToCoord,
  getMap: () => mapInstance.value,
});
</script>

<template>
  <div class="gis-map-console" :style="{ height: props.height }">
    <GisModeBar :active-key="mode" :modes="modeOptions" @change="(k) => (mode = k as GisMapMode)">
      <template #extra>
        <a-input-group compact class="gis-map-console__goto">
          <a-input-number v-model:value="gotoLng" :precision="6" placeholder="经度" size="small" style="width: 112px" />
          <a-input-number v-model:value="gotoLat" :precision="6" placeholder="纬度" size="small" style="width: 112px" />
        </a-input-group>
        <a-tag color="blue">WGS84</a-tag>
      </template>
    </GisModeBar>

    <a-layout class="gis-map-console__body">
      <a-layout-sider :width="320" theme="light" class="gis-map-console__panel">
        <CollapseContainer title="快捷操作" :can-expan="false">
          <a-space direction="vertical" style="width: 100%" :size="8">
            <template v-if="mode === 'markers'">
              <Button block type="primary" pre-icon="ant-design:plus-outlined" @click="addMarkerRow">新增点位</Button>
              <Button block danger pre-icon="ant-design:delete-outlined" :disabled="!selectedRowKey" @click="removeSelectedMarker">
                删除选中
              </Button>
            </template>
            <template v-else-if="mode === 'picker'">
              <a-input-search v-model:value="poiKeyword" placeholder="POI 搜索" :loading="poiSearching" @search="searchPoiHandler" />
              <a-list v-if="poiResults.length" size="small" :data-source="poiResults" class="gis-map-console__poi">
                <template #renderItem="{ item }">
                  <a-list-item class="gis-map-console__poi-item" @click="selectPoi(item)">
                    <a-list-item-meta :title="item.name" :description="item.address" />
                  </a-list-item>
                </template>
              </a-list>
            </template>
            <template v-else>
              <a-space wrap>
                <Button type="primary" pre-icon="ant-design:play-circle-outlined" @click="() => tracksCtl.startPlayback(trackSpeed)">播放</Button>
                <Button pre-icon="ant-design:pause-circle-outlined" @click="() => tracksCtl.stopPlayback()">停止</Button>
              </a-space>
              <a-progress :percent="Math.round(tracksCtl.playProgress.value * 100)" size="small" />
              <Button block pre-icon="ant-design:plus-outlined" @click="addTrackRow">添加轨迹点</Button>
              <a-input-number v-model:value="trackSpeed" :min="0.5" :max="5" :step="0.5" addon-before="倍速" style="width: 100%" />
            </template>
          </a-space>
        </CollapseContainer>

        <CollapseContainer title="选中要素" :can-expan="false" class="gis-map-console__block">
          <a-descriptions bordered size="small" :column="1">
            <a-descriptions-item label="名称">
              <a-input
                v-if="selectedMarkerRow"
                v-model:value="selectedMarkerRow.name"
                size="small"
                @change="syncMapLayers"
              />
              <template v-else>{{ selectedRow?.name || '—' }}</template>
            </a-descriptions-item>
            <a-descriptions-item label="经度">
              <a-input-number v-model:value="gotoLng" :precision="6" size="small" style="width: 100%" />
            </a-descriptions-item>
            <a-descriptions-item label="纬度">
              <a-input-number v-model:value="gotoLat" :precision="6" size="small" style="width: 100%" />
            </a-descriptions-item>
            <a-descriptions-item v-if="mode === 'picker'" label="地址">
              <a-textarea v-model:value="pickResult.address" :rows="2" />
            </a-descriptions-item>
            <a-descriptions-item v-else-if="selectedRow?.extra" label="备注">{{ selectedRow.extra }}</a-descriptions-item>
          </a-descriptions>
          <a-space style="margin-top: 10px">
            <Button type="primary" size="small" pre-icon="ant-design:check-outlined" @click="applySelectionToMap">应用</Button>
            <Button size="small" pre-icon="ant-design:aim-outlined" @click="onGoto">定位</Button>
            <Button size="small" pre-icon="ant-design:copy-outlined" @click="copyCoords">复制</Button>
          </a-space>
        </CollapseContainer>

        <CollapseContainer title="要素列表" :can-expan="false" class="gis-map-console__block gis-map-console__list-wrap">
          <a-input v-model:value="listFilter" allow-clear placeholder="筛选名称/备注" size="small" style="margin-bottom: 8px" />
          <ScrollContainer v-if="filteredListRows.length" class="gis-map-console__list">
            <a-list size="small" :data-source="filteredListRows" :split="false">
              <template #renderItem="{ item }">
                <a-list-item
                  class="gis-map-console__list-item"
                  :class="{ 'is-active': selectedRowKey === item.key }"
                  @click="onListItemClick(item)"
                >
                  <a-list-item-meta>
                    <template #title>
                      <span class="gis-map-console__list-title">{{ item.name }}</span>
                    </template>
                    <template #description>
                      <span class="gis-map-console__list-coord">
                        {{ item.lng != null && item.lat != null ? formatLngLat(Number(item.lng), Number(item.lat)) : '无坐标' }}
                      </span>
                      <span v-if="item.extra" class="gis-map-console__list-extra">{{ item.extra }}</span>
                    </template>
                  </a-list-item-meta>
                </a-list-item>
              </template>
            </a-list>
          </ScrollContainer>
          <a-empty v-else description="暂无数据" />
        </CollapseContainer>
      </a-layout-sider>

      <a-layout-content class="gis-map-console__stage">
        <BasicTiandituMap ref="mapRef" :show-toolbar="false" clickable @ready="onMapReady" @map-click="onMapClick" />
        <GisMapFloatBar
          v-model:base-map-type="baseMapType"
          :cursor-lng="cursorLng"
          :cursor-lat="cursorLat"
          :zoom="mapZoom"
          @fit="fitView"
          @goto="onGoto"
        />
        <div class="gis-map-console__legend">
          <a-tag v-if="mode === 'markers'" color="processing">{{ markerRows.length }} 个点位</a-tag>
          <a-tag v-if="mode === 'picker'" color="purple">点击地图选点</a-tag>
          <a-tag v-if="mode === 'track'" color="success">{{ trackRows.length }} 点 · {{ tracksCtl.playing.value ? '回放中' : '就绪' }}</a-tag>
        </div>
      </a-layout-content>
    </a-layout>
  </div>
</template>

<style scoped lang="less">
.gis-map-console {
  display: flex;
  flex-direction: column;
  min-height: 540px;
  background: #fff;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%), 0 8px 24px rgb(15 23 42 / 6%);

  &__goto {
    display: flex;
  }

  &__body {
    flex: 1;
    min-height: 0;
  }

  &__panel {
    border-right: 1px solid #eef0f4;
    background: #fafafa !important;
    overflow-y: auto;
    padding: 10px;
  }

  &__block {
    margin-top: 10px;
  }

  &__list-wrap {
    :deep(.vben-collapse-container__body) {
      padding-bottom: 4px;
    }
  }

  &__list {
    max-height: 220px;
    min-height: 120px;
  }

  &__list-item {
    padding: 8px 10px !important;
    margin-bottom: 6px;
    border: 1px solid #e8ecf2;
    border-radius: 8px;
    background: #fff;
    cursor: pointer;
    transition: all 0.15s;

    &:hover {
      border-color: #4287fc;
      box-shadow: 0 2px 8px rgb(66 135 252 / 10%);
    }

    &.is-active {
      border-color: #4287fc;
      background: #f0f7ff;
    }

    :deep(.ant-list-item-meta-title) {
      margin-bottom: 0 !important;
    }
  }

  &__list-title {
    font-size: 13px;
    font-weight: 500;
    color: #1e293b;
  }

  &__list-coord {
    margin-top: 4px;
    font-size: 11px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    color: #4287fc;
  }

  &__list-extra {
    display: block;
    margin-top: 2px;
    font-size: 11px;
    color: rgba(0, 0, 0, 0.45);
  }

  &__poi {
    max-height: 120px;
    overflow-y: auto;
    border: 1px solid #eef0f4;
    border-radius: 8px;
  }

  &__poi-item {
    cursor: pointer;
    padding: 4px 10px !important;

    &:hover {
      background: #f0f7ff;
    }
  }

  &__stage {
    flex: 1;
    min-width: 0;
    min-height: 0;
    position: relative;
    background: #e8edf3;

    :deep(.basic-tianditu-map) {
      position: absolute;
      inset: 0;
      height: auto;
      min-height: 0;
      border-radius: 0;
    }
  }

  &__legend {
    position: absolute;
    left: 12px;
    bottom: 12px;
    z-index: 11;
  }
}
</style>

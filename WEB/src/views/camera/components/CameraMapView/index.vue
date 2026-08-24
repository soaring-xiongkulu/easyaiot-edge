<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue';
import { DeviceMonitorMap } from '@/components/TiandituMap';
import type { MapMarkerData } from '@/components/TiandituMap';
import { useDeviceMapData } from '@/components/TiandituMap';
import { Button } from '@/components/Button';
import { CollapseContainer, ScrollContainer } from '@/components/Container';
import { Icon } from '@/components/Icon';
import { formatLocationSummary } from '@/views/camera/utils/deviceLocation';
import { Space } from 'ant-design-vue'

defineOptions({ name: 'CameraMapView' });

const props = withDefaults(defineProps<{
  height?: string;
}>(), {
  height: '100%',
});

const emit = defineEmits<{
  play: [device: Record<string, unknown>];
  edit: [device: Record<string, unknown>];
  view: [device: Record<string, unknown>];
  setLocation: [device: Record<string, unknown>];
}>();

const mapRef = ref<InstanceType<typeof DeviceMonitorMap> | null>(null);
const filterOnline = ref<boolean | null>(null);
const listFilter = ref('');
const selectedDeviceId = ref<string | null>(null);

const deviceData = useDeviceMapData();

const filteredDevices = computed(() => {
  let list = deviceData.devices.value;
  if (filterOnline.value != null) {
    list = list.filter((d) => d.online === filterOnline.value);
  }
  const q = listFilter.value.trim().toLowerCase();
  if (!q) return list;
  return list.filter((d) =>
    d.name.toLowerCase().includes(q)
    || String(d.address || '').toLowerCase().includes(q),
  );
});

async function loadDevices() {
  await deviceData.load({ has_location: true });
  await mapRef.value?.refresh();
  await nextTick();
  mapRef.value?.updateMapSize?.();
}

async function resizeMap() {
  await nextTick();
  mapRef.value?.updateMapSize?.();
  requestAnimationFrame(() => mapRef.value?.updateMapSize?.());
  requestAnimationFrame(() => mapRef.value?.updateMapSize?.());
}

function onMarkerClick(marker: MapMarkerData) {
  if (marker.kind !== 'camera') return;
  selectedDeviceId.value = marker.id;
}

function onListClick(device: { id: string; lng: number; lat: number }) {
  selectedDeviceId.value = device.id;
  mapRef.value?.flyTo(device.lng, device.lat);
}

function getPayload(id: string) {
  return deviceData.findById(id) as Record<string, unknown> | undefined;
}

function handlePlay() {
  const payload = selectedDeviceId.value ? getPayload(selectedDeviceId.value) : undefined;
  if (payload) emit('play', payload);
}

function handleEdit() {
  const payload = selectedDeviceId.value ? getPayload(selectedDeviceId.value) : undefined;
  if (payload) emit('edit', payload);
}

function handleView() {
  const payload = selectedDeviceId.value ? getPayload(selectedDeviceId.value) : undefined;
  if (payload) emit('view', payload);
}

function handleSetLocation() {
  const payload = selectedDeviceId.value ? getPayload(selectedDeviceId.value) : undefined;
  if (payload) emit('setLocation', payload);
}

function onFilterChange() {
  mapRef.value?.refresh();
}

onMounted(loadDevices);

defineExpose({ refresh: loadDevices, resizeMap });
</script>

<template>
  <a-layout class="camera-map-view">
    <a-layout-sider :width="300" theme="light" class="camera-map-view__sider">
      <CollapseContainer :can-expan="true" class="camera-map-view__panel">
        <template #title>
          <div class="camera-map-view__head">
            <Icon icon="ant-design:environment-outlined" class="camera-map-view__head-icon" />
            <span class="camera-map-view__title">已定位设备</span>
            <a-tag color="processing">{{ deviceData.devices.value.length }}</a-tag>
          </div>
        </template>
        <a-spin :spinning="deviceData.loading.value">
          <a-radio-group
            v-model:value="filterOnline"
            size="small"
            button-style="solid"
            class="camera-map-view__filter"
            @change="onFilterChange"
          >
            <a-radio-button :value="null">全部</a-radio-button>
            <a-radio-button :value="true">在线</a-radio-button>
            <a-radio-button :value="false">离线</a-radio-button>
          </a-radio-group>
          <a-input
            v-model:value="listFilter"
            allow-clear
            placeholder="搜索设备名称或地址"
            size="small"
            class="camera-map-view__search"
          >
            <template #prefix>
              <Icon icon="ant-design:search-outlined" />
            </template>
          </a-input>
          <ScrollContainer class="camera-map-view__scroll">
            <a-list
              v-if="filteredDevices.length"
              size="small"
              :data-source="filteredDevices"
              :split="false"
            >
              <template #renderItem="{ item }">
                <a-list-item
                  class="camera-map-view__item"
                  :class="{ 'is-active': selectedDeviceId === item.id }"
                  @click="onListClick(item)"
                >
                  <a-list-item-meta>
                    <template #title>
                      <div class="camera-map-view__item-head">
                        <span class="camera-map-view__item-name">{{ item.name }}</span>
                        <a-tag :color="item.online ? 'success' : 'default'">
                          {{ item.online ? '在线' : '离线' }}
                        </a-tag>
                      </div>
                    </template>
                    <template #description>
                      <span class="camera-map-view__item-coord">
                        {{ formatLocationSummary({ longitude: item.lng, latitude: item.lat }) }}
                      </span>
                    </template>
                  </a-list-item-meta>
                </a-list-item>
              </template>
            </a-list>
            <a-empty v-else description="暂无已定位设备" />
          </ScrollContainer>
          <Space
            v-if="selectedDeviceId"
            direction="vertical"
            :size="8"
            class="camera-map-view__actions"
          >
            <Button block type="primary" size="small" preIcon="octicon:play-16" @click="handlePlay">
              播放
            </Button>
            <Button block size="small" preIcon="ant-design:eye-filled" @click="handleView">
              详情
            </Button>
            <Button block size="small" preIcon="ant-design:edit-filled" @click="handleEdit">
              编辑
            </Button>
            <Button
              block
              size="small"
              preIcon="ant-design:environment-outlined"
              @click="handleSetLocation"
            >
              设置坐标
            </Button>
          </Space>
        </a-spin>
      </CollapseContainer>
    </a-layout-sider>

    <a-layout-content class="camera-map-view__map">
      <DeviceMonitorMap
        ref="mapRef"
        :filter-online="filterOnline"
        :height="height"
        @marker-click="onMarkerClick"
      />
    </a-layout-content>
  </a-layout>
</template>

<style scoped lang="less">
.camera-map-view {
  display: flex;
  flex: 1;
  height: 100%;
  min-height: 480px;
  background: #fff;
  border-radius: 8px;
  overflow: hidden;

  &:deep(.ant-layout),
  &:deep(.ant-layout-content) {
    height: 100%;
    min-height: 0;
  }

  &__sider {
    border-right: 1px solid #f0f0f0;
    background: #fafafa !important;
  }

  &__panel {
    height: 100%;

    :deep(.vben-collapse-container) {
      height: 100%;
      border: none;
      background: transparent;
    }

    :deep(.vben-collapse-container__header) {
      padding: 12px 12px 0;
    }

    :deep(.vben-collapse-container__body) {
      padding: 8px 12px 12px;
    }
  }

  &__head {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  &__head-icon {
    color: #4287fc;
    font-size: 16px;
  }

  &__title {
    flex: 1;
    font-size: 14px;
    font-weight: 500;
    color: rgba(0, 0, 0, 0.88);
  }

  &__filter {
    display: flex;
    width: 100%;
    margin-bottom: 8px;

    :deep(.ant-radio-button-wrapper) {
      flex: 1;
      text-align: center;
    }
  }

  &__search {
    margin-bottom: 8px;
  }

  &__scroll {
    max-height: calc(100vh - 460px);
    min-height: 200px;
  }

  &__item {
    padding: 8px 10px !important;
    margin-bottom: 6px;
    border: 1px solid #e8ecf2;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.15s;

    &:hover,
    &.is-active {
      border-color: #4287fc;
      background: #f0f7ff;
    }

    :deep(.ant-list-item-meta-title) {
      margin-bottom: 0 !important;
    }
  }

  &__item-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }

  &__item-name {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 13px;
    font-weight: 500;
  }

  &__item-coord {
    font-size: 11px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    color: #4287fc;
  }

  &__actions {
    width: 100%;
    margin-top: 10px;
  }

  &__map {
    position: relative;
    flex: 1;
    min-width: 0;
    min-height: 0;
    display: flex;
    flex-direction: column;
    padding: 0;
    background: #f5f5f5;

    :deep(.device-monitor-map) {
      position: absolute;
      inset: 0;
      flex: none;
      height: auto;
      min-height: 0;
    }

    :deep(.basic-tianditu-map) {
      position: absolute;
      inset: 0;
      height: auto;
    }
  }
}
</style>

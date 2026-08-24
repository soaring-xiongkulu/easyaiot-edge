<template>
  <div class="device-map-panel">
    <div class="device-map-panel__layout">
      <aside class="device-map-panel__sider">
        <div class="device-map-panel__sider-head">
          <div class="device-map-panel__sider-title">
            <span class="device-map-panel__sider-icon">
              <Icon icon="ant-design:apartment-outlined" :size="15" />
            </span>
            <div class="device-map-panel__sider-heading">
              <span class="device-map-panel__sider-name">设备目录</span>
              <span class="device-map-panel__sider-desc">共 {{ deviceList.length }} 台</span>
            </div>
          </div>
          <AButton size="small" :loading="listLoading" @click="reloadAll">
            <template #icon>
              <Icon icon="ant-design:reload-outlined" />
            </template>
            刷新
          </AButton>
        </div>

        <div class="device-map-panel__stats">
          <button
            type="button"
            class="device-map-panel__stat"
            :class="{ 'is-active': locateFilter === 'all' }"
            @click="locateFilter = 'all'"
          >
            <strong>{{ deviceList.length }}</strong>
            <span>全部</span>
          </button>
          <button
            type="button"
            class="device-map-panel__stat is-located"
            :class="{ 'is-active': locateFilter === 'located' }"
            @click="locateFilter = 'located'"
          >
            <strong>{{ locatedCount }}</strong>
            <span>已上图</span>
          </button>
          <button
            type="button"
            class="device-map-panel__stat is-pending"
            :class="{ 'is-active': locateFilter === 'unlocated' }"
            @click="locateFilter = 'unlocated'"
          >
            <strong>{{ unlocatedCount }}</strong>
            <span>待上图</span>
          </button>
        </div>

        <div class="device-map-panel__search">
          <a-input
            v-model:value="keyword"
            allow-clear
            placeholder="搜索设备名称或标识"
          >
            <template #prefix>
              <Icon icon="ant-design:search-outlined" />
            </template>
          </a-input>
        </div>

        <div class="device-map-panel__list">
          <a-spin :spinning="listLoading">
            <div v-if="!filteredList.length" class="device-map-panel__empty">
              <Icon icon="ant-design:inbox-outlined" :size="28" />
              <p>{{ emptyText }}</p>
              <AButton
                v-if="unlocatedCount > 0 && locateFilter === 'located'"
                type="primary"
                ghost
                size="small"
                @click="locateFilter = 'unlocated'"
              >
                去设置坐标
              </AButton>
            </div>

            <div
              v-for="group in groupedList"
              :key="group.key"
              class="device-map-panel__group"
            >
              <button
                type="button"
                class="device-map-panel__group-head"
                @click="toggleGroup(group.key)"
              >
                <Icon
                  :icon="collapsedGroups[group.key] ? 'ant-design:caret-right-filled' : 'ant-design:caret-down-filled'"
                  :size="12"
                />
                <span class="device-map-panel__group-title">{{ group.title }}</span>
                <span class="device-map-panel__group-count">{{ group.items.length }}</span>
              </button>

              <div v-show="!collapsedGroups[group.key]" class="device-map-panel__group-body">
                <div
                  v-for="item in group.items"
                  :key="String(item.id)"
                  class="device-map-panel__item"
                  :class="{
                    'is-active': String(selectedId) === String(item.id),
                    'is-located': hasLocation(item),
                    'is-online': isOnline(item),
                  }"
                >
                  <div
                    class="device-map-panel__item-body"
                    @click="handleSelectDevice(item)"
                  >
                    <span
                      class="device-map-panel__dot"
                      :title="isOnline(item) ? '在线' : '离线'"
                    />
                    <div class="device-map-panel__item-main">
                      <div class="device-map-panel__item-name" :title="item.deviceName">
                        {{ item.deviceName || item.deviceIdentification }}
                      </div>
                      <div class="device-map-panel__item-meta">
                        <span v-if="hasLocation(item)" class="device-map-panel__addr">
                          <Icon icon="ant-design:environment-filled" :size="11" />
                          {{ item.address || formatCoord(item) }}
                        </span>
                        <span v-else class="device-map-panel__id">
                          {{ item.deviceIdentification }}
                        </span>
                      </div>
                    </div>
                  </div>

                  <!-- 单一主操作：待上图=设置坐标；已上图=定位到地图 + 改坐标 -->
                  <div class="device-map-panel__item-actions">
                    <template v-if="hasLocation(item)">
                      <AButton
                        type="default"
                        size="small"
                        class="device-map-panel__action-btn"
                        @click="flyToDevice(item)"
                      >
                        <template #icon>
                          <Icon icon="ant-design:aim-outlined" :size="13" />
                        </template>
                        定位
                      </AButton>
                      <AButton
                        type="text"
                        size="small"
                        class="device-map-panel__action-link"
                        @click="openLocationModal(item)"
                      >
                        改坐标
                      </AButton>
                    </template>
                    <AButton
                      v-else
                      type="primary"
                      size="small"
                      ghost
                      class="device-map-panel__action-btn is-set"
                      @click="openLocationModal(item)"
                    >
                      <template #icon>
                        <Icon icon="ant-design:environment-outlined" :size="13" />
                      </template>
                      设置坐标
                    </AButton>
                  </div>
                </div>
              </div>
            </div>
          </a-spin>
        </div>

        <div class="device-map-panel__sider-foot">
          <span v-if="locatedCount > 0">地图已显示 {{ locatedCount }} 个点位</span>
          <span v-else>设置坐标后，设备会出现在右侧地图</span>
        </div>
      </aside>

      <section class="device-map-panel__content">
        <div class="device-map-panel__map-wrap">
          <IotDeviceMap
            ref="mapRef"
            height="100%"
            :total-device-count="deviceList.length"
            @marker-click="onMarkerClick"
          />
        </div>
      </section>
    </div>

    <DeviceLocationModal @register="registerLocationModal" @success="reloadAll" />
  </div>
</template>

<script lang="ts" setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue';
import { Button as AButton } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useModal } from '@/components/Modal';
import { IotDeviceMap } from '@/components/TiandituMap';
import type { MapMarkerData } from '@/components/TiandituMap';
import {
  getIotDeviceLocations,
  type IotDeviceMapLocation,
} from '@/api/device/devices';
import { useMessage } from '@/hooks/web/useMessage';
import { triggerWindowResize } from '@/utils/event';
import DeviceLocationModal from './DeviceLocationModal.vue';

defineOptions({ name: 'DeviceMapPanel' });

type LocateFilter = 'all' | 'located' | 'unlocated';

interface DeviceGroup {
  key: string;
  title: string;
  order: number;
  items: IotDeviceMapLocation[];
}

const DEVICE_TYPE_META: Record<string, { title: string; order: number }> = {
  GATEWAY: { title: '网关设备', order: 1 },
  COMMON: { title: '普通设备', order: 2 },
  VIDEO_COMMON: { title: '视频设备', order: 3 },
  SUBSET: { title: '子设备', order: 4 },
};

const { createMessage } = useMessage();
const mapRef = ref<InstanceType<typeof IotDeviceMap> | null>(null);
const listLoading = ref(false);
const keyword = ref('');
const locateFilter = ref<LocateFilter>('all');
const selectedId = ref<string | null>(null);
const deviceList = ref<IotDeviceMapLocation[]>([]);
const collapsedGroups = reactive<Record<string, boolean>>({});

const [registerLocationModal, { openModal: openLocationModalInner }] = useModal();

function hasLocation(item: IotDeviceMapLocation) {
  return (
    item.hasLocation === true ||
    (item.longitude != null &&
      item.latitude != null &&
      !Number.isNaN(Number(item.longitude)) &&
      !Number.isNaN(Number(item.latitude)))
  );
}

function isOnline(item: IotDeviceMapLocation) {
  return item.online === true || item.connectStatus === 'ONLINE';
}

function formatCoord(item: IotDeviceMapLocation) {
  if (item.longitude == null || item.latitude == null) return '';
  return `${Number(item.longitude).toFixed(5)}, ${Number(item.latitude).toFixed(5)}`;
}

const locatedCount = computed(() => deviceList.value.filter((d) => hasLocation(d)).length);
const unlocatedCount = computed(() => deviceList.value.length - locatedCount.value);

const filteredList = computed(() => {
  const kw = keyword.value.trim().toLowerCase();
  return deviceList.value.filter((item) => {
    if (locateFilter.value === 'located' && !hasLocation(item)) return false;
    if (locateFilter.value === 'unlocated' && hasLocation(item)) return false;
    if (!kw) return true;
    const name = (item.deviceName || '').toLowerCase();
    const id = (item.deviceIdentification || '').toLowerCase();
    const addr = (item.address || '').toLowerCase();
    return name.includes(kw) || id.includes(kw) || addr.includes(kw);
  });
});

const groupedList = computed<DeviceGroup[]>(() => {
  const map = new Map<string, DeviceGroup>();
  for (const item of filteredList.value) {
    const type = item.deviceType || 'OTHER';
    const meta = DEVICE_TYPE_META[type] || { title: '其他设备', order: 9 };
    if (!map.has(type)) {
      map.set(type, { key: type, title: meta.title, order: meta.order, items: [] });
    }
    map.get(type)!.items.push(item);
  }
  return [...map.values()]
    .map((g) => ({
      ...g,
      items: [...g.items].sort((a, b) => {
        const locDiff = Number(hasLocation(b)) - Number(hasLocation(a));
        if (locDiff !== 0) return locDiff;
        const onlineDiff = Number(isOnline(b)) - Number(isOnline(a));
        if (onlineDiff !== 0) return onlineDiff;
        return (a.deviceName || '').localeCompare(b.deviceName || '', 'zh');
      }),
    }))
    .sort((a, b) => a.order - b.order || a.title.localeCompare(b.title, 'zh'));
});

const emptyText = computed(() => {
  if (listLoading.value) return '正在加载设备目录...';
  if (!deviceList.value.length) return '暂无设备，请先在「设备列表」中创建';
  if (locateFilter.value === 'located') return '还没有设备上图';
  if (locateFilter.value === 'unlocated') return '全部设备均已设置坐标';
  return '没有匹配的设备';
});

function toggleGroup(key: string) {
  collapsedGroups[key] = !collapsedGroups[key];
}

async function loadDeviceList() {
  listLoading.value = true;
  try {
    const res = (await getIotDeviceLocations({ has_location: false })) as
      | IotDeviceMapLocation[]
      | { data?: IotDeviceMapLocation[] };
    deviceList.value = Array.isArray(res) ? res : res?.data || [];
  } catch (e) {
    console.error(e);
    deviceList.value = [];
    createMessage.error('加载设备目录失败');
  } finally {
    listLoading.value = false;
  }
}

async function ensureMapReady() {
  await nextTick();
  mapRef.value?.updateMapSize?.();
  await new Promise<void>((r) => requestAnimationFrame(() => r()));
  mapRef.value?.updateMapSize?.();
  triggerWindowResize();
}

async function reloadAll() {
  await Promise.all([loadDeviceList(), mapRef.value?.refresh?.()]);
  await ensureMapReady();
}

function flyToDevice(item: IotDeviceMapLocation) {
  if (!hasLocation(item)) return;
  selectedId.value = String(item.id);
  mapRef.value?.flyTo(Number(item.longitude), Number(item.latitude));
}

function handleSelectDevice(item: IotDeviceMapLocation) {
  selectedId.value = String(item.id);
  if (hasLocation(item)) {
    mapRef.value?.flyTo(Number(item.longitude), Number(item.latitude));
  }
}

function onMarkerClick(marker: MapMarkerData) {
  selectedId.value = marker.id;
  mapRef.value?.flyTo(marker.lng, marker.lat);
}

function openLocationModal(item: IotDeviceMapLocation) {
  selectedId.value = String(item.id);
  openLocationModalInner(true, {
    id: item.id,
    deviceName: item.deviceName,
    deviceIdentification: item.deviceIdentification,
    deviceType: item.deviceType,
  });
}

onMounted(async () => {
  await loadDeviceList();
  await mapRef.value?.refresh?.();
  await ensureMapReady();
  window.setTimeout(() => void ensureMapReady(), 200);
});

defineExpose({
  refresh: reloadAll,
  resizeMap: () => void ensureMapReady(),
});
</script>

<style scoped lang="less">
.device-map-panel {
  flex: 1;
  width: 100%;
  min-width: 0;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;

  &__layout {
    flex: 1;
    width: 100%;
    min-width: 0;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: row;
    background: #fff;
    overflow: hidden;
  }

  &__sider {
    width: 380px;
    flex: 0 0 380px;
    border-right: 1px solid #e5e7eb;
    height: 100%;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    background: #fff;
  }

  &__sider-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 12px 12px 10px;
    flex-shrink: 0;
    background: linear-gradient(180deg, #fafbfc 0%, #fff 100%);
    border-bottom: 1px solid #eef0f3;
  }

  &__sider-title {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
  }

  &__sider-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: 6px;
    background: #eff6ff;
    color: #3b82f6;
    flex-shrink: 0;
  }

  &__sider-heading {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  &__sider-name {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    line-height: 1.2;
  }

  &__sider-desc {
    font-size: 12px;
    color: #9ca3af;
    line-height: 1.2;
  }

  &__stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px;
    padding: 10px 12px 0;
    flex-shrink: 0;
  }

  &__stat {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    padding: 8px 4px;
    border: 1px solid #eef0f3;
    border-radius: 8px;
    background: #fafbfc;
    cursor: pointer;
    transition: all 0.15s ease;
    color: #6b7280;

    strong {
      font-size: 16px;
      font-weight: 600;
      color: #111827;
      font-variant-numeric: tabular-nums;
      line-height: 1.2;
    }

    span {
      font-size: 12px;
      line-height: 1.2;
    }

    &:hover {
      border-color: #dbeafe;
      background: #f8fbff;
    }

    &.is-active {
      border-color: #93c5fd;
      background: #eff6ff;
      color: #2563eb;

      strong {
        color: #1d4ed8;
      }
    }

    &.is-located.is-active {
      border-color: #93c5fd;
      background: #eff6ff;
    }

    &.is-pending.is-active {
      border-color: #fcd34d;
      background: #fffbeb;
      color: #d97706;

      strong {
        color: #b45309;
      }
    }
  }

  &__search {
    padding: 10px 12px;
    flex-shrink: 0;
  }

  &__list {
    flex: 1;
    min-height: 0;
    overflow: auto;
    padding: 0 8px 8px;
  }

  &__empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    padding: 48px 16px;
    text-align: center;
    color: #9ca3af;

    p {
      margin: 0;
      font-size: 13px;
      line-height: 1.5;
    }
  }

  &__group {
    margin-bottom: 4px;
  }

  &__group-head {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 8px;
    border: 0;
    background: transparent;
    cursor: pointer;
    border-radius: 6px;

    &:hover {
      background: #f9fafb;
    }
  }

  &__group-title {
    flex: 1;
    text-align: left;
    font-size: 12px;
    font-weight: 600;
    color: #6b7280;
  }

  &__group-count {
    min-width: 18px;
    height: 18px;
    padding: 0 6px;
    border-radius: 9px;
    background: #f3f4f6;
    color: #6b7280;
    font-size: 11px;
    line-height: 18px;
    text-align: center;
    font-variant-numeric: tabular-nums;
  }

  &__group-body {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px;
    border-radius: 8px;
    border: 1px solid #f0f0f0;
    background: #fff;
    transition: border-color 0.15s, background 0.15s, box-shadow 0.15s;

    &:hover {
      border-color: #dbeafe;
      background: #f8fbff;
    }

    &.is-active {
      border-color: #93c5fd;
      background: #eff6ff;
      box-shadow: 0 0 0 1px #bfdbfe inset;
    }

    &.is-located {
      border-color: #e5e7eb;
    }
  }

  &__item-body {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    flex: 1;
    min-width: 0;
    cursor: pointer;
  }

  &__dot {
    display: block;
    width: 8px;
    height: 8px;
    margin-top: 5px;
    border-radius: 50%;
    background: #d1d5db;
    flex-shrink: 0;
  }

  &__item.is-online &__dot {
    background: #22c55e;
    box-shadow: 0 0 0 3px #dcfce7;
  }

  &__item-main {
    flex: 1;
    min-width: 0;
  }

  &__item-name {
    font-size: 13px;
    font-weight: 500;
    color: #111827;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__item-meta {
    margin-top: 3px;
    font-size: 12px;
    color: #9ca3af;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__addr {
    display: inline-flex;
    align-items: center;
    gap: 3px;
    color: #2563eb;
  }

  &__id {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 11px;
  }

  &__item-actions {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-shrink: 0;
  }

  &__action-btn {
    height: 28px;
    padding: 0 10px;
    font-size: 12px;
    border-radius: 6px;

    &.is-set {
      min-width: 88px;
    }
  }

  &__action-link {
    height: 28px;
    padding: 0 6px;
    font-size: 12px;
    color: #6b7280;

    &:hover {
      color: #2563eb;
    }
  }

  &__sider-foot {
    padding: 10px 12px;
    border-top: 1px solid #eef0f3;
    background: #fafbfc;
    font-size: 12px;
    color: #9ca3af;
    flex-shrink: 0;
    line-height: 1.4;
  }

  &__content {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-width: 0;
    min-height: 0;
    height: 100%;
    background: #e8edf3;
  }

  &__map-wrap {
    position: relative;
    flex: 1;
    min-height: 0;
    height: 100%;
    overflow: hidden;

    :deep(.iot-device-map) {
      position: absolute;
      inset: 0;
      height: auto;
      min-height: 0;
      border-radius: 0;

      .ant-card-body {
        height: 100%;
      }
    }

    :deep(.basic-tianditu-map) {
      position: absolute;
      inset: 0;
      height: auto;
    }
  }
}
</style>

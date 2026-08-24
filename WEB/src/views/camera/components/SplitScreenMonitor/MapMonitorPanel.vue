<template>
  <div class="map-monitor-panel">
    <a-layout class="map-monitor-panel__layout">
      <a-layout-sider :width="350" theme="light" class="device-tree-sider">
        <CollapseContainer :can-expan="true" class="tree-container">
          <template #title>
            <div class="tree-header-title">
              <span class="tree-header-title__icon">
                <Icon icon="ant-design:folder-outlined" :size="16" />
              </span>
              <span class="tree-header-title__text">设备目录</span>
            </div>
          </template>
          <template #action="{ expand, onClick }">
            <div class="tree-header-actions">
              <AButton :loading="treeLoading || treeRefreshing" @click.stop="handleRefreshTree">
                <template #icon>
                  <Icon icon="ant-design:reload-outlined" />
                </template>
                刷新
              </AButton>
              <BasicArrow up :expand="expand" @click="onClick" />
            </div>
          </template>
          <div class="tree-scroll">
            <BasicTree
              search
              :show-icon="true"
              :indent="12"
              v-model:selectedKeys="selectedKeys"
              :expanded-keys="expandedKeys"
              :tree-data="treeData"
              :load-data="onLoadGbDeviceChannels"
              :field-names="{ key: 'key', title: 'title' }"
              class="device-tree"
              @select="handleTreeSelect"
              @update:expanded-keys="expandedKeys = $event"
            />
          </div>
        </CollapseContainer>
      </a-layout-sider>

      <a-layout-content class="map-monitor-panel__content">
        <div class="map-monitor-panel__map-wrap">
          <DeviceMonitorMap
            ref="mapRef"
            :directory-id="directoryId"
            height="100%"
            @marker-click="onMarkerClick"
          />
        </div>
      </a-layout-content>
    </a-layout>
  </div>
</template>

<script lang="ts" setup>
import { nextTick, onMounted, ref } from 'vue';
import { triggerWindowResize } from '@/utils/event';
import { BasicTree, type TreeItem } from '@/components/Tree';
import { BasicArrow } from '@/components/Basic';
import { Button as AButton } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { CollapseContainer } from '@/components/Container';
import { DeviceMonitorMap } from '@/components/TiandituMap';
import type { MapMarkerData } from '@/components/TiandituMap';
import { type MonitorTreeDeviceNode } from '@/api/device/camera';
import { getDeviceChannels } from '@/api/device/gb28181';
import { useMessage } from '@/hooks/web/useMessage';
import { gb28181VirtualDeviceId, isGb28181Device } from '@/views/camera/utils/deviceLabel';
import {
  collectMonitorTreeExpandedKeys,
  findMonitorTreeNodeByKey,
  parseMonitorDirectoryId,
} from '@/views/camera/utils/monitorDeviceTree';
import {
  buildWvpChannelTreeNodes,
  parseGbChannelKey,
} from '@/views/camera/utils/gb28181Tree';
import { enrichWvpChannelTreeNodes } from '@/views/camera/utils/monitorGbDisplay';
import { getCachedMonitorDirectoryTreeBundle } from '@/views/camera/utils/monitorDirectoryTreeCache';
import {
  loadMonitorDirectoryTreeWithCache,
  type MonitorDirectoryTreeBundle,
} from '@/views/camera/utils/monitorDirectoryTreeLoad';
import type { TreeProps } from 'ant-design-vue';

defineOptions({ name: 'MapMonitorPanel' });

const { createMessage } = useMessage();

const mapRef = ref<InstanceType<typeof DeviceMonitorMap> | null>(null);
const selectedKeys = ref<string[]>([]);
const expandedKeys = ref<string[]>([]);
const treeData = ref<TreeItem[]>([]);
const treeLoading = ref(false);
const treeRefreshing = ref(false);
const directoryId = ref<number | undefined>();
const selectedDeviceId = ref<string | null>(null);

const onLoadGbDeviceChannels: TreeProps['loadData'] = (treeNode) => {
  return new Promise<void>((resolve) => {
    const key = String(treeNode?.key ?? treeNode?.eventKey ?? '');
    if (!key.startsWith('gb_dev_')) {
      resolve();
      return;
    }
    const sipDeviceId = key.slice('gb_dev_'.length);
    const dataRef = (treeNode.dataRef ?? treeNode) as TreeItem;
    if (dataRef?.children?.length) {
      resolve();
      return;
    }
    getDeviceChannels(sipDeviceId)
      .then((res) => {
        const list = res.data || res.list || [];
        dataRef.children = enrichWvpChannelTreeNodes(
          buildWvpChannelTreeNodes(list, sipDeviceId),
          treeData.value,
        );
        dataRef.isLeaf = !dataRef.children?.length;
        treeData.value = [...treeData.value];
        if (!expandedKeys.value.includes(key)) {
          expandedKeys.value = [...expandedKeys.value, key];
        }
        resolve();
      })
      .catch(() => resolve());
  });
};

function applyMonitorTreeBundle(bundle: MonitorDirectoryTreeBundle) {
  treeData.value = bundle.treeItems;
  expandedKeys.value = collectMonitorTreeExpandedKeys(treeData.value);
}

async function loadMonitorTree(force = false) {
  const hasCache = !force && !!getCachedMonitorDirectoryTreeBundle()?.treeItems?.length;
  if (!hasCache) treeLoading.value = true;
  await loadMonitorDirectoryTreeWithCache({
    force,
    skipSync: true,
    onBundle: applyMonitorTreeBundle,
    onRefreshingChange: (v) => {
      treeRefreshing.value = v;
      if (!hasCache && !v) treeLoading.value = false;
    },
    onError: () => {
      if (!treeData.value.length) treeData.value = [];
      treeLoading.value = false;
      treeRefreshing.value = false;
    },
  });
  if (!hasCache) treeLoading.value = false;
}

async function handleRefreshTree() {
  await loadMonitorTree(true);
  await mapRef.value?.refresh();
}

async function focusDeviceOnMap(deviceId: string) {
  selectedDeviceId.value = deviceId;
  await mapRef.value?.refresh();
  await nextTick();
  const located = mapRef.value?.findById?.(deviceId);
  if (!located) {
    createMessage.warning('该摄像头未设置坐标点');
    return;
  }
  mapRef.value?.flyTo(located.lng, located.lat);
}

async function handleTreeSelect(keys: string[] | string) {
  const keyList = Array.isArray(keys) ? keys : keys ? [keys] : [];
  if (!keyList.length) return;
  const key = String(keyList[0]);

  const dirId = parseMonitorDirectoryId(key);
  if (dirId != null) {
    directoryId.value = dirId;
    await mapRef.value?.refresh();
    return;
  }

  if (key.startsWith('gb_dev_') || key.startsWith('nvr_') || key.startsWith('gb_dir_')) {
    createMessage.info('请展开并选择具体通道或摄像头');
    return;
  }

  if (key.startsWith('gb_ch_')) {
    // 国标通道已同步坐标入库为虚拟设备 gb28181_{sip}_{channel}，按其定位
    const gb = parseGbChannelKey(key);
    if (!gb) {
      createMessage.warn('无效的国标通道');
      return;
    }
    await focusDeviceOnMap(gb28181VirtualDeviceId(gb.sipDeviceId, gb.channelId));
    return;
  }

  if (!key.startsWith('device_')) return;

  const node = findMonitorTreeNodeByKey(treeData.value, key);
  const device = (node as { device?: MonitorTreeDeviceNode })?.device;
  if (!device) {
    createMessage.warn('无效设备');
    return;
  }
  if (isGb28181Device(device.source, device.device_kind)) {
    createMessage.info('请展开上级国标设备并选择通道');
    return;
  }
  await focusDeviceOnMap(device.id);
}

function onMarkerClick(marker: MapMarkerData) {
  if (marker.kind !== 'camera') return;
  selectedDeviceId.value = marker.id;
  selectedKeys.value = [`device_${marker.id}`];
  mapRef.value?.flyTo(marker.lng, marker.lat);
}

async function ensureMapReady() {
  await nextTick();
  mapRef.value?.updateMapSize?.();
  await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  mapRef.value?.updateMapSize?.();
  await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
  mapRef.value?.updateMapSize?.();
  triggerWindowResize();
}

onMounted(async () => {
  await loadMonitorTree();
  await mapRef.value?.refresh();
  await ensureMapReady();
});

function resizeMap() {
  void ensureMapReady();
}

defineExpose({
  refresh: async () => {
    await loadMonitorTree(true);
    await mapRef.value?.refresh();
    await ensureMapReady();
  },
  resizeMap,
});
</script>

<style scoped lang="less">
.map-monitor-panel {
  flex: 1;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;

  &__layout {
    flex: 1;
    min-height: 0;
    height: 100%;
    background: #fff;
    overflow: hidden;

    &:deep(.ant-layout),
    &:deep(.ant-layout-content) {
      height: 100%;
      min-height: 0;
    }
  }

  &__content {
    display: flex;
    flex-direction: column;
    min-width: 0;
    min-height: 0;
    background: #e8edf3;
  }

  &__map-wrap {
    position: relative;
    flex: 1;
    min-height: 0;
    height: 100%;
    overflow: hidden;

    :deep(.device-monitor-map) {
      position: absolute;
      inset: 0;
      height: auto;
      min-height: 0;
      border-radius: 0;

      .ant-card,
      .ant-card-body,
      .ant-spin-nested-loading,
      .ant-spin-container {
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

.device-tree-sider {
  height: 100%;
  overflow: hidden;
  border-right: 1px solid #e5e7eb;

  :deep(.ant-layout-sider-children) {
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .tree-container {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;

    :deep(.xingyuv-collapse-container__header) {
      height: auto;
      min-height: 48px;
      padding: 0 12px !important;
      background: linear-gradient(180deg, #fafbfc 0%, #fff 100%);
      border-bottom: 1px solid #eef0f3;
      border-radius: 0;
    }

    :deep(.xingyuv-basic-title) {
      flex: 1;
      min-width: 0;
      padding-left: 0 !important;
      font-size: inherit;
      font-weight: inherit;
      line-height: inherit;
      cursor: default;
      user-select: none;
    }

    :deep(.xingyuv-collapse-container__action) {
      flex: none;
    }

    :deep(> .p-2) {
      flex: 1;
      min-height: 0;
      overflow: hidden;
      display: flex;
      flex-direction: column;

      > * {
        flex: 1;
        min-height: 0;
        display: flex;
        flex-direction: column;
        overflow: hidden;
      }
    }

    :deep(.xingyuv-collapse-container__body) {
      flex: 1;
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
  }
}

.tree-header-title {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;

  &__icon {
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

  &__text {
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    line-height: 1;
    letter-spacing: 0.01em;
  }
}

.tree-header-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}

.tree-scroll {
  flex: 1;
  min-height: 0;
  overflow: hidden;
  padding: 12px;
  display: flex;
  flex-direction: column;

  :deep(.device-tree) {
    flex: 1;
    min-height: 0;
    height: 100%;
    overflow: hidden;
    display: flex;
    flex-direction: column;

    .ant-spin-nested-loading,
    .ant-spin-container {
      flex: 1;
      min-height: 0;
      height: 100%;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .scroll-container {
      flex: 1;
      min-height: 0;
    }

    .ant-tree-switcher {
      width: 16px;
      margin-inline-end: 2px;
    }

    .ant-tree-switcher-noop {
      width: 8px;
    }

    .ant-tree-node-content-wrapper {
      padding-inline: 2px 6px;
      min-height: 26px;
      line-height: 26px;
    }

    .ant-tree-title,
    [class*='-tree__title'] {
      padding-left: 0 !important;
      padding-right: 8px;
    }
  }
}
</style>

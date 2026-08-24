<template>
  <div class="snap-space-page">
    <div class="page-header">
      <div class="header-left">
        <Button
          type="text"
          class="back-btn"
          preIcon="ant-design:arrow-left-outlined"
          @click="goBack"
        >
          返回上一级
        </Button>
        <div v-if="spaceInfo" class="space-info">
          <h1 class="page-title">{{ spaceInfo.space_name }}</h1>
          <div class="page-meta">
            <a-tag color="blue">抓拍空间</a-tag>
            <span v-if="spaceInfo.device_id">设备 {{ spaceInfo.device_id }}</span>
          </div>
        </div>
      </div>
    </div>

    <div class="mode-toolbar">
      <RadioGroup
        v-model:value="contentTab"
        button-style="solid"
        size="middle"
        class="mode-radio-group"
        @change="handleContentTabChange"
      >
        <RadioButton value="alerts">
          <span class="mode-radio-item">
            <Icon icon="ant-design:alert-outlined" />
            算法告警
          </span>
        </RadioButton>
        <RadioButton value="images">
          <span class="mode-radio-item">
            <Icon icon="ant-design:picture-outlined" />
            抓拍图库
          </span>
        </RadioButton>
      </RadioGroup>
      <span v-if="contentTab === 'alerts'" class="mode-hint">按日期查看设备算法告警，支持跳转抓拍图库与告警录像</span>
      <span v-else class="mode-hint">图片列表来自数据库索引，按抓拍时间倒序展示（无需同步 MinIO）</span>
    </div>

    <div class="content-body">
      <div
        v-if="alertsMounted"
        v-show="contentTab === 'alerts'"
        class="panel-shell"
      >
        <SpaceAlgorithmAlertPanel
          ref="alertPanelRef"
          :device-id="spaceInfo?.device_id"
          show-gallery-link
          show-snap-link
          @view-gallery-date="openGalleryForSelectedDate"
          @view-snap="openGalleryForAlert"
          @view-record="handleViewRecord"
        />
      </div>

      <div
        v-if="galleryMounted"
        v-show="contentTab === 'images'"
        class="panel-shell gallery-shell"
      >
        <SnapSpaceImageGallery ref="galleryRef" :space-id="activeSpaceId" />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { RadioButton, RadioGroup } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import SnapSpaceImageGallery from '@/views/camera/components/SnapSpace/SnapSpaceImageGallery.vue';
import SpaceAlgorithmAlertPanel, {
  type SpaceAlertItem,
} from '@/views/camera/components/SpaceAlgorithmAlertPanel.vue';
import { useMessage } from '@/hooks/web/useMessage';
import { getSnapSpace } from '@/api/device/snap';
import { navigateToAlertRecord } from '@/views/camera/utils/alertRecordNavigate';
import {
  buildCameraStorageQuery,
  parseSpaceFolderQuery,
} from '@/views/camera/utils/spaceSaveTime';

defineOptions({ name: 'SnapSpaceManage' });

const route = useRoute();
const router = useRouter();
const { createMessage } = useMessage();

function parseRouteSpaceId(param: unknown): number | null {
  let raw = param;
  if (Array.isArray(raw)) raw = raw[0];
  if (raw == null || raw === '') return null;
  const id = Number(raw);
  return Number.isFinite(id) && id > 0 ? id : null;
}

const activeSpaceId = ref<number | null>(null);
const galleryRef = ref<InstanceType<typeof SnapSpaceImageGallery> | null>(null);
const alertPanelRef = ref<InstanceType<typeof SpaceAlgorithmAlertPanel> | null>(null);
let loadToken = 0;

function isOnSnapPage(): boolean {
  return route.name === 'SnapSpaceManage';
}

function teardownPage() {
  loadToken += 1;
  activeSpaceId.value = null;
  spaceInfo.value = null;
}

const spaceInfo = ref<{ space_name: string; device_id?: string } | null>(null);
type ContentTab = 'images' | 'alerts';
const contentTab = ref<ContentTab>('alerts');
const alertsMounted = ref(contentTab.value === 'alerts');
const galleryMounted = ref(contentTab.value === 'images');

function normalizeContentTab(value: unknown): ContentTab {
  if (value === 'images') return 'images';
  return 'alerts';
}

function syncContentTabFromRoute() {
  contentTab.value = normalizeContentTab(route.query.view);
  if (contentTab.value === 'alerts') alertsMounted.value = true;
  else galleryMounted.value = true;
}

function handleContentTabChange() {
  const view = contentTab.value;
  if (view === 'alerts') alertsMounted.value = true;
  else galleryMounted.value = true;
  // 与分屏监控一致：仅本地 v-show 切换，不写 URL（fullPath 变化会导致整页 remount）
}

function openGalleryForSelectedDate(date: string) {
  contentTab.value = 'images';
  galleryMounted.value = true;
  void nextTick(() => {
    galleryRef.value?.applyFilters({ date });
  });
}

function openGalleryForAlert(alert: SpaceAlertItem) {
  if (!alert.time) {
    createMessage.warning('缺少告警时间');
    return;
  }
  const date = alert.time.slice(0, 10);
  contentTab.value = 'images';
  galleryMounted.value = true;
  void nextTick(() => {
    galleryRef.value?.applyFilters({ date, source: 'algorithm' });
  });
}

function goBack() {
  teardownPage();
  router.push({
    path: '/camera/index',
    query: buildCameraStorageQuery('snap', parseSpaceFolderQuery(route.query.folder)),
  });
}

async function handleViewRecord(alert: SpaceAlertItem) {
  if (!alert.device_id || !alert.time) {
    createMessage.warning('缺少设备或告警时间');
    return;
  }
  const ok = await navigateToAlertRecord(router, {
    id: alert.id,
    device_id: alert.device_id,
    time: alert.time,
  });
  if (!ok) {
    createMessage.warning('未找到该设备关联的录像空间');
  }
}

async function loadSpaceInfo(token: number) {
  const id = activeSpaceId.value;
  if (id == null || token !== loadToken || !isOnSnapPage()) return;
  try {
    const res = await getSnapSpace(id);
    if (token !== loadToken) return;
    const data = (res as any)?.data ?? res;
    if (data) {
      spaceInfo.value = data;
    }
  } catch (e) {
    console.error(e);
    createMessage.error('加载抓拍空间信息失败');
  }
}

async function initPage() {
  if (!isOnSnapPage()) return;
  syncContentTabFromRoute();
  const id = parseRouteSpaceId(route.params.spaceId);
  if (id == null) return;
  activeSpaceId.value = id;
  const token = ++loadToken;
  await loadSpaceInfo(token);
}

onMounted(() => {
  void initPage();
});

watch(contentTab, (tab) => {
  if (tab === 'alerts') alertsMounted.value = true;
  else galleryMounted.value = true;
});

watch(
  () => route.query.view,
  () => {
    syncContentTabFromRoute();
  },
);

watch(
  () => (isOnSnapPage() ? route.params.spaceId : null),
  (param, prev) => {
    if (!isOnSnapPage()) {
      teardownPage();
      return;
    }
    if (param === prev && activeSpaceId.value != null) return;
    void initPage();
  },
);

onBeforeRouteLeave(() => {
  teardownPage();
});

onBeforeUnmount(() => {
  teardownPage();
});
</script>

<style lang="less" scoped>
.snap-space-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 100px);
  min-height: 600px;
  background: #f0f2f5;
}

.page-header {
  padding: 12px 20px 0;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 12px;

  .header-left {
    display: flex;
    align-items: center;
    gap: 16px;
    padding-bottom: 8px;
    flex: 1;
    min-width: 0;
  }

  .back-btn {
    color: #595959;
    padding-left: 0;
  }

  .page-title {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
  }

  .page-meta {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 4px;
    font-size: 13px;
    color: #8c8c8c;
  }
}

.mode-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;

  .mode-radio-group {
    :deep(.ant-radio-button-wrapper) {
      height: auto;
      line-height: 1;
      padding: 6px 14px;
    }
  }

  .mode-radio-item {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .mode-hint {
    color: #6b7280;
    font-size: 13px;
  }
}

.content-body {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  > .panel-shell {
    flex: 1;
    min-height: 0;
  }
}

.panel-shell {
  margin: 12px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
  background: #fff;
}

.gallery-shell {
  padding: 16px 20px;
  display: flex;
  flex-direction: column;
}
</style>

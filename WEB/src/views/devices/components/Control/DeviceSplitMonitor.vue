<template>
  <div :class="['device-split-monitor', { 'fullscreen-mode': state.isFull }]">
    <a-layout class="monitor-layout">
      <a-layout-sider :width="220" class="camera-list-sider" theme="light">
        <div class="sider-head">
          <div class="sider-title">
            <Icon icon="ant-design:video-camera-outlined" :size="16" />
            <span>关联摄像头</span>
            <span class="sider-count">({{ cameras.length }})</span>
          </div>
          <Button
            size="small"
            type="text"
            :loading="loading"
            @click="loadCameras"
            title="刷新"
          >
            <Icon icon="ant-design:reload-outlined" />
          </Button>
        </div>
        <div class="camera-list-scroll">
          <Spin :spinning="loading">
            <div v-if="!loading && cameras.length === 0" class="list-empty">
              <Icon icon="ant-design:video-camera-outlined" class="list-empty-icon" />
              <p>暂无关联摄像头</p>
              <p class="list-empty-hint">请先在「关联摄像头」页绑定</p>
            </div>
            <div
              v-for="cam in cameras"
              :key="cam.id"
              :class="['camera-item', { active: selectedId === cam.id, offline: !cam.online }]"
              @click="handleSelectCamera(cam)"
            >
              <div class="camera-item-main">
                <Icon
                  :icon="cam.online ? 'ant-design:video-camera-outlined' : 'ant-design:video-camera-add-outlined'"
                  class="camera-icon"
                />
                <div class="camera-meta">
                  <div class="camera-name" :title="cam.name">{{ cam.name }}</div>
                  <div class="camera-sub">{{ cam.ip || cam.id }}</div>
                </div>
              </div>
              <Tag :color="cam.online ? 'success' : 'default'" class="online-tag">
                {{ cam.online ? '在线' : '离线' }}
              </Tag>
            </div>
          </Spin>
        </div>
      </a-layout-sider>

      <a-layout class="monitor-content-layout">
        <a-layout-header class="toolbar-header">
          <div class="toolbar-content">
            <a-radio-group
              v-model:value="state.splitMode"
              size="small"
              button-style="solid"
              @change="handleSplitModeChange"
            >
              <a-radio-button :value="1">1</a-radio-button>
              <a-radio-button :value="4">4</a-radio-button>
              <a-radio-button :value="9">9</a-radio-button>
            </a-radio-group>

            <a-divider type="vertical" class="toolbar-divider" />
            <a-checkbox v-model:checked="enableAi">启用 AI</a-checkbox>
            <a-divider type="vertical" class="toolbar-divider" />

            <Space size="small">
              <Button
                size="small"
                danger
                :disabled="!state.playCells[state.playerIdx]"
                @click="handleGridDelete"
              >
                删除选中
              </Button>
              <Button size="small" :type="state.isFull ? 'default' : 'primary'" @click="handleGridFull">
                {{ state.isFull ? '退出全屏' : '全屏' }}
              </Button>
              <Button size="small" @click="handleClearAll">清空</Button>
            </Space>

            <span class="status-text">已加载 {{ loadedCount }}/{{ state.splitMode }}</span>
          </div>
        </a-layout-header>

        <a-layout-content class="video-content">
          <div :class="['video-grid', `grid-${state.splitMode}`]">
            <div
              v-for="i in state.splitMode"
              :key="i"
              :class="[
                'video-cell',
                {
                  'cell-selected': state.playerIdx === i - 1,
                  'cell-empty': !state.playCells[i - 1],
                  'cell-loading': state.loadingCells.includes(i - 1),
                },
              ]"
              @click="state.playerIdx = i - 1"
            >
              <div v-if="!state.playCells[i - 1]" class="empty-cell">
                <Icon icon="ant-design:video-camera-add-outlined" class="empty-icon" />
                <span class="empty-text">通道 {{ i }}</span>
                <span class="empty-hint">点击左侧关联摄像头播放</span>
              </div>
              <div v-else class="player-wrapper">
                <Jessibuca
                  v-if="state.playCells[i - 1]!.url"
                  :key="`player-${i - 1}-${state.playCells[i - 1]!.deviceId}`"
                  :ref="(el) => setPlayerRef(el, i - 1)"
                  :playUrl="state.playCells[i - 1]!.url"
                  :hasAudio="false"
                  :fill-video="true"
                  :multi-view="state.splitMode > 1"
                  :ai-with-fallback="!!state.playCells[i - 1]!.fallbackUrl"
                  @stream-error="handleCellStreamError(i - 1)"
                />
                <span
                  v-if="state.playCells[i - 1]!.url"
                  class="cell-name"
                  :title="state.playCells[i - 1]!.name"
                >
                  {{ state.playCells[i - 1]!.name }}
                </span>
                <Button
                  type="text"
                  size="small"
                  danger
                  class="cell-close-btn"
                  @click.stop="handleCellDelete(i - 1)"
                >
                  <Icon icon="ant-design:close-outlined" />
                </Button>
              </div>
            </div>
          </div>
        </a-layout-content>
      </a-layout>
    </a-layout>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import {
  Checkbox as ACheckbox,
  Divider as ADivider,
  Layout as ALayout,
  LayoutContent as ALayoutContent,
  LayoutHeader as ALayoutHeader,
  LayoutSider as ALayoutSider,
  RadioButton as ARadioButton,
  RadioGroup as ARadioGroup,
  Space,
  Spin,
  Tag,
} from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { Button } from '@/components/Button';
import Jessibuca from '@/components/Player/module/jessibuca.vue';
import { useMessage } from '@/hooks/web/useMessage';
import { getDeviceCameraLinks } from '@/api/device/devices';
import { getDeviceInfo, type DeviceInfo } from '@/api/device/camera';
import { formatCameraDeviceLabel, getGb28181PlayIds, shouldPlayViaGb28181 } from '@/views/camera/utils/deviceLabel';
import {
  AI_PLAY_FALLBACK_MS,
  pickDirectPlayUrls,
  resolveGbChannelPlayUrls,
  schedulePendingAiStreamUpgrade,
} from '@/views/camera/utils/devicePlay';

defineOptions({ name: 'DeviceSplitMonitor' });

const props = defineProps<{
  iotDeviceId: string | number;
}>();

interface BoundCamera {
  id: string;
  name: string;
  ip?: string;
  online: boolean;
  device: DeviceInfo;
}

interface PlayCell {
  deviceId: string;
  name: string;
  url: string;
  fallbackUrl?: string | null;
}

const { createMessage } = useMessage();

const loading = ref(false);
const cameras = ref<BoundCamera[]>([]);
const selectedId = ref('');
const enableAi = ref(true);
const playerRefs = ref<any[]>([]);
const aiFallbackTimers = new Map<number, number>();

const state = reactive({
  playCells: [] as (PlayCell | null)[],
  splitMode: 4,
  playerIdx: 0,
  isFull: false,
  loadingCells: [] as number[],
});

const loadedCount = computed(() => state.playCells.filter((c) => c?.url).length);

function setPlayerRef(el: any, index: number) {
  if (el) playerRefs.value[index] = el;
}

async function enrichCamera(cameraDeviceId: string): Promise<BoundCamera | null> {
  try {
    const info = await getDeviceInfo(cameraDeviceId);
    const device = (info as any)?.data || (info as any)?.device || info;
    if (!device?.id) return null;
            return {
      id: String(device.id),
      name: formatCameraDeviceLabel(device),
      ip: device.ip,
      online: !!(device.online ?? device.channel_online),
      device,
    };
  } catch {
    return {
      id: cameraDeviceId,
      name: cameraDeviceId,
      online: false,
      device: { id: cameraDeviceId, name: cameraDeviceId } as DeviceInfo,
    };
  }
}

async function loadCameras() {
  if (!props.iotDeviceId) {
    cameras.value = [];
    return;
  }
  loading.value = true;
  try {
    const res = await getDeviceCameraLinks({
      iotDeviceId: props.iotDeviceId,
      pageNum: 1,
      pageSize: 200,
    });
    const links = res?.data || res?.rows || [];
    const enriched = await Promise.all(
      links.map((link: any) => enrichCamera(String(link.cameraDeviceId))),
    );
    cameras.value = enriched.filter(Boolean) as BoundCamera[];
  } catch (e) {
    console.error(e);
    createMessage.error('加载关联摄像头失败');
  } finally {
    loading.value = false;
  }
}

function resolveTargetCellIndex(): number {
  if (!state.playCells[state.playerIdx]) return state.playerIdx;
  const emptyIdx = state.playCells.findIndex((c) => !c);
  if (emptyIdx >= 0) return emptyIdx;
  return state.playerIdx;
}

function clearAiFallbackTimer(cellIdx: number) {
  const timerId = aiFallbackTimers.get(cellIdx);
  if (timerId != null) {
    window.clearTimeout(timerId);
    aiFallbackTimers.delete(cellIdx);
  }
}

function schedulePendingAiUpgrade(
  cellIdx: number,
  deviceId: string,
  aiUrl: string,
  fallbackUrl: string,
) {
  schedulePendingAiStreamUpgrade(
    aiUrl,
    fallbackUrl,
    () => {
      const cell = state.playCells[cellIdx];
      return !!cell && cell.deviceId === deviceId && cell.url !== aiUrl;
    },
    () => {
      const cell = state.playCells[cellIdx];
      if (!cell) return;
      state.playCells[cellIdx] = { ...cell, url: aiUrl, fallbackUrl };
    },
  );
}

async function startPlayAtCell(
  cellIdx: number,
  payload: {
    deviceId: string;
    name: string;
    url: string;
    fallbackUrl?: string | null;
    preferAi?: boolean;
    pendingAiUrl?: string | null;
  },
) {
  clearAiFallbackTimer(cellIdx);
  const fallbackUrl = payload.fallbackUrl?.trim();
  const hasFallback = !!(payload.preferAi && fallbackUrl && fallbackUrl !== payload.url);
  const pendingAi = payload.pendingAiUrl?.trim();

  state.playerIdx = cellIdx;
  state.playCells[cellIdx] = {
    deviceId: payload.deviceId,
    name: payload.name,
    url: payload.url,
    fallbackUrl: hasFallback ? fallbackUrl : null,
  };

  await nextTick();

  if (pendingAi && pendingAi !== payload.url) {
    schedulePendingAiUpgrade(cellIdx, payload.deviceId, pendingAi, payload.url);
  }

  if (!hasFallback) return;

  const primaryUrl = payload.url;
  const timerId = window.setTimeout(() => {
    aiFallbackTimers.delete(cellIdx);
    const cell = state.playCells[cellIdx];
    if (!cell || cell.url !== primaryUrl) return;
    if (playerRefs.value[cellIdx]?.playing) return;
    state.playCells[cellIdx] = { ...cell, url: fallbackUrl!, fallbackUrl: null };
  }, AI_PLAY_FALLBACK_MS);
  aiFallbackTimers.set(cellIdx, timerId);
}

function handleCellStreamError(cellIdx: number) {
  const cell = state.playCells[cellIdx];
  if (!cell) return;
  const fb = cell.fallbackUrl?.trim();
  if (!fb || fb === cell.url) return;
  clearAiFallbackTimer(cellIdx);
  state.playCells[cellIdx] = { ...cell, url: fb, fallbackUrl: null };
}

async function resolvePlayUrls(device: DeviceInfo) {
  const gbIds = getGb28181PlayIds(device as Record<string, any>);
  if (gbIds || shouldPlayViaGb28181(device)) {
    const sipDeviceId =
      gbIds?.sipDeviceId ?? String((device as any).deviceIdentification || '').trim();
    const channelId =
      gbIds?.channelId ??
      String((device as any).channelId || (device as any).channel_id || '').trim();
    if (!sipDeviceId || !channelId) {
      return { url: null as string | null };
    }
    return resolveGbChannelPlayUrls(sipDeviceId, channelId, {
      enableAi: enableAi.value,
      synced: device as any,
    });
  }
  return pickDirectPlayUrls(device, enableAi.value);
}

async function handleSelectCamera(cam: BoundCamera) {
  selectedId.value = cam.id;
  const cellIdx = resolveTargetCellIndex();

  const duplicate = state.playCells.findIndex((c) => c?.deviceId === cam.id);
  if (duplicate >= 0 && duplicate !== state.playerIdx) {
    state.playerIdx = duplicate;
    createMessage.info('该摄像头已在播放，已切换到对应通道');
    return;
  }

  if (state.loadingCells.includes(cellIdx)) return;
  state.loadingCells.push(cellIdx);

  try {
    const { url, fallbackUrl, preferAi, pendingAiUrl } = await resolvePlayUrls(cam.device);
    if (!url) {
      createMessage.warn(
        enableAi.value
          ? '该摄像头暂无 AI 流或原始流地址'
          : '该摄像头暂无可用播放地址',
      );
      return;
    }
    await startPlayAtCell(cellIdx, {
      deviceId: cam.id,
      name: cam.name,
      url,
      fallbackUrl,
      preferAi,
      pendingAiUrl,
    });
  } catch (e) {
    console.error(e);
    createMessage.error('播放失败，请检查设备连接');
  } finally {
    const i = state.loadingCells.indexOf(cellIdx);
    if (i > -1) state.loadingCells.splice(i, 1);
  }
}

async function reloadPlayCellAtIndex(cellIdx: number) {
  const cell = state.playCells[cellIdx];
  if (!cell) return;
  const cam = cameras.value.find((c) => c.id === cell.deviceId);
  if (!cam) return;
  const { url, fallbackUrl, preferAi, pendingAiUrl } = await resolvePlayUrls(cam.device);
  if (!url) return;
  await startPlayAtCell(cellIdx, {
    deviceId: cell.deviceId,
    name: cell.name,
    url,
    fallbackUrl,
    preferAi,
    pendingAiUrl,
  });
}

watch(enableAi, async () => {
  const tasks: Promise<void>[] = [];
  state.playCells.forEach((cell, idx) => {
    if (cell) tasks.push(reloadPlayCellAtIndex(idx));
  });
  await Promise.all(tasks);
});

function handleSplitModeChange() {
  const n = state.splitMode;
  if (state.playCells.length > n) {
    for (let i = n; i < state.playCells.length; i++) {
      playerRefs.value[i]?.destroy?.();
    }
    state.playCells = state.playCells.slice(0, n);
  } else {
    while (state.playCells.length < n) state.playCells.push(null);
  }
  if (state.playerIdx >= n) state.playerIdx = 0;
}

function handleGridDelete() {
  const idx = state.playerIdx;
  if (!state.playCells[idx]) {
    createMessage.warn('当前通道没有视频');
    return;
  }
  playerRefs.value[idx]?.destroy?.();
  state.playCells[idx] = null;
}

function handleCellDelete(index: number) {
  if (!state.playCells[index]) return;
  playerRefs.value[index]?.destroy?.();
  state.playCells[index] = null;
}

function handleClearAll() {
  playerRefs.value.forEach((p, i) => {
    if (p?.destroy && state.playCells[i]) p.destroy();
  });
  state.playCells = Array(state.splitMode).fill(null);
  state.playerIdx = 0;
}

function handleGridFull() {
  state.isFull = !state.isFull;
  if (state.isFull) document.documentElement.requestFullscreen?.();
  else document.exitFullscreen?.();
}

const handleFullscreenChange = () => {
  state.isFull = !!document.fullscreenElement;
};

onMounted(async () => {
  state.playCells = Array(state.splitMode).fill(null);
  await loadCameras();
  document.addEventListener('fullscreenchange', handleFullscreenChange);
});

onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
  aiFallbackTimers.forEach((id) => window.clearTimeout(id));
  aiFallbackTimers.clear();
  playerRefs.value.forEach((p) => p?.destroy?.());
});

defineExpose({ refresh: loadCameras });
</script>

<style lang="less" scoped>
.device-split-monitor {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 420px;
  background: #fff;
  overflow: hidden;
  border-radius: 8px;

  &.fullscreen-mode {
    position: fixed;
    inset: 0;
    z-index: 9999;
    height: 100vh;
    max-height: 100vh;
    border-radius: 0;
  }
}

.monitor-layout {
  flex: 1;
  min-height: 0;
  height: 100%;
  background: #fff;
  overflow: hidden;

  :deep(.ant-layout) {
    height: 100%;
  }
}

.camera-list-sider {
  border-right: 1px solid #f0f0f0;
  background: #fafafa !important;
  overflow: hidden;

  :deep(.ant-layout-sider-children) {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }
}

.sider-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-bottom: 1px solid #f0f0f0;
  background: #fff;
  flex-shrink: 0;
}

.sider-title {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 600;
  color: #262626;
  min-width: 0;

  .sider-count {
    font-weight: 400;
    color: #8c8c8c;
  }
}

.camera-list-scroll {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 8px;
}

.list-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px 12px;
  color: #8c8c8c;
  text-align: center;

  .list-empty-icon {
    font-size: 28px;
    margin-bottom: 8px;
    opacity: 0.45;
  }

  p {
    margin: 0;
    font-size: 13px;
  }

  .list-empty-hint {
    margin-top: 4px;
    font-size: 12px;
    color: #bfbfbf;
  }
}

.camera-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 10px;
  margin-bottom: 6px;
  border-radius: 6px;
  border: 1px solid transparent;
  background: #fff;
  cursor: pointer;
  transition: all 0.15s;

  &:hover {
    border-color: #91caff;
    background: #f0f7ff;
  }

  &.active {
    border-color: #1677ff;
    background: #e6f4ff;
  }

  &.offline {
    opacity: 0.72;
  }
}

.camera-item-main {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  flex: 1;
}

.camera-icon {
  color: #1677ff;
  flex-shrink: 0;
}

.camera-meta {
  min-width: 0;
}

.camera-name {
  font-size: 13px;
  font-weight: 500;
  color: #262626;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.camera-sub {
  margin-top: 2px;
  font-size: 11px;
  color: #8c8c8c;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.online-tag {
  flex-shrink: 0;
  margin: 0;
  font-size: 11px;
  line-height: 18px;
  padding: 0 4px;
}

.monitor-content-layout {
  min-width: 0;
  background: #fff;
}

.toolbar-header {
  height: auto !important;
  min-height: 44px;
  padding: 8px 12px;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
  line-height: normal;
}

.toolbar-content {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 10px;
  width: 100%;
}

.toolbar-divider {
  height: 18px;
  margin: 0;
}

.status-text {
  margin-left: auto;
  color: #8c8c8c;
  font-size: 12px;
}

.video-content {
  flex: 1;
  min-height: 0;
  padding: 8px;
  background: #f5f5f5;
  overflow: hidden;
}

.video-grid {
  display: grid;
  gap: 6px;
  width: 100%;
  height: 100%;

  &.grid-1 {
    grid-template-columns: 1fr;
    grid-template-rows: 1fr;
  }

  &.grid-4 {
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: repeat(2, 1fr);
  }

  &.grid-9 {
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: repeat(3, 1fr);
  }
}

.video-cell {
  position: relative;
  background: #1a1a1a;
  border-radius: 4px;
  overflow: hidden;
  border: 2px solid transparent;
  cursor: pointer;
  min-height: 0;

  &.cell-selected {
    border-color: #1677ff;
  }

  &.cell-loading::after {
    content: '';
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.35);
    z-index: 2;
  }
}

.empty-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #8c8c8c;
  gap: 4px;

  .empty-icon {
    font-size: 28px;
    opacity: 0.4;
  }

  .empty-text {
    font-size: 13px;
  }

  .empty-hint {
    font-size: 11px;
    opacity: 0.7;
  }
}

.player-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
}

.cell-name {
  position: absolute;
  left: 6px;
  bottom: 6px;
  max-width: calc(100% - 40px);
  padding: 2px 6px;
  border-radius: 3px;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 11px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  z-index: 3;
  pointer-events: none;
}

.cell-close-btn {
  position: absolute;
  top: 4px;
  right: 4px;
  z-index: 3;
  color: #fff !important;
  background: rgba(0, 0, 0, 0.4) !important;
}
</style>

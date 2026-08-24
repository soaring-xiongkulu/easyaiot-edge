<template>
  <div class="alert-map-view">
    <AlertMapPanel
      ref="panelRef"
      @stats-change="onStatsChange"
      @view-image="(r) => emit('viewImage', r)"
      @view-video="(r) => emit('viewVideo', r)"
      @set-location="(r) => emit('setLocation', r)"
      @play="(r) => emit('play', r)"
      @view="(r) => emit('view', r)"
      @edit="(r) => emit('edit', r)"
    />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, ref } from 'vue';
import { triggerWindowResize } from '@/utils/event';
import AlertMapPanel from '@/views/alert/components/AlertMapPanel/index.vue';

defineOptions({ name: 'AlertMapView' });

const emit = defineEmits<{
  viewImage: [record: Record<string, unknown>];
  viewVideo: [record: Record<string, unknown>];
  setLocation: [device: Record<string, unknown>];
  play: [device: Record<string, unknown>];
  view: [device: Record<string, unknown>];
  edit: [device: Record<string, unknown>];
}>();

const panelRef = ref<InstanceType<typeof AlertMapPanel> | null>(null);

function onStatsChange(_payload: { located: number; unlocated: number }) {
  // 统计由 AlertMapPanel 侧栏展示，此处预留扩展
}

async function ensureMapReady() {
  await nextTick();
  panelRef.value?.resizeMap?.();
  await new Promise<void>((r) => requestAnimationFrame(() => r()));
  panelRef.value?.resizeMap?.();
  triggerWindowResize();
}

async function init() {
  await panelRef.value?.init?.();
  await ensureMapReady();
}

async function applyFilters(filters: Record<string, unknown>) {
  await panelRef.value?.applyFilters?.(filters);
  await ensureMapReady();
}

async function refresh() {
  await panelRef.value?.refresh?.();
  await ensureMapReady();
}

async function resizeMap() {
  await ensureMapReady();
}

defineExpose({ init, applyFilters, refresh, resizeMap });
</script>

<style scoped lang="less">
.alert-map-view {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 192px);
  max-height: calc(100vh - 192px);
  min-height: 480px;
  overflow: hidden;

  :deep(.geo-loc) {
    flex: 1;
    min-height: 0;
    height: 100%;
  }
}
</style>

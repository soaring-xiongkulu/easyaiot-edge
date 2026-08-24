<template>
  <div class="camera-map-distribution">
    <CameraMapPanel ref="panelRef" />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, onActivated, ref } from 'vue';
import { triggerWindowResize } from '@/utils/event';
import CameraMapPanel from './CameraMapPanel.vue';

defineOptions({ name: 'CameraMapDistribution' });

const panelRef = ref<InstanceType<typeof CameraMapPanel> | null>(null);

async function ensureMapReady() {
  await nextTick();
  panelRef.value?.resizeMap?.();
  await new Promise<void>((r) => requestAnimationFrame(() => r()));
  panelRef.value?.resizeMap?.();
  triggerWindowResize();
}

async function refresh() {
  await panelRef.value?.refresh?.();
  await ensureMapReady();
  window.setTimeout(() => void ensureMapReady(), 150);
}

async function resizeMap() {
  await ensureMapReady();
}

onActivated(() => {
  void refresh();
});

defineExpose({ refresh, resizeMap });
</script>

<style scoped lang="less">
.camera-map-distribution {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 192px);
  max-height: calc(100vh - 192px);
  min-height: 480px;
  overflow: hidden;
}
</style>

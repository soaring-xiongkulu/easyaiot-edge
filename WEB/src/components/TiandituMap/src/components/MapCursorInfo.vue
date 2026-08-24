<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';
import type Map from 'ol/Map';
import { toLonLat } from 'ol/proj';

defineOptions({ name: 'MapCursorInfo' });

const props = defineProps<{
  /** ol 地图实例（来自 BasicTiandituMap 暴露的 map） */
  map?: Map | null;
}>();

const lng = ref<number | null>(null);
const lat = ref<number | null>(null);
const zoom = ref<number | null>(null);

let boundMap: Map | null = null;
let pointerHandler: ((e: { coordinate: number[] }) => void) | null = null;
let moveHandler: (() => void) | null = null;

function unbind() {
  if (boundMap && pointerHandler) boundMap.un('pointermove', pointerHandler as any);
  if (boundMap && moveHandler) boundMap.un('moveend', moveHandler as any);
  boundMap = null;
  pointerHandler = null;
  moveHandler = null;
}

function bind(map: Map) {
  unbind();
  boundMap = map;
  pointerHandler = (evt) => {
    const [x, y] = toLonLat(evt.coordinate);
    lng.value = x;
    lat.value = y;
  };
  moveHandler = () => {
    zoom.value = Math.round(map.getView().getZoom() ?? 0);
  };
  map.on('pointermove', pointerHandler as any);
  map.on('moveend', moveHandler as any);
  zoom.value = Math.round(map.getView().getZoom() ?? 0);
}

watch(
  () => props.map,
  (m) => {
    if (m) bind(m);
    else unbind();
  },
  { immediate: true },
);

onBeforeUnmount(unbind);
</script>

<template>
  <div class="map-cursor-info">
    <span class="map-cursor-info__coord">
      {{ lng != null ? lng.toFixed(5) : '—' }}, {{ lat != null ? lat.toFixed(5) : '—' }}
    </span>
    <span class="map-cursor-info__sep">|</span>
    <span class="map-cursor-info__zoom">Z{{ zoom ?? '—' }}</span>
  </div>
</template>

<style scoped lang="less">
.map-cursor-info {
  position: absolute;
  right: 12px;
  bottom: 12px;
  z-index: 10;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgba(0, 0, 0, 0.7);
  background: rgb(255 255 255 / 92%);
  border: 1px solid #e4e9f2;
  border-radius: 6px;
  box-shadow: 0 2px 8px rgb(15 23 42 / 6%);
  pointer-events: none;

  &__sep {
    color: rgba(0, 0, 0, 0.25);
  }

  &__zoom {
    color: #266cfb;
    font-weight: 600;
  }
}
</style>

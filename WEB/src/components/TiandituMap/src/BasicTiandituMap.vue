<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import 'ol/ol.css';
import { useOpenLayersMap } from '../composables/useOpenLayersMap';
import { DEFAULT_MAP_CENTER, DEFAULT_MAP_ZOOM } from '../constants';
import MapToolbar from './MapToolbar.vue';
import type { BasicTiandituMapProps, LngLat } from '../types';

const props = withDefaults(defineProps<BasicTiandituMapProps>(), {
  center: () => DEFAULT_MAP_CENTER,
  zoom: DEFAULT_MAP_ZOOM,
  baseMapType: 'vec',
  showToolbar: true,
  showScaleLine: true,
  clickable: false,
});

const emit = defineEmits<{
  (e: 'map-click', payload: LngLat): void;
  (e: 'ready'): void;
}>();

const containerRef = ref<HTMLElement | null>(null);

const {
  map,
  baseMapType,
  tryInitMap,
  updateSize,
  switchBaseMap,
  setLabelVisible,
  resetView,
  flyTo,
  fitExtent,
} = useOpenLayersMap(containerRef, {
  center: props.center,
  zoom: props.zoom,
  baseMapType: props.baseMapType,
  showScaleLine: props.showScaleLine,
  showZoom: props.showZoom,
  showFullScreen: props.showFullScreen,
  showOverview: props.showOverview,
  onClick: props.clickable
    ? ({ lng, lat }) => emit('map-click', { lng, lat })
    : undefined,
  onReady: () => emit('ready'),
});

let bootRaf = 0;
let bootAttempts = 0;
const bootTimers: ReturnType<typeof setTimeout>[] = [];
const MAX_BOOT_ATTEMPTS = 200;

function scheduleBoot() {
  if (map.value || bootAttempts >= MAX_BOOT_ATTEMPTS) return;
  bootAttempts += 1;
  cancelAnimationFrame(bootRaf);
  bootRaf = requestAnimationFrame(() => {
    if (!tryInitMap()) scheduleBoot();
  });
}

onMounted(() => {
  scheduleBoot();
  for (const delay of [50, 150, 400, 800]) {
    bootTimers.push(window.setTimeout(() => tryInitMap(), delay));
  }
});

onBeforeUnmount(() => {
  cancelAnimationFrame(bootRaf);
  bootTimers.forEach((id) => clearTimeout(id));
  bootTimers.length = 0;
});

watch(() => props.baseMapType, (t) => switchBaseMap(t));

defineExpose({ map, flyTo, fitExtent, switchBaseMap, setLabelVisible, resetView, baseMapType, updateSize, tryInitMap });
</script>

<template>
  <div class="basic-tianditu-map">
    <div ref="containerRef" class="basic-tianditu-map__canvas" />
    <MapToolbar
      v-if="showToolbar"
      :base-map-type="baseMapType"
      @switch="switchBaseMap"
    />
    <slot />
  </div>
</template>

<style scoped lang="less">
.basic-tianditu-map {
  position: relative;
  flex: 1;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  border-radius: 8px;
  background: #f0f2f5;

  &__canvas {
    position: absolute;
    inset: 0;
    z-index: 0;
  }
}
</style>

<style lang="less">
/**
 * OpenLayers 原生控件重新布局，避开顶部浮动工具栏/左上搜索框/左下图例：
 * 缩放与全屏移到左侧中部纵向排列，比例尺移到底部居中，鹰眼(若启用)置右下。
 */
.basic-tianditu-map {
  .ol-zoom {
    top: 50%;
    left: 8px;
    right: auto;
    bottom: auto;
    transform: translateY(-50%);
  }

  .ol-full-screen {
    top: calc(50% + 46px);
    left: 8px;
    right: auto;
    bottom: auto;
  }

  .ol-scale-line {
    left: 50%;
    bottom: 10px;
    transform: translateX(-50%);
  }

  .ol-overview-map {
    left: auto;
    right: 10px;
    bottom: 40px;
  }
}

/** 测距/测面实时数值气泡 */
.tianditu-measure-tip {
  padding: 2px 8px;
  font-size: 12px;
  font-weight: 600;
  color: #fff;
  white-space: nowrap;
  background: rgba(250, 140, 22, 0.95);
  border-radius: 4px;
  box-shadow: 0 2px 8px rgb(15 23 42 / 18%);
  pointer-events: none;
  transform: translateY(-2px);
}

.tianditu-map-popup {
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 8px 24px rgb(15 23 42 / 12%);
  padding: 10px 14px;
  min-width: 140px;
  border: 1px solid rgb(66 135 252 / 15%);
  pointer-events: none;

  &__title {
    font-size: 13px;
    font-weight: 600;
    color: #1e293b;
  }

  &__sub {
    margin-top: 4px;
    font-size: 11px;
    color: #64748b;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }

  &__meta {
    margin-top: 6px;
    font-size: 11px;
    color: #334155;
  }

  &__tags {
    margin-top: 3px;
    font-size: 11px;
    color: #266cfb;
  }
}
</style>

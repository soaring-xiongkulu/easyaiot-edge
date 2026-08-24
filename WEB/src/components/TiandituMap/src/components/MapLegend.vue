<script setup lang="ts">
import { computed, ref } from 'vue';
import { Icon } from '@/components/Icon';
import { MARKER_COLORS, MARKER_OFFLINE_COLOR } from '../../constants';
import { cameraIconUri } from '../../core/markerStyles';

defineOptions({ name: 'MapLegend' });

interface LegendItem {
  type: 'camera' | 'offline' | 'alert' | 'cluster' | 'heat';
  label: string;
  color: string;
}

const props = withDefaults(
  defineProps<{
    /** 自定义图例项，不传则用默认（摄像头/离线/告警/聚合） */
    items?: LegendItem[];
    /** 默认图例是否包含「有告警」一项（监控图无告警可关） */
    showAlert?: boolean;
    /** 是否包含热力说明 */
    showHeat?: boolean;
    /** 是否展示相机结构（球机/半球/枪机）图例 */
    showStructure?: boolean;
  }>(),
  { showAlert: true, showHeat: false, showStructure: true },
);

const DEFAULT_ITEMS: LegendItem[] = [
  { type: 'camera', label: '摄像头（在线）', color: MARKER_COLORS.camera },
  { type: 'offline', label: '摄像头（离线）', color: MARKER_OFFLINE_COLOR },
  { type: 'alert', label: '有告警（含数量）', color: MARKER_COLORS.alert },
  { type: 'cluster', label: '聚合点（数字为数量）', color: '#4287fc' },
];

const defaultItems = computed(() => DEFAULT_ITEMS.filter((it) => props.showAlert || it.type !== 'alert'));

const STRUCTURE_ITEMS = [
  { structure: 'dome' as const, label: '球机' },
  { structure: 'hemisphere' as const, label: '半球' },
  { structure: 'bullet' as const, label: '枪机' },
  { structure: 'multi' as const, label: '多目' },
];

function structureIcon(structure: 'dome' | 'hemisphere' | 'bullet' | 'multi') {
  return cameraIconUri(MARKER_COLORS.camera, structure);
}

const collapsed = ref(false);
</script>

<template>
  <div class="map-legend" :class="{ 'map-legend--collapsed': collapsed }">
    <button type="button" class="map-legend__head" @click="collapsed = !collapsed">
      <Icon icon="ant-design:unordered-list-outlined" :size="13" />
      <span class="map-legend__title">图例</span>
      <Icon :icon="collapsed ? 'ant-design:up-outlined' : 'ant-design:down-outlined'" :size="11" />
    </button>
    <ul v-show="!collapsed" class="map-legend__list">
      <li v-for="it in (items || defaultItems)" :key="it.type" class="map-legend__item">
        <span class="map-legend__dot" :class="`map-legend__dot--${it.type}`" :style="{ background: it.color }" />
        <span class="map-legend__label">{{ it.label }}</span>
      </li>
      <li v-if="showHeat" class="map-legend__item">
        <span class="map-legend__dot map-legend__dot--heat" />
        <span class="map-legend__label">告警热力（密度）</span>
      </li>
      <template v-if="showStructure">
        <li class="map-legend__sub">相机结构</li>
        <li v-for="s in STRUCTURE_ITEMS" :key="s.structure" class="map-legend__item">
          <img class="map-legend__glyph" :src="structureIcon(s.structure)" :alt="s.label" />
          <span class="map-legend__label">{{ s.label }}</span>
        </li>
      </template>
    </ul>
  </div>
</template>

<style scoped lang="less">
.map-legend {
  position: absolute;
  left: 12px;
  bottom: 12px;
  z-index: 10;
  min-width: 132px;
  padding: 6px 8px;
  background: rgb(255 255 255 / 95%);
  backdrop-filter: blur(6px);
  border: 1px solid #e4e9f2;
  border-radius: 8px;
  box-shadow: 0 4px 14px rgb(15 23 42 / 8%);
  font-size: 12px;

  &__head {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 0;
    border: none;
    background: transparent;
    cursor: pointer;
    color: rgba(0, 0, 0, 0.65);
    font-weight: 600;
  }

  &__title {
    flex: 1;
    text-align: left;
  }

  &__list {
    margin: 6px 0 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  &__item {
    display: flex;
    align-items: center;
    gap: 7px;
    color: rgba(0, 0, 0, 0.7);
  }

  &__sub {
    margin-top: 2px;
    font-size: 11px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.4);
  }

  &__glyph {
    flex-shrink: 0;
    width: 14px;
    height: 18px;
    object-fit: contain;
  }

  &__dot {
    flex-shrink: 0;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 1.5px solid #fff;
    box-shadow: 0 0 0 1px rgb(0 0 0 / 8%);

    &--cluster {
      width: 16px;
      height: 16px;
    }

    &--heat {
      background: linear-gradient(90deg, #2b83ba, #abdda4, #fdae61, #d7191c);
      border-radius: 3px;
    }
  }
}
</style>

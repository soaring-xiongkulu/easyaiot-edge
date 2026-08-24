<script setup lang="ts">
import { Checkbox } from 'ant-design-vue';
import type { TiandituBaseMapType } from '@/components/TiandituMap';

defineOptions({ name: 'MapBaseMapSwitcher' });

withDefaults(
  defineProps<{
    /** 左侧说明文字 */
    label?: string;
    /** 布局：inline 横排，block 纵向 */
    layout?: 'inline' | 'block';
    /** 是否提供地形底图选项 */
    showTerrain?: boolean;
    /** 是否提供注记显隐开关 */
    showLabelToggle?: boolean;
  }>(),
  {
    label: '底图',
    layout: 'inline',
    showTerrain: true,
    showLabelToggle: true,
  },
);

const baseMapType = defineModel<TiandituBaseMapType>('baseMapType', { default: 'vec' });
/** 注记层显隐 */
const showLabel = defineModel<boolean>('showLabel', { default: true });

function pick(type: TiandituBaseMapType, checked: boolean) {
  // 选中即切换；取消勾选时回退到矢量，保证始终有一个底图
  baseMapType.value = checked ? type : 'vec';
}
</script>

<template>
  <div class="map-base-map-switcher" :class="`map-base-map-switcher--${layout}`">
    <span v-if="label" class="map-base-map-switcher__label">{{ label }}</span>
    <div class="map-base-map-switcher__options">
      <Checkbox :checked="baseMapType === 'vec'" @change="(e) => pick('vec', e.target.checked)">
        矢量
      </Checkbox>
      <Checkbox :checked="baseMapType === 'img'" @change="(e) => pick('img', e.target.checked)">
        影像
      </Checkbox>
      <Checkbox v-if="showTerrain" :checked="baseMapType === 'ter'" @change="(e) => pick('ter', e.target.checked)">
        地形
      </Checkbox>
      <Checkbox v-if="showLabelToggle" v-model:checked="showLabel">
        注记
      </Checkbox>
      <slot />
    </div>
  </div>
</template>

<style scoped lang="less">
.map-base-map-switcher {
  display: inline-flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  max-width: 100%;

  &--block {
    flex-direction: column;
    align-items: flex-start;
  }

  &__label {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
    flex-shrink: 0;
    line-height: 24px;
  }

  &__options {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
    min-width: 0;
  }
}
</style>

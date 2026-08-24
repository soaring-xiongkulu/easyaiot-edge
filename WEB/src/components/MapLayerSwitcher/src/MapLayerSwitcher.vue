<script setup lang="ts">
import { Checkbox } from 'ant-design-vue';

defineOptions({ name: 'MapLayerSwitcher' });

withDefaults(
  defineProps<{
    /** 左侧说明文字 */
    label?: string;
    /** 是否展示摄像头图层项 */
    showCameraOption?: boolean;
    /** 是否展示告警图层项 */
    showAlertOption?: boolean;
    /** 布局：inline 横排，block 纵向 */
    layout?: 'inline' | 'block';
  }>(),
  {
    label: '图层',
    showCameraOption: true,
    showAlertOption: true,
    layout: 'inline',
  },
);

const showCameras = defineModel<boolean>('showCameras', { default: true });
const showAlerts = defineModel<boolean>('showAlerts', { default: true });
</script>

<template>
  <div class="map-layer-switcher" :class="`map-layer-switcher--${layout}`">
    <span v-if="label" class="map-layer-switcher__label">{{ label }}</span>
    <div class="map-layer-switcher__options">
      <Checkbox v-if="showCameraOption" v-model:checked="showCameras">
        摄像头
      </Checkbox>
      <Checkbox v-if="showAlertOption" v-model:checked="showAlerts">
        告警
      </Checkbox>
      <slot />
    </div>
  </div>
</template>

<style scoped lang="less">
.map-layer-switcher {
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

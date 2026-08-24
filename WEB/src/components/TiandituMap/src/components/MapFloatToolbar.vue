<script setup lang="ts">
import { MapBaseMapSwitcher } from '@/components/MapBaseMapSwitcher';
import type { TiandituBaseMapType } from '../../types';

withDefaults(
  defineProps<{
    loading?: boolean;
    showRefresh?: boolean;
    showFit?: boolean;
    showReset?: boolean;
    showBaseMapSwitch?: boolean;
  }>(),
  {
    loading: false,
    showRefresh: true,
    showFit: true,
    showReset: true,
    showBaseMapSwitch: true,
  },
);

const baseMapType = defineModel<TiandituBaseMapType>('baseMapType', { default: 'vec' });
const showLabel = defineModel<boolean>('showLabel', { default: true });

const emit = defineEmits<{
  refresh: [];
  fit: [];
  reset: [];
}>();
</script>

<template>
  <div class="map-float-toolbar">
    <div v-if="$slots.tags" class="map-float-toolbar__left">
      <slot name="tags" />
    </div>

    <div class="map-float-toolbar__right">
      <div v-if="showRefresh || showFit || showReset || $slots.extra" class="map-float-toolbar__actions">
        <a-button
          v-if="showRefresh"
          type="default"
          class="map-float-toolbar__btn"
          :loading="loading"
          preIcon="ant-design:reload-outlined"
          @click="emit('refresh')"
        >
          刷新
        </a-button>
        <a-button
          v-if="showReset"
          type="default"
          class="map-float-toolbar__btn"
          preIcon="ant-design:compass-outlined"
          title="复位到默认视野"
          @click="emit('reset')"
        >
          复位
        </a-button>
        <a-button
          v-if="showFit"
          type="default"
          class="map-float-toolbar__btn map-float-toolbar__btn--accent"
          preIcon="ant-design:border-outer-outlined"
          @click="emit('fit')"
        >
          适应视野
        </a-button>
        <slot name="extra" />
      </div>

      <span
        v-if="showBaseMapSwitch && (showRefresh || showFit || showReset || $slots.extra)"
        class="map-float-toolbar__sep"
        aria-hidden="true"
      />

      <MapBaseMapSwitcher
        v-if="showBaseMapSwitch"
        v-model:base-map-type="baseMapType"
        v-model:show-label="showLabel"
        class="map-float-toolbar__base-map"
      />
    </div>
  </div>
</template>

<style scoped lang="less">
.map-float-toolbar {
  position: absolute;
  top: 12px;
  left: 12px;
  right: 12px;
  z-index: 10;
  pointer-events: auto;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 12px 16px;
  min-height: 48px;
  padding: 10px 16px;
  max-width: calc(100% - 24px);
  background: rgb(255 255 255 / 98%);
  backdrop-filter: blur(8px);
  border-radius: 10px;
  border: 1px solid #e4e9f2;
  box-shadow: 0 4px 14px rgb(15 23 42 / 8%);

  &__btn {
    height: 32px;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    border-color: #e4e9f2;
    box-shadow: none;

    &:hover {
      color: #266cfb;
      border-color: rgb(38 108 251 / 45%);
    }

    &--accent {
      color: #fff;
      background: linear-gradient(180deg, #4d8bff 0%, #266cfb 100%);
      border: none;

      &:hover {
        color: #fff;
        background: linear-gradient(180deg, #5c96ff 0%, #4287fc 100%);
        border: none;
      }
    }
  }

  &__left {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;
    flex: 1 1 auto;
    min-width: 0;
  }

  &__right {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: 10px 12px;
    flex: 0 1 auto;
    margin-left: auto;
    min-width: 0;
  }

  &__actions {
    display: inline-flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
  }

  &__sep {
    display: inline-block;
    width: 1px;
    height: 22px;
    background: #d9d9d9;
    flex-shrink: 0;
  }

  &__base-map {
    flex-shrink: 0;
    padding: 2px 0;

    :deep(.map-base-map-switcher__label) {
      font-size: 13px;
      font-weight: 600;
      color: rgba(0, 0, 0, 0.75);
    }

    :deep(.ant-checkbox-wrapper) {
      font-size: 13px;
      font-weight: 500;
      color: rgba(0, 0, 0, 0.88);
    }
  }

  &__left > * {
    flex-shrink: 0;
  }
}
</style>

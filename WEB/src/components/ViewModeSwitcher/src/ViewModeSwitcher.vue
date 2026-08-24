<script setup lang="ts">
import { watch } from 'vue';

defineOptions({ name: 'ViewModeSwitcher' });

const props = withDefaults(
  defineProps<{
    /** 是否显示「地图」视图（告警页等；设备列表请用「切换视图」按钮） */
    showMap?: boolean;
  }>(),
  { showMap: true },
);

const viewMode = defineModel<'table' | 'card' | 'map'>({ default: 'card' });

watch(
  () => [props.showMap, viewMode.value] as const,
  ([showMap, mode]) => {
    if (!showMap && mode === 'map') {
      viewMode.value = 'card';
    }
  },
  { immediate: true },
);
</script>

<template>
  <a-radio-group v-model:value="viewMode" size="small" button-style="solid" class="view-mode-switcher">
    <a-radio-button value="card">
      <span class="view-mode-switcher__label">卡片</span>
    </a-radio-button>
    <a-radio-button value="table">
      <span class="view-mode-switcher__label">表格</span>
    </a-radio-button>
    <a-radio-button v-if="showMap" value="map">
      <span class="view-mode-switcher__label">地图</span>
    </a-radio-button>
  </a-radio-group>
</template>

<style scoped lang="less">
.view-mode-switcher {
  flex-shrink: 0;

  :deep(.ant-radio-button-wrapper) {
    min-width: 52px;
    text-align: center;
    padding-inline: 12px;
  }
}

.view-mode-switcher__label {
  font-size: 13px;
  white-space: nowrap;
}
</style>

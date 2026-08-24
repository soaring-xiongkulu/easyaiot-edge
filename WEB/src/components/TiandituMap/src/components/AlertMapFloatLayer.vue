<script setup lang="ts">
import { Checkbox, Dropdown, Menu, MenuItem } from 'ant-design-vue';
import type Map from 'ol/Map';
import MapFloatToolbar from './MapFloatToolbar.vue';
import MapToolbarStat from './MapToolbarStat.vue';
import MapSearchBox from './MapSearchBox.vue';
import MapLegend from './MapLegend.vue';
import MapCursorInfo from './MapCursorInfo.vue';
import MapCategoryFilter from './MapCategoryFilter.vue';
import { Button } from '@/components/Button';
import type { TiandituBaseMapType } from '../../types';
import { emptyCategoryFilter, type MapCategoryFilterValue } from '../../core/gb28181Catalog';

defineOptions({ name: 'AlertMapFloatLayer' });

defineProps<{
  loading?: boolean;
  cameraCount?: number;
  alertCount?: number;
  offlineCount?: number;
  map?: Map | null;
  showHeatLegend?: boolean;
  /** 当前激活的工具 key，用于高亮 */
  activeTool?: string | null;
}>();

const baseMapType = defineModel<TiandituBaseMapType>('baseMapType', { default: 'vec' });
const showLabel = defineModel<boolean>('showLabel', { default: true });
const showHeat = defineModel<boolean>('showHeat', { default: false });
const offlineOnly = defineModel<boolean>('offlineOnly', { default: false });
const categoryFilter = defineModel<MapCategoryFilterValue>('categoryFilter', {
  default: () => emptyCategoryFilter(),
});

const emit = defineEmits<{
  refresh: [];
  fit: [];
  reset: [];
  search: [payload: { lng: number; lat: number; name: string }];
  locateLatest: [];
  tool: [key: string];
}>();

function onToolClick({ key }: { key: string }) {
  emit('tool', key as string);
}
</script>

<template>
  <MapFloatToolbar
    v-model:base-map-type="baseMapType"
    v-model:show-label="showLabel"
    :loading="loading"
    @refresh="emit('refresh')"
    @fit="emit('fit')"
    @reset="emit('reset')"
  >
    <template #tags>
      <MapSearchBox class="alert-map-float__search" @select="(p) => emit('search', p)" />
      <MapToolbarStat variant="camera" label="摄像头" :count="cameraCount" />
      <MapToolbarStat variant="alert" label="告警" :count="alertCount" />
    </template>
    <template #extra>
      <Checkbox v-model:checked="showHeat" class="alert-map-float__heat">热力</Checkbox>
      <Checkbox v-model:checked="offlineOnly" class="alert-map-float__heat">
        只看离线<span v-if="offlineCount != null" class="alert-map-float__muted">({{ offlineCount }})</span>
      </Checkbox>
      <MapCategoryFilter v-model="categoryFilter" />
      <Button
        type="default"
        class="alert-map-float__btn"
        preIcon="ant-design:aim-outlined"
        title="定位最新告警"
        @click="emit('locateLatest')"
      >
        最新告警
      </Button>
      <Dropdown :trigger="['click']">
        <Button
          type="default"
          class="alert-map-float__btn"
          :class="{ 'alert-map-float__btn--on': !!activeTool }"
          preIcon="ant-design:tool-outlined"
        >
          工具
        </Button>
        <template #overlay>
          <Menu @click="onToolClick">
            <MenuItem key="measure-line">测距</MenuItem>
            <MenuItem key="measure-area">测面</MenuItem>
            <Menu.Divider />
            <MenuItem key="select-circle">圆形框选</MenuItem>
            <MenuItem key="select-rect">矩形框选</MenuItem>
            <MenuItem key="select-polygon">多边形框选</MenuItem>
            <Menu.Divider />
            <MenuItem key="clear">清除绘制</MenuItem>
          </Menu>
        </template>
      </Dropdown>
    </template>
  </MapFloatToolbar>

  <MapLegend :show-heat="showHeatLegend" />
  <MapCursorInfo :map="map" />
</template>

<style scoped lang="less">
.alert-map-float__btn {
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

  &--on {
    color: #266cfb;
    border-color: rgb(38 108 251 / 60%);
    background: rgb(38 108 251 / 8%);
  }
}

.alert-map-float__muted {
  margin-left: 2px;
  color: rgba(0, 0, 0, 0.4);
}
</style>

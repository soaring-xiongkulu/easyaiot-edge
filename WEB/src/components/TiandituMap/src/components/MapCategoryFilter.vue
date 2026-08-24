<script setup lang="ts">
import { computed } from 'vue';
import { Checkbox, CheckboxGroup, Dropdown } from 'ant-design-vue';
import { Button } from '@/components/Button';
import {
  POSITION_TYPE_LABEL,
  USE_TYPE_LABEL,
  emptyCategoryFilter,
  isCategoryFilterActive,
  type MapCategoryFilterValue,
} from '../../core/gb28181Catalog';

defineOptions({ name: 'MapCategoryFilter' });

const model = defineModel<MapCategoryFilterValue>({ default: () => emptyCategoryFilter() });

const useOptions = Object.entries(USE_TYPE_LABEL).map(([v, label]) => ({ value: Number(v), label }));
const positionOptions = Object.entries(POSITION_TYPE_LABEL).map(([v, label]) => ({ value: Number(v), label }));

const active = computed(() => isCategoryFilterActive(model.value));
const activeCount = computed(() => {
  const f = model.value;
  return f.useTypes.length + f.positionTypes.length + (f.outdoorOnly ? 1 : 0) + (f.nightVisionOnly ? 1 : 0);
});

function patch(p: Partial<MapCategoryFilterValue>) {
  model.value = { ...model.value, ...p };
}

function clearAll() {
  model.value = emptyCategoryFilter();
}
</script>

<template>
  <Dropdown :trigger="['click']" placement="bottomRight">
    <Button
      type="default"
      class="map-category-filter__btn"
      :class="{ 'map-category-filter__btn--on': active }"
      preIcon="ant-design:filter-outlined"
    >
      分类<span v-if="activeCount" class="map-category-filter__count">{{ activeCount }}</span>
    </Button>
    <template #overlay>
      <div class="map-category-filter__panel" @click.stop>
        <div class="map-category-filter__group">
          <div class="map-category-filter__title">用途</div>
          <CheckboxGroup
            :value="model.useTypes"
            :options="useOptions"
            @change="(v) => patch({ useTypes: v as number[] })"
          />
        </div>
        <div class="map-category-filter__group">
          <div class="map-category-filter__title">位置类型</div>
          <CheckboxGroup
            :value="model.positionTypes"
            :options="positionOptions"
            class="map-category-filter__pos"
            @change="(v) => patch({ positionTypes: v as number[] })"
          />
        </div>
        <div class="map-category-filter__group">
          <div class="map-category-filter__title">场景</div>
          <Checkbox
            :checked="model.outdoorOnly"
            @change="(e) => patch({ outdoorOnly: e.target.checked })"
          >
            仅室外
          </Checkbox>
          <Checkbox
            :checked="model.nightVisionOnly"
            @change="(e) => patch({ nightVisionOnly: e.target.checked })"
          >
            仅夜视(有补光)
          </Checkbox>
        </div>
        <div class="map-category-filter__foot">
          <Button type="link" size="small" :disabled="!active" @click="clearAll">清除筛选</Button>
        </div>
      </div>
    </template>
  </Dropdown>
</template>

<style scoped lang="less">
.map-category-filter__btn {
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

.map-category-filter__count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 16px;
  height: 16px;
  margin-left: 5px;
  padding: 0 4px;
  font-size: 11px;
  line-height: 16px;
  color: #fff;
  background: #266cfb;
  border-radius: 8px;
}

.map-category-filter__panel {
  width: 280px;
  padding: 12px 14px;
  background: #fff;
  border-radius: 10px;
  box-shadow: 0 6px 24px rgb(15 23 42 / 14%);
}

.map-category-filter__group {
  & + & {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #f0f2f7;
  }
}

.map-category-filter__title {
  margin-bottom: 8px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.55);
}

.map-category-filter__pos :deep(.ant-checkbox-wrapper) {
  width: calc(50% - 8px);
  margin: 2px 0;
  font-size: 13px;
}

.map-category-filter__foot {
  margin-top: 10px;
  text-align: right;
}
</style>

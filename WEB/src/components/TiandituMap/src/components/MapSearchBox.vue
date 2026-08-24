<script setup lang="ts">
import { ref } from 'vue';
import { AutoComplete } from 'ant-design-vue';
import { searchPoi } from '../../core/tiandituApi';
import type { PoiSearchResult } from '../../types';

defineOptions({ name: 'MapSearchBox' });

const emit = defineEmits<{
  /** 选中地点：飞行定位到该坐标 */
  select: [payload: { lng: number; lat: number; name: string }];
}>();

const keyword = ref('');
const loading = ref(false);
const options = ref<Array<{ value: string; label: string; poi: PoiSearchResult }>>([]);

let seq = 0;

async function onSearch(text: string) {
  const q = text.trim();
  if (!q) {
    options.value = [];
    return;
  }
  const mySeq = ++seq;
  loading.value = true;
  try {
    const { items } = await searchPoi({ keyword: q, pageSize: 8 });
    if (mySeq !== seq) return; // 丢弃过期结果
    options.value = items
      .filter((it) => it.lng != null && it.lat != null)
      .map((it) => ({
        value: it.id,
        label: it.address ? `${it.name} · ${it.address}` : it.name,
        poi: it,
      }));
  } finally {
    if (mySeq === seq) loading.value = false;
  }
}

function onSelect(value: string) {
  const opt = options.value.find((o) => o.value === value);
  if (!opt || opt.poi.lng == null || opt.poi.lat == null) return;
  keyword.value = opt.poi.name;
  emit('select', { lng: opt.poi.lng, lat: opt.poi.lat, name: opt.poi.name });
}
</script>

<template>
  <div class="map-search-box">
    <AutoComplete
      v-model:value="keyword"
      :options="options"
      :default-active-first-option="false"
      class="map-search-box__input"
      placeholder="搜索地点 / 道路 / 建筑"
      @search="onSearch"
      @select="onSelect"
    />
  </div>
</template>

<style scoped lang="less">
.map-search-box {
  // 行内嵌入浮动工具栏（随工具栏一起换行，不再绝对定位以免遮挡按钮）
  width: 200px;
  max-width: 100%;

  &__input {
    width: 100%;

    :deep(.ant-select-selector) {
      border-radius: 8px;
      background: #fff;
      border-color: #e4e9f2;
    }
  }
}
</style>

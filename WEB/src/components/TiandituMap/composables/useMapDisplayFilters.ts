import { ref } from 'vue';
import {
  emptyCategoryFilter,
  isCategoryFilterActive,
  matchCategoryFilter,
  type MapCategoryFilterValue,
} from '../core/gb28181Catalog';
import type { MapMarkerData } from '../types';

/**
 * 地图通用「离线 / 业务分类」筛选：在告警图与监控图间共享，避免两处各写一份过滤逻辑。
 * 框选(spatial)筛选由调用方在传入前先行处理（仅告警图有），这里只做与设备属性相关的过滤。
 */
export function useMapDisplayFilters() {
  const offlineOnly = ref(false);
  const categoryFilter = ref<MapCategoryFilterValue>(emptyCategoryFilter());

  function apply(list: MapMarkerData[]): MapMarkerData[] {
    let out = list;
    if (offlineOnly.value) out = out.filter((m) => m.online === false);
    if (isCategoryFilterActive(categoryFilter.value)) {
      out = out.filter((m) => matchCategoryFilter(m, categoryFilter.value));
    }
    return out;
  }

  return { offlineOnly, categoryFilter, apply };
}

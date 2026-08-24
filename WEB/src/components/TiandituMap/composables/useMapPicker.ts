import { ref } from 'vue';
import { reverseGeocode, searchPoi } from '../core/tiandituApi';
import type { MapPickResult, PoiSearchResult } from '../types';

export function useMapPicker() {
  const mode = ref<'click' | 'search'>('click');
  const lng = ref<number | null>(null);
  const lat = ref<number | null>(null);
  const address = ref('');
  const keyword = ref('');
  const results = ref<PoiSearchResult[]>([]);
  const searching = ref(false);
  const page = ref(1);
  const total = ref(0);
  const pageSize = 10;

  async function pickFromClick(lngVal: number, latVal: number) {
    lng.value = lngVal;
    lat.value = latVal;
    address.value = await reverseGeocode({ lng: lngVal, lat: latVal });
  }

  async function search(pageNo = 1) {
    searching.value = true;
    page.value = pageNo;
    try {
      const { items, total: count } = await searchPoi({
        keyword: keyword.value,
        page: pageNo,
        pageSize,
      });
      results.value = items;
      total.value = count;
    } finally {
      searching.value = false;
    }
  }

  async function selectPoi(item: PoiSearchResult) {
    if (item.lng == null || item.lat == null) return null;
    lng.value = item.lng;
    lat.value = item.lat;
    address.value = item.address || await reverseGeocode({ lng: item.lng, lat: item.lat });
    return { lng: item.lng, lat: item.lat, address: address.value } satisfies MapPickResult;
  }

  function reset() {
    lng.value = null;
    lat.value = null;
    address.value = '';
    keyword.value = '';
    results.value = [];
    page.value = 1;
    total.value = 0;
  }

  function confirm(): MapPickResult | null {
    if (lng.value == null || lat.value == null) return null;
    return { lng: lng.value, lat: lat.value, address: address.value };
  }

  return {
    mode,
    lng,
    lat,
    address,
    keyword,
    results,
    searching,
    page,
    total,
    pageSize,
    pickFromClick,
    search,
    selectPoi,
    reset,
    confirm,
  };
}

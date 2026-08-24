<script setup lang="ts">
import { computed } from 'vue';
import MapFloatToolbar from './components/MapFloatToolbar.vue';
import MapToolbarStat from './components/MapToolbarStat.vue';
import type { TiandituBaseMapType } from '../types';

const props = defineProps<{
  baseMapType: TiandituBaseMapType;
  markerCount?: number;
  trackCount?: number;
}>();

const emit = defineEmits<{
  (e: 'switch', type: TiandituBaseMapType): void;
  (e: 'fit'): void;
}>();

const baseMapTypeModel = computed({
  get: () => props.baseMapType,
  set: (value: TiandituBaseMapType) => emit('switch', value),
});
</script>

<template>
  <MapFloatToolbar
    v-model:base-map-type="baseMapTypeModel"
    :show-refresh="false"
    @fit="emit('fit')"
  >
    <template #tags>
      <MapToolbarStat v-if="markerCount != null" variant="marker" label="标记" :count="markerCount" />
      <MapToolbarStat v-if="trackCount != null" variant="track" label="轨迹" :count="trackCount" />
    </template>
  </MapFloatToolbar>
</template>

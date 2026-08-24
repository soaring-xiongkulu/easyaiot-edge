<script setup lang="ts">
import { computed } from 'vue';
import MapFloatToolbar from './MapFloatToolbar.vue';
import MapToolbarStat from './MapToolbarStat.vue';
import type { TiandituBaseMapType } from '../../types';

const props = defineProps<{
  cursorLng?: number | null;
  cursorLat?: number | null;
  zoom?: number;
}>();

const coordStatusText = computed(() => {
  const lng = props.cursorLng != null ? props.cursorLng.toFixed(6) : '—';
  const lat = props.cursorLat != null ? props.cursorLat.toFixed(6) : '—';
  const zoom = props.zoom ?? '—';
  return `${lng}, ${lat}  ·  L${zoom}`;
});

const baseMapType = defineModel<TiandituBaseMapType>('baseMapType', { required: true });

const emit = defineEmits<{
  fit: [];
  goto: [];
}>();
</script>

<template>
  <MapFloatToolbar
    v-model:base-map-type="baseMapType"
    :show-refresh="false"
    @fit="emit('fit')"
  >
    <template #tags>
      <MapToolbarStat variant="info" :value="coordStatusText" />
    </template>
    <template #extra>
      <a-button type="primary" preIcon="ant-design:aim-outlined" @click="emit('goto')">
        定位
      </a-button>
    </template>
  </MapFloatToolbar>
</template>


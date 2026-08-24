<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import BasicTiandituMap from './BasicTiandituMap.vue';
import { useMapTracks } from '../composables/useMapTracks';
import { Button } from '@/components/Button';
import type { MapTrackSession } from '../types';

const props = withDefaults(defineProps<{
  sessions: MapTrackSession[];
  height?: string;
  playbackSpeed?: number;
}>(), {
  height: '560px',
  playbackSpeed: 1,
});

const mapRef = ref<InstanceType<typeof BasicTiandituMap> | null>(null);
const selectedSessionId = ref<string>('');

const tracks = useMapTracks({
  map: computed(() => mapRef.value?.map ?? null),
});

watch(
  () => props.sessions,
  (list) => {
    tracks.setSessions(list);
    selectedSessionId.value = list[0]?.id ?? '';
  },
  { immediate: true },
);

function onSessionChange(id: string) {
  selectedSessionId.value = id;
  tracks.selectSession(id);
}

function onMapReady() {
  tracks.attach();
}

defineExpose({
  startPlayback: () => tracks.startPlayback(props.playbackSpeed),
  stopPlayback: tracks.stopPlayback,
  playing: tracks.playing,
});
</script>

<template>
  <a-card
    :bordered="false"
    :body-style="{ padding: 0, height }"
    class="track-playback-map"
  >
    <BasicTiandituMap ref="mapRef" :show-toolbar="false" @ready="onMapReady">
      <div class="track-playback-map__bar">
        <a-space>
          <a-select
            v-if="sessions.length > 1"
            :value="selectedSessionId"
            style="width: 180px"
            size="small"
            @change="onSessionChange"
          >
            <a-select-option v-for="s in sessions" :key="s.id" :value="s.id">
              {{ s.title || s.deviceId }}
            </a-select-option>
          </a-select>
          <Button
            size="small"
            type="primary"
            pre-icon="ant-design:play-circle-outlined"
            :disabled="!sessions.length"
            @click="tracks.startPlayback(playbackSpeed)"
          >
            {{ tracks.playing.value ? '回放中' : '播放' }}
          </Button>
          <Button
            size="small"
            pre-icon="ant-design:pause-circle-outlined"
            :disabled="!tracks.playing.value"
            @click="tracks.stopPlayback()"
          >
            停止
          </Button>
          <a-progress
            :percent="Math.round(tracks.playProgress.value * 100)"
            size="small"
            class="track-playback-map__progress"
          />
        </a-space>
      </div>
    </BasicTiandituMap>
  </a-card>
</template>

<style scoped lang="less">
.track-playback-map {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 280px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgb(0 0 0 / 4%);

  :deep(.ant-card-body) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  :deep(.basic-tianditu-map) {
    flex: 1;
    min-height: 0;
  }

  &__bar {
    position: absolute;
    bottom: 16px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 10;
    padding: 10px 16px;
    background: rgb(255 255 255 / 96%);
    border-radius: 8px;
    border: 1px solid #f0f0f0;
    box-shadow: 0 2px 8px rgb(0 0 0 / 8%);
  }

  &__progress {
    width: 140px;
    margin: 0;
  }
}
</style>

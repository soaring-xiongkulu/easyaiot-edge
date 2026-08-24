<template>
  <aside class="monitor-control">
    <AudioTalkPanel
      v-if="talkProtocol"
      :protocol="talkProtocol"
      :status="talkStatus"
      :info-text="talkInfoText"
      :volume="talkVolume"
      :noise-suppression="talkNoiseSuppression"
      :echo-cancellation="talkEchoCancellation"
      :level="talkLevel"
      @start="emit('talk-start')"
      @stop="emit('talk-stop')"
      @volume-change="(v) => emit('talk-volume-change', v)"
      @noise-change="(v) => emit('talk-noise-change', v)"
      @echo-change="(v) => emit('talk-echo-change', v)"
    />

    <section class="monitor-control__section monitor-control__section--ptz">
      <div class="monitor-control__section-head">
        <Icon icon="ant-design:control-outlined" :size="15" />
        <span>云台控制</span>
      </div>
      <MonitorPtzPanel @ptz="(cmd, speed) => emit('ptz', cmd, speed)" @aux="(t, a) => emit('aux', t, a)" />
    </section>

    <section v-if="showPresets" class="monitor-control__section monitor-control__section--preset">
      <div class="monitor-control__section-head">
        <Icon icon="ant-design:environment-outlined" :size="15" />
        <span>预置点</span>
      </div>
      <MonitorPresetPanel
        :presets="presets"
        :loading="presetLoading"
        @call="(id) => emit('preset-call', id)"
        @set="(id) => emit('preset-set', id)"
        @delete="(id) => emit('preset-delete', id)"
        @add="emit('preset-add')"
      />
    </section>
  </aside>
</template>

<script lang="ts" setup>
import { Icon } from '@/components/Icon';
import MonitorPtzPanel from './MonitorPtzPanel.vue';
import MonitorPresetPanel, { type PresetItem } from './MonitorPresetPanel.vue';
import AudioTalkPanel from './AudioTalkPanel.vue';
import type { AudioTalkStatus } from './useOnvifAudioTalk';

defineProps<{
  talkProtocol?: 'gb28181' | 'onvif' | null;
  talkStatus?: AudioTalkStatus;
  talkInfoText?: string;
  talkVolume?: number;
  talkNoiseSuppression?: boolean;
  talkEchoCancellation?: boolean;
  talkLevel?: number;
  showPresets?: boolean;
  presets?: PresetItem[];
  presetLoading?: boolean;
}>();

const emit = defineEmits<{
  'talk-start': [];
  'talk-stop': [];
  'talk-volume-change': [value: number];
  'talk-noise-change': [value: boolean];
  'talk-echo-change': [value: boolean];
  ptz: [command: string, speed: number];
  aux: [type: 'focus' | 'iris', action: 'in' | 'out' | 'stop'];
  'preset-call': [id: string | number];
  'preset-set': [id: string | number];
  'preset-delete': [id: string | number];
  'preset-add': [];
}>();
</script>

<style scoped lang="less">
.monitor-control {
  width: 300px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 0;
  background: #fff;
  border-right: 1px solid #e2e8f0;
  overflow-y: auto;
}

.monitor-control__section {
  padding: 14px 16px;

  & + & {
    border-top: 1px solid #f1f5f9;
  }

  &--preset {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }
}

.monitor-control__section-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
  letter-spacing: 0.02em;
}
</style>

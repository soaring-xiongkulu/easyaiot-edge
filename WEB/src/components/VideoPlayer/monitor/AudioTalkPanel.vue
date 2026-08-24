<template>
  <section class="audio-talk">
    <div class="audio-talk__head">
      <div class="audio-talk__title">
        <Icon icon="ant-design:sound-outlined" :size="15" />
        <span>语音对讲</span>
      </div>
      <span class="audio-talk__proto">{{ protocolLabel }}</span>
    </div>

    <div class="audio-talk__core" :class="`audio-talk__core--${status}`">
      <button
        type="button"
        class="audio-talk__mic"
        :class="{ 'is-active': status === 'active', 'is-busy': status === 'connecting' }"
        :disabled="status === 'connecting'"
        :title="micButtonTitle"
        @click="handleMicClick"
      >
        <span class="audio-talk__mic-ring audio-talk__mic-ring--outer" />
        <span class="audio-talk__mic-ring audio-talk__mic-ring--inner" />
        <span class="audio-talk__mic-icon">
          <Icon
            :icon="status === 'active' ? 'ant-design:audio-filled' : 'ant-design:audio-outlined'"
            :size="28"
          />
        </span>
      </button>

      <div class="audio-talk__vu">
        <span
          v-for="i in 12"
          :key="i"
          class="audio-talk__vu-bar"
          :class="{ active: level >= i }"
        />
      </div>

      <div class="audio-talk__state">
        <span class="audio-talk__state-dot" />
        <span>{{ statusText }}</span>
      </div>
    </div>

    <button
      v-if="status !== 'active'"
      type="button"
      class="audio-talk__primary"
      :disabled="status === 'connecting'"
      @click="emit('start')"
    >
      <Icon icon="ant-design:customer-service-outlined" :size="16" />
      {{ status === 'connecting' ? '正在建立通道...' : '开启对讲' }}
    </button>
    <button
      v-else
      type="button"
      class="audio-talk__primary audio-talk__primary--stop"
      @click="emit('stop')"
    >
      <Icon icon="ant-design:pause-circle-outlined" :size="16" />
      结束对讲
    </button>

    <div class="audio-talk__volume">
      <div class="audio-talk__volume-head">
        <span>发送音量</span>
        <span class="audio-talk__volume-val">{{ volume }}%</span>
      </div>
      <Slider
        :value="volume"
        :min="0"
        :max="200"
        :tooltip-open="false"
        @change="(v) => emit('volume-change', Number(v))"
      />
    </div>

    <div class="audio-talk__toggles">
      <label class="audio-talk__toggle">
        <span>降噪</span>
        <Switch size="small" :checked="noiseSuppression" @change="(v) => emit('noise-change', !!v)" />
      </label>
      <label class="audio-talk__toggle">
        <span>回声消除</span>
        <Switch size="small" :checked="echoCancellation" @change="(v) => emit('echo-change', !!v)" />
      </label>
    </div>

    <p class="audio-talk__hint">{{ infoText }}</p>
  </section>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Slider, Switch } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import type { AudioTalkStatus } from './useOnvifAudioTalk';

const props = defineProps<{
  protocol: 'gb28181' | 'onvif';
  status: AudioTalkStatus;
  infoText: string;
  volume: number;
  noiseSuppression: boolean;
  echoCancellation: boolean;
  level: number;
}>();

const emit = defineEmits<{
  start: [];
  stop: [];
  'volume-change': [value: number];
  'noise-change': [value: boolean];
  'echo-change': [value: boolean];
}>();

const protocolLabel = computed(() => (props.protocol === 'gb28181' ? 'GB28181' : 'ONVIF'));

const statusText = computed(() => {
  if (props.status === 'active') return '对讲进行中';
  if (props.status === 'connecting') return '正在连接设备...';
  if (props.status === 'error') return '连接失败，请重试';
  return '待机，点击开启对讲';
});

const micButtonTitle = computed(() => {
  if (props.status === 'active') return '结束对讲';
  if (props.status === 'connecting') return '连接中';
  return '开启对讲';
});

function handleMicClick() {
  if (props.status === 'active') {
    emit('stop');
    return;
  }
  if (props.status === 'idle' || props.status === 'error') {
    emit('start');
  }
}
</script>

<style scoped lang="less">
@accent: #3b6cf5;
@accent-soft: #eff6ff;
@accent-ring: rgba(59, 108, 245, 0.22);

.audio-talk {
  padding: 14px 16px;
  border-bottom: 1px solid #f1f5f9;
}

.audio-talk__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 14px;
}

.audio-talk__title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
}

.audio-talk__proto {
  padding: 2px 8px;
  border-radius: 4px;
  background: #f1f5f9;
  font-size: 11px;
  font-weight: 500;
  color: #64748b;
  letter-spacing: 0.03em;
}

.audio-talk__core {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;

  &--active .audio-talk__state-dot {
    background: @accent;
    box-shadow: 0 0 0 3px @accent-ring;
  }

  &--connecting .audio-talk__state-dot {
    background: #f59e0b;
    animation: talk-pulse 1.2s ease-in-out infinite;
  }

  &--error .audio-talk__state-dot {
    background: #ef4444;
  }
}

.audio-talk__mic {
  position: relative;
  width: 88px;
  height: 88px;
  border: none;
  background: transparent;
  cursor: pointer;
  padding: 0;

  &:disabled {
    cursor: wait;
  }

  &-ring {
    position: absolute;
    border-radius: 50%;
    border: 1px solid #e2e8f0;
    transition: border-color 0.2s ease, transform 0.2s ease;
  }

  &-ring--outer {
    inset: 0;
    background: #f8fafc;
  }

  &-ring--inner {
    inset: 10px;
    background: #fff;
    border-color: #dbeafe;
  }

  &-icon {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #64748b;
    transition: color 0.2s ease;
  }

  &:hover:not(:disabled) &-icon {
    color: @accent;
  }

  &.is-active {
    .audio-talk__mic-ring--outer {
      border-color: #93bbfd;
      background: @accent-soft;
      animation: talk-breathe 2s ease-in-out infinite;
    }

    .audio-talk__mic-ring--inner {
      border-color: @accent;
    }

    .audio-talk__mic-icon {
      color: @accent;
    }
  }

  &.is-busy .audio-talk__mic-ring--outer {
    border-color: #fcd34d;
    animation: talk-breathe 1s ease-in-out infinite;
  }
}

.audio-talk__vu {
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 3px;
  height: 20px;
  width: 100%;
  max-width: 200px;
}

.audio-talk__vu-bar {
  flex: 1;
  max-width: 8px;
  height: 4px;
  border-radius: 2px;
  background: #e2e8f0;
  transition: height 0.08s ease, background 0.08s ease;

  &.active {
    background: @accent;

    &:nth-child(1), &:nth-child(2) { height: 6px; }
    &:nth-child(3), &:nth-child(4) { height: 8px; }
    &:nth-child(5), &:nth-child(6) { height: 10px; }
    &:nth-child(7), &:nth-child(8) { height: 12px; }
    &:nth-child(9), &:nth-child(10) { height: 14px; }
    &:nth-child(11), &:nth-child(12) { height: 16px; }
  }
}

.audio-talk__state {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #64748b;
}

.audio-talk__state-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #94a3b8;
  flex-shrink: 0;
}

.audio-talk__primary {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  height: 36px;
  margin-bottom: 12px;
  border: 1px solid #c7d9fc;
  border-radius: 8px;
  background: @accent-soft;
  color: @accent;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease;

  &:hover:not(:disabled) {
    background: #dbeafe;
    border-color: #93bbfd;
  }

  &:disabled {
    opacity: 0.65;
    cursor: wait;
  }

  &--stop {
    background: #fff;
    border-color: #fecaca;
    color: #dc2626;

    &:hover {
      background: #fef2f2;
      border-color: #fca5a5;
    }
  }
}

.audio-talk__volume {
  margin-bottom: 10px;

  &-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 4px;
    font-size: 12px;
    color: #475569;
  }

  &-val {
    font-variant-numeric: tabular-nums;
    color: #64748b;
  }
}

.audio-talk__toggles {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 10px;
}

.audio-talk__toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  padding: 6px 8px;
  border: 1px solid #f1f5f9;
  border-radius: 6px;
  background: #fafbfc;
  font-size: 11px;
  color: #475569;
  cursor: pointer;
}

.audio-talk__hint {
  margin: 0;
  padding: 8px 10px;
  border-radius: 6px;
  background: #f8fafc;
  font-size: 11px;
  line-height: 1.5;
  color: #94a3b8;
}

@keyframes talk-breathe {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.03); }
}

@keyframes talk-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.45; }
}
</style>

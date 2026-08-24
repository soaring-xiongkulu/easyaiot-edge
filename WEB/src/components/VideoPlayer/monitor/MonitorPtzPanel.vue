<template>
  <div class="monitor-ptz">
    <div class="monitor-ptz__pad">
      <button
        v-for="dir in directions"
        :key="dir.key"
        type="button"
        class="monitor-ptz__dir"
        :class="`monitor-ptz__dir--${dir.key}`"
        :title="dir.label"
        @mousedown="emitPtz(dir.command)"
        @mouseup="emitPtz('STOP')"
        @mouseleave="emitPtz('STOP')"
        @touchstart.prevent="emitPtz(dir.command)"
        @touchend.prevent="emitPtz('STOP')"
      >
        <Icon
          :icon="dir.icon"
          :size="16"
          :style="dir.rotate != null ? { transform: `rotate(${dir.rotate}deg)` } : undefined"
        />
      </button>
      <button type="button" class="monitor-ptz__stop" title="停止" @click="emitPtz('STOP')">
        <Icon icon="ant-design:pause-outlined" :size="18" />
      </button>
    </div>

    <div class="monitor-ptz__speed">
      <span class="monitor-ptz__speed-label">慢</span>
      <Slider v-model:value="speed" :min="1" :max="255" :tooltip-open="false" />
      <span class="monitor-ptz__speed-label">快</span>
    </div>

    <div class="monitor-ptz__tools">
      <div class="monitor-ptz__tool-group">
        <button type="button" title="变倍+" @mousedown="emitPtz('ZOOM_IN')" @mouseup="emitPtz('STOP')" @mouseleave="emitPtz('STOP')">
          <Icon icon="ant-design:zoom-in-outlined" :size="18" />
        </button>
        <button type="button" title="变倍-" @mousedown="emitPtz('ZOOM_OUT')" @mouseup="emitPtz('STOP')" @mouseleave="emitPtz('STOP')">
          <Icon icon="ant-design:zoom-out-outlined" :size="18" />
        </button>
      </div>
      <div class="monitor-ptz__tool-group">
        <button type="button" title="聚焦+" @mousedown="emitAux('focus', 'in')" @mouseup="emitAux('focus', 'stop')" @mouseleave="emitAux('focus', 'stop')">
          <Icon icon="ant-design:eye-outlined" :size="18" />
        </button>
        <button type="button" title="聚焦-" @mousedown="emitAux('focus', 'out')" @mouseup="emitAux('focus', 'stop')" @mouseleave="emitAux('focus', 'stop')">
          <Icon icon="ant-design:eye-invisible-outlined" :size="18" />
        </button>
      </div>
      <div class="monitor-ptz__tool-group">
        <button type="button" title="光圈+" @mousedown="emitAux('iris', 'in')" @mouseup="emitAux('iris', 'stop')" @mouseleave="emitAux('iris', 'stop')">
          <Icon icon="ant-design:highlight-outlined" :size="18" />
        </button>
        <button type="button" title="光圈-" @mousedown="emitAux('iris', 'out')" @mouseup="emitAux('iris', 'stop')" @mouseleave="emitAux('iris', 'stop')">
          <Icon icon="ant-design:bulb-outlined" :size="18" />
        </button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { Slider } from 'ant-design-vue';
import { Icon } from '@/components/Icon';

const emit = defineEmits<{
  ptz: [command: string, speed: number];
  aux: [type: 'focus' | 'iris', action: 'in' | 'out' | 'stop'];
}>();

const speed = ref(80);

const directions = [
  { key: 'up', label: '上', command: 'UP', icon: 'ant-design:up-outlined' },
  { key: 'down', label: '下', command: 'DOWN', icon: 'ant-design:down-outlined' },
  { key: 'left', label: '左', command: 'LEFT', icon: 'ant-design:left-outlined' },
  { key: 'right', label: '右', command: 'RIGHT', icon: 'ant-design:right-outlined' },
  { key: 'left-up', label: '左上', command: 'LEFT_UP', icon: 'ant-design:arrow-up-outlined', rotate: -45 },
  { key: 'right-up', label: '右上', command: 'RIGHT_UP', icon: 'ant-design:arrow-up-outlined', rotate: 45 },
  { key: 'left-down', label: '左下', command: 'LEFT_DOWN', icon: 'ant-design:arrow-down-outlined', rotate: -135 },
  { key: 'right-down', label: '右下', command: 'RIGHT_DOWN', icon: 'ant-design:arrow-down-outlined', rotate: 135 },
];

function emitPtz(command: string) {
  emit('ptz', command, speed.value);
}

function emitAux(type: 'focus' | 'iris', action: 'in' | 'out' | 'stop') {
  emit('aux', type, action);
}
</script>

<style scoped lang="less">
@monitor-accent: #3b6cf5;
@monitor-accent-soft: #eff6ff;
@monitor-accent-hover: #dbeafe;

.monitor-ptz {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.monitor-ptz__pad {
  position: relative;
  width: 168px;
  height: 168px;
  margin: 0 auto;
  border-radius: 50%;
  background: linear-gradient(145deg, #f8fafc, #eef2f7);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8), 0 4px 16px rgba(15, 23, 42, 0.08);
}

.monitor-ptz__dir {
  position: absolute;
  z-index: 2;
  width: 36px;
  height: 36px;
  border: none;
  border-radius: 50%;
  background: #fff;
  color: @monitor-accent;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 2px 6px rgba(59, 108, 245, 0.15);
  transition: background 0.12s ease, box-shadow 0.12s ease, color 0.12s ease;

  &:hover {
    background: @monitor-accent-soft;
    box-shadow: 0 2px 8px rgba(59, 108, 245, 0.22);
  }

  &:active {
    background: @monitor-accent-hover;
    box-shadow: 0 1px 3px rgba(59, 108, 245, 0.18);
  }

  &--up { top: 8px; left: 50%; transform: translateX(-50%); }
  &--down { bottom: 8px; left: 50%; transform: translateX(-50%); }
  &--left { left: 8px; top: 50%; transform: translateY(-50%); }
  &--right { right: 8px; top: 50%; transform: translateY(-50%); }
  &--left-up { top: 28px; left: 28px; }
  &--right-up { top: 28px; right: 28px; }
  &--left-down { bottom: 28px; left: 28px; }
  &--right-down { bottom: 28px; right: 28px; }

  &--up:hover,
  &--up:active { transform: translateX(-50%); }
  &--down:hover,
  &--down:active { transform: translateX(-50%); }
  &--left:hover,
  &--left:active { transform: translateY(-50%); }
  &--right:hover,
  &--right:active { transform: translateY(-50%); }
}

.monitor-ptz__stop {
  position: absolute;
  z-index: 1;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 44px;
  height: 44px;
  border: 2px solid @monitor-accent;
  border-radius: 50%;
  background: #fff;
  color: @monitor-accent;
  cursor: pointer;
  transition: background 0.12s ease, box-shadow 0.12s ease;

  &:hover {
    background: @monitor-accent-soft;
  }

  &:active {
    background: @monitor-accent-hover;
  }
}

.monitor-ptz__speed {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 8px;
  padding: 0 4px;
}

.monitor-ptz__speed-label {
  font-size: 12px;
  color: #64748b;
}

.monitor-ptz__tools {
  display: flex;
  justify-content: space-between;
  gap: 8px;
}

.monitor-ptz__tool-group {
  display: flex;
  gap: 6px;
  flex: 1;
  justify-content: center;

  button {
    flex: 1;
    height: 34px;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    background: #fff;
    color: #334155;
    cursor: pointer;
    transition: background 0.12s ease, border-color 0.12s ease, color 0.12s ease;

    &:hover {
      border-color: @monitor-accent;
      color: @monitor-accent;
      background: @monitor-accent-soft;
    }

    &:active {
      background: @monitor-accent-hover;
    }
  }
}
</style>

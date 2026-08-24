<script setup lang="ts">
import { computed, onBeforeUnmount } from 'vue';
import { Icon } from '@/components/Icon';
import { controlPTZ } from '@/api/device/camera';
import { controlGbPtz } from '@/api/device/gb28181';

defineOptions({ name: 'CameraPtzPad' });

const props = defineProps<{
  deviceId: string;
  deviceKind?: string | null;
}>();

type Dir = 'up' | 'down' | 'left' | 'right' | 'upleft' | 'upright' | 'downleft' | 'downright';

/** 是否国标通道（id 形如 gb28181_{sip}_{channel}），决定走 WVP 还是直连 PTZ */
const gbIds = computed<{ sip: string; channel: string } | null>(() => {
  const id = props.deviceId || '';
  if (!id.startsWith('gb28181_')) return null;
  const rest = id.slice('gb28181_'.length);
  const sep = rest.indexOf('_');
  if (sep <= 0) return null;
  return { sip: rest.slice(0, sep), channel: rest.slice(sep + 1) };
});

const DIR_VECTOR: Record<Dir, { x: number; y: number }> = {
  up: { x: 0, y: 1 },
  down: { x: 0, y: -1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
  upleft: { x: -1, y: 1 },
  upright: { x: 1, y: 1 },
  downleft: { x: -1, y: -1 },
  downright: { x: 1, y: -1 },
};

const SPEED = 0.6;

/** 是否正在持续运动（用于卸载时兜底停止，避免相机失控继续转动） */
let moving = false;

function send(payload: { command?: string; x?: number; y?: number; z?: number }) {
  const gb = gbIds.value;
  if (gb) {
    const command = payload.command ?? 'stop';
    void controlGbPtz(gb.sip, gb.channel, {
      command,
      horizonSpeed: 120,
      verticalSpeed: 120,
      zoomSpeed: 60,
    }).catch(() => {});
    return;
  }
  void controlPTZ(props.deviceId, { x: payload.x ?? 0, y: payload.y ?? 0, z: payload.z ?? 0 }).catch(() => {});
}

function startDir(dir: Dir) {
  const v = DIR_VECTOR[dir];
  moving = true;
  send({ command: dir, x: v.x * SPEED, y: v.y * SPEED, z: 0 });
}
function startZoom(into: boolean) {
  moving = true;
  send({ command: into ? 'zoomin' : 'zoomout', x: 0, y: 0, z: into ? SPEED : -SPEED });
}
function stop() {
  if (!moving) return;
  moving = false;
  send({ command: 'stop', x: 0, y: 0, z: 0 });
}

// 按住期间组件被卸载/切换设备时，兜底下发停止，避免相机持续运动
onBeforeUnmount(stop);

const DIRS: Array<{ dir?: Dir; icon?: string; center?: boolean }> = [
  { dir: 'upleft', icon: 'ant-design:arrow-up-outlined' },
  { dir: 'up', icon: 'ant-design:up-outlined' },
  { dir: 'upright', icon: 'ant-design:arrow-up-outlined' },
  { dir: 'left', icon: 'ant-design:left-outlined' },
  { center: true },
  { dir: 'right', icon: 'ant-design:right-outlined' },
  { dir: 'downleft', icon: 'ant-design:arrow-down-outlined' },
  { dir: 'down', icon: 'ant-design:down-outlined' },
  { dir: 'downright', icon: 'ant-design:arrow-down-outlined' },
];

// 对角线图标旋转角度
const DIAG_ROTATE: Partial<Record<Dir, number>> = {
  upleft: -45, upright: 45, downleft: -135, downright: 135,
};
</script>

<template>
  <div class="camera-ptz-pad">
    <div class="camera-ptz-pad__grid">
      <template v-for="(cell, i) in DIRS" :key="i">
        <span v-if="cell.center" class="camera-ptz-pad__center">
          <Icon icon="ant-design:aim-outlined" :size="14" />
        </span>
        <button
          v-else
          type="button"
          class="camera-ptz-pad__btn"
          @mousedown.prevent="startDir(cell.dir!)"
          @mouseup="stop"
          @mouseleave="stop"
          @touchstart.prevent="startDir(cell.dir!)"
          @touchend.prevent="stop"
          @touchcancel.prevent="stop"
        >
          <Icon
            :icon="cell.icon!"
            :size="14"
            :style="DIAG_ROTATE[cell.dir!] != null ? { transform: `rotate(${DIAG_ROTATE[cell.dir!]}deg)` } : undefined"
          />
        </button>
      </template>
    </div>
    <div class="camera-ptz-pad__zoom">
      <button
        type="button"
        class="camera-ptz-pad__zoom-btn"
        @mousedown.prevent="startZoom(true)"
        @mouseup="stop"
        @mouseleave="stop"
        @touchstart.prevent="startZoom(true)"
        @touchend.prevent="stop"
        @touchcancel.prevent="stop"
      >
        <Icon icon="ant-design:zoom-in-outlined" :size="14" /> 变倍+
      </button>
      <button
        type="button"
        class="camera-ptz-pad__zoom-btn"
        @mousedown.prevent="startZoom(false)"
        @mouseup="stop"
        @mouseleave="stop"
        @touchstart.prevent="startZoom(false)"
        @touchend.prevent="stop"
        @touchcancel.prevent="stop"
      >
        <Icon icon="ant-design:zoom-out-outlined" :size="14" /> 变倍-
      </button>
    </div>
  </div>
</template>

<style scoped lang="less">
.camera-ptz-pad {
  margin-top: 10px;

  &__grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 4px;
    width: 132px;
  }

  &__btn,
  &__center {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    height: 30px;
    border-radius: 6px;
    border: 1px solid #e4e9f2;
    background: #fff;
    color: rgba(0, 0, 0, 0.7);
    cursor: pointer;
    user-select: none;
    transition: all 0.12s;
  }

  &__btn:hover {
    color: #266cfb;
    border-color: rgb(38 108 251 / 45%);
    background: rgb(38 108 251 / 6%);
  }

  &__btn:active {
    background: rgb(38 108 251 / 14%);
  }

  &__center {
    cursor: default;
    color: rgba(0, 0, 0, 0.25);
    background: #f7f9fc;
  }

  &__zoom {
    display: flex;
    gap: 6px;
    margin-top: 6px;
  }

  &__zoom-btn {
    flex: 1;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 4px;
    height: 28px;
    font-size: 12px;
    border-radius: 6px;
    border: 1px solid #e4e9f2;
    background: #fff;
    color: rgba(0, 0, 0, 0.7);
    cursor: pointer;
    user-select: none;

    &:hover {
      color: #266cfb;
      border-color: rgb(38 108 251 / 45%);
    }

    &:active {
      background: rgb(38 108 251 / 14%);
    }
  }
}
</style>

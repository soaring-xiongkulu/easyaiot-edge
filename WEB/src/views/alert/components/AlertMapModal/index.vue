<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    :width="modalWidth"
    :min-height="720"
    :can-fullscreen="true"
    :default-fullscreen="true"
    :show-ok-btn="false"
    :show-cancel-btn="false"
    :footer="null"
    destroy-on-close
    wrap-class-name="geo-loc-modal-wrap"
    @cancel="onModalClose"
  >
    <template #title>
      <div class="geo-loc-modal-head">
        <span class="geo-loc-modal-head__title">地图分布</span>
        <span class="geo-loc-modal-head__line" />
        <span class="geo-loc-modal-head__device">按设备坐标展示告警</span>
        <span
          v-if="statsLocated != null"
          class="geo-loc-modal-head__badge"
          :class="{ 'is-on': statsLocated > 0 }"
        >
          已上图 {{ statsLocated }}
        </span>
        <span
          v-if="statsUnlocated > 0"
          class="geo-loc-modal-head__badge"
        >
          无坐标 {{ statsUnlocated }}
        </span>
      </div>
    </template>

    <!-- 与 DeviceLocationDrawer 相同结构；不用 a-spin 避免未注册组件与高度链断裂 -->
    <div class="geo-loc-spin">
      <AlertMapPanel
        ref="panelRef"
        @stats-change="onStatsChange"
        @view-image="(r) => emit('viewImage', r)"
        @view-video="(r) => emit('viewVideo', r)"
        @set-location="(r) => emit('setLocation', r)"
        @play="(r) => emit('play', r)"
        @view="(r) => emit('view', r)"
        @edit="(r) => emit('edit', r)"
      />
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { nextTick, ref } from 'vue';
import { triggerWindowResize } from '@/utils/event';
import { BasicModal, useModalInner } from '@/components/Modal';
import AlertMapPanel from '@/views/alert/components/AlertMapPanel/index.vue';

defineOptions({ name: 'AlertMapModal' });

const emit = defineEmits<{
  viewImage: [record: Record<string, unknown>];
  viewVideo: [record: Record<string, unknown>];
  setLocation: [device: Record<string, unknown>];
  play: [device: Record<string, unknown>];
  view: [device: Record<string, unknown>];
  edit: [device: Record<string, unknown>];
}>();

const modalWidth = '100vw';
const panelRef = ref<InstanceType<typeof AlertMapPanel> | null>(null);
const statsLocated = ref<number | null>(null);
const statsUnlocated = ref(0);

function onStatsChange(payload: { located: number; unlocated: number }) {
  statsLocated.value = payload.located;
  statsUnlocated.value = payload.unlocated;
}

async function ensureMapReady() {
  await nextTick();
  panelRef.value?.resizeMap?.();
  await new Promise<void>((r) => requestAnimationFrame(() => r()));
  panelRef.value?.resizeMap?.();
  await new Promise<void>((r) => requestAnimationFrame(() => r()));
  panelRef.value?.resizeMap?.();
  triggerWindowResize();
}

const [register, { setModalProps, closeModal }] = useModalInner(
  async (data?: { filters?: Record<string, unknown> }) => {
    setModalProps({ confirmLoading: false });
    statsLocated.value = null;
    statsUnlocated.value = 0;
    await nextTick();
    try {
      if (data?.filters && Object.keys(data.filters).length) {
        await panelRef.value?.applyFilters?.(data.filters);
      } else {
        await panelRef.value?.init?.();
      }
    } finally {
      await ensureMapReady();
      window.setTimeout(() => void ensureMapReady(), 200);
      window.setTimeout(() => void ensureMapReady(), 500);
    }
  },
);

function onModalClose() {
  statsLocated.value = null;
  statsUnlocated.value = 0;
}

async function refresh() {
  await panelRef.value?.refresh?.();
  await ensureMapReady();
}

defineExpose({ refresh, closeModal });
</script>

<style scoped lang="less">
@text: rgba(0, 0, 0, 0.88);
@text-2: rgba(0, 0, 0, 0.55);
@divider: #f0f2f7;

.geo-loc-modal-head {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
  padding-right: 48px;

  &__title {
    flex-shrink: 0;
    font-size: 18px;
    font-weight: 600;
    color: @text;
  }

  &__line {
    width: 1px;
    height: 20px;
    background: @divider;
    flex-shrink: 0;
  }

  &__device {
    min-width: 0;
    font-size: 16px;
    font-weight: 500;
    color: @text;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__badge {
    flex-shrink: 0;
    margin-left: auto;
    padding: 5px 14px;
    font-size: 13px;
    color: @text-2;
    background: #f4f5f7;
    border-radius: 20px;
    border: 1px solid rgba(228, 233, 242, 0.9);

    &.is-on {
      color: #16a34a;
      background: rgba(22, 163, 74, 0.1);
      border-color: rgba(22, 163, 74, 0.2);
    }

    & + & {
      margin-left: 0;
    }
  }
}

/* 与 DeviceLocationDrawer 一致（div 替代 a-spin，样式等同 ant-spin-container） */
.geo-loc-spin {
  display: block;
  height: 100%;
  min-height: calc(100vh - 120px);

  :deep(.geo-loc) {
    height: 100%;
    min-height: inherit;
  }
}
</style>

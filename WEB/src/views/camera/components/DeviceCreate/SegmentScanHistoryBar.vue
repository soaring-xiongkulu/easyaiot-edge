<template>
  <Tooltip :title="triggerTooltip">
    <Popover
      v-if="canShowPopover"
      v-model:open="popoverOpen"
      trigger="hover"
      placement="bottomRight"
      overlay-class-name="segment-scan-history-popover"
      :mouse-enter-delay="0.15"
      :mouse-leave-delay="0.12"
    >
      <template #content>
        <div class="history-panel">
          <div class="history-panel__head">
            <span class="history-panel__title">扫描历史</span>
            <span class="history-panel__hint">点击条目回填参数</span>
          </div>
          <ul class="history-list">
            <li
              v-for="entry in historyList"
              :key="entry.id"
              class="history-item"
              @click="handleApply(entry)"
            >
              <div class="history-item__body">
                <div class="history-item__primary">{{ formatSegmentScanHistoryPrimary(entry) }}</div>
                <div class="history-item__meta">{{ formatSegmentScanHistoryMeta(entry) }}</div>
              </div>
              <button
                type="button"
                class="history-item__delete"
                title="删除"
                @click.stop="handleRemove(entry.id)"
              >
                <DeleteOutlined />
              </button>
            </li>
          </ul>
        </div>
      </template>
      <span
        class="segment-scan-history-trigger has-history"
        :class="{ 'is-disabled': disabled }"
      >
        <ClockCircleOutlined />
      </span>
    </Popover>
    <span
      v-else
      class="segment-scan-history-trigger"
      :class="{ 'is-disabled': disabled }"
    >
      <ClockCircleOutlined />
    </span>
  </Tooltip>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Popover, Tooltip } from 'ant-design-vue';
import { ClockCircleOutlined, DeleteOutlined } from '@ant-design/icons-vue';
import { useMessage } from '@/hooks/web/useMessage';
import {
  formatSegmentScanHistoryMeta,
  formatSegmentScanHistoryPrimary,
  loadSegmentScanHistory,
  removeSegmentScanHistory,
  type SegmentScanHistoryEntry,
  type SegmentScanHistoryMode,
} from '@/views/camera/utils/segmentScanHistory';

const props = defineProps<{
  mode: SegmentScanHistoryMode;
  disabled?: boolean;
  refreshToken?: number;
}>();

const emit = defineEmits<{
  apply: [entry: SegmentScanHistoryEntry];
}>();

const { createMessage } = useMessage();

const historyList = ref<SegmentScanHistoryEntry[]>([]);
const popoverOpen = ref(false);

const emptyTooltip = '暂无扫描历史，完成一次跨网段扫描后自动保存';

const canShowPopover = computed(
  () => !props.disabled && historyList.value.length > 0,
);

const triggerTooltip = computed(() => {
  if (props.disabled) {
    return historyList.value.length ? '扫描进行中，请稍候' : emptyTooltip;
  }
  if (!historyList.value.length) return emptyTooltip;
  return '扫描历史，移入查看并回填';
});

function reload() {
  historyList.value = loadSegmentScanHistory(props.mode);
}

watch(
  () => [props.mode, props.refreshToken] as const,
  () => {
    popoverOpen.value = false;
    reload();
  },
  { immediate: true },
);

watch(
  () => props.disabled,
  (v) => {
    if (v) popoverOpen.value = false;
  },
);

function handleApply(entry: SegmentScanHistoryEntry) {
  popoverOpen.value = false;
  emit('apply', entry);
  createMessage.success('已恢复历史扫描参数');
}

function handleRemove(id: string) {
  removeSegmentScanHistory(id);
  reload();
  createMessage.success('已删除');
}

defineExpose({ reload });
</script>

<style lang="less" scoped>
.segment-scan-history-trigger {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 6px;
  color: rgb(0 0 0 / 45%);
  font-size: 16px;
  cursor: pointer;
  transition: color 0.2s, background 0.2s;

  &:hover:not(.is-disabled) {
    color: var(--ant-primary-color, #1677ff);
    background: rgb(22 119 255 / 8%);
  }

  &.has-history {
    color: var(--ant-primary-color, #1677ff);
  }

  &.is-disabled {
    color: rgb(0 0 0 / 25%);
    cursor: not-allowed;
  }
}

.history-panel {
  width: 320px;
  max-width: 80vw;

  &__head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 8px;
    padding-bottom: 8px;
    border-bottom: 1px solid #f0f0f0;
  }

  &__title {
    font-size: 13px;
    font-weight: 600;
    color: rgb(0 0 0 / 88%);
  }

  &__hint {
    font-size: 12px;
    color: rgb(0 0 0 / 45%);
  }
}

.history-list {
  margin: 0;
  padding: 0;
  list-style: none;
  max-height: 280px;
  overflow-y: auto;
}

.history-item {
  display: flex;
  align-items: flex-start;
  gap: 4px;
  padding: 8px 6px;
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.15s;

  &:hover {
    background: #f5f5f5;

    .history-item__delete {
      opacity: 1;
    }
  }

  & + & {
    margin-top: 2px;
  }

  &__body {
    flex: 1;
    min-width: 0;
  }

  &__primary {
    font-size: 13px;
    color: rgb(0 0 0 / 88%);
    line-height: 1.4;
    word-break: break-all;
  }

  &__meta {
    margin-top: 2px;
    font-size: 12px;
    color: rgb(0 0 0 / 45%);
    line-height: 1.35;
  }

  &__delete {
    flex-shrink: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    margin-top: 2px;
    padding: 0;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: rgb(0 0 0 / 35%);
    opacity: 0;
    cursor: pointer;
    transition: opacity 0.15s, color 0.15s, background 0.15s;

    &:hover {
      color: #ff4d4f;
      background: rgb(255 77 79 / 8%);
    }
  }
}
</style>

<style lang="less">
.segment-scan-history-popover {
  .ant-popover-inner {
    padding: 10px 12px;
  }
}
</style>

<template>
  <div class="segment-scan-targets-field">
    <Input.TextArea
      :value="value"
      :disabled="disabled"
      :placeholder="placeholder"
      :auto-size="autoSize"
      allow-clear
      class="segment-scan-targets-field__input"
      @update:value="onInput"
    />
    <SegmentScanHistoryBar
      class="segment-scan-targets-field__history"
      :mode="mode"
      :disabled="disabled"
      :refresh-token="refreshToken"
      @apply="(entry) => emit('applyHistory', entry)"
    />
  </div>
</template>

<script lang="ts" setup>
import { Input } from 'ant-design-vue';
import SegmentScanHistoryBar from './SegmentScanHistoryBar.vue';
import { SEGMENT_SCAN_TARGETS_PLACEHOLDER } from './segmentScanGuide';
import { DEVICE_CREATE_FIELD_LINE_WIDTH } from './deviceCreateForm';
import type { SegmentScanHistoryEntry, SegmentScanHistoryMode } from '@/views/camera/utils/segmentScanHistory';

const fieldLineWidth = `${DEVICE_CREATE_FIELD_LINE_WIDTH}px`;

withDefaults(
  defineProps<{
    value?: string;
    mode: SegmentScanHistoryMode;
    disabled?: boolean;
    refreshToken?: number;
    placeholder?: string;
    autoSize?: { minRows: number; maxRows: number };
  }>(),
  {
    value: '',
    placeholder: SEGMENT_SCAN_TARGETS_PLACEHOLDER,
    autoSize: () => ({ minRows: 3, maxRows: 8 }),
  },
);

const emit = defineEmits<{
  'update:value': [value: string];
  applyHistory: [entry: SegmentScanHistoryEntry];
}>();

function onInput(v: string) {
  emit('update:value', v);
}
</script>

<style lang="less" scoped>
.segment-scan-targets-field {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  width: 100%;
  max-width: v-bind(fieldLineWidth);

  &__input {
    flex: 1;
    min-width: 0;
    width: 100%;

    :deep(textarea.ant-input) {
      resize: none;
    }
  }

  &__history {
    flex-shrink: 0;
    margin-top: 4px;
  }
}
</style>

<template>
  <div class="node-name-field">
    <Input
      :value="value"
      :disabled="disabled"
      :placeholder="placeholder"
      allow-clear
      class="node-name-field__input"
      @update:value="onInput"
      @change="onChange"
    />
    <NodeFormHistoryBar
      v-if="showHistory"
      class="node-name-field__history"
      :refresh-token="refreshToken"
      @apply="(entry) => emit('applyHistory', entry)"
    />
  </div>
</template>

<script lang="ts" setup>
import { Input } from 'ant-design-vue';
import NodeFormHistoryBar from '../NodeFormHistoryBar/index.vue';
import type { NodeFormHistoryEntry } from '../../utils/nodeFormHistory';

withDefaults(
  defineProps<{
    value?: string;
    disabled?: boolean;
    showHistory?: boolean;
    refreshToken?: number;
    placeholder?: string;
  }>(),
  {
    value: '',
    showHistory: true,
    placeholder: '请输入节点名称',
  },
);

const emit = defineEmits<{
  'update:value': [value: string];
  applyHistory: [entry: NodeFormHistoryEntry];
}>();

function onInput(v: string) {
  emit('update:value', v);
}

function onChange(e: Event) {
  const target = e.target as HTMLInputElement | null;
  if (target) {
    emit('update:value', target.value);
  }
}
</script>

<style lang="less" scoped>
.node-name-field {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;

  &__input {
    flex: 1;
    min-width: 0;
  }

  &__history {
    flex-shrink: 0;
  }
}
</style>

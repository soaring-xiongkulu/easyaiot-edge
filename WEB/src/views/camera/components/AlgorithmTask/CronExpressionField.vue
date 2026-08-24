<template>
  <div class="cron-expression-field">
    <a-input
      :value="modelValue"
      :disabled="disabled"
      placeholder="例如: 0 */5 * * * * (每5分钟)"
      allow-clear
      @update:value="handleInput"
    />
    <div class="cron-expression-hint">{{ CRON_FORMAT_HINT }}</div>
  </div>
</template>

<script lang="ts" setup>
import { CRON_FORMAT_HINT } from '@/views/camera/utils/cronExpression';

defineOptions({ name: 'CronExpressionField' });

defineProps<{
  modelValue?: string;
  disabled?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void;
}>();

const handleInput = (value: string) => {
  emit('update:modelValue', value ?? '');
};
</script>

<style scoped lang="less">
.cron-expression-field {
  width: 100%;
}

.cron-expression-hint {
  margin-top: 6px;
  font-size: 12px;
  line-height: 1.5;
  color: rgba(0, 0, 0, 0.45);
}
</style>

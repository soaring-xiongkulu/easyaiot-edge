<template>
  <div class="save-time-input">
    <Checkbox v-model:checked="permanent" :disabled="disabled">
      永久保存
    </Checkbox>
    <div v-if="!permanent" class="save-time-input__fields">
      <InputNumber
        v-model:value="days"
        :min="0"
        :max="MAX_SAVE_TIME_DAYS"
        :precision="0"
        :disabled="disabled"
        class="save-time-input__num"
        @change="emitFromParts"
      />
      <span class="save-time-input__unit">天</span>
      <InputNumber
        v-model:value="hours"
        :min="0"
        :max="23"
        :precision="0"
        :disabled="disabled"
        class="save-time-input__num"
        @change="emitFromParts"
      />
      <span class="save-time-input__unit">小时</span>
    </div>
    <div v-if="!permanent" class="save-time-input__hint">
      最短 1 小时；可组合设置天与小时
    </div>
  </div>
</template>

<script lang="ts" setup>
import { ref, watch } from 'vue';
import { Checkbox, InputNumber } from 'ant-design-vue';
import {
  hoursToSaveTimeParts,
  MAX_SAVE_TIME_DAYS,
  saveTimePartsToHours,
} from '@/views/camera/utils/spaceSaveTime';

const props = withDefaults(
  defineProps<{
    value?: number;
    disabled?: boolean;
  }>(),
  {
    value: 1,
    disabled: false,
  },
);

const emit = defineEmits<{
  'update:value': [value: number];
  change: [value: number];
}>();

const permanent = ref(false);
const days = ref(0);
const hours = ref(0);

function syncFromValue(totalHours: number) {
  if (totalHours === 0) {
    permanent.value = true;
    days.value = 0;
    hours.value = 0;
    return;
  }
  permanent.value = false;
  const parts = hoursToSaveTimeParts(totalHours);
  days.value = parts.days;
  hours.value = parts.hours;
}

function emitFromParts() {
  if (permanent.value) {
    emit('update:value', 0);
    emit('change', 0);
    return;
  }
  const total = saveTimePartsToHours({ days: days.value ?? 0, hours: hours.value ?? 0 });
  emit('update:value', total);
  emit('change', total);
}

watch(
  () => props.value,
  (val) => syncFromValue(val ?? 0),
  { immediate: true },
);

watch(permanent, (checked, prev) => {
  if (checked === prev) return;
  if (checked) {
    emit('update:value', 0);
    emit('change', 0);
    return;
  }
  if ((days.value ?? 0) === 0 && (hours.value ?? 0) === 0) {
    days.value = 0;
    hours.value = 1;
  }
  emitFromParts();
});
</script>

<style lang="less" scoped>
.save-time-input {
  display: flex;
  flex-direction: column;
  gap: 8px;

  &__fields {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
  }

  &__num {
    width: 100px;
  }

  &__unit {
    font-size: 14px;
    color: rgba(0, 0, 0, 0.55);
  }

  &__hint {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
    line-height: 1.5;
  }
}
</style>

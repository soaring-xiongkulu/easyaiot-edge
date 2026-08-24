<script setup lang="ts">
import { Badge, RadioButton, RadioGroup } from 'ant-design-vue';
import { Icon } from '@/components/Icon';

export interface GisModeOption {
  key: string;
  label: string;
  icon: string;
  count?: string | number;
}

defineProps<{
  activeKey: string;
  modes: GisModeOption[];
}>();

const emit = defineEmits<{
  (e: 'change', key: string): void;
}>();

function onModeChange(e: { target: { value: string } }) {
  emit('change', e.target.value);
}
</script>

<template>
  <div class="gis-mode-bar">
    <RadioGroup
      :value="activeKey"
      size="middle"
      button-style="solid"
      class="gis-mode-bar__tabs"
      @change="onModeChange"
    >
      <RadioButton v-for="m in modes" :key="m.key" :value="m.key">
        <span class="gis-mode-bar__tab-inner">
          <Icon :icon="m.icon" :size="16" />
          <span>{{ m.label }}</span>
          <Badge
            v-if="m.count != null && m.count !== ''"
            :count="m.count"
            :number-style="{
              backgroundColor: activeKey === m.key ? 'rgba(255,255,255,0.25)' : '#f0f0f0',
              color: activeKey === m.key ? '#fff' : '#595959',
              boxShadow: 'none',
            }"
          />
        </span>
      </RadioButton>
    </RadioGroup>
    <div class="gis-mode-bar__extra">
      <slot name="extra" />
    </div>
  </div>
</template>

<style scoped lang="less">
.gis-mode-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 14px;
  background: #fff;
  border-bottom: 1px solid #eef0f4;

  &__tabs {
    flex: 1;
    min-width: 0;

    :deep(.ant-radio-button-wrapper) {
      height: auto;
      line-height: 1;
      padding: 6px 12px;
    }
  }

  &__tab-inner {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  &__extra {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
  }
}
</style>

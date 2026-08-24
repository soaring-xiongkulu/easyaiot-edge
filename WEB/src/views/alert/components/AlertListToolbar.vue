<script setup lang="ts">
import { SwapOutlined } from '@ant-design/icons-vue';
import { Button } from '@/components/Button';

defineOptions({ name: 'AlertListToolbar' });

const emit = defineEmits<{
  toggleView: [];
  clearAll: [];
}>();
</script>

<template>
  <div class="alert-list-toolbar">
    <Button type="default" @click="emit('toggleView')">
      <template #icon><SwapOutlined /></template>
      切换视图
    </Button>
    <Button type="primary" danger preIcon="ant-design:delete-outlined" @click="emit('clearAll')">
      一键清空告警
    </Button>
  </div>
</template>

<style scoped lang="less">
.alert-list-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}
</style>

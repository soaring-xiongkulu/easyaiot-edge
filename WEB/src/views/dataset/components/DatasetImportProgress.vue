<template>
  <div class="dataset-import-progress">
    <Progress
      :percent="percent"
      :status="percent >= 100 ? 'success' : 'active'"
      :stroke-color="percent >= 100 ? undefined : progressStrokeColor"
    />
    <div class="progress-footer">
      <Typography.Text v-if="detail" type="secondary" class="progress-detail">
        {{ detail }}
      </Typography.Text>
      <Popconfirm
        v-if="showCancel"
        placement="topRight"
        :title="confirmTitle"
        :ok-text="okText"
        :cancel-text="dismissText"
        @confirm="emit('cancel')"
      >
        <Button size="small" danger :loading="loading">
          <template #icon>
            <Icon icon="ant-design:close-circle-outlined" />
          </template>
          {{ cancelText }}
        </Button>
      </Popconfirm>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Popconfirm, Progress, Typography } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { Button } from '@/components/Button'
defineOptions({ name: 'DatasetImportProgress' });

const props = withDefaults(defineProps<{
  percent: number;
  detail?: string;
  loading?: boolean;
  cancelText?: string;
  confirmTitle?: string;
  okText?: string;
  dismissText?: string;
}>(), {
  detail: '',
  loading: false,
  cancelText: '取消',
  confirmTitle: '确定取消吗？进行中的任务将立即停止。',
  okText: '确定取消',
  dismissText: '继续等待',
});

const emit = defineEmits<{
  (e: 'cancel'): void;
}>();

const progressStrokeColor = {
  '0%': '#4361ee',
  '100%': '#6c8cff',
};

const showCancel = computed(() => props.percent < 100);
</script>

<style lang="less" scoped>
.dataset-import-progress {
  width: 100%;
}

.progress-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 8px;
}

.progress-detail {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  line-height: 1.5;
}
</style>

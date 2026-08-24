<script lang="ts" setup>
import { computed, nextTick, ref, watch } from 'vue';
import { Alert, Spin } from 'ant-design-vue';
import {
  CheckCircleOutlined,
  CloseCircleOutlined,
  LoadingOutlined,
  MinusCircleOutlined,
} from '@ant-design/icons-vue';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import { copyText } from '@/utils/copyTextToClipboard';
import type { MediaDeployStepVO } from '@/api/device/node';
import { formatDeployLog, type DeployResultState } from '../../utils/deployLog';

defineOptions({ name: 'DeployProgressPanel' });

const props = withDefaults(
  defineProps<{
    loading?: boolean;
    result?: DeployResultState | null;
    pendingSteps?: string[];
    showStop?: boolean;
  }>(),
  {
    loading: false,
    result: null,
    pendingSteps: () => ['SSH 连接', '同步文件', '执行部署', '服务验证'],
    showStop: false,
  },
);

const emit = defineEmits<{ stop: [] }>();

const { createMessage } = useMessage();
const logRef = ref<HTMLElement>();

const displaySteps = computed<MediaDeployStepVO[]>(() => {
  if (props.result?.steps?.length) return props.result.steps;
  if (props.loading) {
    return props.pendingSteps.map((name) => ({
      name,
      status: 'running',
    }));
  }
  return props.pendingSteps.map((name) => ({
    name,
    status: 'pending',
  }));
});

const logText = computed(() => {
  if (props.loading && !props.result) {
    const stepLine = props.pendingSteps?.length
      ? `\n\n步骤：${props.pendingSteps.join(' → ')}`
      : '';
    return `正在远程执行部署，请耐心等待…${stepLine}`;
  }
  return formatDeployLog(props.result?.steps || []);
});

const statusType = computed(() => {
  if (props.loading && !props.result) return 'info';
  if (!props.result) return 'info';
  return props.result.success ? 'success' : 'error';
});

const statusMessage = computed(() => {
  if (props.loading && !props.result) return '部署进行中';
  if (!props.result) return '';
  return props.result.message;
});

function stepIcon(status?: string) {
  if (status === 'success' || status === 'skipped') return CheckCircleOutlined;
  if (status === 'failed') return CloseCircleOutlined;
  if (status === 'running') return LoadingOutlined;
  return MinusCircleOutlined;
}

function stepClass(status?: string) {
  if (status === 'success' || status === 'skipped') return 'is-success';
  if (status === 'failed') return 'is-error';
  if (status === 'running') return 'is-running';
  return 'is-wait';
}

function handleCopyLog() {
  if (!logText.value?.trim()) {
    createMessage.warning('暂无日志可复制');
    return;
  }
  copyText(logText.value, '部署日志已复制');
}

function scrollToBottom() {
  const el = logRef.value;
  if (!el) return;
  el.scrollTop = el.scrollHeight;
}

function handleStop() {
  emit('stop');
}

watch(
  () => [props.loading, props.result?.steps?.length, logText.value] as const,
  async ([loading]) => {
    if (loading) return;
    await nextTick();
    scrollToBottom();
  },
);
</script>

<template>
  <div class="deploy-progress">
    <div class="deploy-progress__steps">
      <div
        v-for="(step, index) in displaySteps"
        :key="`${step.name}-${index}`"
        class="deploy-step"
        :class="stepClass(step.status)"
      >
        <component
          :is="stepIcon(step.status)"
          class="deploy-step__icon"
          :spin="step.status === 'running'"
        />
        <span class="deploy-step__name">{{ step.name }}</span>
      </div>
    </div>

    <Alert
      v-if="statusMessage"
      :type="statusType"
      show-icon
      :message="statusMessage"
      class="deploy-progress__alert"
    />

    <div class="deploy-log">
      <div class="deploy-log__header">
        <span class="deploy-log__title">部署日志</span>
        <div class="deploy-log__actions">
          <Button
            v-if="loading && showStop"
            size="small"
            danger
            @click="handleStop"
          >
            停止部署
          </Button>
          <Button size="small" :disabled="!logText?.trim()" @click="handleCopyLog">复制日志</Button>
          <Button size="small" :disabled="!logText?.trim()" @click="scrollToBottom">滚动到底部</Button>
        </div>
      </div>
      <Spin :spinning="loading && !result" tip="部署中…">
        <div ref="logRef" class="deploy-log__body" :class="{ 'is-empty': !logText?.trim() }">
          <pre v-if="logText?.trim()">{{ logText }}</pre>
          <span v-else class="deploy-log__placeholder">暂无日志</span>
        </div>
      </Spin>
    </div>
  </div>
</template>

<style lang="less" scoped>
@import '../../utils/deploy-log.less';
</style>

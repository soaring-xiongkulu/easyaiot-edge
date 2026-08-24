<script lang="ts" setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import {
  CheckCircleFilled,
  CloseCircleFilled,
  MinusCircleFilled,
  ReloadOutlined,
  SyncOutlined,
} from '@ant-design/icons-vue';
import { Alert, Progress, Spin } from 'ant-design-vue';
import { CollapseContainer } from '@/components/Container';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import { copyText } from '@/utils/copyTextToClipboard';
import { formatToDateTime } from '@/utils/dateUtil';
import {
  checkAgentBySsh,
  getNode,
  type AgentCheckResult as AgentCheckResultVO,
  type ComputeNodeVO,
} from '@/api/device/node';
import {
  getControlPlaneAgentUrl,
  isLocalControlPlaneUrl,
  SETUP_COPY,
  NODE_TERM,
  VERIFY_STATUS_POLL_INTERVAL_MS,
  VERIFY_STATUS_POLL_MAX_ATTEMPTS,
} from '../../utils/constants';
import AgentCheckResult from '../AgentCheckResult/index.vue';
import NodeMetaBadge from '../NodeMetaBadge/index.vue';
import SetupStepShell from '../SetupStepShell/index.vue';

defineOptions({ name: 'SetupVerifyPanel' });

type StepState = 'ok' | 'fail' | 'pending';

const props = defineProps<{
  nodeId?: number;
  active?: boolean;
  sshReady?: boolean;
}>();

const controlPlaneUrl = defineModel<string>('controlPlaneUrl', { required: true });

const emit = defineEmits<{ online: [] }>();

const { createMessage } = useMessage();

const loading = ref(false);
const diagnosing = ref(false);
const node = ref<ComputeNodeVO | null>(null);
const diagnostic = ref<AgentCheckResultVO | null>(null);
const pollAttempt = ref(0);
const pollExhausted = ref(false);
const isPolling = ref(false);
let pollTimer: ReturnType<typeof setInterval> | null = null;

const isOnline = computed(() => node.value?.status === 'online');
const expectedControlPlaneUrl = computed(
  () => diagnostic.value?.expectedControlPlaneUrl || getControlPlaneAgentUrl(),
);
const remoteControlPlaneUrl = computed(() => diagnostic.value?.controlPlaneUrl?.trim() || '');
const showLocalhostWarn = computed(() => isLocalControlPlaneUrl(expectedControlPlaneUrl.value));
const urlMismatch = computed(
  () =>
    !!remoteControlPlaneUrl.value &&
    remoteControlPlaneUrl.value !== expectedControlPlaneUrl.value,
);

const pollProgress = computed(() =>
  Math.min(100, Math.round((pollAttempt.value / VERIFY_STATUS_POLL_MAX_ATTEMPTS) * 100)),
);

const verifySteps = computed(() => {
  const d = diagnostic.value;
  const hasDiagnostic = !!d;

  function resolve(ok: boolean | undefined, checked: boolean): StepState {
    if (ok === true) return 'ok';
    if (checked && ok === false) return 'fail';
    return 'pending';
  }

  return [
    {
      key: 'service',
      label: `${NODE_TERM.agent}服务`,
      state: resolve(d?.serviceRunning, hasDiagnostic),
      hint: d?.serviceRunning
        ? 'systemd 服务运行中'
        : hasDiagnostic
          ? '服务未运行或未检测到'
          : `运行${NODE_TERM.accessDiagnostic}后可查看`,
    },
    {
      key: 'config',
      label: SETUP_COPY.credentials,
      state: resolve(d?.configOk, hasDiagnostic),
      hint: d?.configOk
        ? 'NODE_ID / TOKEN 与平台一致'
        : d?.nodeIdMatch === false
          ? 'NODE_ID 与平台不匹配'
          : d?.tokenMatch === false
            ? 'AGENT_TOKEN 与平台不匹配'
            : hasDiagnostic
              ? '请核对 agent.env 中的凭证'
              : `运行${NODE_TERM.accessDiagnostic}后可查看`,
    },
    {
      key: 'network',
      label: '平台网络连通',
      state: resolve(d?.controlPlaneReachable, hasDiagnostic),
      hint: d?.controlPlaneReachable
        ? '目标机可访问平台地址'
        : hasDiagnostic
          ? `目标机无法连接${NODE_TERM.platformUrl}`
          : `运行${NODE_TERM.accessDiagnostic}后可查看`,
    },
    {
      key: 'heartbeat',
      label: '平台心跳注册',
      state: isOnline.value ? 'ok' : pollExhausted.value ? 'fail' : 'pending',
      hint: isOnline.value
        ? node.value?.lastHeartbeatAt
          ? `最近心跳 ${formatToDateTime(node.value.lastHeartbeatAt)}`
          : '节点已纳入集群'
        : pollExhausted.value
          ? '自动检测超时，仍未收到心跳'
          : isPolling.value
            ? `等待${NODE_TERM.agent}向平台上报心跳…`
            : NODE_TERM.notOnlineYet,
    },
  ];
});

const statusTone = computed(() => {
  if (isOnline.value) return 'success';
  if (pollExhausted.value) return 'error';
  if (diagnostic.value?.serviceRunning && diagnostic.value?.controlPlaneReachable === false) {
    return 'error';
  }
  if (diagnostic.value?.serviceRunning && diagnostic.value?.configOk === false) return 'warning';
  if (diagnostic.value?.serviceRunning || isPolling.value) return 'processing';
  return 'pending';
});

const statusTitle = computed(() => {
  if (isOnline.value) return NODE_TERM.onlineSuccess;
  if (pollExhausted.value) return SETUP_COPY.verifyPollingExhausted.split('。')[0];
  if (diagnostic.value?.serviceRunning && diagnostic.value?.controlPlaneReachable === false) {
    return `${NODE_TERM.agent}已运行，但无法连接平台`;
  }
  if (diagnostic.value?.serviceRunning && diagnostic.value?.configOk === false) {
    return `${NODE_TERM.agent}已运行，但接入配置有误`;
  }
  if (diagnostic.value?.serviceRunning) return `${NODE_TERM.agent}运行中，等待心跳确认`;
  if (isPolling.value) return '正在检测节点上线状态';
  return NODE_TERM.notOnlineYet;
});

const statusSubtitle = computed(() => {
  if (isOnline.value) return '节点已纳入集群，可参与调度与任务分配。';
  if (showLocalhostWarn.value) {
    return `${NODE_TERM.platformUrl}使用了 localhost，远程节点无法访问。请改为 Gateway 实际 IP 并更新 agent.env。`;
  }
  if (pollExhausted.value) return SETUP_COPY.verifyPollingExhausted;
  if (isPolling.value) {
    return `已检测 ${pollAttempt.value}/${VERIFY_STATUS_POLL_MAX_ATTEMPTS} 次，间隔 ${VERIFY_STATUS_POLL_INTERVAL_MS / 1000} 秒。${SETUP_COPY.verifyDiagnosticHint}`;
  }
  return SETUP_COPY.verifyDiagnosticHint;
});

async function refreshStatus(silent = false) {
  if (!props.nodeId) return;
  loading.value = true;
  try {
    node.value = await getNode(props.nodeId);
    if (node.value?.status === 'online') {
      stopPolling();
      emit('online');
      if (!silent) createMessage.success(NODE_TERM.onlineSuccess);
    } else if (!silent) {
      createMessage.info(`${NODE_TERM.notOnlineYet}，请确认${NODE_TERM.agent}已在目标主机启动`);
    }
  } catch {
    if (!silent) createMessage.error('获取节点状态失败');
  } finally {
    loading.value = false;
  }
}

async function runDiagnostic() {
  if (!props.nodeId || diagnosing.value) return;
  if (!props.sshReady) {
    createMessage.warning('请先在「确认配置」步骤完成 SSH 凭据配置');
    return;
  }
  diagnosing.value = true;
  try {
    diagnostic.value = await checkAgentBySsh(props.nodeId, controlPlaneUrl.value);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '诊断请求失败';
    diagnostic.value = {
      success: false,
      message: msg,
      steps: [{ name: '诊断中断', status: 'failed', output: msg }],
    };
  } finally {
    diagnosing.value = false;
  }
}

function tickPoll() {
  if (isOnline.value || pollAttempt.value >= VERIFY_STATUS_POLL_MAX_ATTEMPTS) {
    if (!isOnline.value && pollAttempt.value >= VERIFY_STATUS_POLL_MAX_ATTEMPTS) {
      pollExhausted.value = true;
    }
    stopPolling();
    return;
  }
  pollAttempt.value += 1;
  refreshStatus(true);
}

function startPolling() {
  stopPolling();
  pollExhausted.value = false;
  isPolling.value = true;
  pollAttempt.value = 0;
  tickPoll();
  pollTimer = setInterval(tickPoll, VERIFY_STATUS_POLL_INTERVAL_MS);
}

function stopPolling() {
  isPolling.value = false;
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function handleRetryPolling() {
  if (isOnline.value) return;
  startPolling();
}

function handleCopyUrl(text: string, label: string) {
  copyText(text, `${label}已复制`);
}

watch(
  () => [props.active, props.nodeId] as const,
  ([active, nodeId]) => {
    if (active && nodeId) {
      diagnostic.value = null;
      refreshStatus(true);
      startPolling();
      if (props.sshReady) runDiagnostic();
    } else {
      stopPolling();
      diagnostic.value = null;
      pollAttempt.value = 0;
      pollExhausted.value = false;
    }
  },
  { immediate: true },
);

onBeforeUnmount(stopPolling);
</script>

<template>
  <SetupStepShell>
    <template #intro>
      <Alert type="info" show-icon :message="SETUP_COPY.verifyIntro" />
    </template>

    <div class="verify-status-card" :class="`verify-status-card--${statusTone}`">
      <div class="verify-status-card__head">
        <div class="verify-status-card__main">
          <div class="verify-status-card__title-row">
            <h3 class="verify-status-card__title">{{ statusTitle }}</h3>
            <NodeMetaBadge v-if="node" type="status" :status="node.status" size="lg" />
          </div>
          <p class="verify-status-card__subtitle">{{ statusSubtitle }}</p>
        </div>
      </div>

      <div v-if="!isOnline && (isPolling || pollExhausted)" class="verify-status-card__poll">
        <div class="verify-status-card__poll-meta">
          <span v-if="isPolling" class="verify-status-card__poll-label">
            <SyncOutlined spin />
            {{ SETUP_COPY.verifyPolling }}
          </span>
          <span v-else class="verify-status-card__poll-label verify-status-card__poll-label--muted">
            自动检测已停止
          </span>
          <span class="verify-status-card__poll-count">
            {{ pollAttempt }}/{{ VERIFY_STATUS_POLL_MAX_ATTEMPTS }}
          </span>
        </div>
        <Progress
          :percent="pollProgress"
          :show-info="false"
          :status="pollExhausted ? 'exception' : 'active'"
          :stroke-color="pollExhausted ? undefined : { from: '#69b1ff', to: '#266cfb' }"
          size="small"
        />
        <Button
          v-if="pollExhausted"
          size="small"
          type="link"
          class="verify-status-card__retry"
          @click="handleRetryPolling"
        >
          <ReloadOutlined />
          {{ SETUP_COPY.verifyRetryPolling }}
        </Button>
      </div>
    </div>

    <CollapseContainer :title="SETUP_COPY.verifySection" :can-expan="false">
      <Spin :spinning="loading && pollAttempt === 0 && isPolling">
        <ul class="verify-checklist">
          <li
            v-for="step in verifySteps"
            :key="step.key"
            :class="[`verify-checklist__item--${step.state}`]"
          >
            <CheckCircleFilled
              v-if="step.state === 'ok'"
              class="verify-checklist__icon verify-checklist__icon--ok"
            />
            <CloseCircleFilled
              v-else-if="step.state === 'fail'"
              class="verify-checklist__icon verify-checklist__icon--fail"
            />
            <MinusCircleFilled v-else class="verify-checklist__icon verify-checklist__icon--pending" />
            <div class="verify-checklist__body">
              <span class="verify-checklist__label">{{ step.label }}</span>
              <span class="verify-checklist__hint">{{ step.hint }}</span>
            </div>
          </li>
        </ul>

        <div class="verify-actions">
          <Button type="primary" :loading="loading" @click="refreshStatus(false)">
            {{ SETUP_COPY.verifyRefreshStatus }}
          </Button>
          <Button :loading="diagnosing" :disabled="!sshReady" @click="runDiagnostic">
            {{ SETUP_COPY.verifyRunDiagnostic }}
          </Button>
        </div>
      </Spin>
    </CollapseContainer>

    <CollapseContainer :title="SETUP_COPY.verifyUrlSection" :can-expan="false">
      <div class="verify-url-block">
        <div class="verify-url-block__row">
          <span class="verify-url-block__label">{{ SETUP_COPY.verifyExpectedUrl }}</span>
          <Button size="small" @click="handleCopyUrl(expectedControlPlaneUrl, NODE_TERM.platformUrl)">
            复制
          </Button>
        </div>
        <code class="verify-url-block__value">{{ expectedControlPlaneUrl }}</code>
      </div>

      <div v-if="remoteControlPlaneUrl" class="verify-url-block verify-url-block--remote">
        <div class="verify-url-block__row">
          <span class="verify-url-block__label">{{ SETUP_COPY.verifyRemoteUrl }}</span>
          <Button size="small" @click="handleCopyUrl(remoteControlPlaneUrl, NODE_TERM.remotePlatformUrl)">
            复制
          </Button>
        </div>
        <code
          class="verify-url-block__value"
          :class="{ 'verify-url-block__value--warn': urlMismatch }"
        >
          {{ remoteControlPlaneUrl }}
        </code>
      </div>

      <Alert
        v-if="showLocalhostWarn"
        type="warning"
        show-icon
        class="verify-url-block__alert"
        :message="`${NODE_TERM.platformUrl}含 localhost/127.0.0.1，远程${NODE_TERM.agent}无法访问。请改为平台 Gateway 实际 IP 并写入 agent.env 后重启${NODE_TERM.agent}。`"
      />
      <Alert
        v-else-if="urlMismatch"
        type="warning"
        show-icon
        class="verify-url-block__alert"
        :message="`目标机 agent.env 中的 CONTROL_PLANE_URL 与平台期望不一致，请修正后重启${NODE_TERM.agent}。`"
      />
    </CollapseContainer>

    <AgentCheckResult v-if="diagnostic" :result="diagnostic" @close="diagnostic = null" />
  </SetupStepShell>
</template>

<style lang="less" scoped>
@import '../../utils/setup-panel.less';
@import '../../utils/theme.less';

.verify-status-card {
  .setup-section-card();
  padding: 18px 22px;
  border-left: 3px solid #adc6ff;

  &--success {
    border-left-color: #b7eb8f;
    background: linear-gradient(135deg, #f6ffed 0%, #ffffff 55%);
  }

  &--warning {
    border-left-color: #ffe58f;
    background: linear-gradient(135deg, #fffbe6 0%, #ffffff 55%);
  }

  &--error {
    border-left-color: #ffa39e;
    background: linear-gradient(135deg, #fff1f0 0%, #ffffff 55%);
  }

  &--processing {
    border-left-color: @node-primary;
    background: linear-gradient(135deg, #f0f5ff 0%, #ffffff 55%);
  }

  &--pending {
    border-left-color: #d9d9d9;
  }
}

.verify-status-card__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.verify-status-card__main {
  flex: 1;
  min-width: 0;
}

.verify-status-card__title-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.verify-status-card__title {
  margin: 0;
  font-size: @node-font-subtitle;
  font-weight: 600;
  color: @node-text-primary;
}

.verify-status-card__subtitle {
  margin: 8px 0 0;
  font-size: @node-font-caption;
  line-height: 1.65;
  color: @node-text-secondary;
}

.verify-status-card__poll {
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px dashed @node-border-light;
}

.verify-status-card__poll-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
}

.verify-status-card__poll-label {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: @node-primary;

  &--muted {
    color: @node-text-muted;
  }
}

.verify-status-card__poll-count {
  font-size: 12px;
  font-variant-numeric: tabular-nums;
  color: @node-text-muted;
}

.verify-status-card__retry {
  margin-top: 4px;
  padding-left: 0;
  height: auto;
}

.verify-checklist {
  margin: 0;
  padding: 0;
  list-style: none;
}

.verify-checklist li {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px dashed #f0f0f0;

  &:first-child {
    padding-top: 2px;
  }

  &:last-child {
    border-bottom: none;
    padding-bottom: 0;
  }
}

.verify-checklist__icon {
  margin-top: 2px;
  font-size: 16px;

  &--ok {
    color: #52c41a;
  }

  &--fail {
    color: #ff4d4f;
  }

  &--pending {
    color: #bfbfbf;
  }
}

.verify-checklist__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.verify-checklist__label {
  font-size: @node-font-body;
  color: @node-text-body;
}

.verify-checklist__hint {
  font-size: 12px;
  color: @node-text-muted;
  line-height: 1.5;
}

.verify-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}

.verify-url-block {
  & + & {
    margin-top: 14px;
    padding-top: 14px;
    border-top: 1px dashed @node-border-light;
  }

  &__row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 8px;
  }

  &__label {
    font-size: @node-font-caption;
    font-weight: 500;
    color: @node-text-secondary;
  }

  &__value {
    display: block;
    padding: 8px 10px;
    border-radius: 6px;
    background: #fafafa;
    border: 1px solid @node-border-light;
    font-size: 12px;
    line-height: 1.6;
    word-break: break-all;
    color: @node-text-body;

    &--warn {
      border-color: #ffe58f;
      background: #fffbe6;
    }
  }

  &__alert {
    margin-top: 12px;
  }
}
</style>

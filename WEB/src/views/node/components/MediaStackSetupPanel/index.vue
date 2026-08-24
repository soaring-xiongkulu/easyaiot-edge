<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Alert, Form, FormItem, Radio, Space } from 'ant-design-vue';
import { CodeEditor } from '@/components/CodeEditor';
import { CollapseContainer } from '@/components/Container';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import { copyText } from '@/utils/copyTextToClipboard';
import {
  checkMediaStackBySsh,
  checkMediaPortsBySsh,
  deployMediaStackBySsh,
  removeMediaContainerBySsh,
  removeMediaImageBySsh,
  stopMediaServiceBySsh,
  type MediaStackCheckResult as MediaStackCheckData,
  type PortCheckResult as PortCheckData,
} from '@/api/device/node';
import {
  buildMediaStackManualContent,
  getMediaStackGuideState,
  MEDIA_STACK_DEPLOY_PENDING_STEPS,
  SETUP_COPY,
  SETUP_FORM_LABEL_COL,
  SETUP_FORM_WRAPPER_COL,
  type MediaStackScriptParams,
} from '../../utils/constants';
import { resolveDeployMessage, type DeployResultState } from '../../utils/deployLog';
import DeployProgressPanel from '../DeployProgressPanel/index.vue';
import MediaStackCheckResult from '../MediaStackCheckResult/index.vue';
import PortCheckResult from '../PortCheckResult/index.vue';
import SetupStepShell from '../SetupStepShell/index.vue';

defineOptions({ name: 'MediaStackSetupPanel' });

const emit = defineEmits<{ deployed: [success: boolean] }>();

const props = defineProps<{
  active?: boolean;
  formValues?: MediaStackScriptParams & {
    nodeRole?: string;
    nodeId?: number;
    sshUsername?: string;
    sshCredentialConfigured?: boolean;
    sshLastTestOk?: boolean;
    sshPort?: number;
  };
}>();

const { createMessage } = useMessage();

type DeployMode = 'auto' | 'manual';
const deployMode = ref<DeployMode>('auto');
const deploying = ref(false);
const deployResult = ref<DeployResultState | null>(null);
const deployAbort = ref<AbortController | null>(null);
const checking = ref(false);
const checkResult = ref<MediaStackCheckData | null>(null);
const portChecking = ref(false);
const portCheckResult = ref<PortCheckData | null>(null);
const mediaOpLoading = ref<'stop-srs' | 'stop-zlm' | 'remove-container' | 'remove-image' | null>(null);
const mediaOpResult = ref<DeployResultState | null>(null);
const hasAutoChecked = ref(false);

const guide = computed(() => getMediaStackGuideState(props.formValues));

const canCheckDeploy = computed(
  () =>
    guide.value.isReady &&
    !!props.formValues?.nodeId &&
    (!!props.formValues?.sshUsername?.trim() || props.formValues?.sshCredentialConfigured === true),
);

const canAutoDeploy = computed(
  () =>
    guide.value.isReady &&
    !!props.formValues?.nodeId &&
    (!!props.formValues?.sshUsername?.trim() || props.formValues?.sshCredentialConfigured === true),
);

const autoDisabledReason = computed(() => {
  if (!guide.value.isReady) return '请先在节点配置中填写主机地址与流媒体引擎端口';
  if (!props.formValues?.nodeId) return '请先保存节点信息';
  if (!props.formValues?.sshUsername?.trim() && props.formValues?.sshCredentialConfigured !== true) {
    return '请先在节点配置中填写 SSH 用户名及认证凭据';
  }
  if (props.formValues?.sshLastTestOk === false) {
    return 'SSH 连通性检测未通过，请先在概览页检测 SSH 或检查端口/凭据';
  }
  return '';
});

const manualContent = computed(() => {
  if (!guide.value.isReady) return '';
  return buildMediaStackManualContent(props.formValues || {});
});

function isDeployAborted(e: unknown): boolean {
  if (!(e instanceof Error)) return false;
  const msg = e.message.toLowerCase();
  return e.name === 'AbortError' || e.name === 'CanceledError' || msg.includes('abort') || msg.includes('cancel');
}

function handleCopy(text: string, label: string) {
  if (!text?.trim()) {
    createMessage.warning(`${label}为空，无法复制`);
    return;
  }
  copyText(text, `${label}已复制`);
}

function handleStopDeploy() {
  deployAbort.value?.abort();
}

async function handleCheckDeploy() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId || checking.value) return;
  checking.value = true;
  checkResult.value = null;
  try {
    checkResult.value = await checkMediaStackBySsh(nodeId);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '检测请求失败';
    checkResult.value = {
      success: false,
      message: msg,
      steps: [{ name: '检测中断', status: 'failed', output: msg }],
    };
  } finally {
    checking.value = false;
  }
}

async function handleCheckPorts() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId || portChecking.value) return;
  portChecking.value = true;
  portCheckResult.value = null;
  try {
    portCheckResult.value = await checkMediaPortsBySsh(nodeId);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '检测请求失败';
    portCheckResult.value = {
      success: false,
      portsReady: false,
      message: msg,
      steps: [{ name: '检测中断', status: 'failed', output: msg }],
    };
  } finally {
    portChecking.value = false;
  }
}

async function runMediaOp(
  op: 'stop-srs' | 'stop-zlm' | 'remove-container' | 'remove-image',
  request: () => Promise<{ success?: boolean; message?: string; steps?: DeployResultState['steps'] }>,
  successMsg: string,
) {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId || mediaOpLoading.value) return;
  mediaOpLoading.value = op;
  mediaOpResult.value = null;
  try {
    const data = await request();
    mediaOpResult.value = {
      success: !!data?.success,
      message: resolveDeployMessage(data || {}),
      steps: data?.steps || [],
    };
    if (data?.success) {
      createMessage.success(successMsg);
      checkResult.value = null;
    } else {
      createMessage.error(mediaOpResult.value.message || '操作失败');
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '操作请求失败';
    mediaOpResult.value = {
      success: false,
      message: msg,
      steps: [{ name: '操作中断', status: 'failed', output: msg }],
    };
    createMessage.error(msg);
  } finally {
    mediaOpLoading.value = null;
  }
}

function handleStopSrs() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId) return;
  runMediaOp('stop-srs', () => stopMediaServiceBySsh(nodeId, 'srs'), 'SRS 已停止');
}

function handleStopZlm() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId) return;
  runMediaOp('stop-zlm', () => stopMediaServiceBySsh(nodeId, 'zlm'), 'ZLMediaKit 已停止');
}

function handleRemoveContainer() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId) return;
  runMediaOp('remove-container', () => removeMediaContainerBySsh(nodeId), 'SRS / ZLM 容器已删除');
}

function handleRemoveImage() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId) return;
  runMediaOp('remove-image', () => removeMediaImageBySsh(nodeId), 'SRS / ZLM 镜像已删除');
}

async function handleAutoDeploy() {
  const nodeId = props.formValues?.nodeId;
  if (!nodeId || deploying.value) return;
  deploying.value = true;
  deployResult.value = null;
  deployAbort.value = new AbortController();
  try {
    const data = await deployMediaStackBySsh(nodeId, { signal: deployAbort.value.signal });
    deployResult.value = {
      success: !!data?.success,
      message: resolveDeployMessage(data || {}),
      steps: data?.steps || [],
    };
    emit('deployed', !!deployResult.value.success);
  } catch (e: unknown) {
    if (isDeployAborted(e)) {
      deployResult.value = {
        success: false,
        message: '部署已停止',
        steps: [{ name: '部署中断', status: 'failed', output: '用户已停止部署（服务端可能仍在执行，请稍后检查目标机）' }],
      };
      createMessage.info('已停止部署请求');
    } else {
      const msg = e instanceof Error ? e.message : '部署请求失败';
      deployResult.value = {
        success: false,
        message: msg,
        steps: [{ name: '部署中断', status: 'failed', output: msg }],
      };
      emit('deployed', false);
    }
  } finally {
    deploying.value = false;
    deployAbort.value = null;
  }
}

watch(
  () => [props.active, props.formValues?.nodeId, canCheckDeploy.value] as const,
  ([active, nodeId, canCheck]) => {
    if (!active) {
      hasAutoChecked.value = false;
      return;
    }
    if (active && nodeId && canCheck && !hasAutoChecked.value) {
      hasAutoChecked.value = true;
      handleCheckDeploy();
    }
  },
  { immediate: true },
);
</script>

<template>
  <SetupStepShell v-if="guide.isMediaRole">
    <template v-if="!guide.isReady" #intro>
      <Alert
        type="warning"
        show-icon
        :message="`${SETUP_COPY.mediaService}配置不完整`"
      >
        <template #description>
          <ul class="pending-list">
            <li v-for="item in guide.pendingItems" :key="item.key" :class="{ done: item.done }">
              {{ item.label }}<span v-if="item.hint"> — {{ item.hint }}</span>
            </li>
          </ul>
        </template>
      </Alert>
    </template>

    <CollapseContainer v-if="guide.isReady" :title="SETUP_COPY.deployConfig" :can-expan="false">
      <Form
        :label-col="SETUP_FORM_LABEL_COL"
        :wrapper-col="SETUP_FORM_WRAPPER_COL"
        class="setup-resource-form"
      >
        <FormItem :label="SETUP_COPY.deployMode">
          <Radio.Group v-model:value="deployMode">
            <Radio value="auto">{{ SETUP_COPY.deployModeAuto }}</Radio>
            <Radio value="manual">{{ SETUP_COPY.deployModeManual }}</Radio>
          </Radio.Group>
        </FormItem>

        <FormItem :label="SETUP_COPY.mediaPortCheck">
          <Space wrap>
            <Button
              :loading="portChecking"
              :disabled="!canCheckDeploy || deploying || checking"
              @click="handleCheckPorts"
            >
              {{ SETUP_COPY.checkMediaPortBtn }}
            </Button>
          </Space>
          <div v-if="!canCheckDeploy" class="form-hint">{{ autoDisabledReason || '请先保存节点并配置 SSH' }}</div>
          <PortCheckResult v-else-if="portCheckResult" :result="portCheckResult" @close="portCheckResult = null" />
          <div v-else class="form-hint">
            检测 SRS/ZLM 部署端口（RTMP、HTTP、RTSP、API 等）是否被占用；RTP 端口范围不在检测范围内
          </div>
        </FormItem>

        <FormItem :label="SETUP_COPY.mediaDeployCheck">
          <Space wrap>
            <Button :loading="checking" :disabled="!canCheckDeploy || deploying" @click="handleCheckDeploy">
              {{ SETUP_COPY.checkMediaDeployBtn }}
            </Button>
          </Space>
          <div v-if="!canCheckDeploy" class="form-hint">{{ autoDisabledReason || '请先保存节点并配置 SSH' }}</div>
          <MediaStackCheckResult v-else-if="checkResult" :result="checkResult" @close="checkResult = null" />
          <div v-else class="form-hint">通过 SSH 探测目标机 Docker、SRS、ZLMediaKit 运行状态，不会修改目标机</div>
        </FormItem>

        <FormItem v-if="deployMode === 'auto'" :label="SETUP_COPY.remoteDeploy">
          <Space wrap>
            <Button type="primary" :loading="deploying" :disabled="!canAutoDeploy" @click="handleAutoDeploy">
              {{ SETUP_COPY.deployMediaBtn }}
            </Button>
            <Button v-if="deploying" danger @click="handleStopDeploy">停止部署</Button>
          </Space>
          <div v-if="autoDisabledReason" class="form-hint">{{ autoDisabledReason }}</div>
          <div v-else-if="formValues?.sshLastTestOk !== true" class="form-hint form-hint--warn">
            建议先在「节点概览」执行 SSH 连通性检测（当前 SSH 端口 {{ formValues?.sshPort ?? 22 }}）
          </div>
          <div v-else-if="guide.readySummary" class="form-hint">{{ guide.readySummary }}</div>
          <div v-if="canAutoDeploy" class="form-hint">
            镜像仅在本机（平台服务器）下载并导出，经文件同步至目标机 docker load；目标机不会联网拉取镜像
          </div>
          <div v-if="canAutoDeploy" class="form-hint">
            部署前将自动检测目标机端口占用，并检测已有镜像与服务
          </div>
        </FormItem>

        <FormItem v-if="deployMode === 'auto'" :label="SETUP_COPY.mediaOps">
          <Space wrap>
            <Button
              :loading="mediaOpLoading === 'stop-srs'"
              :disabled="!canCheckDeploy || deploying || !!mediaOpLoading"
              @click="handleStopSrs"
            >
              {{ SETUP_COPY.stopSrsBtn }}
            </Button>
            <Button
              :loading="mediaOpLoading === 'stop-zlm'"
              :disabled="!canCheckDeploy || deploying || !!mediaOpLoading"
              @click="handleStopZlm"
            >
              {{ SETUP_COPY.stopZlmBtn }}
            </Button>
            <Button
              danger
              :loading="mediaOpLoading === 'remove-container'"
              :disabled="!canCheckDeploy || deploying || !!mediaOpLoading"
              @click="handleRemoveContainer"
            >
              {{ SETUP_COPY.removeContainerBtn }}
            </Button>
            <Button
              danger
              :loading="mediaOpLoading === 'remove-image'"
              :disabled="!canCheckDeploy || deploying || !!mediaOpLoading"
              @click="handleRemoveImage"
            >
              {{ SETUP_COPY.removeImageBtn }}
            </Button>
          </Space>
          <div v-if="!canCheckDeploy" class="form-hint">{{ autoDisabledReason || '请先保存节点并配置 SSH' }}</div>
          <div v-else class="form-hint">
            通过 SSH 在目标机执行停止/删除操作；删除容器不会删除 Docker 镜像，删除镜像会同时清理离线 tar 包
          </div>
        </FormItem>

        <FormItem v-else :label="SETUP_COPY.deployScript">
          <div class="script-toolbar">
            <Button size="small" preIcon="tdesign:copy-filled" @click="handleCopy(manualContent, SETUP_COPY.deployScript)">
              复制全部步骤
            </Button>
          </div>
          <CodeEditor class="script-editor script-editor--manual" :value="manualContent" readonly bordered />
          <div class="form-hint">
            含三步：① 本机拉取并导出离线镜像（已有 tar 则跳过） ② rsync 增量同步（目标机已有镜像可跳过 tar） ③ 目标机 docker load 并启动
          </div>
        </FormItem>
      </Form>
    </CollapseContainer>

    <CollapseContainer
      v-if="deployMode === 'auto' && guide.isReady && (deploying || deployResult || mediaOpLoading || mediaOpResult)"
      :title="SETUP_COPY.deployProgress"
      :can-expan="false"
    >
      <DeployProgressPanel
        :loading="deploying || !!mediaOpLoading"
        :result="deployResult || mediaOpResult"
        :pending-steps="[...MEDIA_STACK_DEPLOY_PENDING_STEPS]"
        :show-stop="deploying"
        @stop="handleStopDeploy"
      />
    </CollapseContainer>
  </SetupStepShell>
</template>

<style lang="less" scoped>
@import '../../utils/setup-panel.less';

.pending-list {
  margin: 4px 0 0;
  padding-left: 18px;
  font-size: @node-font-caption;

  li {
    line-height: 1.8;
    color: @node-text-secondary;

    &.done {
      color: @node-text-muted;
      text-decoration: line-through;
    }
  }
}

</style>

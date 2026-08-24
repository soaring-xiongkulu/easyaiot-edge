<template>
  <div class="workload-bundle-panel">
    <Alert type="info" show-icon class="mb-4" :message="bundle.desc" />
    <Alert type="warning" show-icon class="mb-4" :message="WORKLOAD_BUNDLE_COPY.offlineHint" />

    <div class="path-hints mb-4">
      <div><span class="label">远程根目录：</span><code>{{ bundle.remoteRoot }}</code></div>
      <div><span class="label">Python 启动器：</span><code>{{ bundle.pythonLauncher }}</code></div>
      <div><span class="label">脚本标记：</span><code>{{ bundle.scriptMarker }}</code></div>
    </div>

    <Space wrap class="action-bar mb-4">
      <Button :loading="loading === 'check'" :disabled="!canOperate" @click="runAction('check')">
        {{ WORKLOAD_BUNDLE_COPY.check }}
      </Button>
      <Button type="primary" :loading="loading === 'env'" :disabled="!canOperate" @click="runAction('env')">
        {{ WORKLOAD_BUNDLE_COPY.deployEnv }}
      </Button>
      <Button type="primary" :loading="loading === 'scripts'" :disabled="!canOperate" @click="runAction('scripts')">
        {{ WORKLOAD_BUNDLE_COPY.deployScripts }}
      </Button>
      <Button type="primary" ghost :loading="loading === 'full'" :disabled="!canOperate" @click="runAction('full')">
        {{ WORKLOAD_BUNDLE_COPY.deployFull }}{{ isVideoBundle ? '（含 FFmpeg）' : '' }}
      </Button>
      <Button danger :loading="loading === 'removeEnv'" :disabled="!canOperate" @click="confirmRemove('removeEnv')">
        {{ WORKLOAD_BUNDLE_COPY.removeEnv }}
      </Button>
      <Button danger ghost :loading="loading === 'removeScripts'" :disabled="!canOperate" @click="confirmRemove('removeScripts')">
        {{ WORKLOAD_BUNDLE_COPY.removeScripts }}
      </Button>
    </Space>

    <Alert
      v-if="lastResult"
      class="mb-4"
      :type="lastResult.success ? 'success' : 'error'"
      show-icon
      :message="lastResult.message || (lastResult.success ? '操作完成' : '操作失败')"
    />

    <div v-if="nodeResults.length" class="node-results">
      <CollapseContainer title="各节点执行结果" :canExpan="true" :defaultExpan="true">
        <div v-for="item in nodeResults" :key="item.nodeId" class="node-result-item">
          <div class="node-result-header">
            <Tag :color="item.success ? 'success' : 'error'">{{ item.success ? '成功' : '失败' }}</Tag>
            <span class="node-name">{{ item.nodeName || item.host }} ({{ item.host }})</span>
            <span class="node-msg">{{ item.message }}</span>
          </div>
          <DeployProgressPanel
            v-if="item.steps?.length"
            :loading="false"
            :result="{ success: !!item.success, message: item.message || '', steps: item.steps }"
          />
        </div>
      </CollapseContainer>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { Alert, Modal, Space, Tag } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { CollapseContainer } from '@/components/Container';
import { useMessage } from '@/hooks/web/useMessage';
import {
  batchCheckWorkloadBundleBySsh,
  batchDeployWorkloadBundleEnvBySsh,
  batchDeployWorkloadBundleFullBySsh,
  batchDeployWorkloadBundleScriptsBySsh,
  batchRemoveWorkloadBundleEnvBySsh,
  batchRemoveWorkloadBundleScriptsBySsh,
  type WorkloadBundleNodeResult,
  type WorkloadBundleTypeKey,
} from '@/api/device/node';
import { WORKLOAD_BUNDLE_COPY } from '../../utils/constants';
import DeployProgressPanel from '../DeployProgressPanel/index.vue';

defineOptions({ name: 'WorkloadBundlePanel' });

const props = defineProps<{
  bundle: (typeof import('../../utils/constants').WORKLOAD_BUNDLE_TYPES)[number];
  nodeIds: number[];
}>();

const { createMessage } = useMessage();

type ActionKey = 'check' | 'env' | 'scripts' | 'full' | 'removeEnv' | 'removeScripts';

const loading = ref<ActionKey | null>(null);
const lastResult = ref<{ success: boolean; message: string } | null>(null);
const nodeResults = ref<WorkloadBundleNodeResult[]>([]);

const canOperate = computed(() => props.nodeIds.length > 0);
const isVideoBundle = computed(() => props.bundle.module === 'VIDEO');

async function runAction(action: ActionKey) {
  if (!canOperate.value) {
    createMessage.warning('请先选择目标节点');
    return;
  }
  loading.value = action;
  lastResult.value = null;
  nodeResults.value = [];
  const payload = {
    nodeIds: props.nodeIds,
    bundleType: props.bundle.key as WorkloadBundleTypeKey,
  };
  try {
    let data;
    switch (action) {
      case 'check':
        data = await batchCheckWorkloadBundleBySsh(payload);
        break;
      case 'env':
        data = await batchDeployWorkloadBundleEnvBySsh(payload);
        break;
      case 'scripts':
        data = await batchDeployWorkloadBundleScriptsBySsh(payload);
        break;
      case 'full':
        data = await batchDeployWorkloadBundleFullBySsh(payload);
        break;
      case 'removeEnv':
        data = await batchRemoveWorkloadBundleEnvBySsh(payload);
        break;
      case 'removeScripts':
        data = await batchRemoveWorkloadBundleScriptsBySsh(payload);
        break;
    }
    nodeResults.value = data?.results || [];
    lastResult.value = {
      success: !!data?.success,
      message: data?.message || '',
    };
    if (data?.success) {
      createMessage.success(data.message || '操作完成');
    } else {
      createMessage.error(data?.message || '部分节点失败');
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '请求失败';
    lastResult.value = { success: false, message: msg };
    createMessage.error(msg);
  } finally {
    loading.value = null;
  }
}

function confirmRemove(action: 'removeEnv' | 'removeScripts') {
  const label = action === 'removeEnv' ? WORKLOAD_BUNDLE_COPY.removeEnv : WORKLOAD_BUNDLE_COPY.removeScripts;
  Modal.confirm({
    title: `确认${label}？`,
    content: `将对 ${props.nodeIds.length} 个节点执行「${props.bundle.label}」${label}，此操作不可自动恢复。`,
    okType: 'danger',
    onOk: () => runAction(action),
  });
}
</script>

<style scoped lang="less">
.workload-bundle-panel {
  padding: 8px 4px 16px;
}

.path-hints {
  font-size: 13px;
  color: #666;
  line-height: 1.8;

  .label {
    color: #333;
  }

  code {
    font-size: 12px;
    background: #f5f5f5;
    padding: 1px 6px;
    border-radius: 4px;
  }
}

.node-result-item {
  margin-bottom: 16px;
  padding-bottom: 12px;
  border-bottom: 1px dashed #eee;

  &:last-child {
    border-bottom: none;
  }
}

.node-result-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
  flex-wrap: wrap;

  .node-name {
    font-weight: 500;
  }

  .node-msg {
    color: #888;
    font-size: 13px;
  }
}
</style>

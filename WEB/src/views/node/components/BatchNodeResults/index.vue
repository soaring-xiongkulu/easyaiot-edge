<template>
  <div v-if="results.length" class="batch-node-results">
    <Alert
      v-if="summary"
      class="mb-3"
      :type="summary.success ? 'success' : 'error'"
      show-icon
      :message="summary.message"
    />
    <CollapseContainer title="各节点执行结果" :canExpan="true" :defaultExpan="true">
      <div v-for="item in results" :key="item.nodeId" class="node-result-item">
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
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Alert, Tag } from 'ant-design-vue';
import { CollapseContainer } from '@/components/Container';
import type { WorkloadBundleNodeResult } from '@/api/device/node';
import { summarizeBatchResults } from '../../utils/batchNodeOps';
import DeployProgressPanel from '../DeployProgressPanel/index.vue';

defineOptions({ name: 'BatchNodeResults' });

const props = defineProps<{
  results: WorkloadBundleNodeResult[];
}>();

const summary = computed(() =>
  props.results.length ? summarizeBatchResults(props.results) : null,
);
</script>

<style scoped lang="less">
.node-result-item {
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;

  &:last-child {
    border-bottom: none;
  }
}

.node-result-header {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 4px;
}

.node-name {
  font-weight: 500;
  color: #333;
}

.node-msg {
  font-size: 13px;
  color: #666;
}
</style>

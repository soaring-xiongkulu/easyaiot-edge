<template>
  <div class="sam-model-setup-page">
    <div class="page-card">
      <header class="page-toolbar">
        <Button
          type="text"
          class="back-btn"
          preIcon="ant-design:arrow-left-outlined"
          @click="goBack"
        >
          返回
        </Button>
        <div class="toolbar-main">
          <h1 class="page-title">SAM 模型安装</h1>
          <span class="page-desc">
            {{ datasetId ? '完成安装后即可开始智能标注' : '下载并部署至 AI 服务' }}
          </span>
        </div>
      </header>

      <SamModelSetupPanel
        class="page-panel"
        :checking="!modelStatusChecked"
        :model-status="modelStatus"
        :show-progress="showProgressPanel"
        :progress="displayProgress"
        :current-step="downloadStepCurrent"
        :finished="modelDownloadJustFinished"
        :starting="downloadStarting"
        @download="handleDownloadModel"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { Button } from '@/components/Button';
import SamModelSetupPanel from '@/views/dataset/components/AutoLabel/SamModelSetupPanel/index.vue';
import { useSamModelSetup } from '@/views/dataset/components/AutoLabel/useSamModelSetup';

defineOptions({ name: 'SamModelSetup' });

const route = useRoute();
const router = useRouter();

const datasetId = computed(() => String(route.query.datasetId || '').trim());

function goBack() {
  if (datasetId.value) {
    router.push({ name: 'DatasetDetail', params: { id: datasetId.value } });
    return;
  }
  router.back();
}

function onModelReady() {
  if (datasetId.value) {
    router.replace({
      name: 'DatasetDetail',
      params: { id: datasetId.value },
      query: { openSam: '1' },
    });
    return;
  }
  router.back();
}

const {
  modelStatusChecked,
  modelStatus,
  modelReady,
  showProgressPanel,
  displayProgress,
  downloadStepCurrent,
  modelDownloadJustFinished,
  downloadStarting,
  refreshModelStatus,
  handleDownloadModel,
} = useSamModelSetup(onModelReady);

onMounted(async () => {
  await refreshModelStatus();
  if (modelReady.value && datasetId.value) {
    router.replace({
      name: 'DatasetDetail',
      params: { id: datasetId.value },
      query: route.query.autoOpen === '1' ? { openSam: '1' } : undefined,
    });
  }
});
</script>

<style scoped lang="less">
.sam-model-setup-page {
  height: calc(100vh - 96px);
  min-height: 560px;
  padding: 0 12px 12px;
  box-sizing: border-box;
}

.page-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
  overflow: hidden;
}

.page-toolbar {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 14px 28px 14px 16px;
  border-bottom: 1px solid #f5f5f5;

  @media (max-width: 960px) {
    padding: 10px 16px;
  }

  .back-btn {
    flex-shrink: 0;
    height: 28px;
    padding: 0 2px 0 0;
    color: #8c8c8c;
    font-size: 13px;

    &:hover {
      color: #266cfb;
      background: rgba(38, 108, 251, 0.06);
    }
  }

  .toolbar-main {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }

  .page-title {
    flex-shrink: 0;
    margin: 0;
    font-size: 15px;
    font-weight: 600;
    line-height: 1.3;
    color: rgba(0, 0, 0, 0.75);
  }

  .page-desc {
    position: relative;
    padding-left: 11px;
    min-width: 0;
    font-size: 12px;
    line-height: 1.3;
    color: #a3a3a3;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;

    &::before {
      content: '';
      position: absolute;
      left: 0;
      top: 50%;
      width: 1px;
      height: 12px;
      margin-top: -6px;
      background: #ebebeb;
    }
  }
}

.page-panel {
  flex: 1;
  min-height: 0;
}
</style>

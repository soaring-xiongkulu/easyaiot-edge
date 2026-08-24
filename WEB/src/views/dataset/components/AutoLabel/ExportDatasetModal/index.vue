<template>
  <BasicModal
    @register="register"
    width="960px"
    @cancel="handleCancel"
    :canFullscreen="false"
    :showOkBtn="false"
    :showCancelBtn="false"
    :get-container="getContainer"
    wrap-class-name="dataset-export-modal-wrap"
  >
    <template #title>
      <span class="modal-title-with-icon">
        <Icon icon="ant-design:download-outlined" class="title-icon" />
        导出数据集
      </span>
    </template>
    <div class="modal-content export-modal-content">
      <Tabs v-model:activeKey="tabActive" class="dataset-tabs">
        <TabPane key="export-local" tab="导出到本地">
          <form class="export-form" @submit.prevent="handleLocalExport">
            <div class="form-row ratios-row">
              <div class="form-group">
                <label>训练集比例:</label>
                <InputNumber v-model:value="form.train_ratio" :min="0" :max="1" :step="0.1" style="width: 100%" />
              </div>
              <div class="form-group">
                <label>验证集比例:</label>
                <InputNumber v-model:value="form.val_ratio" :min="0" :max="1" :step="0.1" style="width: 100%" />
              </div>
              <div class="form-group">
                <label>测试集比例:</label>
                <InputNumber v-model:value="form.test_ratio" :min="0" :max="1" :step="0.1" style="width: 100%" />
              </div>
            </div>

            <div class="form-group">
              <label>样本选择:</label>
              <div class="sample-selection">
                <label :class="{ active: form.sampleSelection === 'all' }">
                  <input v-model="form.sampleSelection" type="radio" value="all" />
                  所有图片
                </label>
                <label :class="{ active: form.sampleSelection === 'annotated' }">
                  <input v-model="form.sampleSelection" type="radio" value="annotated" />
                  仅已标注的图片
                </label>
                <label :class="{ active: form.sampleSelection === 'unannotated' }">
                  <input v-model="form.sampleSelection" type="radio" value="unannotated" />
                  仅未标注的图片
                </label>
              </div>
            </div>

            <div class="form-group">
              <label>类别选择:</label>
              <CheckboxGroup v-model:value="form.selectedClasses" class="class-checkbox-container">
                <Row :gutter="[8, 8]">
                  <Col :span="8" v-for="label in labels" :key="label.id">
                    <Checkbox :value="label.name">{{ label.name }}</Checkbox>
                  </Col>
                </Row>
              </CheckboxGroup>
            </div>

            <div class="form-row export-action-row">
              <div class="form-group prefix-group">
                <label>导出文件前缀 (可选):</label>
                <Input v-model:value="form.filePrefix" placeholder="输入文件前缀" allow-clear />
              </div>
              <div class="form-group action-group">
                <Button v-show="!loading" type="primary" html-type="submit" class="export-submit-btn">
                  <Icon icon="ant-design:download-outlined" />
                  导出
                </Button>
                <div v-show="loading" class="loading-indicator">
                  <Icon icon="ant-design:loading-outlined" spin />
                  正在处理...
                </div>
              </div>
            </div>
          </form>
        </TabPane>

        <TabPane key="export-cloud" tab="云平台">
          <div class="upload-area cloud-export-area">
            <p class="cloud-desc">
              将当前标注结果同步为云平台上的<strong>新数据集</strong>（自动创建并上传图片与标注）。
            </p>
            <div class="form-row">
              <div class="form-group flex-1">
                <label>数据集名称</label>
                <Input v-model:value="cloudForm.name" placeholder="例如：行人检测-2026" />
              </div>
              <div class="form-group flex-1">
                <label>版本</label>
                <Input v-model:value="cloudForm.version" placeholder="例如：v1.0.0" />
              </div>
            </div>
            <div class="upload-actions">
              <Button type="primary" :loading="cloudLoading" @click="handleCloudExport">
                <Icon icon="ant-design:cloud-upload-outlined" />
                导出到云平台
              </Button>
            </div>
            <div v-if="cloudStatus" class="cloud-status">{{ cloudStatus }}</div>
          </div>
        </TabPane>
      </Tabs>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { reactive, ref, watch } from 'vue';
import { BasicModal, useModal } from '@/components/Modal';
import { Icon } from '@/components/Icon';
import { InputNumber,
  CheckboxGroup,
  Checkbox,
  Row,
  Col,
  Input,
  Tabs,
  TabPane, } from 'ant-design-vue';
import { useMessage } from '@/hooks/web/useMessage';
import { exportAnnotationDataset, exportAnnotationToCloud } from '@/api/device/dataset';
import { Button } from '@/components/Button'
defineOptions({ name: 'ExportDatasetModal' });

const props = defineProps<{
  datasetId?: number;
  datasetLabels?: { id: number; name: string; color?: string; shortcut?: string }[];
  getContainer?: () => HTMLElement;
}>();

const { createMessage } = useMessage();
const emits = defineEmits(['success']);

const loading = ref(false);
const cloudLoading = ref(false);
const cloudStatus = ref('');
const tabActive = ref('export-local');
const labels = ref<{ id: number; name: string }[]>([]);

const form = reactive({
  train_ratio: 0.7,
  val_ratio: 0.2,
  test_ratio: 0.1,
  sampleSelection: 'annotated' as 'all' | 'annotated' | 'unannotated',
  selectedClasses: [] as string[],
  filePrefix: '',
});

const cloudForm = reactive({
  name: '',
  version: '',
});

const [register, { openModal, closeModal }] = useModal();

const syncLabelsFromProps = () => {
  const source = props.datasetLabels;
  if (source?.length) {
    labels.value = source;
    if (form.selectedClasses.length === 0) {
      form.selectedClasses = source.map((l) => l.name);
    }
  }
};

watch(() => props.datasetLabels, syncLabelsFromProps, { immediate: true, deep: true });

const openModalWithLabels = () => {
  syncLabelsFromProps();
  tabActive.value = 'export-local';
  cloudStatus.value = '';
  openModal();
};

defineExpose({ openModal: openModalWithLabels, closeModal, form });

async function handleLocalExport() {
  const dsId = props.datasetId;
  if (!dsId) {
    createMessage.warning('请先选择数据集');
    return;
  }
  if (form.selectedClasses.length === 0) {
    createMessage.warning('请至少选择一个类别');
    return;
  }

  loading.value = true;
  try {
    const blob = await exportAnnotationDataset(dsId, {
      trainRatio: form.train_ratio,
      valRatio: form.val_ratio,
      testRatio: form.test_ratio,
      sampleSelection: form.sampleSelection,
      selectedClasses: form.selectedClasses,
      exportPrefix: form.filePrefix,
    });

    if (blob instanceof Blob) {
      const now = new Date();
      const pad = (n: number) => String(n).padStart(2, '0');
      const filename = `datasets_${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}.zip`;
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
      createMessage.success('导出成功');
      closeModal();
      emits('success');
    } else {
      createMessage.error('导出失败');
    }
  } catch (e: any) {
    console.error('导出失败:', e);
    createMessage.error(e?.message || '导出失败');
  } finally {
    loading.value = false;
  }
}

async function handleCloudExport() {
  const dsId = props.datasetId;
  if (!dsId) {
    createMessage.warning('请先选择数据集');
    return;
  }
  const name = cloudForm.name.trim();
  const version = cloudForm.version.trim();
  if (!name) {
    createMessage.warning('请填写数据集名称');
    return;
  }
  if (!version) {
    createMessage.warning('请填写版本');
    return;
  }

  cloudLoading.value = true;
  cloudStatus.value = '正在创建云平台数据集并同步标注…';
  try {
    const res = await exportAnnotationToCloud(dsId, { name, version });
    const data = res?.data ?? res;
    createMessage.success('导出完成');
    cloudStatus.value = `新数据集 ID: ${data?.cloudDatasetId}；新建 ${data?.createdImages ?? 0} 张图片`;
    emits('success');
  } catch (e: any) {
    createMessage.error(e?.message || '导出失败');
    cloudStatus.value = '';
  } finally {
    cloudLoading.value = false;
  }
}

function handleCancel() {
  closeModal();
}
</script>

<style lang="less" scoped>
.modal-title-with-icon {
  display: flex;
  align-items: center;
  gap: 8px;
  .title-icon { font-size: 18px; }
}

.export-modal-content {
  padding: 8px 4px 16px;
}

.form-row {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 16px;

  &.ratios-row .form-group {
    flex: 1;
    min-width: 140px;
  }

  &.export-action-row {
    align-items: flex-end;
  }
}

.form-group {
  margin-bottom: 16px;

  label {
    display: block;
    font-weight: 500;
    margin-bottom: 8px;
    color: #333;
  }

  &.prefix-group {
    flex: 0 0 200px;
    min-width: 200px;
  }

  &.action-group {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 0;
  }

  &.flex-1 {
    flex: 1;
    min-width: 160px;
  }
}

.sample-selection {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  padding: 10px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  background: #fafafa;

  label {
    display: flex;
    align-items: center;
    gap: 6px;
    margin: 0;
    padding: 8px 14px;
    border-radius: 8px;
    border: 1px solid #e0e0e0;
    background: #fff;
    cursor: pointer;
    font-weight: normal;
    font-size: 14px;
    transition: all 0.2s;

    &:hover {
      border-color: #1890ff;
      color: #1890ff;
    }

    &.active {
      background: #e6f4ff;
      border-color: #1890ff;
      color: #1890ff;
    }

    input { margin: 0; }
  }
}

.class-checkbox-container {
  padding: 10px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  background: #fafafa;
  max-height: 200px;
  overflow-y: auto;
}

.export-submit-btn {
  min-width: 100px;
  height: 36px;
}

.loading-indicator {
  height: 36px;
  line-height: 36px;
  padding: 0 10px;
  color: #666;
  display: flex;
  align-items: center;
  gap: 8px;
}

.cloud-export-area {
  text-align: left;
  padding: 16px;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  background: #fafafa;

  .cloud-desc {
    color: #555;
    font-size: 14px;
    margin-bottom: 16px;
  }
}

.cloud-status {
  margin-top: 12px;
  font-size: 13px;
  color: #444;
}

.upload-actions {
  text-align: center;
  margin-top: 16px;
}
</style>

<template>
  <BasicModal
    @register="register"
    :title="modalTitle"
    :width="560"
    :confirmLoading="submitting"
    okText="发布"
    @ok="handleSubmit"
  >
    <Alert
      type="info"
      show-icon
      class="publish-tip"
      message="发布后将写入模型管理，可直接用于模型推理、导出与算法任务。"
    />
    <Form :label-col="{ span: 6 }" :wrapper-col="{ span: 17 }">
      <FormItem label="模型名称" required>
        <Input v-model:value="formState.name" placeholder="请输入模型名称" />
      </FormItem>
      <FormItem label="版本策略" required>
        <Radio.Group v-model:value="formState.autoIncrement" @change="handleVersionModeChange">
          <Radio :value="true">自动递增</Radio>
          <Radio :value="false">手动指定</Radio>
        </Radio.Group>
      </FormItem>
      <FormItem label="模型版本" required>
        <Input
          v-model:value="formState.version"
          :readonly="formState.autoIncrement"
          placeholder="例如 1.0.0"
        />
        <div class="form-hint">
          <template v-if="formState.autoIncrement">
            将按补丁位自动递增（如 1.0.0 → 1.0.1 → 1.0.2）
          </template>
          <template v-else>
            请输入自定义版本号，格式建议 x.y.z（如 2.0.0）
          </template>
        </div>
      </FormItem>
      <FormItem label="模型描述">
        <Input.TextArea
          v-model:value="formState.description"
          :rows="3"
          placeholder="可选，便于在模型管理中识别"
        />
      </FormItem>
    </Form>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import { Alert, Form, FormItem, Input, Radio } from 'ant-design-vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { publishTrainTask } from '@/api/device/train';
import { useMessage } from '@/hooks/web/useMessage';
import { normalizeModelVersion } from '../../utils/modelVersionUtils';
import {
  getPublishedModelId,
  getSuggestedPublishVersion,
  resolveTaskBaseNameFromRecord,
} from '../TrainTaskList/trainTaskUtils';

defineOptions({ name: 'PublishTrainModelModal' });

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();

const submitting = ref(false);
const currentRecord = ref<Record<string, unknown> | null>(null);

const formState = reactive({
  name: '',
  version: '',
  description: '',
  autoIncrement: true,
});

const suggestedVersion = ref('1.0.0');

const modalTitle = computed(() =>
  getPublishedModelId(currentRecord.value || undefined) ? '更新发布到模型管理' : '发布到模型管理',
);

function buildDefaultVersion(record: Record<string, unknown>) {
  return getSuggestedPublishVersion(record as {
    suggested_publish_version?: string;
    published_version?: string;
    hyperparameters?: unknown;
  });
}

function buildDefaultName(record: Record<string, unknown>) {
  const base = resolveTaskBaseNameFromRecord(record);
  const dsName = String(record.dataset_name || '').trim();
  if (dsName && base === 'train') {
    return dsName;
  }
  return base || String(record.name || 'train');
}

const [register, { closeModal, setModalProps }] = useModalInner((data) => {
  currentRecord.value = (data?.record || null) as Record<string, unknown> | null;
  submitting.value = false;
  setModalProps({ confirmLoading: false });

  const record = currentRecord.value;
  if (!record) {
    formState.name = '';
    formState.version = '';
    formState.description = '';
    formState.autoIncrement = true;
    suggestedVersion.value = '1.0.0';
    return;
  }

  suggestedVersion.value = buildDefaultVersion(record);
  formState.name = buildDefaultName(record);
  formState.version = suggestedVersion.value;
  formState.autoIncrement = true;
  formState.description = `从训练任务「${record.name || record.id}」发布`;
});

function handleVersionModeChange() {
  if (formState.autoIncrement) {
    formState.version = suggestedVersion.value;
  }
}

async function handleSubmit() {
  const record = currentRecord.value;
  if (!record?.id) {
    createMessage.error('训练任务信息无效');
    return;
  }

  const name = formState.name.trim();
  if (!name) {
    createMessage.warning('请输入模型名称');
    return;
  }

  if (!formState.autoIncrement) {
    const version = normalizeModelVersion(formState.version);
    if (!version) {
      createMessage.warning('请输入模型版本');
      return;
    }
    formState.version = version;
  }

  submitting.value = true;
  setModalProps({ confirmLoading: true });
  try {
    const payload: {
      name: string;
      description: string;
      auto_increment: boolean;
      version?: string;
    } = {
      name,
      description: formState.description.trim(),
      auto_increment: formState.autoIncrement,
    };
    if (!formState.autoIncrement) {
      payload.version = formState.version;
    }

    const publishedModel = await publishTrainTask(Number(record.id), payload);
    createMessage.success('发布成功');
    closeModal();
    emit('success', publishedModel);
  } catch (error: any) {
    createMessage.error(error?.response?.data?.msg || error?.message || '发布失败');
  } finally {
    submitting.value = false;
    setModalProps({ confirmLoading: false });
  }
}
</script>

<style lang="less" scoped>
.publish-tip {
  margin-bottom: 16px;
}

.form-hint {
  margin-top: 6px;
  color: #8c8c8c;
  font-size: 12px;
  line-height: 1.5;
}
</style>

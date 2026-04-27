<template>
  <BasicModal
    @register="register"
    title="从云端同步模型到本地"
    :width="560"
    :canFullscreen="false"
    @ok="handleOk"
  >
    <Alert
      type="info"
      show-icon
      class="mb-4"
      message="在 AI 服务环境中配置 EDGE_CLOUD_MODEL_API_BASE（云端与边缘相同的模型 API 根路径，例如 https://your-cloud/admin-api/model），可选 EDGE_CLOUD_MODEL_TOKEN。"
    />
    <Spin :spinning="state.loading">
      <Form layout="vertical">
        <FormItem label="选择云端模型" required>
          <Select
            v-model:value="state.remoteId"
            placeholder="请先加载云端目录"
            :options="state.options"
            :loading="state.loading"
            show-search
            :filter-option="filterOption"
            allow-clear
          />
        </FormItem>
      </Form>
    </Spin>
  </BasicModal>
</template>

<script lang="ts" setup>
import { reactive } from 'vue';
import { Alert, Form, FormItem, Select, Spin } from 'ant-design-vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import { listCloudModelCatalog, syncModelFromCloud } from '@/api/device/model';

const { createMessage } = useMessage();

const state = reactive({
  loading: false,
  remoteId: undefined as number | undefined,
  options: [] as { label: string; value: number }[],
});

const emit = defineEmits<{ (e: 'success'): void }>();

const [register, { closeModal, setModalProps }] = useModalInner(async () => {
  state.remoteId = undefined;
  state.options = [];
  await loadCatalog();
});

async function loadCatalog() {
  state.loading = true;
  try {
    const res: any = await listCloudModelCatalog();
    const rows = (res && res.data) || [];
    state.options = rows.map((row: any) => ({
      value: row.id,
      label: `${row.name || '未命名'} · v${row.version || ''} · 云端ID:${row.id}`,
    }));
    if (!rows.length) {
      createMessage.warning('云端目录为空或未配置云端地址');
    }
  } catch (e) {
    console.error(e);
  } finally {
    state.loading = false;
  }
}

function filterOption(input: string, option: any) {
  return (option?.label as string)?.toLowerCase().includes(input.toLowerCase());
}

async function handleOk() {
  if (state.remoteId == null) {
    createMessage.warning('请选择要同步的云端模型');
    return;
  }
  setModalProps({ confirmLoading: true });
  try {
    await syncModelFromCloud(state.remoteId);
    createMessage.success('已同步到本地');
    closeModal();
    emit('success');
  } catch (e) {
    console.error(e);
  } finally {
    setModalProps({ confirmLoading: false });
  }
}
</script>

<style scoped>
.mb-4 {
  margin-bottom: 16px;
}
</style>

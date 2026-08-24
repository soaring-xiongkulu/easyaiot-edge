<template>
  <BasicModal
    @register="register"
    title="编辑通道"
    @cancel="handleCancel"
    :width="560"
    @ok="handleOk"
    :canFullscreen="false"
  >
    <div class="channel-modal">
      <Spin :spinning="state.loading">
        <Form
          :labelCol="{ span: 6 }"
          :wrapperCol="{ span: 16 }"
          :model="modelRef"
        >
          <FormItem label="通道名称" name="gbName">
            <Input v-model:value="modelRef.gbName" placeholder="通道名称" allow-clear />
          </FormItem>
          <FormItem label="国标编码" name="gbDeviceId">
            <Input v-model:value="modelRef.gbDeviceId" disabled />
          </FormItem>
          <FormItem label="厂商" name="gbManufacturer">
            <Input v-model:value="modelRef.gbManufacturer" allow-clear />
          </FormItem>
          <FormItem label="型号" name="gbModel">
            <Input v-model:value="modelRef.gbModel" allow-clear />
          </FormItem>
          <FormItem label="安装地址" name="gbAddress">
            <Input v-model:value="modelRef.gbAddress" allow-clear />
          </FormItem>
        </Form>
      </Spin>
    </div>
  </BasicModal>
</template>
<script lang="ts" setup>
import {reactive} from 'vue';
import {BasicModal, useModalInner} from '@/components/Modal';
import {Form, FormItem, Input, Spin} from 'ant-design-vue';
import {useMessage} from '@/hooks/web/useMessage';
import {getChannel, updateChannel} from '@/api/device/gb28181';

defineOptions({name: 'ChannelModal'});

const {createMessage} = useMessage();

const state = reactive({
  loading: false,
});

const modelRef = reactive({
  gbId: 0,
  gbName: '',
  gbDeviceId: '',
  gbManufacturer: '',
  gbModel: '',
  gbAddress: '',
});

function resetModel() {
  modelRef.gbId = 0;
  modelRef.gbName = '';
  modelRef.gbDeviceId = '';
  modelRef.gbManufacturer = '';
  modelRef.gbModel = '';
  modelRef.gbAddress = '';
}

const [register, {closeModal}] = useModalInner(async (data) => {
  resetModel();
  const row = data?.record;
  if (!row?.id) {
    return;
  }
  state.loading = true;
  try {
    const res: any = await getChannel(row.id);
    const ch = res?.data ?? res;
    if (!ch) {
      return;
    }
    modelRef.gbId = ch.gbId ?? ch.id ?? row.id;
    modelRef.gbName = ch.gbName ?? '';
    modelRef.gbDeviceId = ch.gbDeviceId ?? '';
    modelRef.gbManufacturer = ch.gbManufacturer ?? '';
    modelRef.gbModel = ch.gbModel ?? '';
    modelRef.gbAddress = ch.gbAddress ?? '';
  } finally {
    state.loading = false;
  }
});

const emits = defineEmits(['success']);

function handleCancel() {
  resetModel();
}

async function handleOk() {
  if (!modelRef.gbId) {
    createMessage.warning('未加载到通道数据');
    return;
  }
  state.loading = true;
  try {
    await updateChannel({
      gbId: modelRef.gbId,
      gbName: modelRef.gbName,
      gbDeviceId: modelRef.gbDeviceId,
      gbManufacturer: modelRef.gbManufacturer,
      gbModel: modelRef.gbModel,
      gbAddress: modelRef.gbAddress,
    });
    createMessage.success('保存成功');
    closeModal();
    resetModel();
    emits('success');
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
  } finally {
    state.loading = false;
  }
}
</script>
<style lang="less" scoped>
.channel-modal {
  :deep(.ant-form-item-label) {
    & > label::after {
      content: '';
    }
  }
}
</style>

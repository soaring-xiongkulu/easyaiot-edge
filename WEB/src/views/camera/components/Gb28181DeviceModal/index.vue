<template>
  <BasicModal
    @register="register"
    :title="modalTitle"
    :width="640"
    :canFullscreen="false"
    :showOkBtn="!isView"
    @ok="handleOk"
    @cancel="handleCancel"
  >
    <Spin :spinning="state.loading">
      <Form :labelCol="{ span: 7 }" :wrapperCol="{ span: 15 }" :model="modelRef">
        <FormItem label="设备国标编号">
          <Input v-model:value="modelRef.deviceId" disabled />
        </FormItem>
        <FormItem label="设备名称">
          <Input
            v-model:value="modelRef.name"
            :disabled="isView"
            placeholder="设备名称"
            allow-clear
          />
        </FormItem>
        <FormItem label="生产厂商">
          <Input v-model:value="modelRef.manufacturer" disabled />
        </FormItem>
        <FormItem label="型号">
          <Input v-model:value="modelRef.model" disabled />
        </FormItem>
        <FormItem label="IP地址">
          <Input v-model:value="modelRef.ip" disabled />
        </FormItem>
        <FormItem label="端口">
          <Input v-model:value="modelRef.portText" disabled />
        </FormItem>
        <FormItem label="信令传输">
          <Select
            v-model:value="modelRef.transport"
            :disabled="isView"
            :options="transportOptions"
            allow-clear
          />
        </FormItem>
        <FormItem label="流传输模式">
          <Select
            v-model:value="modelRef.streamMode"
            :disabled="isView"
            :options="streamModeOptions"
            allow-clear
          />
        </FormItem>
        <FormItem label="字符集">
          <Select
            v-model:value="modelRef.charset"
            :disabled="isView"
            :options="charsetOptions"
            allow-clear
          />
        </FormItem>
        <FormItem label="媒体服务器">
          <Input
            v-model:value="modelRef.mediaServerId"
            :disabled="isView"
            placeholder="媒体唯一标识"
            allow-clear
          />
        </FormItem>
        <FormItem label="在线状态">
          <Input :value="modelRef.onLine ? '在线' : '离线'" disabled />
        </FormItem>
        <FormItem label="通道个数">
          <Input v-model:value="modelRef.channelCountText" disabled />
        </FormItem>
        <FormItem label="注册时间">
          <Input v-model:value="modelRef.registerTime" disabled />
        </FormItem>
      </Form>
    </Spin>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { Form, FormItem, Input, Select, Spin } from 'ant-design-vue';
import { useMessage } from '@/hooks/web/useMessage';
import { getDevice, updateDevice } from '@/api/device/gb28181';
import { stripGb28181DeviceDisplayPrefix } from '@/views/camera/utils/gb28181DeviceLabel';

defineOptions({ name: 'Gb28181DeviceModal' });

const emit = defineEmits(['success']);

const { createMessage } = useMessage();

const isView = ref(false);
const state = reactive({ loading: false });

const transportOptions = [
  { label: 'UDP', value: 'UDP' },
  { label: 'TCP', value: 'TCP' },
];

const streamModeOptions = [
  { label: 'UDP', value: 'UDP' },
  { label: 'TCP主动', value: 'TCP-ACTIVE' },
  { label: 'TCP被动', value: 'TCP-PASSIVE' },
];

const charsetOptions = [
  { label: 'UTF-8', value: 'UTF-8' },
  { label: 'GB2312', value: 'GB2312' },
];

const modelRef = reactive({
  id: 0,
  deviceId: '',
  name: '',
  manufacturer: '',
  model: '',
  ip: '',
  portText: '',
  transport: '',
  streamMode: '',
  charset: '',
  mediaServerId: '',
  onLine: false,
  channelCountText: '',
  registerTime: '',
});

const rawDevice = ref<Record<string, any>>({});

const modalTitle = computed(() => (isView.value ? '国标设备详情' : '编辑国标设备'));

function resetModel() {
  modelRef.id = 0;
  modelRef.deviceId = '';
  modelRef.name = '';
  modelRef.manufacturer = '';
  modelRef.model = '';
  modelRef.ip = '';
  modelRef.portText = '';
  modelRef.transport = '';
  modelRef.streamMode = '';
  modelRef.charset = '';
  modelRef.mediaServerId = '';
  modelRef.onLine = false;
  modelRef.channelCountText = '';
  modelRef.registerTime = '';
  rawDevice.value = {};
}

function fillFromDevice(dev: Record<string, any>) {
  rawDevice.value = { ...dev };
  modelRef.id = Number(dev.id ?? dev.deviceDbId ?? 0);
  modelRef.deviceId = String(dev.deviceId ?? dev.deviceIdentification ?? '').trim();
  modelRef.name = stripGb28181DeviceDisplayPrefix(dev.name);
  modelRef.manufacturer = dev.manufacturer ?? dev.manufacture ?? '';
  modelRef.model = dev.model ?? '';
  modelRef.ip = dev.ip ?? dev.localIp ?? '';
  modelRef.portText = dev.port != null && dev.port !== '' ? String(dev.port) : '-';
  modelRef.transport = dev.transport ?? '';
  modelRef.streamMode = dev.streamMode ?? '';
  modelRef.charset = dev.charset ?? '';
  modelRef.mediaServerId = dev.mediaServerId != null ? String(dev.mediaServerId) : '';
  modelRef.onLine = !!(dev.onLine ?? dev.on_line ?? dev.online);
  modelRef.channelCountText =
    dev.channelCount != null ? String(dev.channelCount) : dev.subCount != null ? String(dev.subCount) : '-';
  modelRef.registerTime = dev.registerTime ?? dev.register_time ?? '-';
}

const [register, { closeModal }] = useModalInner(async (data) => {
  resetModel();
  isView.value = !!data?.isView;
  const sipId = String(
    data?.sipDeviceId ?? data?.record?.deviceIdentification ?? data?.record?.sip_device_id ?? '',
  ).trim();
  if (!sipId) {
    createMessage.warning('缺少设备国标编号');
    return;
  }
  state.loading = true;
  try {
    const res: any = await getDevice(sipId);
    const dev = res?.data ?? res;
    if (!dev) {
      createMessage.error('获取设备信息失败');
      return;
    }
    fillFromDevice(dev);
  } catch (e) {
    console.error(e);
    createMessage.error('获取设备信息失败');
  } finally {
    state.loading = false;
  }
});

function handleCancel() {
  resetModel();
}

async function handleOk() {
  if (isView.value) {
    closeModal();
    return;
  }
  if (!modelRef.id || !modelRef.deviceId) {
    createMessage.warning('设备数据不完整，无法保存');
    return;
  }
  state.loading = true;
  try {
    const payload = {
      ...rawDevice.value,
      id: modelRef.id,
      deviceId: modelRef.deviceId,
      name: stripGb28181DeviceDisplayPrefix(modelRef.name) || modelRef.deviceId,
      transport: modelRef.transport,
      streamMode: modelRef.streamMode,
      charset: modelRef.charset,
      mediaServerId: modelRef.mediaServerId || null,
    };
    await updateDevice(payload);
    createMessage.success('保存成功');
    closeModal();
    emit('success');
  } catch (e) {
    console.error(e);
    createMessage.error('保存失败');
  } finally {
    state.loading = false;
  }
}
</script>

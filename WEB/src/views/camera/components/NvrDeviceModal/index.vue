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
        <FormItem label="NVR IP" required>
          <Input v-model:value="modelRef.ip" :disabled="isView" placeholder="192.168.1.64" />
        </FormItem>
        <FormItem label="端口">
          <InputNumber
            v-model:value="modelRef.port"
            :min="1"
            :max="65535"
            style="width: 100%"
            :disabled="isView"
          />
        </FormItem>
        <FormItem label="名称">
          <Input v-model:value="modelRef.name" :disabled="isView" placeholder="录像机名称" allow-clear />
        </FormItem>
        <FormItem label="品牌">
          <Select
            v-model:value="modelRef.vendor"
            :disabled="isView"
            allow-clear
            placeholder="海康/大华"
            :options="vendorOptions"
          />
        </FormItem>
        <FormItem label="型号">
          <Input v-model:value="modelRef.model" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="序列号">
          <Input v-model:value="modelRef.serial_number" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="固件版本">
          <Input v-model:value="modelRef.firmware_version" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="MAC">
          <Input v-model:value="modelRef.mac" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="用户名">
          <Input v-model:value="modelRef.username" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="密码">
          <Input.Password v-model:value="modelRef.password" :disabled="isView" allow-clear />
        </FormItem>
        <FormItem label="Web 地址">
          <Input :value="webUrlDisplay" disabled />
        </FormItem>
        <FormItem label="挂载摄像头">
          <Input :value="cameraCountText" disabled />
        </FormItem>
      </Form>
    </Spin>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { Form, FormItem, Input, InputNumber, Select, Spin } from 'ant-design-vue';
import { useMessage } from '@/hooks/web/useMessage';
import { getNvrDetail, upsertNvr, type NvrInfo } from '@/api/device/camera';

defineOptions({ name: 'NvrDeviceModal' });

const emit = defineEmits(['success']);

const { createMessage } = useMessage();

const isView = ref(false);
const state = reactive({ loading: false });

const vendorOptions = [
  { label: '海康', value: 'hikvision' },
  { label: '大华', value: 'dahua' },
  { label: '华为', value: 'huawei' },
  { label: '萤石', value: 'ezviz' },
  { label: '小米', value: 'xiaomi' },
];

const modelRef = reactive({
  id: 0,
  ip: '',
  port: 80,
  name: '',
  vendor: '',
  model: '',
  serial_number: '',
  firmware_version: '',
  mac: '',
  username: '',
  password: '',
  camera_count: 0,
  web_url: '',
});

const modalTitle = computed(() => (isView.value ? 'NVR 详情' : '编辑 NVR'));

const webUrlDisplay = computed(() => {
  if (modelRef.web_url) return modelRef.web_url;
  const sch = modelRef.port === 443 || modelRef.port === 8443 ? 'https' : 'http';
  return modelRef.ip ? `${sch}://${modelRef.ip}:${modelRef.port || 80}` : '—';
});

const cameraCountText = computed(() =>
  modelRef.camera_count != null ? `${modelRef.camera_count} 路` : '—',
);

function resetModel() {
  modelRef.id = 0;
  modelRef.ip = '';
  modelRef.port = 80;
  modelRef.name = '';
  modelRef.vendor = '';
  modelRef.model = '';
  modelRef.serial_number = '';
  modelRef.firmware_version = '';
  modelRef.mac = '';
  modelRef.username = '';
  modelRef.password = '';
  modelRef.camera_count = 0;
  modelRef.web_url = '';
}

function fillFromNvr(nvr: NvrInfo) {
  modelRef.id = Number(nvr.id ?? 0);
  modelRef.ip = nvr.ip ?? '';
  modelRef.port = nvr.port ?? 80;
  modelRef.name = nvr.name ?? nvr.device_name ?? '';
  modelRef.vendor = nvr.vendor ?? '';
  modelRef.model = nvr.model ?? '';
  modelRef.serial_number = nvr.serial_number ?? nvr.serial ?? '';
  modelRef.firmware_version = nvr.firmware_version ?? nvr.firmware ?? '';
  modelRef.mac = nvr.mac ?? '';
  modelRef.username = nvr.username ?? '';
  modelRef.password = nvr.password ?? '';
  modelRef.camera_count = nvr.camera_count ?? nvr.cameras?.length ?? 0;
  modelRef.web_url = nvr.web_url ?? '';
}

const [register, { closeModal }] = useModalInner(async (data) => {
  resetModel();
  isView.value = !!data?.isView;
  const nvrId = Number(data?.nvrId ?? data?.record?.nvr_id_num ?? 0);
  if (!nvrId) {
    createMessage.warning('缺少 NVR ID');
    return;
  }
  state.loading = true;
  try {
    const res = await getNvrDetail(nvrId, true);
    const nvr = (res as NvrInfo) || (res as { data?: NvrInfo })?.data;
    if (!nvr) {
      createMessage.error('获取 NVR 信息失败');
      return;
    }
    fillFromNvr(nvr);
  } catch (e) {
    console.error(e);
    createMessage.error('获取 NVR 信息失败');
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
  if (!modelRef.id) {
    createMessage.warning('NVR 数据不完整，无法保存');
    return;
  }
  const ip = (modelRef.ip || '').trim();
  if (!ip) {
    createMessage.warning('请填写 NVR IP');
    return;
  }
  state.loading = true;
  try {
    await upsertNvr({
      id: modelRef.id,
      ip,
      port: modelRef.port ?? 80,
      name: modelRef.name || undefined,
      vendor: modelRef.vendor || undefined,
      model: modelRef.model || undefined,
      serial_number: modelRef.serial_number || undefined,
      firmware_version: modelRef.firmware_version || undefined,
      mac: modelRef.mac || undefined,
      username: modelRef.username || undefined,
      password: modelRef.password || undefined,
    });
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

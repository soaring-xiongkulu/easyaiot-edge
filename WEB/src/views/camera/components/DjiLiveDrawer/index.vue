<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="drawerTitle"
    width="1400"
    placement="right"
    :showFooter="true"
    :showCancelBtn="false"
    :showOkBtn="false"
    destroy-on-close
  >
    <template #footer>
      <div class="footer-buttons">
        <Button @click="closeDrawer">{{ isViewMode ? '关闭' : '取消' }}</Button>
        <Button v-if="!isViewMode" type="primary" :loading="loading" @click="handleSubmit">
          {{ drawerMode === 'edit' ? '保存' : '接入' }}
        </Button>
      </div>
    </template>

    <Spin :spinning="loading" tip="正在开启司空直播并创建本地 SRS 桥接任务...">
      <div class="dji-drawer-content">
        <Alert
          class="dji-hint"
          type="info"
          show-icon
          message="大疆司空直播接入"
          description="司空返回直播供应商地址后，系统会将其作为上游源接入，并通过本地 SRS 转发播放；火山 RTC 型地址由前端 SDK 播放。"
        />

        <Form
          ref="formRef"
          :model="formState"
          :rules="rules"
          :disabled="isViewMode"
          :label-col="SETUP_FORM_LABEL_COL"
          :wrapper-col="SETUP_FORM_WRAPPER_COL"
          class="section-form"
        >
          <Divider orientation="left">司空 API 配置</Divider>
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="API Host" name="api_host">
                <Input v-model:value="formState.api_host" placeholder="es-flight-api-cn.djigate.com" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="项目编号" name="project_uuid">
                <Input
                  v-model:value="formState.project_uuid"
                  placeholder="X-Project-Uuid，例如 e7b81eec-f182-473a-9368-9e220e46f9d9"
                />
              </FormItem>
            </Col>
            <Col :span="24">
              <FormItem label="开启直播接口" name="api_path">
                <Input v-model:value="formState.api_path" placeholder="/openapi/v0.1/live-stream/start" />
              </FormItem>
            </Col>
            <Col :span="24">
              <FormItem label="X-User-Token" name="user_token">
                <InputPassword v-model:value="formState.user_token" placeholder="请输入司空 X-User-Token" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="工作空间名称">
                <Input v-model:value="formState.workspace_name" placeholder="金鼎飞控" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="平台名称">
                <Input v-model:value="formState.platform_name" placeholder="金鼎飞控" />
              </FormItem>
            </Col>
          </Row>

          <Divider orientation="left">直播参数</Divider>
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="接入方式" name="use_skylink_api">
                <RadioGroup v-model:value="formState.use_skylink_api" button-style="solid">
                  <RadioButton :value="true">司空 API 开启直播</RadioButton>
                  <RadioButton :value="false">手动直播源</RadioButton>
                </RadioGroup>
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="设备类型" name="device_type">
                <RadioGroup v-model:value="formState.device_type" button-style="solid">
                  <RadioButton value="dock">大疆机场</RadioButton>
                  <RadioButton value="drone">无人机</RadioButton>
                </RadioGroup>
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="设备名称" name="name">
                <Input v-model:value="formState.name" placeholder="例如：机场 1 号直播" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="设备 SN" name="sn">
                <Input v-model:value="formState.sn" placeholder="例如：8UUDMAQ00A0133" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="camera_index" name="camera_index">
                <Input v-model:value="formState.camera_index" placeholder="例如：165-0-7" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="位置备注" name="address">
                <Input v-model:value="formState.address" placeholder="例如：金鼎基地东侧机场" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="机场 SN">
                <Input v-model:value="formState.dock_sn" placeholder="可选" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="无人机 SN">
                <Input v-model:value="formState.drone_sn" placeholder="可选" />
              </FormItem>
            </Col>
            <template v-if="formState.use_skylink_api">
              <Col :span="12">
                <FormItem label="Token 有效期" name="video_expire">
                  <InputNumber
                    v-model:value="formState.video_expire"
                    :min="60"
                    :max="86400"
                    class="w-full"
                    addon-after="秒"
                  />
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="直播清晰度" name="quality_type">
                  <Select v-model:value="formState.quality_type" :options="qualityOptions" />
                </FormItem>
              </Col>
            </template>
            <Col v-else :span="24">
              <FormItem label="直播源地址" name="source">
                <Input
                  v-model:value="formState.source"
                  placeholder="rtmp:// / rtsp:// / https://...m3u8 / http://...flv"
                />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="自动创建转发" name="enable_forward">
                <Switch v-model:checked="formState.enable_forward" />
              </FormItem>
            </Col>
          </Row>

          <div class="form-hint">
            司空 API 模式会调用开启直播接口并自动登记设备；手动模式直接以 RTSP/RTMP/HTTP-FLV/HLS 源接入流媒体。
          </div>
        </Form>

        <Alert
          v-if="liveIssue"
          class="live-issue"
          type="warning"
          show-icon
          :message="liveIssue.title"
          :description="liveIssue.description"
        />
      </div>
    </Spin>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import {
  Alert,
  Col,
  Divider,
  Form,
  FormItem,
  Input,
  InputNumber,
  RadioButton,
  RadioGroup,
  Row,
  Select,
  Spin,
  Switch,
} from 'ant-design-vue';
import type { Rule } from 'ant-design-vue/es/form';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getFlighthubConfig,
  registerDevice,
  registerDjiLiveDevice,
  startDjiSkylinkLive,
  type DjiSkylinkStartPayload,
} from '@/api/device/camera';
import { SETUP_FORM_LABEL_COL, SETUP_FORM_WRAPPER_COL } from '@/views/node/utils/constants';

defineOptions({ name: 'DjiLiveDrawer' });

const emit = defineEmits(['success', 'register']);
const { createMessage } = useMessage();
const InputPassword = Input.Password;

const loading = ref(false);
const formRef = ref();
const liveIssue = ref<{ title: string; description: string } | null>(null);
const drawerMode = ref<'create' | 'view' | 'edit'>('create');
const isViewMode = computed(() => drawerMode.value === 'view');
const drawerTitle = computed(() => {
  if (drawerMode.value === 'view') return '查看大疆直播';
  if (drawerMode.value === 'edit') return '编辑大疆直播';
  return '接入大疆直播';
});

const qualityOptions = [
  { label: '自适应', value: 'adaptive' },
  { label: '流畅', value: 'smooth' },
  { label: '超高清', value: 'ultra_high_definition' },
];

type DjiLiveFormState = DjiSkylinkStartPayload & {
  use_skylink_api: boolean;
  api_path: string;
  source: string;
  address: string;
};

const formState = reactive<DjiLiveFormState>({
  use_skylink_api: true,
  user_token: '',
  project_uuid: '',
  api_host: 'es-flight-api-cn.djigate.com',
  api_path: '/openapi/v0.1/live-stream/start',
  workspace_id: '',
  workspace_name: '',
  platform_name: '',
  platform_host: 'flight-api.szjdaq.com',
  name: '',
  device_type: 'dock',
  sn: '',
  camera_index: '',
  video_expire: 7200,
  quality_type: 'adaptive',
  source: '',
  dock_sn: '',
  drone_sn: '',
  enable_forward: true,
  address: '',
});

const rules: Record<string, Rule[]> = {
  api_host: [{ required: true, message: '请输入 API Host', trigger: 'blur' }],
  project_uuid: [
    {
      validator: async () => {
        if (!formState.use_skylink_api || formState.project_uuid) return Promise.resolve();
        return Promise.reject('请输入项目编号 X-Project-Uuid');
      },
      trigger: 'blur',
    },
  ],
  user_token: [
    {
      validator: async () => {
        if (!formState.use_skylink_api || formState.user_token) return Promise.resolve();
        return Promise.reject('请输入 X-User-Token');
      },
      trigger: 'blur',
    },
  ],
  name: [{ required: true, message: '请输入设备名称', trigger: 'blur' }],
  sn: [
    {
      validator: async () => {
        if (!formState.use_skylink_api || formState.sn) return Promise.resolve();
        return Promise.reject('请输入设备 SN');
      },
      trigger: 'blur',
    },
  ],
  camera_index: [
    {
      validator: async () => {
        if (!formState.use_skylink_api || formState.camera_index) return Promise.resolve();
        return Promise.reject('请输入 camera_index');
      },
      trigger: 'blur',
    },
  ],
  source: [
    {
      validator: async (_rule, value) => {
        if (formState.use_skylink_api) return Promise.resolve();
        const source = String(value || '').trim().toLowerCase();
        if (!source) return Promise.reject('请输入直播源地址');
        if (/^(rtsp|rtsps|rtmp|rtmps|http|https):\/\//.test(source) || source.startsWith('//')) {
          return Promise.resolve();
        }
        return Promise.reject('直播源仅支持 RTSP/RTSPS、RTMP/RTMPS、HTTP-FLV、HLS 地址');
      },
      trigger: 'blur',
    },
  ],
};

function resetForm() {
  liveIssue.value = null;
  drawerMode.value = 'create';
  formState.use_skylink_api = true;
  formState.user_token = '';
  formState.name = '';
  formState.sn = '';
  formState.camera_index = '';
  formState.source = '';
  formState.device_type = 'dock';
  formState.dock_sn = '';
  formState.drone_sn = '';
  formState.video_expire = 7200;
  formState.quality_type = 'adaptive';
  formState.enable_forward = true;
  formState.address = '';
}

function parseVolcCameraIndex(source?: string) {
  const raw = String(source || '').trim();
  if (!raw) return '';
  const query = raw.startsWith('volc://') ? decodeURIComponent(raw.slice('volc://'.length)) : raw;
  const params = new URLSearchParams(query.includes('?') ? query.slice(query.indexOf('?') + 1) : query);
  const roomId = params.get('room_id') || '';
  return roomId.includes('_') ? roomId.split('_').slice(1).join('_') : '';
}

function fillFromDeviceRecord(record: Record<string, any>) {
  formState.use_skylink_api = String(record.source || '').startsWith('volc://') || /DJI/i.test(String(record.manufacturer || ''));
  formState.name = record.name || '';
  formState.device_type = /drone|无人机|Drone\s*Live/i.test(String(record.model || record.name || record.dji_device_type || ''))
    ? 'drone'
    : /dock|机场|Dock\s*Live/i.test(String(record.model || record.name || record.dji_device_type || ''))
      ? 'dock'
      : ((record.dji_device_type as 'dock' | 'drone') || 'dock');
  formState.sn = record.serial_number || record.serial || '';
  formState.dock_sn = formState.device_type === 'dock' ? formState.sn : '';
  formState.drone_sn = formState.device_type === 'drone' ? formState.sn : '';
  formState.camera_index = record.camera_index || parseVolcCameraIndex(record.source) || '';
  formState.source = record.source || '';
  formState.project_uuid = record.username || String(record.hardware_id || '').replace(/^flighthub:/, '') || formState.project_uuid;
  formState.workspace_id = formState.project_uuid;
  formState.api_host = record.firmware_version || formState.api_host;
  formState.platform_host = record.firmware_version || formState.platform_host;
  formState.address = record.address || '';
  formState.user_token = '';
}

async function loadConfig() {
  try {
    const config = await getFlighthubConfig();
    formState.workspace_id = config.workspace_id || '7b9f3b4e-8a2c-4f69-9d88-1f4a36b4d001';
    formState.project_uuid = config.workspace_id || '7b9f3b4e-8a2c-4f69-9d88-1f4a36b4d001';
    formState.workspace_name = config.workspace_name || '金鼎飞控';
    formState.platform_name = config.platform_name || '金鼎飞控';
    formState.platform_host = config.platform_host || 'flight-api.szjdaq.com';
    formState.api_host = config.openapi_host || 'es-flight-api-cn.djigate.com';
    formState.api_path = config.live_start_path || '/openapi/v0.1/live-stream/start';
  } catch (error) {
    formState.workspace_id = '7b9f3b4e-8a2c-4f69-9d88-1f4a36b4d001';
    formState.project_uuid = '7b9f3b4e-8a2c-4f69-9d88-1f4a36b4d001';
    formState.workspace_name = '金鼎飞控';
    formState.platform_name = '金鼎飞控';
    formState.platform_host = 'flight-api.szjdaq.com';
    formState.api_host = 'es-flight-api-cn.djigate.com';
    formState.api_path = '/openapi/v0.1/live-stream/start';
  }
}

const [register, { closeDrawer }] = useDrawerInner(async (data?: Record<string, any>) => {
  resetForm();
  await loadConfig();
  if (data?.record) {
    drawerMode.value = data.isView ? 'view' : data.isEdit ? 'edit' : data.type === 'view' ? 'view' : 'edit';
    fillFromDeviceRecord(data.record);
  }
});

function errorMessage(error: unknown) {
  const err = error as {
    msg?: string;
    message?: string;
    response?: { data?: { msg?: string; message?: string; data?: { message?: string; msg?: string } } };
  };
  return (
    err?.msg ||
    err?.response?.data?.msg ||
    err?.response?.data?.message ||
    err?.response?.data?.data?.message ||
    err?.response?.data?.data?.msg ||
    err?.message ||
    '接入大疆直播失败'
  );
}

function serialNumber() {
  return formState.sn || formState.drone_sn || formState.dock_sn;
}

function isVolcSdkLiveResult(payload: any) {
  const detail = payload?.data || payload || {};
  const provider = detail?.provider || detail;
  const urlType = String(detail?.url_type || provider?.url_type || provider?.type || '').toLowerCase();
  return urlType === 'volc' && !!provider?.url;
}

function getVolcProvider(payload: any) {
  const detail = payload?.data || payload || {};
  return detail?.provider || detail;
}

function toVolcSource(provider: any) {
  const url = String(provider?.url || '').trim();
  if (!url) return '';
  return url.startsWith('volc://') ? url : `volc://${encodeURIComponent(url)}`;
}

async function registerVolcSdkDevice(payload: any) {
  const provider = getVolcProvider(payload);
  const source = toVolcSource(provider);
  if (!source) return false;
  await registerDevice({
    name: formState.name.trim() || (formState.device_type === 'dock' ? '大疆机场直播' : '大疆无人机直播'),
    source,
    cameraType: 'custom',
    username: formState.project_uuid.trim(),
    password: '',
    skylink_token: formState.user_token.trim(),
    manufacturer: 'DJI',
    model: formState.device_type === 'dock' ? 'DJI Dock Live' : 'DJI Drone Live',
    serial_number: serialNumber(),
    hardware_id: formState.project_uuid ? `flighthub:${formState.project_uuid.trim()}` : '',
    firmware_version: formState.api_host.trim(),
    enable_forward: false,
    port: 554,
    address: formState.address || null,
  });
  return true;
}

async function handleSubmit() {
  try {
    liveIssue.value = null;
    loading.value = true;
    await formRef.value?.validate();
    if (formState.use_skylink_api) {
      const response = (await startDjiSkylinkLive({
        ...formState,
        serial_number: serialNumber(),
        sn: formState.sn.trim(),
        camera_index: formState.camera_index.trim(),
        api_host: formState.api_host.trim(),
        api_path: formState.api_path.trim(),
        platform_host: formState.api_host.trim(),
        project_uuid: formState.project_uuid.trim(),
        workspace_id: formState.project_uuid.trim(),
        name: formState.name.trim(),
      })) as any;
      const result = response?.data || response;
      if (result?.code && result.code !== 0 && result.code !== 200) {
        if (isVolcSdkLiveResult(result)) {
          await registerVolcSdkDevice(result);
          createMessage.success('司空直播已开启，火山 RTC 将由前端 SDK 播放');
          closeDrawer();
          emit('success');
          return;
        }
        const detail = result?.data || {};
        const provider = detail?.provider || {};
        const urlType = detail?.url_type || provider?.url_type || provider?.type || 'SDK 型鉴权';
        const suggestion = detail?.suggestion || '请在司空侧切换为 RTMP/HTTP-FLV/HLS/SRS 等可直拉供应商，或增加对应供应商 SDK 桥接服务后再转推本地 SRS。';
        liveIssue.value = {
          title: result?.msg || '司空返回的直播地址当前不能直接接入本地 SRS',
          description: `返回类型：${urlType}。${suggestion}`,
        };
        createMessage.warning('司空已返回直播信息，但当前不是本地 SRS 可直接拉流的地址');
        return;
      }
      createMessage.success('司空直播已开启并接入流媒体');
    } else {
      await registerDjiLiveDevice({
        ...formState,
        serial_number: serialNumber(),
        source: formState.source.trim(),
        name: formState.name.trim(),
      });
      createMessage.success('大疆直播设备接入成功');
    }
    closeDrawer();
    emit('success');
  } catch (error) {
    if ((error as { errorFields?: unknown[] })?.errorFields) return;
    console.error('接入大疆直播失败', error);
    createMessage.error(errorMessage(error));
  } finally {
    loading.value = false;
  }
}
</script>

<style lang="less" scoped>
.dji-drawer-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.dji-hint {
  margin-bottom: 4px;
}

.section-form {
  :deep(.ant-form-item) {
    margin-bottom: 16px;
  }

  :deep(.ant-input-number) {
    width: 100%;
  }

  :deep(.ant-divider) {
    margin: 8px 0 20px;
    font-weight: 600;
  }
}

.form-hint {
  color: rgba(0, 0, 0, 0.45);
  font-size: 13px;
  line-height: 1.5;
  padding-left: 150px;
}

.live-issue {
  margin-top: 4px;
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
}

.w-full {
  width: 100%;
}
</style>

<template>
  <BasicModal
    @register="register"
    :title="getTitle"
    :width="700"
    @cancel="handleCancel"
    @ok="handleOk"
    :canFullscreen="false"
  >
    <div class="product-modal">
      <Spin :spinning="state.editLoading">
        <Form
          :labelCol="{ span: 3 }"
          :model="validateInfos"
          :wrapperCol="{ span: 21 }"
          :disabled="state.isView"
        >
          <FormItem label="任务类型" name="taskType" v-bind=validateInfos.taskType>
            <Select
              placeholder="任务类型"
              :options="state.taskType"
              @change="handleTaskTypeChange"
              v-model:value="modelRef.taskType"
              allowClear
            />
          </FormItem>
          <FormItem label="任务名称" name="taskName" v-bind=validateInfos.taskName>
            <Input v-model:value="modelRef.taskName"/>
          </FormItem>
          <FormItem v-show="modelRef.taskType == 0" label="RTMP流地址" name="rtmpUrl"
                    v-bind=validateInfos.rtmpUrl>
            <Input v-model:value="modelRef.rtmpUrl"/>
          </FormItem>
          <FormItem v-show="modelRef.taskType == 1" label="设备ID" name="deviceId"
                    v-bind=validateInfos.deviceId>
            <Select
              v-model:value="modelRef.deviceId"
              :options="deviceOptions"
              :loading="state.deviceLoading"
              :filter-option="filterGbOption"
              placeholder="请选择GB28181设备"
              show-search
              allow-clear
              @change="handleDeviceChange"
            />
          </FormItem>
          <FormItem v-show="modelRef.taskType == 1" label="通道ID" name="channelId"
                    v-bind=validateInfos.channelId>
            <Select
              v-model:value="modelRef.channelId"
              :options="channelOptions"
              :loading="state.channelLoading"
              :disabled="!modelRef.deviceId"
              :filter-option="filterGbOption"
              placeholder="请先选择设备，再选择通道"
              show-search
              allow-clear
            />
          </FormItem>
        </Form>
      </Spin>
    </div>
  </BasicModal>
</template>
<script lang="ts" setup>
import {computed, reactive, ref} from 'vue';
import {BasicModal, useModalInner} from '@/components/Modal';
import {Form, FormItem, Input, Select, Spin,} from 'ant-design-vue';
import {useMessage} from '@/hooks/web/useMessage';
import {createDatasetFrameTask, updateDatasetFrameTask} from "@/api/device/dataset";
import {queryAllDeviceChannels, queryAllVideoList} from '@/api/device/gb28181';

type GbSelectOption = {
  label: string;
  value: string;
  searchText: string;
};

const {createMessage} = useMessage();

const state = reactive({
  isEdit: false,
  isView: false,
  taskType: [
    {
      label: '实时帧捕获',
      value: 0,
    },
    {
      label: 'GB28181帧捕获',
      value: 1,
    },
  ],
  loading: false,
  editLoading: false,
  deviceLoading: false,
  channelLoading: false,
  deviceLoadFailed: false,
  channelLoadFailed: false,
  loadedChannelDeviceId: '',
  defaultRule: [],
  defaultRuleParams: {
    pageSize: 30,
    page: 1,
    total: 0,
  },
  defaultQueue: [],
  defaultQueueParams: {
    pageSize: 30,
    page: 1,
    total: 0,
  },
});


const modelRef = reactive({
  id: null,
  datasetId: null,
  taskName: '',
  taskType: 0,
  channelId: '',
  deviceId: '',
  rtmpUrl: '',
});

const deviceOptions = ref<GbSelectOption[]>([]);
const channelOptions = ref<GbSelectOption[]>([]);
let channelLoadSequence = 0;

const getTitle = computed(() => (state.isEdit ? '编辑帧捕获任务' : state.isView ? '查看帧捕获任务' : '新增帧捕获任务'));

const [register, {closeModal}] = useModalInner(async (data) => {
  const {datasetId, isEdit, isView, record} = data;
  state.isEdit = isEdit;
  state.isView = isView;
  resetGbSelectionState();
  Object.assign(modelRef, {
    id: null,
    datasetId,
    taskName: '',
    taskType: 0,
    channelId: '',
    deviceId: '',
    rtmpUrl: '',
  });
  if (state.isEdit || state.isView) {
    modelEdit(record);
  }
  if (modelRef.taskType == 1) {
    await loadGbDevices(modelRef.deviceId);
    if (modelRef.deviceId) {
      await loadGbChannels(modelRef.deviceId, modelRef.channelId);
    }
  }
});

function resetGbSelectionState() {
  channelLoadSequence += 1;
  deviceOptions.value = [];
  channelOptions.value = [];
  state.deviceLoading = false;
  state.channelLoading = false;
  state.deviceLoadFailed = false;
  state.channelLoadFailed = false;
  state.loadedChannelDeviceId = '';
}

function modelEdit(record) {
  Object.keys(modelRef).forEach((item) => {
    modelRef[item] = record[item];
  });
}

function normalizeOnlineLabel(value: unknown) {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (value === true || ['1', 'on', 'online', 'true'].includes(normalized)) {
    return '在线';
  }
  if (value === false || ['0', 'off', 'offline', 'false'].includes(normalized)) {
    return '离线';
  }
  return '状态未知';
}

function createGbOption(name: unknown, id: unknown, status: unknown): GbSelectOption | null {
  const value = String(id ?? '').trim();
  if (!value) return null;
  const displayName = String(name ?? '').trim() || value;
  const statusLabel = normalizeOnlineLabel(status);
  const identityLabel = displayName === value ? value : `${displayName} (${value})`;
  return {
    label: `${identityLabel} - ${statusLabel}`,
    value,
    searchText: `${displayName} ${value}`.toLowerCase(),
  };
}

function deduplicateOptions(options: Array<GbSelectOption | null>) {
  const optionMap = new Map<string, GbSelectOption>();
  options.forEach((option) => {
    if (option && !optionMap.has(option.value)) {
      optionMap.set(option.value, option);
    }
  });
  return Array.from(optionMap.values());
}

function preserveSavedOption(options: GbSelectOption[], value: string, type: '设备' | '通道') {
  const savedValue = String(value || '').trim();
  if (!savedValue || options.some((option) => option.value === savedValue)) {
    return options;
  }
  return [
    {
      label: `已保存${type} (${savedValue}) - 当前未找到`,
      value: savedValue,
      searchText: savedValue.toLowerCase(),
    },
    ...options,
  ];
}

function filterGbOption(input: string, option?: GbSelectOption) {
  const keyword = String(input || '').trim().toLowerCase();
  return !keyword || String(option?.searchText || option?.label || '').toLowerCase().includes(keyword);
}

async function loadGbDevices(savedDeviceId = '') {
  state.deviceLoading = true;
  state.deviceLoadFailed = false;
  try {
    const res = await queryAllVideoList();
    const options = deduplicateOptions(
      (res.data || []).map((device: any) => createGbOption(
        device.name ?? device.deviceName,
        device.deviceIdentification ?? device.deviceId,
        device.onLine ?? device.online ?? device.status,
      )),
    );
    deviceOptions.value = preserveSavedOption(options, savedDeviceId, '设备');
  } catch (error) {
    console.error('加载GB28181设备失败', error);
    state.deviceLoadFailed = true;
    deviceOptions.value = preserveSavedOption([], savedDeviceId, '设备');
    createMessage.error('GB28181设备加载失败');
  } finally {
    state.deviceLoading = false;
  }
}

async function loadGbChannels(deviceId: string, savedChannelId = '') {
  const currentSequence = ++channelLoadSequence;
  state.channelLoading = true;
  state.channelLoadFailed = false;
  state.loadedChannelDeviceId = '';
  channelOptions.value = preserveSavedOption([], savedChannelId, '通道');
  try {
    const res = await queryAllDeviceChannels(deviceId);
    if (currentSequence !== channelLoadSequence) return;
    const options = deduplicateOptions(
      (res.data || [])
        .filter((channel: any) => channel.channelType !== true && Number(channel.channelType || 0) !== 1)
        .map((channel: any) => createGbOption(
          channel.name ?? channel.channelName ?? channel.deviceName,
          channel.channelId ?? channel.gbDeviceId,
          channel.status ?? channel.onLine ?? channel.online,
        )),
    );
    channelOptions.value = preserveSavedOption(options, savedChannelId, '通道');
    state.loadedChannelDeviceId = deviceId;
  } catch (error) {
    if (currentSequence !== channelLoadSequence) return;
    console.error('加载GB28181通道失败', error);
    state.channelLoadFailed = true;
    createMessage.error('GB28181通道加载失败');
  } finally {
    if (currentSequence === channelLoadSequence) {
      state.channelLoading = false;
    }
  }
}

const emits = defineEmits(['success']);

const rulesRef = reactive({
  taskType: [{required: true, message: '请输入任务类型', trigger: ['change']}],
  taskName: [{required: true, message: '请输入任务名称', trigger: ['change']}],
});

const useForm = Form.useForm;
const {validate, resetFields, validateInfos} = useForm(modelRef, rulesRef);

async function handleTaskTypeChange(value) {
  if (value != 1) return;
  if (!deviceOptions.value.length || state.deviceLoadFailed) {
    await loadGbDevices(modelRef.deviceId);
  }
  if (modelRef.deviceId && state.loadedChannelDeviceId !== modelRef.deviceId) {
    await loadGbChannels(modelRef.deviceId, modelRef.channelId);
  }
}

async function handleDeviceChange(value?: string) {
  modelRef.channelId = '';
  channelOptions.value = [];
  state.channelLoadFailed = false;
  state.loadedChannelDeviceId = '';
  channelLoadSequence += 1;
  state.channelLoading = false;
  if (value) {
    await loadGbChannels(value);
  }
}

function handleCancel() {
  resetGbSelectionState();
  resetFields();
}

function handleOk() {
  if (modelRef.taskType == 0 && modelRef.rtmpUrl == '') {
    createMessage.error("RTMP流地址不能为空")
    return;
  }
  if (modelRef.taskType == 1 && (modelRef.deviceId == '' || modelRef.channelId == '')) {
    createMessage.error("设备ID和通道ID不能为空")
    return;
  }
  if (modelRef.taskType == 1 && (state.deviceLoading || state.channelLoading)) {
    createMessage.error('GB28181设备或通道正在加载，请稍后重试');
    return;
  }
  if (modelRef.taskType == 1 && (state.deviceLoadFailed || state.channelLoadFailed)) {
    createMessage.error('GB28181设备或通道加载失败，无法提交任务');
    return;
  }
  if (modelRef.taskType == 1 && state.loadedChannelDeviceId !== modelRef.deviceId) {
    createMessage.error('当前设备的通道尚未加载完成');
    return;
  }
  validate().then(async () => {
    let api = createDatasetFrameTask;
    if (modelRef?.id) {
      api = updateDatasetFrameTask;
    }
    state.editLoading = true;
    api(modelRef)
      .then(() => {
        closeModal();
        resetFields();
        emits('success');
      })
      .finally(() => {
        state.editLoading = false;
      });
  }).catch((err) => {
    createMessage.error('操作失败');
    console.error(err);
  });
}
</script>
<style lang="less" scoped>
.product-modal {
  :deep(.ant-form-item-label) {
    & > label::after {
      content: '';
    }
  }
}
</style>

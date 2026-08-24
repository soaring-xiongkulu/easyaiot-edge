<template>
  <div v-if="checking && !modelStatus?.exists" class="p-8 text-center">
    <Spin /> 正在检测车牌识别模型…
  </div>
  <div v-else-if="!modelStatus?.exists" class="plate-model-setup p-8 text-center">
    <a-result status="info" title="车牌识别模型未就绪">
      <template #subTitle>
        启用车牌库管理、自动录入与算法任务车牌匹配前，需在本机部署
        <strong>plate_detect.onnx</strong> 与 <strong>plate_rec.onnx</strong>。
      </template>
      <template #extra>
        <Button type="primary" :loading="downloading" @click="handleDownload">下载/检查模型</Button>
        <Button @click="refresh">刷新状态</Button>
      </template>
    </a-result>
    <p v-if="modelStatus?.error" class="text-red-500 mt-4">{{ modelStatus.error }}</p>
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref, watch } from 'vue';
import { Spin } from 'ant-design-vue';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button'
import {
downloadPlateModel,
  getPlateModelStatus,
  parsePlateApiError,
  type PlateModelStatus,
} from '@/api/device/plate_library';

defineOptions({ name: 'PlateModelSetupPanel' });

const props = defineProps<{
  checking?: boolean;
  modelStatus?: PlateModelStatus | null;
}>();

const emit = defineEmits(['ready']);

const { createMessage } = useMessage();
const internalChecking = ref(true);
const downloading = ref(false);
const localStatus = ref<PlateModelStatus | null>(null);

const checking = ref(props.checking ?? true);
const modelStatus = ref<PlateModelStatus | null>(props.modelStatus ?? null);

watch(
  () => props.checking,
  (v) => {
    if (v !== undefined) checking.value = v;
  },
);

watch(
  () => props.modelStatus,
  (v) => {
    if (v !== undefined) modelStatus.value = v;
  },
);

async function refresh() {
  internalChecking.value = true;
  checking.value = true;
  try {
    const res = await getPlateModelStatus();
    localStatus.value = res.data;
    modelStatus.value = res.data;
    if (res.data?.exists) emit('ready');
  } finally {
    internalChecking.value = false;
    checking.value = false;
  }
}

async function handleDownload() {
  downloading.value = true;
  try {
    const res = await downloadPlateModel();
    createMessage.info(res.msg || '已提交下载任务');
    await refresh();
  } catch (e: unknown) {
    createMessage.error(parsePlateApiError(e, '操作失败'));
  } finally {
    downloading.value = false;
  }
}

onMounted(refresh);
</script>

<template>
  <div class="nvr-mount-fields">
    <Divider orientation="left" plain>NVR 挂载（可选）</Divider>
    <FormItem label="挂载到 NVR">
      <Switch v-model:checked="localMount" :disabled="disabled" @change="onMountToggle" />
      <span class="mount-hint">开启后记录所属 NVR 与通道号</span>
    </FormItem>
    <template v-if="localMount">
      <FormItem label="选择 NVR">
        <Select
          v-model:value="selectValue"
          :disabled="disabled"
          allow-clear
          show-search
          placeholder="选择已有 NVR 或新建"
          :options="selectOptions"
          :filter-option="filterNvr"
          @change="onSelectChange"
        />
        <Button type="link" size="small" :disabled="disabled" @click="loadNvrs">刷新列表</Button>
      </FormItem>
      <template v-if="selectValue === NEW_NVR_KEY">
        <Row :gutter="12">
          <Col :span="12">
            <FormItem label="NVR IP" required>
              <Input v-model:value="localNvr.ip" :disabled="disabled" placeholder="192.168.1.64" />
            </FormItem>
          </Col>
          <Col :span="12">
            <FormItem label="NVR 端口">
              <InputNumber v-model:value="localNvr.port" :min="1" :max="65535" style="width: 100%" :disabled="disabled" />
            </FormItem>
          </Col>
          <Col :span="12">
            <FormItem label="NVR 名称">
              <Input v-model:value="localNvr.name" :disabled="disabled" placeholder="录像机名称" />
            </FormItem>
          </Col>
          <Col :span="12">
            <FormItem label="品牌">
              <Select
                v-model:value="localNvr.vendor"
                :disabled="disabled"
                allow-clear
                placeholder="海康/大华"
                :options="vendorOptions"
              />
            </FormItem>
          </Col>
          <Col :span="24">
            <FormItem label="NVR RTSP">
              <Input
                v-model:value="localNvr.rtsp_url"
                :disabled="disabled"
                placeholder="NVR 预览/取流地址（可选）"
              />
            </FormItem>
          </Col>
        </Row>
      </template>
      <FormItem label="NVR 通道号">
        <InputNumber
          v-model:value="localChannel"
          :min="1"
          :max="256"
          style="width: 160px"
          :disabled="disabled"
          placeholder="如 1、2、3"
        />
      </FormItem>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { Col, Divider, FormItem, Input, InputNumber, Row, Select, Switch } from 'ant-design-vue';
import { getNvrList, type NvrInfo } from '@/api/device/camera';
import { Button } from '@/components/Button'
defineOptions({ name: 'NvrMountFields' });

const NEW_NVR_KEY = '__new_nvr__';

const props = defineProps<{
  disabled?: boolean;
  nvrId?: number | null;
  nvrChannel?: number;
  nvr?: Partial<NvrInfo> | null;
}>();

const emit = defineEmits<{
  (e: 'update:nvrId', v: number | null | undefined): void;
  (e: 'update:nvrChannel', v: number): void;
  (e: 'update:nvr', v: Partial<NvrInfo> | null): void;
}>();

const localMount = ref(false);
const selectValue = ref<number | string | undefined>(undefined);
const localChannel = ref<number | undefined>(undefined);
const nvrList = ref<NvrInfo[]>([]);

const localNvr = reactive({
  ip: '',
  port: 80,
  name: '',
  vendor: undefined as string | undefined,
  rtsp_url: '',
});

const vendorOptions = [
  { label: '海康', value: 'hikvision' },
  { label: '大华', value: 'dahua' },
];

const selectOptions = computed(() => {
  const opts = nvrList.value.map((n) => ({
    label: `${n.name || n.ip}:${n.port ?? 80}（${n.camera_count ?? 0} 路）`,
    value: n.id as number,
  }));
  return [{ label: '+ 新建 NVR', value: NEW_NVR_KEY }, ...opts];
});

function filterNvr(input: string, option: { label?: string }) {
  return (option?.label ?? '').toLowerCase().includes(input.toLowerCase());
}

async function loadNvrs() {
  try {
    const res = await getNvrList(false);
    const list = Array.isArray(res) ? res : (res as { data?: NvrInfo[] })?.data ?? [];
    nvrList.value = list;
  } catch {
    nvrList.value = [];
  }
}

function syncFromProps() {
  const hasNvr = !!(props.nvrId || props.nvr?.ip);
  localMount.value = hasNvr;
  localChannel.value = props.nvrChannel && props.nvrChannel > 0 ? props.nvrChannel : undefined;
  if (props.nvrId) {
    selectValue.value = props.nvrId;
  } else if (props.nvr?.ip) {
    selectValue.value = NEW_NVR_KEY;
    localNvr.ip = props.nvr.ip || '';
    localNvr.port = props.nvr.port ?? 80;
    localNvr.name = props.nvr.name || '';
    localNvr.vendor = props.nvr.vendor;
    localNvr.rtsp_url = props.nvr.rtsp_url || '';
  } else {
    selectValue.value = undefined;
  }
}

function emitPayload() {
  if (!localMount.value) {
    emit('update:nvrId', null);
    emit('update:nvrChannel', 0);
    emit('update:nvr', null);
    return;
  }
  const ch = localChannel.value ? Number(localChannel.value) : 0;
  emit('update:nvrChannel', ch);
  if (selectValue.value === NEW_NVR_KEY) {
    emit('update:nvrId', undefined);
    emit('update:nvr', {
      ip: localNvr.ip.trim(),
      port: localNvr.port || 80,
      name: localNvr.name || undefined,
      vendor: localNvr.vendor,
      rtsp_url: localNvr.rtsp_url?.trim() || undefined,
    });
  } else if (typeof selectValue.value === 'number') {
    emit('update:nvrId', selectValue.value);
    emit('update:nvr', null);
  }
}

function onMountToggle() {
  if (!localMount.value) {
    selectValue.value = undefined;
    localChannel.value = undefined;
  }
  emitPayload();
}

function onSelectChange() {
  emitPayload();
}

watch([localChannel, () => localNvr.ip, () => localNvr.port, () => localNvr.name, () => localNvr.vendor], () => {
  if (localMount.value) emitPayload();
});

watch(
  () => [props.nvrId, props.nvrChannel, props.nvr],
  () => syncFromProps(),
  { immediate: true, deep: true },
);

onMounted(() => loadNvrs());

defineExpose({ loadNvrs, getPayload: () => {
  if (!localMount.value) return { nvr_id: null, nvr_channel: 0 };
  const ch = localChannel.value ? Number(localChannel.value) : 0;
  if (selectValue.value === NEW_NVR_KEY) {
    return {
      nvr_channel: ch,
      nvr: {
        ip: localNvr.ip.trim(),
        port: localNvr.port || 80,
        name: localNvr.name || undefined,
        vendor: localNvr.vendor,
      },
    };
  }
  if (typeof selectValue.value === 'number') {
    return { nvr_id: selectValue.value, nvr_channel: ch };
  }
  return { nvr_channel: ch };
}});
</script>

<style lang="less" scoped>
.nvr-mount-fields {
  .mount-hint {
    margin-left: 8px;
    color: #888;
    font-size: 12px;
  }
}
</style>

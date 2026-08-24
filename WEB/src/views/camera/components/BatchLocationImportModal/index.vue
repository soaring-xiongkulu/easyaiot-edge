<template>
  <BasicModal
    v-bind="$attrs"
    title="批量导入坐标"
    :width="720"
    @register="register"
    @ok="handleSubmit"
  >
    <Alert
      type="info"
      show-icon
      message="CSV 格式：device_id,longitude,latitude,address,altitude,heading（首行可为表头）"
      style="margin-bottom: 12px"
    />
    <a-upload-dragger
      :before-upload="beforeUpload"
      :show-upload-list="false"
      accept=".csv,.txt"
    >
      <p class="ant-upload-drag-icon">
        <InboxOutlined />
      </p>
      <p class="ant-upload-text">点击或拖拽 CSV 文件到此处</p>
    </a-upload-dragger>
    <Divider plain>或粘贴 CSV 内容</Divider>
    <a-textarea
      v-model:value="csvText"
      :rows="10"
      placeholder="device_id,longitude,latitude,address,heading&#10;cam001,114.057868,22.543099,深圳市南山区,90"
    />
    <div v-if="previewRows.length" class="batch-location-import__preview">
      <Divider plain>预览（前 5 条）</Divider>
      <a-table
        size="small"
        :pagination="false"
        :columns="previewColumns"
        :data-source="previewRows.slice(0, 5)"
        row-key="device_id"
      />
      <div class="batch-location-import__count">共解析 {{ previewRows.length }} 条</div>
    </div>
    <div v-if="lastResult" class="batch-location-import__result">
      <Alert
        :type="lastResult.errors.length ? 'warning' : 'success'"
        show-icon
        :message="`成功 ${lastResult.updated} 条，失败 ${lastResult.errors.length} 条`"
      />
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { Alert, Divider, Upload } from 'ant-design-vue';
import { InboxOutlined } from '@ant-design/icons-vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import {
  batchUpdateDeviceLocations,
  type BatchLocationItem,
  type BatchLocationResult,
} from '@/api/device/camera';

defineOptions({ name: 'BatchLocationImportModal' });

const emit = defineEmits<{ success: [] }>();

const AUploadDragger = Upload.Dragger;
const { createMessage } = useMessage();
const csvText = ref('');
const submitting = ref(false);
const lastResult = ref<BatchLocationResult | null>(null);

const previewColumns = [
  { title: 'device_id', dataIndex: 'device_id', width: 140 },
  { title: '经度', dataIndex: 'longitude', width: 120 },
  { title: '纬度', dataIndex: 'latitude', width: 120 },
  { title: '地址', dataIndex: 'address', ellipsis: true },
  { title: '朝向', dataIndex: 'heading', width: 70 },
];

const previewRows = computed(() => parseCsv(csvText.value));

const [register, { closeModal, setModalProps }] = useModalInner(() => {
  csvText.value = '';
  lastResult.value = null;
  setModalProps({ confirmLoading: false });
});

function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (ch === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
      continue;
    }
    current += ch;
  }
  result.push(current.trim());
  return result;
}

function parseCsv(text: string): BatchLocationItem[] {
  const lines = text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (!lines.length) return [];

  const rows: BatchLocationItem[] = [];
  for (let i = 0; i < lines.length; i += 1) {
    const cols = parseCsvLine(lines[i]);
    if (!cols.length) continue;
    const maybeHeader = i === 0 && /device|id|经|纬|longitude|latitude/i.test(cols.join(','));
    if (maybeHeader) continue;

    const device_id = cols[0];
    const longitude = Number(cols[1]);
    const latitude = Number(cols[2]);
    if (!device_id || Number.isNaN(longitude) || Number.isNaN(latitude)) continue;

    rows.push({
      device_id,
      longitude,
      latitude,
      address: cols[3] || null,
      altitude: cols[4] != null && cols[4] !== '' ? Number(cols[4]) : null,
      heading: cols[5] != null && cols[5] !== '' ? Number(cols[5]) : null,
    });
  }
  return rows;
}

function beforeUpload(file: File) {
  const reader = new FileReader();
  reader.onload = () => {
    csvText.value = String(reader.result || '');
  };
  reader.readAsText(file);
  return false;
}

async function handleSubmit() {
  const items = parseCsv(csvText.value);
  if (!items.length) {
    createMessage.warning('请提供有效的 CSV 数据');
    return;
  }
  submitting.value = true;
  setModalProps({ confirmLoading: true });
  try {
    const res = await batchUpdateDeviceLocations(items) as BatchLocationResult | { data?: BatchLocationResult };
    const result = (res as { data?: BatchLocationResult })?.data ?? (res as BatchLocationResult);
    lastResult.value = result;
    if (result.updated > 0) {
      createMessage.success(`已成功导入 ${result.updated} 条坐标`);
      emit('success');
      if (!result.errors?.length) {
        closeModal();
      }
    } else {
      createMessage.error('导入失败，请检查 CSV 内容与 device_id');
    }
  } catch (e: unknown) {
    createMessage.error(e instanceof Error ? e.message : '导入失败');
  } finally {
    submitting.value = false;
    setModalProps({ confirmLoading: false });
  }
}
</script>

<style scoped lang="less">
.batch-location-import {
  &__preview {
    margin-top: 8px;
  }

  &__count {
    margin-top: 6px;
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
  }

  &__result {
    margin-top: 12px;
  }
}
</style>

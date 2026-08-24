<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="车牌归一化"
    :width="720"
    :ok-text="okButtonText"
    cancel-text="取消"
    :confirm-loading="submitting"
    wrap-class-name="plate-normalize-modal"
    @ok="handleSubmit"
  >
    <div class="normalize-modal">
      <div v-if="library" class="summary-card">
        <div class="summary-title">{{ library.name }}</div>
        <div class="summary-stats">
          <span>当前库内 <strong>{{ libraryStats.plate_count }}</strong> 条车牌记录</span>
        </div>
      </div>

      <a-alert type="info" show-icon :closable="false" class="tip-alert">
        <template #message>做什么？</template>
        <template #description>
          同一车辆可能被录入为多条记录（格式差异或 OCR 误识）。
          归一化按<strong>车牌号相似度</strong>将重复记录合并为一条，保留信息更完整的一条。
        </template>
      </a-alert>

      <div class="threshold-panel">
        <div class="panel-head">
          <span class="panel-title">合并严格度</span>
          <span class="threshold-badge">{{ threshold.toFixed(2) }}</span>
        </div>

        <div class="preset-row">
          <Button
            v-for="preset in THRESHOLD_PRESETS"
            :key="preset.key"
            size="small"
            :type="isActivePreset(preset.value) ? 'primary' : 'default'"
            :ghost="isActivePreset(preset.value)"
            @click="applyPreset(preset.value)"
          >
            {{ preset.label }}
          </Button>
        </div>

        <BasicForm @register="registerForm" />

        <div class="threshold-tip">
          <span class="tip-left">← 更宽松，合并更多</span>
          <span class="tip-right">更严格，仅合并相同车牌 →</span>
        </div>
      </div>

      <div class="result-card" :class="resultCardClass">
        <template v-if="previewLoading">
          <a-spin size="small" />
          <span>正在检测重复车牌…</span>
        </template>
        <template v-else-if="previewCount > 0">
          <CheckCircleOutlined class="result-icon success" />
          <div class="result-body">
            <div class="result-title">
              发现 <strong>{{ previewCount }}</strong> 组重复车牌，约可合并
              <strong>{{ mergeableEntryCount }}</strong> 条记录
            </div>
            <div class="result-desc">点击下方「{{ okButtonText }}」即可自动整理，操作前会再次确认。</div>
          </div>
        </template>
        <template v-else>
          <InfoCircleOutlined class="result-icon muted" />
          <div class="result-body">
            <div class="result-title">当前设置下未发现可合并的重复车牌</div>
            <div class="result-desc">
              可尝试点击「标准」或「宽松」降低严格度；严格度为 1.00 时仅合并规范化后完全相同的车牌号。
            </div>
            <Button size="small" type="link" class="try-loose-btn" @click="applyPreset(0.88)">
              一键设为标准模式
            </Button>
          </div>
        </template>
      </div>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Modal } from 'ant-design-vue';
import { CheckCircleOutlined, InfoCircleOutlined } from '@ant-design/icons-vue';
import { useDebounceFn } from '@vueuse/core';
import { BasicModal, useModalInner } from '@/components/Modal';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button'
import {
getPlateLibrary,
  mergeAllPlateNormalizeGroups,
  parsePlateApiError,
  previewPlateNormalizeGroups,
  type PlateLibrary,
  type PlateNormalizeGroup,
} from '@/api/device/plate_library';

defineOptions({ name: 'PlateNormalizeModal' });

const DEFAULT_THRESHOLD = 1;

const THRESHOLD_PRESETS = [
  { key: 'loose', label: '宽松', value: 0.85 },
  { key: 'normal', label: '标准', value: 0.9 },
  { key: 'recommend', label: '推荐', value: 0.95 },
  { key: 'strict', label: '精确', value: 1 },
];

const emit = defineEmits(['success', 'register']);
const { createMessage } = useMessage();

const library = ref<PlateLibrary | null>(null);
const libraryStats = ref({ plate_count: 0 });
const threshold = ref(DEFAULT_THRESHOLD);
const previewGroups = ref<PlateNormalizeGroup[]>([]);
const previewLoading = ref(false);
const submitting = ref(false);

const previewCount = computed(() => previewGroups.value.length);
const mergeableEntryCount = computed(() =>
  previewGroups.value.reduce((sum, group) => {
    const count = group.entry_count ?? group.count ?? 0;
    return sum + Math.max(0, count - 1);
  }, 0),
);

const okButtonText = computed(() => {
  if (previewLoading.value) return '检测中…';
  if (previewCount.value <= 0) return '暂无可合并';
  return `合并 ${previewCount.value} 组重复车牌`;
});

const resultCardClass = computed(() => {
  if (previewLoading.value) return 'is-loading';
  if (previewCount.value > 0) return 'is-ready';
  return 'is-empty';
});

const debouncedLoadPreview = useDebounceFn(loadPreviewCount, 300);

const [registerForm, { setFieldsValue, getFieldsValue }] = useForm({
  labelWidth: 0,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'threshold',
      label: '',
      component: 'Slider',
      required: true,
      colProps: { span: 24 },
      componentProps: {
        min: 0.75,
        max: 1,
        step: 0.01,
        marks: { 0.85: '宽松', 0.95: '推荐', 1: '精确' },
        tooltip: { formatter: (v: number) => v?.toFixed(2) },
        onChange: (value: number) => {
          threshold.value = value;
          debouncedLoadPreview();
        },
      },
    },
  ],
  showActionButtonGroup: false,
});

const [register, { closeModal, setModalProps }] = useModalInner(async (data) => {
  library.value = data?.library || null;
  threshold.value = DEFAULT_THRESHOLD;
  previewGroups.value = [];
  setFieldsValue({ threshold: DEFAULT_THRESHOLD });
  await refreshLibraryStats();
  await loadPreviewCount();
});

watch([previewLoading, previewCount], () => {
  setModalProps({
    okButtonProps: {
      disabled: previewLoading.value || previewCount.value <= 0,
    },
  });
});

function isActivePreset(value: number) {
  return Math.abs(threshold.value - value) < 0.005;
}

function applyPreset(value: number) {
  threshold.value = value;
  setFieldsValue({ threshold: value });
  loadPreviewCount();
}

async function refreshLibraryStats() {
  if (!library.value?.id) return;
  try {
    const res = await getPlateLibrary(library.value.id);
    const lib = res.data;
    if (lib) {
      library.value = { ...library.value, ...lib };
      libraryStats.value = { plate_count: lib.plate_count ?? 0 };
      return;
    }
  } catch {
    /* fallback */
  }
  libraryStats.value = { plate_count: library.value?.plate_count ?? 0 };
}

async function loadPreviewCount() {
  if (!library.value?.id) return;
  const current = getFieldsValue()?.threshold;
  if (typeof current === 'number') {
    threshold.value = current;
  }
  previewLoading.value = true;
  try {
    const res = await previewPlateNormalizeGroups(library.value.id, threshold.value);
    previewGroups.value = res.data || [];
  } catch {
    previewGroups.value = [];
  } finally {
    previewLoading.value = false;
  }
}

function handleSubmit() {
  if (!library.value?.id || previewLoading.value) return;
  if (previewCount.value <= 0) {
    createMessage.info('当前没有可合并的重复车牌，可尝试调低严格度');
    return;
  }

  Modal.confirm({
    title: '确认合并重复车牌？',
    content: `将合并 ${previewCount.value} 组重复记录，约 ${mergeableEntryCount.value} 条冗余记录将被删除，保留每组信息最完整的一条。`,
    okText: '确认合并',
    cancelText: '再想想',
    onOk: runMerge,
  });
}

async function runMerge() {
  if (!library.value?.id) return;

  submitting.value = true;
  setModalProps({ confirmLoading: true });
  try {
    const res = await mergeAllPlateNormalizeGroups(library.value.id, threshold.value);
    const data = res.data;
    createMessage.success(
      res.msg || `整理完成：合并 ${data?.merged_groups ?? 0} 组、删除 ${data?.merged_entries ?? 0} 条重复记录`,
    );
    emit('success');
    closeModal();
  } catch (e: unknown) {
    createMessage.error(parsePlateApiError(e, '归一化失败'));
  } finally {
    submitting.value = false;
    setModalProps({ confirmLoading: false });
  }
}
</script>

<style lang="less" scoped>
.normalize-modal {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 4px 8px 8px;

  .summary-card {
    padding: 14px 16px;
    border: 1px solid #e6f4ff;
    border-radius: 8px;
    background: linear-gradient(135deg, #f0f7ff 0%, #fafcff 100%);

    .summary-title {
      margin-bottom: 4px;
      font-size: 15px;
      font-weight: 600;
      color: rgba(0, 0, 0, 0.88);
    }

    .summary-stats {
      font-size: 13px;
      color: rgba(0, 0, 0, 0.65);

      strong {
        color: #1677ff;
        font-size: 16px;
      }
    }
  }

  .tip-alert {
    margin: 0;

    :deep(.ant-alert-description) {
      line-height: 1.6;
    }
  }

  .threshold-panel {
    padding: 18px 20px 12px;
    border: 1px solid #f0f0f0;
    border-radius: 8px;
    background: #fafafa;

    .panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;

      .panel-title {
        font-size: 14px;
        font-weight: 600;
        color: rgba(0, 0, 0, 0.88);
      }

      .threshold-badge {
        padding: 2px 10px;
        border-radius: 12px;
        background: #1677ff;
        color: #fff;
        font-size: 13px;
        font-weight: 600;
      }
    }

    .preset-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 8px;
    }

    .threshold-tip {
      display: flex;
      justify-content: space-between;
      margin-top: 4px;
      font-size: 12px;
      color: rgba(0, 0, 0, 0.45);
    }
  }

  :deep(.ant-form-item) {
    margin-bottom: 0;
  }

  :deep(.ant-slider-with-marks) {
    margin: 4px 8px 28px;
  }

  .result-card {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 14px 16px;
    border-radius: 8px;
    font-size: 13px;
    line-height: 1.6;

    &.is-loading {
      align-items: center;
      background: #fafafa;
      color: rgba(0, 0, 0, 0.65);
    }

    &.is-ready {
      background: #f6ffed;
      border: 1px solid #b7eb8f;
    }

    &.is-empty {
      background: #fafafa;
      border: 1px solid #f0f0f0;
    }

    .result-icon {
      flex-shrink: 0;
      margin-top: 2px;
      font-size: 18px;

      &.success {
        color: #52c41a;
      }

      &.muted {
        color: rgba(0, 0, 0, 0.45);
      }
    }

    .result-body {
      flex: 1;
      min-width: 0;
    }

    .result-title {
      color: rgba(0, 0, 0, 0.88);
      font-weight: 500;

      strong {
        color: #fa8c16;
      }
    }

    .result-desc {
      margin-top: 4px;
      color: rgba(0, 0, 0, 0.55);
    }

    .try-loose-btn {
      margin-top: 4px;
      padding-left: 0;
    }
  }
}
</style>

<style lang="less">
.plate-normalize-modal {
  .ant-modal-body > .scrollbar {
    padding: 16px 24px 8px !important;
  }

  .ant-modal-footer {
    padding: 12px 24px 16px !important;
    border-top: 1px solid #f0f0f0;
  }
}
</style>

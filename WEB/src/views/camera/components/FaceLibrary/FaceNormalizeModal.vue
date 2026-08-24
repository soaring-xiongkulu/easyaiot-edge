<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="人脸归一化"
    :width="720"
    :ok-text="okButtonText"
    cancel-text="取消"
    :confirm-loading="submitting"
    wrap-class-name="face-normalize-modal"
    @ok="handleSubmit"
  >
    <div class="normalize-modal">
      <div v-if="library" class="summary-card">
        <div class="summary-title">{{ library.name }}</div>
        <div class="summary-stats">
          <span><strong>{{ libraryStats.person_count }}</strong> 人</span>
          <span class="dot">·</span>
          <span><strong>{{ libraryStats.face_count }}</strong> 张照片</span>
        </div>
      </div>

      <a-alert
        type="info"
        show-icon
        :closable="false"
        class="tip-alert"
      >
        <template #message>做什么？</template>
        <template #description>
          录入时同一人可能被拆成多条人员记录。归一化会把<strong>同一个人的多条记录合并为一条</strong>，照片全部保留，不会删除。
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
          <span class="tip-right">更严格，只合并极相似 →</span>
        </div>
      </div>

      <div class="result-card" :class="resultCardClass">
        <template v-if="previewLoading">
          <a-spin size="small" />
          <span>正在检测是否有重复人员…</span>
        </template>
        <template v-else-if="previewCount > 0">
          <CheckCircleOutlined class="result-icon success" />
          <div class="result-body">
            <div class="result-title">
              发现 <strong>{{ previewCount }}</strong> 组重复人员，约可合并
              <strong>{{ mergeablePersonCount }}</strong> 条记录
            </div>
            <div class="result-desc">点击下方「{{ okButtonText }}」即可自动整理，操作前会再次确认。</div>
          </div>
        </template>
        <template v-else>
          <InfoCircleOutlined class="result-icon muted" />
          <div class="result-body">
            <div class="result-title">当前设置下未发现可合并的重复人员</div>
            <div class="result-desc">
              可尝试点击上方「宽松」降低严格度；若仍无结果，说明人员档案可能已整理完毕。
            </div>
            <Button size="small" type="link" class="try-loose-btn" @click="applyPreset(0.45)">
              一键设为宽松模式
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
  getFaceLibrary,
  mergeAllFaceNormalizeGroups,
  previewFaceNormalizeGroups,
  unwrapFaceApiEntity,
  type FaceLibrary,
  type FaceNormalizeGroup,
} from '@/api/device/face_library';

defineOptions({ name: 'FaceNormalizeModal' });

const DEFAULT_THRESHOLD = 0.55;

const THRESHOLD_PRESETS = [
  { key: 'loose', label: '宽松', value: 0.45 },
  { key: 'recommend', label: '推荐', value: 0.55 },
  { key: 'normal', label: '标准', value: 0.65 },
  { key: 'strict', label: '严格', value: 0.75 },
];

const emit = defineEmits(['success', 'register']);
const { createMessage } = useMessage();

const library = ref<FaceLibrary | null>(null);
const libraryStats = ref({ person_count: 0, face_count: 0 });
const threshold = ref(DEFAULT_THRESHOLD);
const previewGroups = ref<FaceNormalizeGroup[]>([]);
const previewLoading = ref(false);
const submitting = ref(false);

const previewCount = computed(() => previewGroups.value.length);
const mergeablePersonCount = computed(() =>
  previewGroups.value.reduce((sum, group) => {
    const count = group.person_count ?? group.persons?.length ?? 0;
    return sum + Math.max(0, count - 1);
  }, 0),
);

const okButtonText = computed(() => {
  if (previewLoading.value) return '检测中…';
  if (previewCount.value <= 0) return '暂无可合并';
  return `合并 ${previewCount.value} 组重复人员`;
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
        min: 0.3,
        max: 0.95,
        step: 0.01,
        marks: { 0.5: '0.50', 0.55: '推荐', 0.7: '0.70' },
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
    const res = await getFaceLibrary(library.value.id);
    const lib = unwrapFaceApiEntity(res);
    if (lib) {
      library.value = { ...library.value, ...lib };
      libraryStats.value = {
        person_count: lib.person_count ?? 0,
        face_count: lib.face_count ?? 0,
      };
      return;
    }
  } catch {
    /* fallback below */
  }
  libraryStats.value = {
    person_count: library.value?.person_count ?? 0,
    face_count: library.value?.face_count ?? 0,
  };
}

async function loadPreviewCount() {
  if (!library.value?.id) return;
  const current = getFieldsValue()?.threshold;
  if (typeof current === 'number') {
    threshold.value = current;
  }
  previewLoading.value = true;
  try {
    const res = await previewFaceNormalizeGroups(library.value.id, threshold.value);
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
    createMessage.info('当前没有可合并的重复人员，可尝试调低严格度');
    return;
  }

  Modal.confirm({
    title: '确认合并重复人员？',
    content: `将合并 ${previewCount.value} 组重复记录，约 ${mergeablePersonCount.value} 条人员档案归入同一人。所有人脸照片都会保留。`,
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
    const res = await mergeAllFaceNormalizeGroups(library.value.id, threshold.value);
    const data = res.data;
    createMessage.success(
      res.msg || `整理完成：合并 ${data?.merged_groups ?? 0} 组、${data?.merged_persons ?? 0} 人`,
    );
    emit('success');
    closeModal();
  } catch (e: any) {
    createMessage.error(e?.message || '归一化失败');
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

      .dot {
        margin: 0 8px;
        color: rgba(0, 0, 0, 0.25);
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
.face-normalize-modal {
  .ant-modal-body > .scrollbar {
    padding: 16px 24px 8px !important;
  }

  .ant-modal-footer {
    padding: 12px 24px 16px !important;
    border-top: 1px solid #f0f0f0;
  }
}
</style>

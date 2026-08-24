<template>
  <div class="sam-workbench model-workbench">
    <div v-if="!modelReady" class="sam-setup-wrap">
      <SamModelSetupPanel />
    </div>

    <div v-else class="main-content">
      <div class="left-panel" :class="{ collapsed: leftPanelCollapsed }">
        <div class="left-panel-body">
          <div class="config-section">
            <div class="section-title">
              <ExperimentOutlined class="icon" />
              <span>分析类型</span>
            </div>
            <div class="config-options">
              <div class="input-group">
                <select class="select-field" disabled>
                  <option>SAM3 万物识别</option>
                </select>
              </div>
            </div>
          </div>

          <div class="config-section">
            <div class="section-title">
              <TagsOutlined class="icon" />
              <span>文本类别</span>
              <BasicHelp class="section-help" placement="top" text="输入英文类别后回车添加，支持多个类别同时识别" />
            </div>
            <div class="config-options">
              <Select
                v-model:value="textPrompts"
                mode="tags"
                :token-separators="[',', '，']"
                placeholder="输入后回车，如 person、car"
                :options="presetPromptOptions"
                class="class-select"
                allow-clear
              />
            </div>
          </div>

          <div class="config-section">
            <div class="section-title">
              <ExperimentOutlined class="icon" />
              <span>检测置信度</span>
            </div>
            <div class="config-options">
              <InputNumber
                v-model:value="conf"
                class="detect-conf-input"
                :min="0.1"
                :max="0.9"
                :step="0.05"
              />
            </div>
          </div>

          <div class="config-section">
            <div class="section-title">
              <UploadOutlined class="icon" />
              <span>输入源选择</span>
            </div>
            <div class="config-options">
              <div class="source-content">
                <div class="file-upload-wrapper">
                  <input
                    id="sam-image-upload-input"
                    ref="imageInput"
                    type="file"
                    class="file-input"
                    accept="image/*"
                    @change="handleImageUpload"
                  />
                  <label for="sam-image-upload-input" class="file-upload-label">
                    <PictureOutlined class="icon" />
                    <span>{{ uploadedImageFile ? uploadedImageFile.name : '选择图片文件' }}</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="config-section config-section--footer">
          <div class="section-title">
            <ControlOutlined class="icon" />
            <span>控制操作</span>
          </div>
          <div class="config-options">
            <div class="button-group">
              <button class="btn btn-primary" :disabled="!canRun" @click="runPredict">
                <PlayCircleOutlined class="icon" />
                <span>{{ loading ? '推理中...' : '开始检测' }}</span>
              </button>
              <button class="btn btn-white" @click="showOriginal = !showOriginal">
                <EyeOutlined v-if="!showOriginal" class="icon" />
                <CloseOutlined v-else class="icon" />
                <span>{{ showOriginal ? '关闭对照' : '显示对照' }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <div class="panel-toggle" :class="{ collapsed: leftPanelCollapsed }" @click="toggleLeftPanel">
        <LeftOutlined v-if="!leftPanelCollapsed" class="icon" />
        <RightOutlined v-else class="icon" />
      </div>

      <div class="video-area">
        <div class="video-container">
          <div v-if="showOriginal" class="dual-video">
            <div class="video-wrapper">
              <div class="video-title"><span>原始输入源</span></div>
              <div class="video-content">
                <div v-if="uploadedImage" class="image-preview">
                  <img :src="uploadedImage" alt="原始图片" class="preview-image" />
                </div>
                <div v-else class="video-placeholder">
                  <PictureOutlined class="icon" />
                  <span>等待图片上传</span>
                </div>
              </div>
            </div>
            <div class="video-wrapper">
              <div class="video-title"><span>检测结果</span></div>
              <div class="video-content video-content-scrollable">
                <SamResultPanel :loading="loading" :result="result" />
              </div>
            </div>
          </div>
          <div v-else class="single-video">
            <div class="video-wrapper">
              <div class="video-title"><span>检测结果</span></div>
              <div class="video-content video-content-scrollable">
                <SamResultPanel :loading="loading" :result="result" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';
import { InputNumber, Select } from 'ant-design-vue';
import {
  CloseOutlined,
  ControlOutlined,
  ExperimentOutlined,
  EyeOutlined,
  LeftOutlined,
  PictureOutlined,
  PlayCircleOutlined,
  RightOutlined,
  TagsOutlined,
  UploadOutlined,
} from '@ant-design/icons-vue';
import { BasicHelp } from '@/components/Basic';
import SamModelSetupPanel from '@/views/dataset/components/AutoLabel/SamModelSetupPanel/index.vue';
import { useSamModelSetup } from '@/views/dataset/components/AutoLabel/useSamModelSetup';
import { samPredictFile, type SamPredictResult } from '@/api/device/sam';
import { useMessage } from '@/hooks/web/useMessage';
import SamResultPanel from './SamResultPanel.vue';

defineOptions({ name: 'SamInferencePage' });

const { createMessage } = useMessage();
const { modelReady, refreshModelStatus } = useSamModelSetup();

const textPrompts = ref<string[]>([]);
const conf = ref(0.45);
const uploadedImageFile = ref<File | null>(null);
const uploadedImage = ref<string | null>(null);
const imageInput = ref<HTMLInputElement>();
const loading = ref(false);
const result = ref<SamPredictResult | null>(null);
const showOriginal = ref(true);
const leftPanelCollapsed = ref(false);

const presetPromptOptions = [
  { label: 'person', value: 'person' },
  { label: 'car', value: 'car' },
  { label: 'fire', value: 'fire' },
  { label: 'helmet', value: 'helmet' },
  { label: 'dog', value: 'dog' },
  { label: 'bicycle', value: 'bicycle' },
];

const canRun = computed(
  () => !!uploadedImageFile.value && textPrompts.value.length > 0 && !loading.value,
);

onMounted(() => {
  refreshModelStatus();
});

function toggleLeftPanel() {
  leftPanelCollapsed.value = !leftPanelCollapsed.value;
}

function handleImageUpload(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) return;
  if (!file.type.startsWith('image/')) {
    createMessage.warning('请选择有效的图片文件');
    target.value = '';
    return;
  }
  if (file.size > 10 * 1024 * 1024) {
    createMessage.warning('图片不能超过 10MB');
    target.value = '';
    return;
  }
  uploadedImageFile.value = file;
  const reader = new FileReader();
  reader.onload = (e) => {
    uploadedImage.value = e.target?.result as string;
    result.value = null;
  };
  reader.readAsDataURL(file);
}

async function runPredict() {
  if (!uploadedImageFile.value || !textPrompts.value.length) return;
  loading.value = true;
  result.value = null;
  try {
    const data = await samPredictFile(uploadedImageFile.value, {
      text: textPrompts.value,
      return_masks: true,
      conf: conf.value,
    });
    result.value = data as SamPredictResult;
    if (!result.value?.predictions?.length) {
      createMessage.info('未检测到匹配目标，可尝试降低置信度或调整类别词');
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : '识别失败';
    createMessage.error(msg);
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped lang="less">
@primary-color: #2C3E50;
@accent-color: #495057;
@light-bg: #F8F9FA;
@light-text: #212529;
@text-secondary: #6C757D;
@text-muted: #868E96;
@gray-color: #ADB5BD;
@border-color: #DEE2E6;
@border-hover: #CED4DA;
@sidebar-width: 320px;
@panel-transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
@shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
@shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
@shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);

.sam-workbench {
  height: 100%;
  min-height: 480px;
  max-height: 100%;
}

.sam-setup-wrap {
  padding: 16px;
  height: 100%;
  overflow: auto;
}

.main-content {
  display: flex;
  flex: 1;
  overflow: hidden;
  position: relative;
  min-width: 0;
  height: 100%;
}

.left-panel {
  width: @sidebar-width;
  min-width: @sidebar-width;
  max-width: @sidebar-width;
  display: flex;
  flex-direction: column;
  background: #fff;
  overflow: hidden;
  transition: @panel-transition;
  flex-shrink: 0;
  height: 100%;
  position: relative;

  &::after {
    content: '';
    position: absolute;
    right: 0;
    top: 0;
    bottom: 0;
    width: 1px;
    background: linear-gradient(
      to bottom,
      rgba(0, 0, 0, 0) 0%,
      rgba(0, 0, 0, 0.2) 20%,
      rgba(0, 0, 0, 0.3) 50%,
      rgba(0, 0, 0, 0.2) 80%,
      rgba(0, 0, 0, 0) 100%
    );
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.1), -2px 0 8px rgba(0, 0, 0, 0.05);
  }

  &.collapsed {
    width: 0;
    min-width: 0;
    max-width: 0;
    overflow: hidden;
  }

  .left-panel-body {
    flex: 1;
    min-height: 0;
    overflow-x: hidden;
    overflow-y: auto;
    padding-bottom: 4px;
  }
}

.config-section {
  padding: 10px 16px 12px;
  border-bottom: 1px solid fade(@border-color, 65%);
  display: flex;
  flex-direction: column;

  &--footer {
    flex-shrink: 0;
    border-bottom: none;
    border-top: 1px solid @border-color;
    padding: 12px 16px 14px;
    background: #fff;
    box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.04);
    z-index: 1;
  }

  .section-title {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
    font-weight: 600;
    font-size: 14px;
    color: @light-text;

    .icon {
      font-size: 18px;
      color: @primary-color;
    }

    .section-help {
      margin-left: 4px;
      color: @text-secondary;
      font-size: 14px;
    }
  }

  .config-options {
    display: flex;
    flex-direction: column;
    gap: 8px;

    .detect-conf-input {
      width: 100%;

      :deep(.ant-input-number) {
        width: 100%;
        border-radius: 6px;
      }

      :deep(.ant-input-number-input) {
        height: 36px;
      }
    }

    .class-select {
      width: 100%;

      :deep(.ant-select-selector) {
        min-height: 38px !important;
        border-radius: 6px !important;
        border-color: @border-color !important;
        box-shadow: @shadow-sm;
        padding-top: 2px;
        padding-bottom: 2px;
      }

      :deep(.ant-select:hover .ant-select-selector) {
        border-color: @border-hover !important;
      }

      :deep(.ant-select-focused .ant-select-selector) {
        border-color: @primary-color !important;
        box-shadow: 0 0 0 3px rgba(44, 62, 80, 0.1), @shadow-sm !important;
      }
    }

    .input-group {
      display: flex;
      flex-direction: column;
      gap: 5px;
    }

    .select-field {
      padding: 11px 14px;
      border: 1px solid @border-color;
      border-radius: 6px;
      background: #fff;
      width: 100%;
      font-size: 14px;
      color: @light-text;
      box-shadow: @shadow-sm;
      cursor: pointer;

      &:disabled {
        background: @light-bg;
        color: @text-secondary;
        cursor: not-allowed;
      }
    }

    .checkbox-group {
      display: flex;
      align-items: center;
      gap: 8px;

      input[type='checkbox'] {
        width: 16px;
        height: 16px;
      }

      label {
        font-size: 14px;
        color: @light-text;
      }
    }

    .source-content {
      display: flex;
      flex-direction: column;
      gap: 12px;

      .file-upload-wrapper {
        position: relative;
        width: 100%;

        .file-input {
          position: absolute;
          width: 0;
          height: 0;
          opacity: 0;
          overflow: hidden;
          z-index: -1;
        }

        .file-upload-label {
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 8px;
          padding: 12px 20px;
          border: 1px solid @border-color;
          border-radius: 6px;
          background: #fff;
          cursor: pointer;
          transition: all 0.2s ease;
          font-size: 14px;
          color: @light-text;
          font-weight: 500;
          min-height: 44px;
          box-shadow: @shadow-sm;

          .icon {
            font-size: 16px;
            color: @text-secondary;
            flex-shrink: 0;
          }

          span {
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          &:hover {
            border-color: @primary-color;
            background: @light-bg;
            box-shadow: @shadow-md;
          }
        }
      }
    }

    .button-group {
      display: flex;
      flex-direction: column;
      gap: 12px;

      .btn {
        padding: 11px 20px;
        border: 1px solid @border-color;
        border-radius: 6px;
        background: #fff;
        cursor: pointer;
        transition: all 0.2s ease;
        font-size: 14px;
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        font-weight: 500;
        box-shadow: @shadow-sm;

        .icon {
          font-size: 16px;
        }

        &-primary {
          background: @primary-color;
          color: #fff;
          border-color: @primary-color;

          &:disabled {
            opacity: 0.6;
            cursor: not-allowed;
          }
        }

        &-white {
          background: #fff;
          color: @light-text;
          border-color: @border-color;

          &:hover {
            background: @light-bg;
            border-color: @border-hover;
          }
        }
      }
    }
  }
}

.panel-toggle {
  position: absolute;
  top: 50%;
  left: @sidebar-width;
  transform: translateY(-50%) translateX(-50%);
  background: #fff;
  color: @accent-color;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 100;
  border: 1px solid @border-color;
  box-shadow: @shadow-md;
  transition: @panel-transition;

  &.collapsed {
    left: 0;
  }

  .icon {
    font-size: 16px;
    font-weight: 500;
  }
}

.video-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: @light-bg;
  position: relative;
  overflow: hidden;
  min-width: 0;
  height: 100%;

  .video-container {
    display: flex;
    flex-direction: column;
    height: 100%;
    width: 100%;
    padding: 12px;
    overflow: hidden;
    box-sizing: border-box;
  }

  .dual-video {
    display: flex;
    gap: 16px;
    height: 100%;
    width: 100%;
    min-width: 0;
    overflow: hidden;
    align-items: stretch;

    .video-wrapper {
      flex: 1;
      min-width: 0;
      min-height: 0;
    }
  }

  .single-video {
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .video-wrapper {
    display: flex;
    flex-direction: column;
    border-radius: 12px;
    overflow: hidden;
    position: relative;
    flex: 1;
    min-height: 0;
    background: #fff;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08), 0 2px 8px rgba(0, 0, 0, 0.05);

    .video-title {
      padding: 16px 20px;
      background: @light-bg;
      border-bottom: 1px solid @border-color;
      font-weight: 600;
      color: @light-text;
      font-size: 16px;
    }

    .video-content {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: #fff;
      position: relative;
      overflow: hidden;
      min-height: 0;
      width: 100%;

      &.video-content-scrollable {
        align-items: flex-start;
        overflow-y: auto;
        overflow-x: hidden;
      }

      .image-preview {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: flex-start;
        justify-content: center;
        overflow: hidden;

        .preview-image {
          max-width: 100%;
          max-height: 100%;
          width: auto;
          height: auto;
          object-fit: contain;
          display: block;
        }
      }

      .video-placeholder {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 20px;
        color: @text-secondary;
        width: 100%;
        min-height: 200px;

        .icon {
          font-size: 64px;
          color: @gray-color;
          opacity: 0.5;
        }

        span {
          font-size: 16px;
          color: @text-secondary;
          font-weight: 500;
        }
      }
    }
  }
}
</style>

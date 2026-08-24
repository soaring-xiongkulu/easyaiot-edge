<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="JSON 编辑设备目录"
    :width="920"
    :min-height="520"
    ok-text="同步"
    :loading="loading"
    loading-tip="正在加载目录结构..."
    @ok="handleApply"
  >
    <div class="json-modal-body">
      <a-alert
        type="info"
        show-icon
        class="format-hint"
        message="格式说明"
        description="根节点为目录数组，与「默认分组」同级（JSON 中不写默认分组）。每项含 name、devices、children。未写入 JSON 的设备仍留在默认分组。"
      />

      <div class="camera-picker">
        <span class="picker-label">摄像头</span>
        <a-select
          v-model:value="selectedCameraIds"
          mode="multiple"
          show-search
          allow-clear
          :options="cameraOptions"
          :loading="loading"
          :disabled="loading"
          placeholder="搜索并多选摄像头，复制 ID 粘贴到 JSON 的 devices 中"
          option-filter-prop="label"
          class="camera-select"
          :max-tag-count="2"
        />
        <Button
          preIcon="tdesign:copy-filled"
          :disabled="!selectedCameraIds.length"
          @click="handleCopyCameraIds"
        >
          复制 ID
        </Button>
      </div>

      <div class="toolbar">
        <Space wrap :size="8">
          <Button preIcon="ant-design:undo-outlined" :disabled="loading" @click="handleReset">
            重置
          </Button>

          <a-dropdown :trigger="['click']">
            <Button preIcon="ant-design:file-text-outlined" postIcon="ant-design:down-outlined" :disabled="loading">
              使用模板
            </Button>
            <template #overlay>
              <a-menu class="template-menu" @click="handleUseTemplate">
                <a-menu-item-group title="内置样例">
                  <a-menu-item v-for="sample in DIRECTORY_JSON_SAMPLES" :key="sample.key">
                    <div class="menu-item-title">{{ sample.label }}</div>
                    <div class="menu-item-desc">{{ sample.hint }}</div>
                  </a-menu-item>
                </a-menu-item-group>
                <a-menu-item-group v-if="customTemplates.length" title="我的模板">
                  <a-menu-item v-for="t in customTemplates" :key="t.key">
                    <div class="menu-item-row">
                      <div>
                        <div class="menu-item-title">{{ t.label }}</div>
                        <div v-if="t.hint" class="menu-item-desc">{{ t.hint }}</div>
                      </div>
                      <a-typography-link type="danger" @click.stop="handleRemoveTemplate(t.key)">
                        删除
                      </a-typography-link>
                    </div>
                  </a-menu-item>
                </a-menu-item-group>
                <a-menu-item v-if="!customTemplates.length" disabled key="empty-custom">
                  暂无自定义模板
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>

          <a-upload
            :before-upload="handleImportTemplate"
            :show-upload-list="false"
            accept="application/json,.json"
          >
            <Button preIcon="ant-design:import-outlined" :disabled="loading">
              导入模板
            </Button>
          </a-upload>

          <Button preIcon="ant-design:plus-outlined" :disabled="loading" @click="openSaveTemplateModal">
            添加为模板
          </Button>
        </Space>
      </div>

      <p v-if="activeSampleHint" class="sample-hint">{{ activeSampleHint }}</p>

      <a-spin :spinning="loading" tip="正在加载目录结构...">
        <a-textarea
          v-model:value="jsonText"
          class="json-textarea"
          placeholder='[{"name":"一楼","devices":["设备ID"]}]'
          :disabled="loading"
        />
      </a-spin>
    </div>

    <a-modal
      v-model:open="saveTemplateVisible"
      title="添加为模板"
      ok-text="保存"
      cancel-text="取消"
      :confirm-loading="saveTemplateLoading"
      @ok="confirmSaveTemplate"
    >
      <a-form layout="vertical">
        <a-form-item label="模板名称" required>
          <a-input
            v-model:value="templateName"
            placeholder="例如：园区标准目录结构"
            allow-clear
            @press-enter="confirmSaveTemplate"
          />
        </a-form-item>
        <a-form-item label="备注说明（可选）">
          <a-input v-model:value="templateHint" placeholder="简要说明适用场景" allow-clear />
        </a-form-item>
      </a-form>
    </a-modal>
  </BasicModal>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import {
  Alert as AAlert,
  Dropdown as ADropdown,
  Form as AForm,
  FormItem as AFormItem,
  Input as AInput,
  Menu as AMenu,
  MenuItem as AMenuItem,
  MenuItemGroup as AMenuItemGroup,
  Modal as AModal,
  Select as ASelect,
  Space,
  Spin as ASpin,
  Textarea as ATextarea,
  TypographyLink as ATypographyLink,
  Upload as AUpload,
} from 'ant-design-vue';
import type { MenuInfo } from 'ant-design-vue/lib/menu/src/interface';
import { Button } from '@/components/Button';
import { BasicModal, useModalInner } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import {
  applyDirectoryJsonSync,
  DIRECTORY_JSON_SAMPLES,
  fetchDirectoryJsonPayload,
  formatDeviceIdsForCopy,
  loadCustomDirectoryTemplates,
  parseDirectoryJsonText,
  removeCustomDirectoryTemplate,
  saveCustomDirectoryTemplate,
  type CameraSelectOption,
  type DirectoryJsonTemplate,
} from '@/views/camera/utils/directoryJson';

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();
const jsonText = ref('');
const loading = ref(false);
const activeSampleHint = ref('');
const savedSnapshot = ref('');
const customTemplates = ref<DirectoryJsonTemplate[]>([]);
const cameraOptions = ref<CameraSelectOption[]>([]);
const selectedCameraIds = ref<string[]>([]);

const saveTemplateVisible = ref(false);
const saveTemplateLoading = ref(false);
const templateName = ref('');
const templateHint = ref('');

const templateMap = () => {
  const map = new Map<string, DirectoryJsonTemplate>();
  DIRECTORY_JSON_SAMPLES.forEach((t) => map.set(t.key, t));
  customTemplates.value.forEach((t) => map.set(t.key, t));
  return map;
};

function refreshCustomTemplates() {
  customTemplates.value = loadCustomDirectoryTemplates();
}

async function loadCurrentJson() {
  loading.value = true;
  try {
    const payload = await fetchDirectoryJsonPayload();
    jsonText.value = payload.jsonText || '[]';
    cameraOptions.value = payload.cameraOptions;
    savedSnapshot.value = jsonText.value;
    selectedCameraIds.value = [];
  } catch (e: any) {
    console.error(e);
    jsonText.value = '[]';
    createMessage.error(e?.message || '加载当前目录失败');
  } finally {
    loading.value = false;
  }
}

async function initOnOpen() {
  activeSampleHint.value = '';
  savedSnapshot.value = '';
  selectedCameraIds.value = [];
  refreshCustomTemplates();
  await loadCurrentJson();
}

const [register, { setModalProps, closeModal, changeLoading }] = useModalInner(async () => {
  await initOnOpen();
});

function handleReset() {
  if (!savedSnapshot.value) {
    loadCurrentJson();
    return;
  }
  activeSampleHint.value = '';
  jsonText.value = savedSnapshot.value;
  selectedCameraIds.value = [];
  createMessage.success('已重置为打开时的目录结构');
}

function applyTemplate(template: DirectoryJsonTemplate) {
  activeSampleHint.value = `${template.label}：${template.hint || '已载入模板'}`;
  jsonText.value = template.json;
  createMessage.info(`已载入「${template.label}」`);
}

function handleUseTemplate(info: MenuInfo) {
  const key = String(info.key);
  if (key === 'empty-custom') return;
  const template = templateMap().get(key);
  if (template) applyTemplate(template);
}

function handleImportTemplate(file: File) {
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const text = String(reader.result || '');
      parseDirectoryJsonText(text);
      const baseName = file.name.replace(/\.json$/i, '') || '导入模板';
      activeSampleHint.value = `${baseName}：已从文件导入，确认后点「同步」写入系统`;
      jsonText.value = text;
      createMessage.success('模板文件已载入编辑器');
    } catch (e: any) {
      createMessage.error(e?.message || '模板文件格式不正确');
    }
  };
  reader.onerror = () => createMessage.error('读取文件失败');
  reader.readAsText(file);
  return false;
}

async function handleCopyCameraIds() {
  if (!selectedCameraIds.value.length) {
    createMessage.warning('请先选择摄像头');
    return;
  }
  const text = formatDeviceIdsForCopy(selectedCameraIds.value);
  try {
    await navigator.clipboard.writeText(text);
    createMessage.success('已复制设备 ID，可粘贴到 JSON 的 devices 数组中');
  } catch {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
    createMessage.success('已复制设备 ID');
  }
}

function openSaveTemplateModal() {
  if (!jsonText.value?.trim()) {
    createMessage.warning('编辑器内容为空');
    return;
  }
  try {
    parseDirectoryJsonText(jsonText.value);
  } catch (e: any) {
    createMessage.error(e?.message || '当前内容不是合法目录 JSON');
    return;
  }
  templateName.value = '';
  templateHint.value = '';
  saveTemplateVisible.value = true;
}

async function confirmSaveTemplate() {
  const label = templateName.value.trim();
  if (!label) {
    createMessage.warning('请输入模板名称');
    return Promise.reject();
  }
  try {
    saveTemplateLoading.value = true;
    parseDirectoryJsonText(jsonText.value);
    saveCustomDirectoryTemplate({
      key: `custom_${Date.now()}`,
      label,
      hint: templateHint.value.trim() || '用户自定义模板',
      json: jsonText.value,
    });
    refreshCustomTemplates();
    saveTemplateVisible.value = false;
    createMessage.success(`模板「${label}」已保存`);
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
    return Promise.reject();
  } finally {
    saveTemplateLoading.value = false;
  }
}

function handleRemoveTemplate(key: string) {
  removeCustomDirectoryTemplate(key);
  refreshCustomTemplates();
  createMessage.success('已删除模板');
}

async function handleApply() {
  if (!jsonText.value?.trim()) {
    createMessage.warning('请输入或等待当前目录加载完成');
    return;
  }
  try {
    setModalProps({ confirmLoading: true });
    changeLoading(true);
    const tree = parseDirectoryJsonText(jsonText.value);
    await applyDirectoryJsonSync(tree);
    createMessage.success('目录已同步');
    closeModal();
    emit('success');
  } catch (e: any) {
    console.error(e);
    createMessage.error(e?.message || '同步失败');
  } finally {
    setModalProps({ confirmLoading: false });
    changeLoading(false);
  }
}
</script>

<style lang="less" scoped>
.json-modal-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.format-hint {
  margin-bottom: 0;
}

.camera-picker {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;

  .picker-label {
    flex-shrink: 0;
    color: #6b7280;
    font-size: 13px;
  }

  .camera-select {
    flex: 1;
    min-width: 280px;
  }
}

.toolbar {
  :deep(.ant-space) {
    width: 100%;
  }
}

:deep(.template-menu) {
  min-width: 260px;
  max-height: 360px;
  overflow-y: auto;
}

.menu-item-title {
  font-size: 13px;
  line-height: 1.4;
}

.menu-item-desc {
  font-size: 12px;
  color: #8c8c8c;
  line-height: 1.3;
}

.menu-item-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  width: 100%;
}

.sample-hint {
  margin: 0;
  padding: 8px 12px;
  font-size: 13px;
  color: #1677ff;
  background: #e6f4ff;
  border-radius: 4px;
}

.json-textarea {
  min-height: 400px;
  font-family: 'Consolas', 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 13px;
  line-height: 1.55;
  resize: vertical;
}
</style>

<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="modalTitle"
    width="1200"
    placement="right"
    :showFooter="true"
    :showCancelBtn="false"
    :showOkBtn="false"
  >
    <template #footer>
      <div class="footer-buttons">
        <Button @click="closeDrawer">{{ isViewMode ? '关闭' : '取消' }}</Button>
        <Button v-if="!isViewMode" @click="handleReset">重置</Button>
        <Button v-if="!isViewMode" type="primary" :loading="confirmLoading" @click="handleSubmit">
          {{ isEditMode ? '保存修改' : '确认录入' }}
        </Button>
      </div>
    </template>

    <div class="face-entry-drawer">
      <!-- 所属人脸库 -->
      <div v-if="libraryInfo" class="library-banner">
        <div class="banner-icon">
          <TeamOutlined />
        </div>
        <div class="banner-body">
          <span class="banner-label">录入至</span>
          <span class="banner-name">{{ libraryInfo.name }}</span>
          <span v-if="libraryInfo.code" class="banner-meta">{{ libraryInfo.code }}</span>
        </div>
      </div>

      <div class="entry-body">
        <!-- 人脸照片 -->
        <section class="form-section">
          <div class="section-head">
            <CameraOutlined class="section-icon" />
            <span class="section-title">人脸照片</span>
            <a-tag v-if="!isViewMode && !isEditMode" color="error" class="required-tag">必填</a-tag>
            <a-tag v-if="allowMultiUpload && uploadFiles.length" color="processing" class="required-tag">
              已选 {{ uploadFiles.length }} 张
            </a-tag>
          </div>

          <div class="photo-area">
            <input
              ref="fileInputRef"
              type="file"
              class="photo-file-input"
              :multiple="allowMultiUpload"
              accept="image/jpeg,image/png,image/webp"
              @change="onFileInputChange"
            />
            <div
              class="photo-zone"
              :class="{
                'has-image': !!primaryPreviewUrl,
                'is-view': isViewMode,
                'is-dragover': isDragover,
              }"
              @click="triggerFileSelect"
              @dragover.prevent="onDragOver"
              @dragleave.prevent="onDragLeave"
              @drop.prevent="onDrop"
            >
              <template v-if="primaryPreviewUrl">
                <img :src="primaryPreviewUrl" alt="人脸照片" class="photo-preview" />
                <div v-if="!isViewMode" class="photo-mask">
                  <span class="mask-action">
                    <CameraOutlined />
                    {{ allowMultiUpload ? '继续添加' : '更换照片' }}
                  </span>
                </div>
              </template>
              <template v-else-if="!isViewMode">
                <div class="photo-placeholder">
                  <div class="placeholder-icon">
                    <UserOutlined />
                  </div>
                  <p class="placeholder-title">
                    {{ allowMultiUpload ? '批量上传人脸照片' : '上传人脸照片' }}
                  </p>
                  <p class="placeholder-desc">点击选择图片，或拖拽至此处</p>
                  <p class="placeholder-formats">
                    JPG / PNG / WebP · 单张最大 5MB{{ allowMultiUpload ? ' · 可多选' : '' }}
                  </p>
                </div>
              </template>
              <template v-else>
                <div class="photo-placeholder empty">
                  <UserOutlined class="empty-icon" />
                  <span>暂无照片</span>
                </div>
              </template>
            </div>

            <div v-if="allowMultiUpload && previewItems.length > 1" class="photo-thumbs">
              <div v-for="(item, idx) in previewItems" :key="item.key" class="thumb-item">
                <img :src="item.url" alt="" class="thumb-img" />
                <button type="button" class="thumb-remove" @click.stop="removeUploadFile(idx)">×</button>
              </div>
            </div>

            <div v-if="!isViewMode" class="photo-tips">
              <div class="tips-title">
                <InfoCircleOutlined /> 拍摄建议
              </div>
              <ul class="tips-list">
                <li><CheckCircleOutlined class="tip-icon ok" /> 正面免冠，五官清晰可见</li>
                <li><CheckCircleOutlined class="tip-icon ok" /> 光线均匀，避免强逆光或阴影</li>
                <li><CloseCircleOutlined class="tip-icon no" /> 避免遮挡、模糊或侧脸照片</li>
              </ul>
              <p v-if="isEditMode" class="tips-note">不上传新照片则保留原图</p>
            </div>
          </div>
        </section>

        <!-- 基本信息 -->
        <section class="form-section">
          <div class="section-head">
            <IdcardOutlined class="section-icon" />
            <span class="section-title">基本信息</span>
          </div>

          <!-- 查看模式：信息卡片 -->
          <div v-if="isViewMode && recordInfo" class="info-grid">
            <div class="info-item">
              <span class="info-label">姓名</span>
              <span class="info-value">{{ recordInfo.person_name || '-' }}</span>
            </div>
            <div class="info-item">
              <span class="info-label">编号</span>
              <span class="info-value">{{ recordInfo.person_code || '-' }}</span>
            </div>
            <div class="info-item">
              <span class="info-label">状态</span>
              <a-tag :color="recordInfo.is_enabled !== false ? 'success' : 'default'">
                {{ recordInfo.is_enabled !== false ? '启用' : '停用' }}
              </a-tag>
            </div>
            <div class="info-item">
              <span class="info-label">录入时间</span>
              <span class="info-value">{{ recordInfo.created_at || '-' }}</span>
            </div>
            <div v-if="recordInfo.remark" class="info-item full">
              <span class="info-label">备注</span>
              <span class="info-value">{{ recordInfo.remark }}</span>
            </div>
          </div>

          <!-- 编辑 / 录入模式 -->
          <div v-else class="form-wrap">
            <BasicForm @register="registerForm" />
          </div>
        </section>
      </div>
    </div>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import {
  CameraOutlined,
  CheckCircleOutlined,
  CloseCircleOutlined,
  IdcardOutlined,
  InfoCircleOutlined,
  TeamOutlined,
  UserOutlined,
} from '@ant-design/icons-vue';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button'
import {
  addFaceEntriesBatch,
  addFaceEntry,
  isFaceLibraryApiOk,
  parseFaceApiError,
  resolveFaceImageDisplayUrl,
  updateFaceEntry,
  type FaceEntry,
  type FaceLibrary,
  type FacePerson,
} from '@/api/device/face_library';

defineOptions({ name: 'FaceEntryModal' });

const { createMessage } = useMessage();
const emit = defineEmits(['success', 'register']);

const modalData = ref<{
  type?: string;
  library?: FaceLibrary;
  record?: FaceEntry;
  person?: FacePerson;
  addToPerson?: boolean;
}>({});
const confirmLoading = ref(false);
const fileInputRef = ref<HTMLInputElement | null>(null);
const uploadFiles = ref<File[]>([]);
const previewItems = ref<Array<{ key: string; url: string; file?: File }>>([]);
const isDragover = ref(false);

const libraryInfo = computed(() => modalData.value.library ?? null);
const recordInfo = computed(() => modalData.value.record ?? null);

const modalTitle = computed(() => {
  if (modalData.value.type === 'view') return '查看人脸';
  if (modalData.value.type === 'edit') return '编辑人脸';
  if (modalData.value.addToPerson) return '添加人脸照片';
  return '录入人脸';
});

const isAddToPerson = computed(() => !!modalData.value.addToPerson && !!modalData.value.person);

const isViewMode = computed(() => modalData.value.type === 'view');
const isEditMode = computed(() => modalData.value.type === 'edit');
const allowMultiUpload = computed(() => !isViewMode.value && !isEditMode.value);

const primaryPreviewUrl = computed(() => previewItems.value[0]?.url || '');

const [registerForm, { setFieldsValue, validate, resetFields, updateSchema }] = useForm({
  labelWidth: 80,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'person_name',
      label: '姓名',
      component: 'Input',
      required: true,
      colProps: { span: 12 },
      componentProps: {
        placeholder: '请输入姓名',
        maxlength: 50,
        showCount: true,
      },
    },
    {
      field: 'person_code',
      label: '编号',
      component: 'Input',
      colProps: { span: 12 },
      componentProps: {
        placeholder: '工号 / 编号（可选）',
        maxlength: 64,
      },
    },
    {
      field: 'is_enabled',
      label: '状态',
      component: 'Switch',
      colProps: { span: 8 },
      componentProps: {
        checkedChildren: '启用',
        unCheckedChildren: '停用',
      },
      helpMessage: '停用后该人脸不参与算法比对',
    },
    {
      field: 'remark',
      label: '备注',
      component: 'InputTextArea',
      componentProps: {
        placeholder: '补充说明（可选）',
        rows: 3,
        maxlength: 200,
        showCount: true,
      },
    },
  ],
  showActionButtonGroup: false,
});

function setFormDisabled(disabled: boolean) {
  updateSchema([
    { field: 'person_name', componentProps: { disabled } },
    { field: 'person_code', componentProps: { disabled } },
    { field: 'remark', componentProps: { disabled } },
    { field: 'is_enabled', componentProps: { disabled } },
  ]);
}

function revokePreviewItem(item: { url: string }) {
  if (item.url.startsWith('blob:')) {
    URL.revokeObjectURL(item.url);
  }
}

function resetUpload() {
  previewItems.value.forEach(revokePreviewItem);
  uploadFiles.value = [];
  previewItems.value = [];
  if (fileInputRef.value) {
    fileInputRef.value.value = '';
  }
}

function triggerFileSelect() {
  if (isViewMode.value) return;
  fileInputRef.value?.click();
}

function onFileInputChange(e: Event) {
  const input = e.target as HTMLInputElement;
  const files = Array.from(input.files || []);
  input.value = '';
  if (!files.length) return;
  if (!allowMultiUpload.value) {
    validateAndAcceptFile(files[0]);
    return;
  }
  files.forEach(validateAndAcceptFile);
}

function setExistingImage(url?: string) {
  resetUpload();
  const resolved = resolveFaceImageDisplayUrl(url);
  if (resolved) {
    previewItems.value = [{ key: `existing-${resolved}`, url: resolved }];
  }
}

function appendUploadFile(file: File) {
  const url = URL.createObjectURL(file);
  uploadFiles.value = [...uploadFiles.value, file];
  previewItems.value = [
    ...previewItems.value,
    { key: `${file.name}-${file.size}-${Date.now()}`, url, file },
  ];
}

function removeUploadFile(index: number) {
  const item = previewItems.value[index];
  if (item) revokePreviewItem(item);
  previewItems.value = previewItems.value.filter((_, i) => i !== index);
  uploadFiles.value = uploadFiles.value.filter((_, i) => i !== index);
}

const [register, { setDrawerProps, closeDrawer }] = useDrawerInner(async (data) => {
  resetFields();
  resetUpload();
  isDragover.value = false;
  setDrawerProps({ confirmLoading: false });
  confirmLoading.value = false;
  modalData.value = data || {};

  if (data?.record) {
    setFieldsValue({
      person_name: data.record.person_name,
      person_code: data.record.person_code,
      remark: data.record.remark,
      is_enabled: data.record.is_enabled !== false,
    });
    setExistingImage(data.record.image_url);
    setFormDisabled(data.type === 'view');
  } else if (data?.addToPerson && data?.person) {
    setFieldsValue({
      person_name: data.person.person_name,
      person_code: data.person.person_code,
      is_enabled: data.person.is_enabled !== false,
    });
    setFormDisabled(false);
    updateSchema([
      { field: 'person_name', componentProps: { disabled: true } },
      { field: 'person_code', componentProps: { disabled: true } },
    ]);
  } else {
    resetUpload();
    setFieldsValue({ is_enabled: true });
    setFormDisabled(false);
    updateSchema([
      { field: 'person_name', componentProps: { disabled: false } },
      { field: 'person_code', componentProps: { disabled: false } },
    ]);
  }
});

function validateAndAcceptFile(file: File): boolean {
  if (!file.type.startsWith('image/')) {
    createMessage.warning('只能上传图片文件');
    return false;
  }
  if (file.size / 1024 / 1024 >= 5) {
    createMessage.warning('图片大小不能超过 5MB');
    return false;
  }
  if (!allowMultiUpload.value) {
    resetUpload();
  }
  appendUploadFile(file);
  return true;
}

function onDragOver() {
  if (!isViewMode.value) isDragover.value = true;
}

function onDragLeave() {
  isDragover.value = false;
}

function onDrop(e: DragEvent) {
  isDragover.value = false;
  if (isViewMode.value) return;
  const files = Array.from(e.dataTransfer?.files || []).filter((f) => f.type.startsWith('image/'));
  if (!files.length) return;
  if (!allowMultiUpload.value) {
    validateAndAcceptFile(files[0]);
    return;
  }
  files.forEach(validateAndAcceptFile);
}

async function handleSubmit() {
  const libraryId = modalData.value.library?.id;
  if (!libraryId) {
    createMessage.error('未关联人脸库，请关闭后重新打开');
    return;
  }

  try {
    const values = isAddToPerson.value
      ? await validate(['remark', 'is_enabled'])
      : await validate();
    if (!isEditMode.value && !uploadFiles.value.length) {
      createMessage.warning('请上传人脸照片');
      return;
    }

    confirmLoading.value = true;
    setDrawerProps({ confirmLoading: true });

    const fd = new FormData();
    const personName = isAddToPerson.value
      ? String(modalData.value.person?.person_name || '').trim()
      : String(values.person_name || '').trim();
    fd.append('person_name', personName);
    const personCode = isAddToPerson.value
      ? modalData.value.person?.person_code
      : values.person_code;
    if (personCode) fd.append('person_code', String(personCode).trim());
    if (values.remark) fd.append('remark', String(values.remark).trim());
    fd.append('is_enabled', values.is_enabled ? 'true' : 'false');
    if (isAddToPerson.value && modalData.value.person?.id) {
      fd.append('person_id', String(modalData.value.person.id));
    }

    if (isEditMode.value && modalData.value.record) {
      if (uploadFiles.value[0]) {
        fd.append('file', uploadFiles.value[0]);
      }
      const response = await updateFaceEntry(modalData.value.record.id, fd);
      if (isFaceLibraryApiOk(response)) {
        createMessage.success('保存成功');
        closeDrawer();
        emit('success');
      } else {
        createMessage.error(parseFaceApiError(response, '保存失败'));
      }
    } else if (uploadFiles.value.length > 1 || (isAddToPerson.value && uploadFiles.value.length >= 1)) {
      uploadFiles.value.forEach((f) => fd.append('files', f));
      const response = await addFaceEntriesBatch(libraryId, fd);
      if (isFaceLibraryApiOk(response)) {
        const n = (response as { data?: { success_count?: number } }).data?.success_count
          ?? uploadFiles.value.length;
        createMessage.success(
          (response as { msg?: string }).msg || `成功录入 ${n} 张人脸`,
        );
        closeDrawer();
        emit('success');
      } else {
        createMessage.error(parseFaceApiError(response, '录入失败'));
      }
    } else {
      if (uploadFiles.value[0]) {
        fd.append('file', uploadFiles.value[0]);
      }
      const response = await addFaceEntry(libraryId, fd);
      if (isFaceLibraryApiOk(response)) {
        createMessage.success('录入成功');
        closeDrawer();
        emit('success');
      } else {
        createMessage.error(parseFaceApiError(response, '录入失败'));
      }
    }
  } catch (error: unknown) {
    createMessage.error(parseFaceApiError(error, '提交失败'));
  } finally {
    confirmLoading.value = false;
    setDrawerProps({ confirmLoading: false });
  }
}

function handleReset() {
  resetFields();
  if (modalData.value.record) {
    setFieldsValue({
      person_name: modalData.value.record.person_name,
      person_code: modalData.value.record.person_code,
      remark: modalData.value.record.remark,
      is_enabled: modalData.value.record.is_enabled !== false,
    });
    setExistingImage(modalData.value.record.image_url);
  } else {
    resetUpload();
    setFieldsValue({ is_enabled: true });
  }
}
</script>

<style lang="less" scoped>
.face-entry-drawer {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.library-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: linear-gradient(135deg, #f0f5ff 0%, #fafbff 100%);
  border: 1px solid #d6e4ff;
  border-radius: 8px;

  .banner-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 8px;
    background: #266cfb;
    color: #fff;
    font-size: 18px;
    flex-shrink: 0;
  }

  .banner-body {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    min-width: 0;
  }

  .banner-label {
    font-size: 13px;
    color: rgba(0, 0, 0, 0.45);
  }

  .banner-name {
    font-size: 15px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.85);
  }

  .banner-meta {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
    padding: 2px 8px;
    background: rgba(255, 255, 255, 0.7);
    border-radius: 4px;
    border: 1px solid #e8e8e8;
  }
}

.entry-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-section {
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  overflow: hidden;

  .section-head {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    background: #fafafa;
    border-bottom: 1px solid #f0f0f0;

    .section-icon {
      font-size: 15px;
      color: #266cfb;
    }

    .section-title {
      font-size: 14px;
      font-weight: 600;
      color: rgba(0, 0, 0, 0.85);
    }

    .required-tag {
      margin-left: auto;
      font-size: 12px;
      line-height: 18px;
      padding: 0 6px;
    }
  }
}

.photo-area {
  display: flex;
  gap: 20px;
  padding: 20px;

  @media (max-width: 576px) {
    flex-direction: column;
  }
}

.photo-file-input {
  display: none;
}

.photo-zone {
  flex-shrink: 0;
  position: relative;
  width: 200px;
  height: 240px;
  border: 2px dashed #d9d9d9;
  border-radius: 10px;
  overflow: hidden;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s, box-shadow 0.2s;
  background: #fafafa;

  &:hover:not(.is-view) {
    border-color: #266cfb;
    background: #f0f5ff;
  }

  &.is-dragover:not(.is-view) {
    border-color: #266cfb;
    background: #e6f0ff;
    box-shadow: 0 0 0 3px rgba(38, 108, 251, 0.12);
  }

  &.has-image {
    border-style: solid;
    border-color: #e8e8e8;
    background: #f5f5f5;

    &:hover:not(.is-view) .photo-mask {
      opacity: 1;
      pointer-events: auto;
    }
  }

  &.is-view {
    cursor: default;
  }

  .photo-preview {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  .photo-mask {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.45);
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.2s;

    .mask-action {
      display: flex;
      align-items: center;
      gap: 6px;
      color: #fff;
      font-size: 14px;
      padding: 8px 16px;
      border: 1px solid rgba(255, 255, 255, 0.6);
      border-radius: 6px;
      background: rgba(0, 0, 0, 0.2);
    }
  }

  .photo-placeholder {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    padding: 16px;
    text-align: center;

    .placeholder-icon {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 56px;
      height: 56px;
      border-radius: 50%;
      background: #eef3ff;
      color: #266cfb;
      font-size: 26px;
      margin-bottom: 12px;
    }

    .placeholder-title {
      margin: 0 0 4px;
      font-size: 14px;
      font-weight: 500;
      color: rgba(0, 0, 0, 0.85);
    }

    .placeholder-desc {
      margin: 0 0 8px;
      font-size: 12px;
      color: rgba(0, 0, 0, 0.45);
    }

    .placeholder-formats {
      margin: 0;
      font-size: 11px;
      color: rgba(0, 0, 0, 0.25);
    }

    &.empty {
      color: rgba(0, 0, 0, 0.25);
      gap: 8px;

      .empty-icon {
        font-size: 40px;
      }
    }
  }
}

.photo-thumbs {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-content: flex-start;
  max-width: 360px;

  .thumb-item {
    position: relative;
    width: 72px;
    height: 72px;
    border-radius: 6px;
    overflow: hidden;
    border: 1px solid #e8e8e8;

    .thumb-img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }

    .thumb-remove {
      position: absolute;
      top: 2px;
      right: 2px;
      width: 20px;
      height: 20px;
      border: none;
      border-radius: 50%;
      background: rgba(0, 0, 0, 0.55);
      color: #fff;
      font-size: 14px;
      line-height: 1;
      cursor: pointer;
    }
  }
}

.photo-tips {
  flex: 1;
  min-width: 0;
  padding: 14px 16px;
  background: #f6f8fa;
  border-radius: 8px;
  border: 1px solid #eef0f3;

  .tips-title {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 500;
    color: rgba(0, 0, 0, 0.65);
    margin-bottom: 10px;
  }

  .tips-list {
    margin: 0;
    padding: 0;
    list-style: none;

    li {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      color: rgba(0, 0, 0, 0.65);
      line-height: 2;

      .tip-icon {
        font-size: 13px;
        flex-shrink: 0;

        &.ok {
          color: #52c41a;
        }

        &.no {
          color: #ff4d4f;
        }
      }
    }
  }

  .tips-note {
    margin: 10px 0 0;
    padding-top: 10px;
    border-top: 1px dashed #e8e8e8;
    font-size: 12px;
    color: rgba(0, 0, 0, 0.45);
  }
}

.form-wrap {
  padding: 20px 20px 4px;

  :deep(.ant-form-item) {
    margin-bottom: 18px;
  }

  :deep(.ant-form-item-label > label) {
    color: rgba(0, 0, 0, 0.65);
  }
}

.info-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px 24px;
  padding: 20px;

  .info-item {
    display: flex;
    flex-direction: column;
    gap: 6px;

    &.full {
      grid-column: 1 / -1;
    }

    .info-label {
      font-size: 12px;
      color: rgba(0, 0, 0, 0.45);
    }

    .info-value {
      font-size: 14px;
      color: rgba(0, 0, 0, 0.85);
      word-break: break-all;
    }
  }
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>

<template>
  <BasicModal
    @register="register"
    :title="getTitle"
    :closeFunc="handleClose"
    :width="700"
    @ok="handleOk"
    :canFullscreen="false"
    :okButtonProps="{ disabled: state.uploading }"
  >
    <div class="upload-modal">
      <Spin :spinning="state.uploading && state.progressPercent < 100">
        <Form :labelCol="{ span: 5 }" :wrapperCol="{ span: 19 }">
          <FormItem label="数据集ID">
            <InputNumber v-model:value="state.datasetId" disabled/>
          </FormItem>

          <FormItem :label="uploadLabel" required>
            <Upload
              v-model:file-list="state.fileList"
              :before-upload="beforeUpload"
              :custom-request="noopCustomRequest"
              :accept="acceptType"
              :max-count="1"
              list-type="picture"
              :disabled="state.uploading"
            >
              <Button :disabled="state.uploading">
                <UploadOutlined/>
                选择文件
              </Button>
              <template v-if="hintText">
                <div class="ant-upload-hint">{{ hintText }}</div>
              </template>
            </Upload>
          </FormItem>

          <FormItem v-if="state.isZip" label="解压选项">
            <Checkbox v-model:checked="state.unzip" :disabled="state.uploading">自动解压压缩包</Checkbox>
          </FormItem>

          <FormItem v-if="state.uploading" label="上传进度">
            <DatasetImportProgress
              :percent="state.progressPercent"
              detail="支持断点续传，关闭页面后重新选择同一文件可继续上传（最大 200GB）"
              :loading="state.cancelling"
              cancel-text="取消上传"
              confirm-title="确定取消上传吗？已上传的分片将被删除。"
              @cancel="cancelUpload"
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
import { Checkbox, Form, FormItem, InputNumber, message, Spin, Upload } from 'ant-design-vue';
import {UploadOutlined} from '@ant-design/icons-vue';
import {useMessage} from '@/hooks/web/useMessage';
import DatasetImportProgress from '@/views/dataset/components/DatasetImportProgress.vue';
import { Button } from '@/components/Button'
import {
DATASET_MAX_FILE_SIZE,
  formatFileSize,
  resumableUploadDatasetFile,
} from '@/utils/upload/resumableUpload';
defineOptions({name: 'DatasetImageModal'});

const {createMessage} = useMessage();

const state = reactive({
  datasetId: null as number | null,
  isImage: false,
  isZip: false,
  fileList: [] as any[],
  unzip: true,
  uploading: false,
  cancelling: false,
  progressPercent: 0,
});

const abortController = ref<AbortController | null>(null);

const getTitle = computed(() => state.isImage ? '上传图片' : '上传图片压缩包');
const uploadLabel = computed(() => state.isImage ? '选择图片' : '选择压缩包');
const hintText = computed(() => {
  if (state.isImage) return '支持 JPG/PNG/JPEG，最大 200GB，支持断点续传';
  return '支持 ZIP 压缩包，最大 200GB，支持断点续传';
});
const acceptType = computed(() => state.isImage ? 'image/*' : '.zip');

const [register, {closeModal}] = useModalInner((data) => {
  const {datasetId, isImage, isZip} = data;
  state.datasetId = datasetId;
  state.isImage = isImage;
  state.isZip = isZip;
  state.fileList = [];
  state.unzip = true;
  state.uploading = false;
  state.cancelling = false;
  state.progressPercent = 0;
});

const emits = defineEmits(['success']);

function cancelUpload() {
  if (!state.uploading || state.cancelling) {
    return;
  }
  state.cancelling = true;
  abortController.value?.abort();
  state.fileList = [];
  state.uploading = false;
  state.progressPercent = 0;
  createMessage.info('已取消上传');
}

async function handleClose(): Promise<boolean> {
  if (state.uploading) {
    abortController.value?.abort();
  }
  state.fileList = [];
  state.uploading = false;
  state.cancelling = false;
  state.progressPercent = 0;
  return true;
}

function beforeUpload(file: File) {
  if (file.size > DATASET_MAX_FILE_SIZE) {
    message.error(`文件大小不能超过 ${formatFileSize(DATASET_MAX_FILE_SIZE)}`);
    return Upload.LIST_IGNORE;
  }
  return true;
}

function noopCustomRequest(options: { onSuccess?: (body: string) => void }) {
  options.onSuccess?.('ok');
}

async function handleOk() {
  if (!state.fileList.length) {
    message.error('请选择要上传的文件');
    return;
  }

  if (!state.datasetId) {
    message.error('数据集ID不能为空');
    return;
  }

  const fileItem = state.fileList[0];
  const file: File = fileItem.originFileObj || fileItem;
  if (!file) {
    message.error('无法读取文件');
    return;
  }

  abortController.value = new AbortController();

  try {
    state.uploading = true;
    state.progressPercent = 0;

    const result = await resumableUploadDatasetFile({
      datasetId: state.datasetId,
      file,
      isZip: state.isZip,
      onProgress: (percent) => {
        state.progressPercent = percent;
      },
      signal: abortController.value.signal,
    });

    const failedCount = result?.failedCount ?? 0;
    const successCount = result?.successCount ?? 0;
    if (failedCount > 0) {
      createMessage.warning(`上传完成：成功 ${successCount} 个，失败 ${failedCount} 个`);
    } else {
      createMessage.success(successCount > 1 ? `成功上传 ${successCount} 个文件` : '上传成功');
    }
    emits('success');
    closeModal();
  } catch (error: any) {
    if (error?.message !== '上传已取消') {
      console.error('上传失败:', error);
      createMessage.error(error?.message || '上传失败，可重新选择同一文件继续上传');
    }
  } finally {
    state.uploading = false;
    state.cancelling = false;
    abortController.value = null;
  }
}
</script>

<style lang="less" scoped>
.upload-modal {
  padding: 20px;

  :deep(.ant-form-item-label) {
    & > label::after {
      content: '';
    }
  }
}

.upload-modal :deep(.ant-upload-hint) {
  margin-top: 8px;
  color: #999;
  font-size: 12px;
}
</style>

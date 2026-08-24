<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="空间存储策略"
    :width="520"
    @ok="handleSubmit"
  >
    <a-alert
      type="info"
      show-icon
      class="modal-alert"
      message="修改文件夹默认保存时间后，该文件夹下所有「跟随目录」的设备将自动同步。"
    />
    <BasicForm @register="registerForm" />
    <div class="save-time-field">
      <div class="save-time-field__label">默认保存时间</div>
      <SaveTimeInput v-model:value="saveTime" />
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { Alert as AAlert } from 'ant-design-vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import { updateDirectory } from '@/api/device/camera';
import SaveTimeInput from './SaveTimeInput.vue';
import { DEFAULT_SAVE_TIME, formatSaveTimeLabel, isValidSaveTime } from '@/views/camera/utils/spaceSaveTime';

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();
const directoryId = ref<number | null>(null);
const saveTimeField = ref<'snap_save_time' | 'record_save_time'>('snap_save_time');
const saveTime = ref(DEFAULT_SAVE_TIME);

const [registerForm, { setFieldsValue, validate, resetFields }] = useForm({
  labelWidth: 110,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'directory_name',
      label: '目录名称',
      component: 'Input',
      componentProps: { disabled: true },
    },
  ],
  showActionButtonGroup: false,
});

const [register, { setModalProps, closeModal }] = useModalInner(async (data) => {
  resetFields();
  directoryId.value = data?.directoryId ?? null;
  saveTimeField.value = data?.saveTimeField ?? 'snap_save_time';
  saveTime.value = data?.saveTime ?? DEFAULT_SAVE_TIME;
  await setFieldsValue({
    directory_name: data?.directoryName ?? '',
  });
});

async function handleSubmit() {
  if (directoryId.value == null) return;
  await validate();
  if (!isValidSaveTime(saveTime.value)) {
    createMessage.warning('保存时间须为永久，或不少于 1 小时');
    return;
  }
  setModalProps({ confirmLoading: true });
  try {
    const res = await updateDirectory(directoryId.value, {
      [saveTimeField.value]: saveTime.value,
    });
    if (res?.code !== undefined && res.code !== 0) {
      createMessage.error(res.msg || '保存失败');
      return;
    }
    createMessage.success(`文件夹默认保存时间已设为 ${formatSaveTimeLabel(saveTime.value)}`);
    closeModal();
    emit('success');
  } catch (e) {
    console.error(e);
    createMessage.error('保存空间存储策略失败');
  } finally {
    setModalProps({ confirmLoading: false });
  }
}
</script>

<style lang="less" scoped>
.modal-alert {
  margin-bottom: 16px;
}

.save-time-field {
  margin-top: 8px;
  padding-left: 110px;

  &__label {
    margin-bottom: 8px;
    font-size: 14px;
    color: rgba(0, 0, 0, 0.88);

    &::before {
      display: inline-block;
      margin-right: 4px;
      color: #ff4d4f;
      font-size: 14px;
      line-height: 1;
      content: '*';
    }
  }
}
</style>

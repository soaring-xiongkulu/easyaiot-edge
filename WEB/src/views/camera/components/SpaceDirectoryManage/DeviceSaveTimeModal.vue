<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="空间存储策略"
    :width="520"
    @ok="handleSubmit"
  >
    <BasicForm @register="registerForm" />
    <div v-if="saveTimeCustom" class="save-time-field">
      <div class="save-time-field__label">保存时间</div>
      <SaveTimeInput v-model:value="saveTime" />
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import { updateSnapSpace } from '@/api/device/snap';
import { updateRecordSpace } from '@/api/device/record';
import SaveTimeInput from './SaveTimeInput.vue';
import {
  DEFAULT_SAVE_TIME,
  formatSaveTimeLabel,
  isValidSaveTime,
  type SpaceKind,
} from '@/views/camera/utils/spaceSaveTime';

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();
const spaceId = ref<number | null>(null);
const spaceKind = ref<SpaceKind>('snap');
const directorySaveTime = ref(DEFAULT_SAVE_TIME);
const groupSaveTime = ref<number | null>(null);
const hasGroupPolicy = ref(false);
const initialSaveMode = ref(0);
const saveTimeCustom = ref(false);
const saveTime = ref(DEFAULT_SAVE_TIME);

const [registerForm, { setFieldsValue, validate, resetFields, updateSchema }] = useForm({
  labelWidth: 110,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'device_name',
      label: '设备名称',
      component: 'Input',
      componentProps: { disabled: true },
    },
    {
      field: 'save_mode',
      label: '存储模式',
      component: 'Select',
      componentProps: {
        options: [
          { label: '标准存储', value: 0 },
          { label: '归档存储', value: 1 },
        ],
      },
      helpMessage: '标准存储适合频繁访问，归档存储成本更低',
    },
    {
      field: 'save_time_custom',
      label: '自定义策略',
      component: 'Switch',
      defaultValue: false,
      componentProps: {
        checkedChildren: '自定义',
        unCheckedChildren: '跟随分组',
      },
      helpMessage: '',
    },
  ],
  showActionButtonGroup: false,
});

const [register, { setModalProps, closeModal }] = useModalInner(async (data) => {
  resetFields();
  spaceId.value = data?.spaceId ?? null;
  spaceKind.value = data?.spaceKind ?? 'snap';
  directorySaveTime.value = data?.directorySaveTime ?? DEFAULT_SAVE_TIME;
  groupSaveTime.value = data?.groupSaveTime ?? null;
  hasGroupPolicy.value = !!data?.groupType;
  initialSaveMode.value = data?.saveMode ?? 0;
  const inheritedSaveTime = hasGroupPolicy.value
    ? (groupSaveTime.value ?? data?.directorySaveTime ?? DEFAULT_SAVE_TIME)
    : directorySaveTime.value;
  const custom = !!data?.saveTimeCustom;
  saveTimeCustom.value = custom;
  saveTime.value = custom ? (data?.saveTime ?? DEFAULT_SAVE_TIME) : inheritedSaveTime;
  await setFieldsValue({
    device_name: data?.deviceName ?? '',
    save_mode: data?.saveMode ?? 0,
    save_time_custom: custom,
  });
  const followLabel = hasGroupPolicy.value ? '跟随分组' : '跟随目录';
  updateSchema({
    field: 'save_time_custom',
    componentProps: {
      checkedChildren: '自定义',
      unCheckedChildren: followLabel,
      onChange: (checked: boolean) => {
        saveTimeCustom.value = checked;
      },
    },
    helpMessage: `关闭时${followLabel}（${formatSaveTimeLabel(inheritedSaveTime)}）`,
  });
});

async function handleSubmit() {
  if (spaceId.value == null) return;
  const values = await validate();
  const custom = !!values.save_time_custom;
  saveTimeCustom.value = custom;
  if (custom && !isValidSaveTime(saveTime.value)) {
    createMessage.warning('自定义保存时间须为永久，或不少于 1 小时');
    return;
  }
  setModalProps({ confirmLoading: true });
  try {
    const payload = {
      save_mode: Number(values.save_mode ?? initialSaveMode.value),
      ...(custom
        ? { save_time: saveTime.value, save_time_custom: true }
        : { save_time_custom: false }),
    };
    const api = spaceKind.value === 'snap' ? updateSnapSpace : updateRecordSpace;
    const res = await api(spaceId.value, payload);
    if (res?.code !== undefined && res.code !== 0) {
      createMessage.error(res.msg || '保存失败');
      return;
    }
    createMessage.success('空间存储策略已更新');
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
.save-time-field {
  margin-top: 8px;
  padding-left: 110px;

  &__label {
    margin-bottom: 8px;
    font-size: 14px;
    color: rgba(0, 0, 0, 0.88);
  }
}
</style>

<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    :title="modalTitle"
    @ok="handleSubmit"
    :width="560"
  >
    <BasicForm @register="registerForm" />
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getDirectoryList,
  moveDeviceToDirectory,
  type DeviceDirectory,
} from '@/api/device/camera';

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();
const deviceIds = ref<string[]>([]);

const modalTitle = computed(() =>
  deviceIds.value.length > 1 ? '批量移动到目录' : '移动到目录',
);

const [registerForm, { validate, resetFields, updateSchema }] = useForm({
  labelWidth: 100,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'directory_id',
      label: '目标目录',
      component: 'TreeSelect',
      required: true,
      componentProps: {
        placeholder: '请选择目标目录',
        treeData: [],
        allowClear: false,
        treeDefaultExpandAll: true,
        fieldNames: {
          label: 'name',
          value: 'id',
          children: 'children',
        },
      },
    },
  ],
  showActionButtonGroup: false,
});

const [register, { setModalProps, closeModal }] = useModalInner(async (data?: {
  deviceIds?: string[];
}) => {
  resetFields();
  setModalProps({ confirmLoading: false });
  deviceIds.value = data?.deviceIds?.filter(Boolean) ?? [];
  await loadDirectoryOptions();
});

async function loadDirectoryOptions() {
  try {
    const response = await getDirectoryList();
    const data = response.code !== undefined ? response.data : response;
    if (!data || !Array.isArray(data)) return;

    const convertToTreeSelect = (directories: DeviceDirectory[]): any[] =>
      directories.map((dir) => ({
        id: dir.id,
        name: dir.name,
        children: dir.children?.length ? convertToTreeSelect(dir.children) : [],
      }));

    updateSchema({
      field: 'directory_id',
      componentProps: {
        treeData: convertToTreeSelect(data),
      },
    });
  } catch (error) {
    console.error('加载目录列表失败', error);
    createMessage.error('加载目录列表失败');
  }
}

async function handleSubmit() {
  if (!deviceIds.value.length) {
    createMessage.warning('未选择设备');
    return;
  }
  try {
    const values = await validate();
    setModalProps({ confirmLoading: true });
    const targetId = values.directory_id as number;
    await Promise.all(deviceIds.value.map((id) => moveDeviceToDirectory(id, targetId)));
    const count = deviceIds.value.length;
    createMessage.success(count > 1 ? `已成功移动 ${count} 个摄像头` : '移动成功');
    closeModal();
    emit('success');
  } catch (error) {
    console.error('移动设备失败', error);
    createMessage.error('移动失败，请重试');
  } finally {
    setModalProps({ confirmLoading: false });
  }
}
</script>

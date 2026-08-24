<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="modalTitle"
    width="720"
    placement="right"
    :showFooter="true"
    :showCancelBtn="false"
    :showOkBtn="false"
  >
    <template #footer>
      <div class="footer-buttons">
        <Button @click="closeDrawer">{{ isViewMode ? '关闭' : '取消' }}</Button>
        <Button v-if="!isViewMode" @click="handleReset">重置</Button>
        <Button v-if="!isViewMode" type="primary" :loading="confirmLoading" @click="handleSubmit">保存</Button>
      </div>
    </template>
    <BasicForm @register="registerForm" />
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { BasicForm, useForm } from '@/components/Form';
import { useMessage } from '@/hooks/web/useMessage';
import { createPlateLibrary, updatePlateLibrary, type PlateLibrary } from '@/api/device/plate_library';
import { Button } from '@/components/Button'
defineOptions({ name: 'PlateLibraryModal' });

const { createMessage } = useMessage();
const emit = defineEmits(['success', 'register']);

const modalData = ref<{ type?: string; record?: PlateLibrary }>({});
const confirmLoading = ref(false);

const modalTitle = computed(() => {
  if (modalData.value.type === 'view') return '查看车牌库';
  if (modalData.value.type === 'edit') return '编辑车牌库';
  return '新建车牌库';
});

const isViewMode = computed(() => modalData.value.type === 'view');
const isEditMode = computed(() => modalData.value.type === 'edit');

function normalizeBusinessTags(tags: unknown): string[] {
  if (tags == null || tags === '') return [];
  const items = Array.isArray(tags) ? tags : [String(tags)];
  const result: string[] = [];
  for (const item of items) {
    for (const part of String(item).split(',')) {
      const tag = part.trim();
      if (tag) result.push(tag);
    }
  }
  return [...new Set(result)];
}

const [registerForm, { setFieldsValue, validate, resetFields, updateSchema }] = useForm({
  labelWidth: 100,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'name',
      label: '库名称',
      component: 'Input',
      required: true,
      componentProps: { placeholder: '如：内部车辆库、访客车辆库', maxlength: 50, showCount: true },
    },
    {
      field: 'code',
      label: '库编号',
      component: 'Input',
      ifShow: () => isEditMode.value || isViewMode.value,
      componentProps: { disabled: true },
    },
    {
      field: 'business_tags',
      label: '业务标签',
      component: 'Select',
      componentProps: {
        mode: 'tags',
        placeholder: '如 access,parking',
        tokenSeparators: [','],
        open: false,
      },
    },
    {
      field: 'is_enabled',
      label: '启用',
      component: 'Switch',
      componentProps: { checkedChildren: '启用', unCheckedChildren: '停用' },
    },
    {
      field: 'description',
      label: '描述',
      component: 'InputTextArea',
      componentProps: { placeholder: '可选', rows: 3, maxlength: 200, showCount: true },
    },
  ],
  showActionButtonGroup: false,
});

function setFormDisabled(disabled: boolean) {
  updateSchema([
    { field: 'name', componentProps: { disabled } },
    { field: 'business_tags', componentProps: { disabled } },
    { field: 'is_enabled', componentProps: { disabled } },
    { field: 'description', componentProps: { disabled } },
  ]);
}

function fillForm(record: PlateLibrary) {
  setFieldsValue({
    name: record.name,
    code: record.code,
    business_tags: record.business_tags || [],
    description: record.description,
    is_enabled: record.is_enabled !== false,
  });
}

const [register, { setDrawerProps, closeDrawer }] = useDrawerInner(async (data) => {
  resetFields();
  modalData.value = data || {};
  if (data?.record) {
    fillForm(data.record);
    setFormDisabled(data.type === 'view');
  } else {
    setFormDisabled(false);
    setFieldsValue({ business_tags: [], is_enabled: true });
  }
});

async function handleSubmit() {
  try {
    const values = await validate();
    const { code: _code, ...payload } = values;
    payload.business_tags = normalizeBusinessTags(payload.business_tags);
    confirmLoading.value = true;
    if (modalData.value.type === 'edit' && modalData.value.record) {
      await updatePlateLibrary(modalData.value.record.id, payload);
    } else {
      await createPlateLibrary(payload);
    }
    createMessage.success('保存成功');
    closeDrawer();
    emit('success');
  } catch (error: any) {
    createMessage.error(error?.message || '提交失败');
  } finally {
    confirmLoading.value = false;
  }
}

function handleReset() {
  resetFields();
  if (modalData.value.record) fillForm(modalData.value.record);
  else setFieldsValue({ business_tags: [], is_enabled: true });
}
</script>

<style scoped>
.footer-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>

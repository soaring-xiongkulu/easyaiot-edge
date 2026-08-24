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
import {
  createScenarioPoseLibrary,
  updateScenarioPoseLibrary,
  type ScenarioPoseLibrary,
  parseScenarioPoseApiError,
  isScenarioPoseApiOk,
} from '@/api/device/scenario_pose_library';
import { MATCH_MODE_OPTIONS, SCENE_CATEGORY_OPTIONS } from './Data';
import { Button } from '@/components/Button';

defineOptions({ name: 'ScenarioPoseLibraryModal' });

const { createMessage } = useMessage();
const emit = defineEmits(['success', 'register']);

const modalData = ref<{ type?: string; record?: ScenarioPoseLibrary }>({});
const confirmLoading = ref(false);

const modalTitle = computed(() => {
  if (modalData.value.type === 'view') return '查看场景姿态库';
  if (modalData.value.type === 'edit') return '编辑场景姿态库';
  return '新建场景姿态库';
});

const isViewMode = computed(() => modalData.value.type === 'view');
const isEditMode = computed(() => modalData.value.type === 'edit');

const [registerForm, { setFieldsValue, validate, resetFields, updateSchema }] = useForm({
  labelWidth: 110,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'name',
      label: '库名称',
      component: 'Input',
      required: true,
      componentProps: { placeholder: '如：厂区跌倒检测库', maxlength: 50 },
    },
    {
      field: 'code',
      label: '库编号',
      component: 'Input',
      ifShow: () => isEditMode.value || isViewMode.value,
      componentProps: { disabled: true },
    },
    {
      field: 'scene_category',
      label: '场景类别',
      component: 'Select',
      defaultValue: 'custom',
      componentProps: { options: SCENE_CATEGORY_OPTIONS },
    },
    {
      field: 'similarity_threshold',
      label: '匹配阈值',
      component: 'InputNumber',
      defaultValue: 0.72,
      componentProps: { min: 0.1, max: 0.99, step: 0.01, style: { width: '100%' } },
    },
    {
      field: 'match_mode',
      label: '匹配模式',
      component: 'Select',
      defaultValue: 'angle',
      componentProps: { options: MATCH_MODE_OPTIONS },
    },
    {
      field: 'intent_event',
      label: '告警事件',
      component: 'Input',
      defaultValue: 'pose_intent_match',
      componentProps: { placeholder: '如 pose_fall_detected' },
    },
    {
      field: 'intent_object',
      label: '告警对象',
      component: 'Input',
      defaultValue: '姿态意图',
    },
    {
      field: 'business_tags',
      label: '业务标签',
      component: 'Select',
      componentProps: { mode: 'tags', placeholder: '如 safety,factory', tokenSeparators: [','], open: false },
    },
    {
      field: 'is_enabled',
      label: '启用',
      component: 'Switch',
      defaultValue: true,
    },
    {
      field: 'description',
      label: '描述',
      component: 'InputTextArea',
      componentProps: { rows: 3, maxlength: 200 },
    },
  ],
  showActionButtonGroup: false,
});

function setFormDisabled(disabled: boolean) {
  updateSchema([
    { field: 'name', componentProps: { disabled } },
    { field: 'scene_category', componentProps: { disabled } },
    { field: 'similarity_threshold', componentProps: { disabled } },
    { field: 'match_mode', componentProps: { disabled } },
    { field: 'intent_event', componentProps: { disabled } },
    { field: 'intent_object', componentProps: { disabled } },
    { field: 'business_tags', componentProps: { disabled } },
    { field: 'is_enabled', componentProps: { disabled } },
    { field: 'description', componentProps: { disabled } },
  ]);
}

const [register, { closeDrawer }] = useDrawerInner(async (data) => {
  modalData.value = data || {};
  await resetFields();
  if (data?.record) {
    const r = data.record;
    await setFieldsValue({
      name: r.name,
      code: r.code,
      scene_category: r.scene_category || 'custom',
      similarity_threshold: r.similarity_threshold ?? 0.72,
      match_mode: r.match_mode || 'angle',
      intent_event: r.intent_event || 'pose_intent_match',
      intent_object: r.intent_object || '姿态意图',
      business_tags: r.business_tags || [],
      is_enabled: r.is_enabled !== false,
      description: r.description,
    });
  }
  setFormDisabled(isViewMode.value);
});

async function handleSubmit() {
  if (isViewMode.value) {
    closeDrawer();
    return;
  }
  try {
    confirmLoading.value = true;
    const values = await validate();
    let res;
    if (isEditMode.value && modalData.value.record?.id) {
      res = await updateScenarioPoseLibrary(modalData.value.record.id, values);
    } else {
      res = await createScenarioPoseLibrary(values);
    }
    if (!isScenarioPoseApiOk(res)) {
      createMessage.error(parseScenarioPoseApiError(res, '保存失败'));
      return;
    }
    createMessage.success('保存成功');
    closeDrawer();
    emit('success');
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  } finally {
    confirmLoading.value = false;
  }
}
</script>

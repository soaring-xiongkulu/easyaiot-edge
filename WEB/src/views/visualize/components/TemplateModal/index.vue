<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="getTitle"
    width="1100"
    placement="right"
    :showFooter="true"
    :showCancelBtn="false"
    :showOkBtn="false"
    destroy-on-close
  >
    <template #footer>
      <div class="footer-buttons">
        <Button @click="handleCancel">{{ state.isView ? '关闭' : '取消' }}</Button>
        <Button v-if="!state.isView" type="primary" :loading="state.editLoading" @click="handleOk">
          保存
        </Button>
      </div>
    </template>
    <Spin :spinning="state.editLoading">
      <div class="visualize-drawer">
        <div class="drawer-hero">
          <img
            v-if="previewUrl"
            :src="previewUrl"
            alt="模板封面"
            class="hero-image"
            @error="onPreviewError"
          />
          <div v-else class="hero-empty">
            <span>模板封面预览</span>
            <p>填写封面图地址后将在此展示</p>
          </div>
        </div>
        <div class="drawer-body">
          <div class="section-title">基本信息</div>
          <BasicForm @register="registerForm" @field-value-change="onFieldChange" />
        </div>
      </div>
    </Spin>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue'
import { BasicDrawer, useDrawerInner } from '@/components/Drawer'
import { BasicForm, useForm } from '@/components/Form'
import { Spin } from 'ant-design-vue'
import { useMessage } from '@/hooks/web/useMessage'
import { Button } from '@/components/Button'
import {
  createVisualizeTemplate,
  getVisualizeTemplate,
  updateVisualizeTemplate,
} from '@/api/device/visualize'

defineOptions({ name: 'VisualizeTemplateDrawer' })

const { createMessage } = useMessage()
const emits = defineEmits(['success', 'register'])
const previewUrl = ref('')

const state = reactive({
  isEdit: false,
  isView: false,
  editLoading: false,
  recordId: null as number | null,
})

const getTitle = computed(() =>
  state.isEdit ? '编辑模板' : state.isView ? '查看模板' : '新增模板',
)

const [registerForm, { setFieldsValue, validate, resetFields, setProps }] = useForm({
  labelWidth: 120,
  baseColProps: { span: 24 },
  showActionButtonGroup: false,
  schemas: [
    {
      field: 'templateName',
      label: '模板名称',
      component: 'Input',
      required: true,
      colProps: { span: 12 },
      componentProps: { placeholder: '请输入模板名称', maxlength: 128 },
    },
    {
      field: 'category',
      label: '分类',
      component: 'Input',
      colProps: { span: 12 },
      componentProps: { placeholder: '如：工业监控 / 智慧城市' },
    },
    {
      field: 'coverImage',
      label: '封面图地址',
      component: 'Input',
      colProps: { span: 16 },
      componentProps: {
        placeholder: '填写可访问的封面图 URL',
        onChange: (e: any) => {
          previewUrl.value = e?.target?.value || ''
        },
      },
    },
    {
      field: 'sort',
      label: '排序',
      component: 'InputNumber',
      defaultValue: 0,
      colProps: { span: 8 },
      componentProps: { min: 0, style: { width: '100%' } },
    },
    {
      field: 'remarks',
      label: '备注',
      component: 'InputTextArea',
      componentProps: { rows: 3, maxlength: 512 },
    },
    {
      field: 'content',
      label: '模板内容',
      component: 'InputTextArea',
      componentProps: { rows: 10, placeholder: '模板画布 JSON（可选，可从编辑器导出）' },
    },
  ],
})

const [register, { closeDrawer }] = useDrawerInner(async (data) => {
  const { isEdit, isView, record } = data || {}
  state.isEdit = !!isEdit
  state.isView = !!isView
  state.recordId = record?.id ?? null
  setProps({ disabled: state.isView })
  if (state.isEdit || state.isView) {
    await loadDetail(record)
  } else {
    resetFields()
    state.recordId = null
    previewUrl.value = ''
  }
})

function onFieldChange(key: string, value: any) {
  if (key === 'coverImage') previewUrl.value = value || ''
}

function onPreviewError() {
  previewUrl.value = ''
}

async function loadDetail(record: any) {
  try {
    state.editLoading = true
    let detail = record
    if (record?.id) {
      try {
        detail = (await getVisualizeTemplate(record.id)) || record
      } catch {
        detail = record
      }
    }
    state.recordId = detail?.id ?? null
    previewUrl.value = detail?.coverImage ?? ''
    await setFieldsValue({
      templateName: detail?.templateName ?? '',
      category: detail?.category ?? '',
      coverImage: detail?.coverImage ?? '',
      sort: detail?.sort ?? 0,
      remarks: detail?.remarks ?? '',
      content: detail?.content ?? '',
    })
  } finally {
    state.editLoading = false
  }
}

function handleCancel() {
  closeDrawer()
}

async function handleOk() {
  try {
    const values = await validate()
    state.editLoading = true
    const payload = {
      templateName: values.templateName,
      category: values.category,
      coverImage: values.coverImage,
      sort: values.sort ?? 0,
      remarks: values.remarks,
      content: values.content,
    }
    if (state.isEdit && state.recordId) {
      await updateVisualizeTemplate({ id: state.recordId, ...payload })
      createMessage.success('更新成功')
    } else {
      await createVisualizeTemplate(payload)
      createMessage.success('创建成功')
    }
    emits('success')
    closeDrawer()
  } catch (e) {
    console.error(e)
  } finally {
    state.editLoading = false
  }
}
</script>

<style lang="less" scoped>
.visualize-drawer {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.drawer-hero {
  width: 100%;
  height: 240px;
  border-radius: 8px;
  overflow: hidden;
  background: linear-gradient(145deg, #eef3ff 0%, #dce7ff 50%, #c5d6ff 100%);
  box-shadow: 0 1px 4px rgba(24, 24, 24, 0.08);
}

.hero-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.hero-empty {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #266cfb;

  span {
    font-size: 16px;
    font-weight: 600;
  }

  p {
    margin: 8px 0 0;
    font-size: 13px;
    color: #8c8c8c;
  }
}

.drawer-body {
  padding: 4px 4px 12px;
}

.section-title {
  margin-bottom: 16px;
  padding-left: 10px;
  border-left: 3px solid #266cfb;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.2;
  color: #181818;
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
}
</style>

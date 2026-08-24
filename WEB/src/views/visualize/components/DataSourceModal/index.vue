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
        <Button @click="closeDrawer">{{ state.isView ? '关闭' : '取消' }}</Button>
        <Button v-if="!state.isView" type="primary" :loading="state.editLoading" @click="handleOk">
          保存
        </Button>
      </div>
    </template>
    <Spin :spinning="state.editLoading">
      <div class="visualize-drawer">
        <div class="drawer-banner" :class="`type-${state.dsType || 'http'}`">
          <div class="banner-main">
            <div class="banner-label">数据源配置</div>
            <div class="banner-type">{{ dsTypeLabel }}</div>
          </div>
          <div class="banner-status" :class="state.status === 1 ? 'off' : 'on'">
            {{ state.status === 1 ? '停用' : '启用' }}
          </div>
        </div>
        <div class="drawer-body">
          <div class="section-title">基础配置</div>
          <BasicForm @register="registerForm" @field-value-change="onFieldChange" />
        </div>
      </div>
    </Spin>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, reactive } from 'vue'
import { BasicDrawer, useDrawerInner } from '@/components/Drawer'
import { BasicForm, useForm } from '@/components/Form'
import { Spin } from 'ant-design-vue'
import { useMessage } from '@/hooks/web/useMessage'
import { Button } from '@/components/Button'
import {
  createVisualizeDatasource,
  getVisualizeDatasource,
  updateVisualizeDatasource,
} from '@/api/device/visualize'

defineOptions({ name: 'VisualizeDataSourceDrawer' })

const { createMessage } = useMessage()
const emits = defineEmits(['success', 'register'])

const DS_TYPE_MAP: Record<string, string> = {
  http: 'HTTP',
  sql: 'SQL',
  static: '静态数据',
  device: '设备数据',
}

const state = reactive({
  isEdit: false,
  isView: false,
  editLoading: false,
  recordId: null as number | null,
  dsType: 'http',
  status: 0,
})

const getTitle = computed(() =>
  state.isEdit ? '编辑数据源' : state.isView ? '查看数据源' : '新增数据源',
)

const dsTypeLabel = computed(() => DS_TYPE_MAP[state.dsType] || state.dsType || 'HTTP')

const [registerForm, { setFieldsValue, validate, resetFields, setProps, getFieldsValue }] = useForm({
  labelWidth: 120,
  baseColProps: { span: 24 },
  showActionButtonGroup: false,
  schemas: [
    {
      field: 'dsName',
      label: '数据源名称',
      component: 'Input',
      required: true,
      colProps: { span: 12 },
      componentProps: { maxlength: 128, placeholder: '请输入数据源名称' },
    },
    {
      field: 'dsType',
      label: '类型',
      component: 'Select',
      required: true,
      defaultValue: 'http',
      colProps: { span: 6 },
      componentProps: {
        options: [
          { label: 'HTTP', value: 'http' },
          { label: 'SQL', value: 'sql' },
          { label: '静态数据', value: 'static' },
          { label: '设备数据', value: 'device' },
        ],
        onChange: (v: string) => {
          state.dsType = v
        },
      },
    },
    {
      field: 'status',
      label: '状态',
      component: 'Select',
      defaultValue: 0,
      colProps: { span: 6 },
      componentProps: {
        options: [
          { label: '启用', value: 0 },
          { label: '停用', value: 1 },
        ],
        onChange: (v: number) => {
          state.status = v
        },
      },
    },
    {
      field: 'requestMethod',
      label: '请求方法',
      component: 'Select',
      defaultValue: 'GET',
      colProps: { span: 8 },
      ifShow: () => state.dsType === 'http' || state.dsType === 'device',
      componentProps: {
        options: [
          { label: 'GET', value: 'GET' },
          { label: 'POST', value: 'POST' },
          { label: 'PUT', value: 'PUT' },
        ],
      },
    },
    {
      field: 'requestUrl',
      label: '请求地址',
      component: 'Input',
      colProps: { span: 16 },
      ifShow: () => state.dsType === 'http' || state.dsType === 'device',
      componentProps: { placeholder: 'https://...' },
    },
    {
      field: 'requestHeaders',
      label: '请求头',
      component: 'InputTextArea',
      ifShow: () => state.dsType === 'http' || state.dsType === 'device',
      componentProps: { rows: 3, placeholder: 'JSON 格式，可选' },
    },
    {
      field: 'requestBody',
      label: '请求体',
      component: 'InputTextArea',
      ifShow: () => state.dsType === 'http' || state.dsType === 'device',
      componentProps: { rows: 4, placeholder: '可选' },
    },
    {
      field: 'sqlContent',
      label: 'SQL',
      component: 'InputTextArea',
      ifShow: () => state.dsType === 'sql',
      componentProps: { rows: 8, placeholder: 'SELECT ...' },
    },
    {
      field: 'staticData',
      label: '静态数据',
      component: 'InputTextArea',
      ifShow: () => state.dsType === 'static',
      componentProps: { rows: 8, placeholder: 'JSON 数组或对象' },
    },
    {
      field: 'remarks',
      label: '备注',
      component: 'InputTextArea',
      componentProps: { rows: 3, maxlength: 512 },
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
    state.dsType = 'http'
    state.status = 0
  }
})

function onFieldChange(key: string, value: any) {
  if (key === 'dsType') state.dsType = value || 'http'
  if (key === 'status') state.status = Number(value) || 0
}

async function loadDetail(record: any) {
  try {
    state.editLoading = true
    let detail = record
    if (record?.id) {
      try {
        detail = (await getVisualizeDatasource(record.id)) || record
      } catch {
        detail = record
      }
    }
    state.recordId = detail?.id ?? null
    state.dsType = detail?.dsType || 'http'
    state.status = detail?.status ?? 0
    await setFieldsValue({
      dsName: detail?.dsName ?? '',
      dsType: detail?.dsType ?? 'http',
      status: detail?.status ?? 0,
      requestMethod: detail?.requestMethod ?? 'GET',
      requestUrl: detail?.requestUrl ?? '',
      requestHeaders: detail?.requestHeaders ?? '',
      requestBody: detail?.requestBody ?? '',
      sqlContent: detail?.sqlContent ?? '',
      staticData: detail?.staticData ?? '',
      remarks: detail?.remarks ?? '',
    })
  } finally {
    state.editLoading = false
  }
}

async function handleOk() {
  try {
    const values = await validate()
    const current = getFieldsValue()
    state.dsType = values.dsType || current.dsType || state.dsType
    state.editLoading = true
    const payload = {
      dsName: values.dsName,
      dsType: values.dsType,
      status: values.status ?? 0,
      requestMethod: values.requestMethod,
      requestUrl: values.requestUrl,
      requestHeaders: values.requestHeaders,
      requestBody: values.requestBody,
      sqlContent: values.sqlContent,
      staticData: values.staticData,
      remarks: values.remarks,
    }
    if (state.isEdit && state.recordId) {
      await updateVisualizeDatasource({ id: state.recordId, ...payload })
      createMessage.success('更新成功')
    } else {
      await createVisualizeDatasource(payload)
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

.drawer-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 160px;
  padding: 0 36px;
  border-radius: 8px;
  color: #fff;
  box-shadow: 0 1px 4px rgba(24, 24, 24, 0.08);
  background: linear-gradient(135deg, #1a3a6b 0%, #266cfb 100%);

  &.type-sql {
    background: linear-gradient(135deg, #1a4a38 0%, #3db88a 100%);
  }

  &.type-static {
    background: linear-gradient(135deg, #4a3818 0%, #d4a017 100%);
  }

  &.type-device {
    background: linear-gradient(135deg, #1e3a5f 0%, #3b7ddd 100%);
  }
}

.banner-label {
  font-size: 13px;
  opacity: 0.85;
  margin-bottom: 8px;
}

.banner-type {
  font-size: 28px;
  font-weight: 700;
  letter-spacing: 1px;
}

.banner-status {
  min-width: 72px;
  padding: 6px 16px;
  border-radius: 16px;
  text-align: center;
  font-size: 13px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.2);

  &.on {
    background: rgba(82, 196, 26, 0.25);
  }

  &.off {
    background: rgba(0, 0, 0, 0.2);
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

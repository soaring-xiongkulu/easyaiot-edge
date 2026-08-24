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
        <div class="drawer-banner" :class="`status-${state.status}`">
          <div class="banner-main">
            <div class="banner-label">服务投放</div>
            <div class="banner-type">{{ statusLabel }}</div>
          </div>
          <div class="banner-code" :title="state.deployCode || '投放编码待生成'">
            {{ state.deployCode || 'CODE PENDING' }}
          </div>
        </div>
        <div class="drawer-body">
          <div class="section-title">部署信息</div>
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
  createVisualizeDeploy,
  getVisualizeDeploy,
  getVisualizeProjectPage,
  updateVisualizeDeploy,
} from '@/api/device/visualize'

defineOptions({ name: 'VisualizeDeployDrawer' })

const { createMessage } = useMessage()
const emits = defineEmits(['success', 'register'])

const STATUS_MAP: Record<number, string> = {
  0: '草稿',
  1: '已上线',
  2: '已下线',
}

const state = reactive({
  isEdit: false,
  isView: false,
  editLoading: false,
  recordId: null as number | null,
  projectOptions: [] as { label: string; value: number }[],
  status: 0,
  deployCode: '',
})

const getTitle = computed(() =>
  state.isEdit ? '编辑服务部署' : state.isView ? '查看服务部署' : '新建服务部署',
)

const statusLabel = computed(() => STATUS_MAP[state.status] || '草稿')

const [registerForm, { setFieldsValue, validate, resetFields, setProps, updateSchema }] = useForm({
  labelWidth: 120,
  baseColProps: { span: 24 },
  showActionButtonGroup: false,
  schemas: [
    {
      field: 'deployName',
      label: '部署名称',
      component: 'Input',
      required: true,
      colProps: { span: 12 },
      componentProps: { maxlength: 128, placeholder: '请输入部署名称' },
    },
    {
      field: 'projectId',
      label: '关联项目',
      component: 'Select',
      required: true,
      colProps: { span: 12 },
      componentProps: {
        showSearch: true,
        optionFilterProp: 'label',
        options: [],
        placeholder: '选择可视化项目（大屏/组态）',
      },
    },
    {
      field: 'deployCode',
      label: '投放编码',
      component: 'Input',
      colProps: { span: 12 },
      componentProps: {
        placeholder: '留空则自动生成',
        maxlength: 64,
        onChange: (e: any) => {
          state.deployCode = e?.target?.value || ''
        },
      },
    },
    {
      field: 'expireTime',
      label: '过期时间',
      component: 'DatePicker',
      colProps: { span: 12 },
      componentProps: {
        showTime: true,
        valueFormat: 'YYYY-MM-DD HH:mm:ss',
        style: { width: '100%' },
      },
    },
    {
      field: 'remarks',
      label: '备注',
      component: 'InputTextArea',
      componentProps: { rows: 4, maxlength: 512 },
    },
    {
      field: 'status',
      label: '状态',
      component: 'Select',
      colProps: { span: 12 },
      ifShow: () => state.isView || state.isEdit,
      componentProps: {
        disabled: true,
        options: [
          { label: '草稿', value: 0 },
          { label: '已上线', value: 1 },
          { label: '已下线', value: 2 },
        ],
      },
    },
    {
      field: 'accessPath',
      label: '访问路径',
      component: 'Input',
      colProps: { span: 12 },
      ifShow: () => state.isView || state.isEdit,
      componentProps: { disabled: true },
    },
  ],
})

const [register, { closeDrawer }] = useDrawerInner(async (data) => {
  const { isEdit, isView, record } = data || {}
  state.isEdit = !!isEdit
  state.isView = !!isView
  state.recordId = record?.id ?? null
  setProps({ disabled: state.isView })
  await loadProjectOptions()
  if (state.isEdit || state.isView) {
    await loadDetail(record)
  } else {
    resetFields()
    state.recordId = null
    state.status = 0
    state.deployCode = ''
  }
})

function onFieldChange(key: string, value: any) {
  if (key === 'deployCode') state.deployCode = value || ''
  if (key === 'status') state.status = Number(value) || 0
}

async function loadProjectOptions() {
  try {
    const page = await getVisualizeProjectPage({ pageNo: 1, pageSize: 200 })
    const list = page?.list || page?.records || []
    state.projectOptions = list.map((item: any) => ({
      label: `[${item.projectType === 'scada' ? '组态' : '大屏'}] ${item.projectName} (#${item.id})`,
      value: item.id,
    }))
    updateSchema({
      field: 'projectId',
      componentProps: {
        showSearch: true,
        optionFilterProp: 'label',
        options: state.projectOptions,
        placeholder: '选择可视化项目（大屏/组态）',
      },
    })
  } catch (e) {
    console.error(e)
  }
}

async function loadDetail(record: any) {
  try {
    state.editLoading = true
    let detail = record
    if (record?.id) {
      try {
        detail = (await getVisualizeDeploy(record.id)) || record
      } catch {
        detail = record
      }
    }
    state.recordId = detail?.id ?? null
    state.status = detail?.status ?? 0
    state.deployCode = detail?.deployCode ?? ''
    await setFieldsValue({
      deployName: detail?.deployName ?? '',
      projectId: detail?.projectId,
      deployCode: detail?.deployCode ?? '',
      expireTime: detail?.expireTime,
      remarks: detail?.remarks ?? '',
      status: detail?.status ?? 0,
      accessPath: detail?.accessPath ?? '',
    })
  } finally {
    state.editLoading = false
  }
}

async function handleOk() {
  try {
    const values = await validate()
    state.editLoading = true
    const payload = {
      deployName: values.deployName,
      projectId: values.projectId,
      deployCode: values.deployCode,
      expireTime: values.expireTime,
      remarks: values.remarks,
    }
    if (state.isEdit && state.recordId) {
      await updateVisualizeDeploy({ id: state.recordId, ...payload })
      createMessage.success('更新成功')
    } else {
      await createVisualizeDeploy(payload)
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
  background: linear-gradient(135deg, #3a3f4b 0%, #6b7280 100%);

  &.status-1 {
    background: linear-gradient(135deg, #1a4a38 0%, #3db88a 100%);
  }

  &.status-2 {
    background: linear-gradient(135deg, #4a3818 0%, #d4a017 100%);
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

.banner-code {
  max-width: 46%;
  padding: 8px 14px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.16);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.5px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
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

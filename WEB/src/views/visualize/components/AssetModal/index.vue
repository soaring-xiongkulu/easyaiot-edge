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
        <div class="drawer-hero">
          <img
            v-if="previewUrl && isImageType"
            :src="previewUrl"
            alt="素材预览"
            class="hero-image hero-image--contain"
            @error="onPreviewError"
          />
          <div v-else class="hero-empty">
            <span>{{ isImageType ? '素材预览' : '非图片素材' }}</span>
            <p>{{ isImageType ? '填写文件地址后将在此展示' : '视频/其他类型仅登记元信息' }}</p>
          </div>
        </div>
        <div class="drawer-body">
          <div class="section-title">素材信息</div>
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
  createVisualizeAsset,
  getVisualizeAsset,
  updateVisualizeAsset,
} from '@/api/device/visualize'

defineOptions({ name: 'VisualizeAssetDrawer' })

const { createMessage } = useMessage()
const emits = defineEmits(['success', 'register'])
const previewUrl = ref('')
const assetType = ref('image')

const isImageType = computed(() => assetType.value === 'image')

const state = reactive({
  isEdit: false,
  isView: false,
  editLoading: false,
  recordId: null as number | null,
})

const getTitle = computed(() =>
  state.isEdit ? '编辑素材' : state.isView ? '查看素材' : '登记素材',
)

const [registerForm, { setFieldsValue, validate, resetFields, setProps }] = useForm({
  labelWidth: 120,
  baseColProps: { span: 24 },
  showActionButtonGroup: false,
  schemas: [
    {
      field: 'assetName',
      label: '素材名称',
      component: 'Input',
      required: true,
      colProps: { span: 12 },
      componentProps: { maxlength: 256, placeholder: '请输入素材名称' },
    },
    {
      field: 'assetType',
      label: '类型',
      component: 'Select',
      defaultValue: 'image',
      colProps: { span: 12 },
      componentProps: {
        options: [
          { label: '图片', value: 'image' },
          { label: '视频', value: 'video' },
          { label: '其他', value: 'other' },
        ],
        onChange: (v: string) => {
          assetType.value = v
        },
      },
    },
    {
      field: 'fileUrl',
      label: '文件地址',
      component: 'Input',
      required: true,
      colProps: { span: 16 },
      componentProps: {
        placeholder: '填写可访问的文件 URL',
        onChange: (e: any) => {
          previewUrl.value = e?.target?.value || ''
        },
      },
    },
    {
      field: 'fileSize',
      label: '文件大小',
      component: 'InputNumber',
      colProps: { span: 8 },
      componentProps: { min: 0, style: { width: '100%' }, placeholder: '字节，可选' },
    },
    {
      field: 'remarks',
      label: '备注',
      component: 'InputTextArea',
      componentProps: { rows: 4, maxlength: 512 },
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
    assetType.value = 'image'
  }
})

function onFieldChange(key: string, value: any) {
  if (key === 'fileUrl') previewUrl.value = value || ''
  if (key === 'assetType') assetType.value = value || 'image'
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
        detail = (await getVisualizeAsset(record.id)) || record
      } catch {
        detail = record
      }
    }
    state.recordId = detail?.id ?? null
    previewUrl.value = detail?.fileUrl ?? ''
    assetType.value = detail?.assetType ?? 'image'
    await setFieldsValue({
      assetName: detail?.assetName ?? '',
      assetType: detail?.assetType ?? 'image',
      fileUrl: detail?.fileUrl ?? '',
      fileSize: detail?.fileSize,
      remarks: detail?.remarks ?? '',
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
      assetName: values.assetName,
      assetType: values.assetType || 'image',
      fileUrl: values.fileUrl,
      fileSize: values.fileSize,
      remarks: values.remarks,
    }
    if (state.isEdit && state.recordId) {
      await updateVisualizeAsset({ id: state.recordId, ...payload })
      createMessage.success('更新成功')
    } else {
      await createVisualizeAsset(payload)
      createMessage.success('登记成功')
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
  height: 260px;
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

  &--contain {
    object-fit: contain;
    background: #0b1220;
  }
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

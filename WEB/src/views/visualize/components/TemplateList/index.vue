<template>
  <div class="template-list-container">
    <BasicTable @register="registerTable" v-if="state.isTableMode">
      <template #toolbar>
        <Button type="primary" @click="openModal(true, { isEdit: false, isView: false })">
          新增模板
        </Button>
        <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
          切换视图
        </Button>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'templateName'">
          <a class="name-link" @click="handleView(record)">{{ record.templateName }}</a>
        </template>
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:eye-filled',
                tooltip: { title: '详情', placement: 'top' },
                onClick: handleView.bind(null, record),
              },
              {
                icon: 'ant-design:edit-filled',
                tooltip: { title: '编辑', placement: 'top' },
                onClick: openModal.bind(null, true, { isEdit: true, isView: false, record }),
              },
              {
                icon: 'material-symbols:delete-outline-rounded',
                tooltip: { title: '删除', placement: 'top' },
                popConfirm: {
                  placement: 'topRight',
                  title: '是否确认删除该模板？',
                  confirm: handleDelete.bind(null, record),
                },
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>

    <div v-else class="template-list-card-wrap">
      <TemplateCardList
        :params="params"
        :api="getVisualizeTemplatePage"
        @get-method="getMethod"
        @delete="handleDelete"
        @view="handleView"
        @edit="handleEdit"
      >
        <template #header>
          <Button type="primary" @click="openModal(true, { isEdit: false, isView: false })">
            新增模板
          </Button>
          <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
            切换视图
          </Button>
        </template>
      </TemplateCardList>
    </div>

    <TemplateModal @register="registerModal" @success="handleSuccess" />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, reactive } from 'vue'
import { BasicTable, TableAction, useTable } from '@/components/Table'
import { useMessage } from '@/hooks/web/useMessage'
import { useDrawer } from '@/components/Drawer'
import { Button } from '@/components/Button'
import { deleteVisualizeTemplate, getVisualizeTemplatePage } from '@/api/device/visualize'
import { getBasicColumns, getFormConfig } from './data'
import TemplateModal from '../TemplateModal/index.vue'
import TemplateCardList from '../TemplateCardList/index.vue'

defineOptions({ name: 'VisualizeTemplateList' })

const { createMessage } = useMessage()
const [registerModal, { openDrawer: openModal }] = useDrawer()

const state = reactive({
  isTableMode: false,
})

const params = {}
let cardListReload: (opts?: { resetPage?: boolean }) => void = () => {}

function getMethod(m: any) {
  cardListReload = m
}

function handleView(record) {
  openModal(true, { isEdit: false, isView: true, record })
}

function handleEdit(record) {
  openModal(true, { isEdit: true, isView: false, record })
}

async function reloadTableFirstPage(options?: { resetForm?: boolean }) {
  if (options?.resetForm) {
    try {
      const form = getForm()
      await form?.resetFields?.()
    } catch {
      // ignore
    }
  }
  try {
    await reload({ page: 1 })
  } catch (error) {
    console.warn('表格尚未注册，跳过刷新', error)
  }
}

async function handleClickSwap() {
  state.isTableMode = !state.isTableMode
  await nextTick()
  if (state.isTableMode) {
    await nextTick()
    await reloadTableFirstPage({ resetForm: true })
  } else {
    cardListReload({ resetPage: true })
  }
}

async function handleSuccess() {
  if (state.isTableMode) {
    await reloadTableFirstPage()
  } else {
    cardListReload({ resetPage: true })
  }
}

const [registerTable, { reload, getForm }] = useTable({
  canResize: true,
  showIndexColumn: false,
  title: '模板中心',
  api: getVisualizeTemplatePage,
  columns: getBasicColumns(),
  useSearchForm: true,
  showTableSetting: false,
  pagination: true,
  formConfig: getFormConfig(),
  rowKey: 'id',
})

async function handleDelete(record: Recordable) {
  try {
    await deleteVisualizeTemplate(record.id)
    createMessage.success('删除成功')
    handleSuccess()
  } catch (error) {
    console.error(error)
  }
}
</script>

<style lang="less" scoped>
.template-list-container {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.template-list-card-wrap {
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.name-link {
  color: #266cfb;
  cursor: pointer;

  &:hover {
    color: #4d8afb;
  }
}
</style>

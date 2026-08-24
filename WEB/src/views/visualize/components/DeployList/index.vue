<template>
  <div class="deploy-list-container">
    <BasicTable @register="registerTable" v-if="state.isTableMode">
      <template #toolbar>
        <Button type="primary" @click="openModal(true, { isEdit: false, isView: false })">
          新建部署
        </Button>
        <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
          切换视图
        </Button>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'deployName'">
          <a class="name-link" @click="handleView(record)">{{ record.deployName }}</a>
        </template>
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:eye-outlined',
                tooltip: { title: '打开预览', placement: 'top' },
                onClick: handlePreview.bind(null, record),
              },
              {
                icon: 'ant-design:edit-filled',
                tooltip: { title: '编辑', placement: 'top' },
                onClick: openModal.bind(null, true, { isEdit: true, isView: false, record }),
              },
              {
                icon:
                  Number(record.status) === 1
                    ? 'ant-design:stop-outlined'
                    : 'ant-design:cloud-upload-outlined',
                tooltip: {
                  title: Number(record.status) === 1 ? '下线' : '上线',
                  placement: 'top',
                },
                onClick: handleToggleOnline.bind(null, record),
              },
              {
                icon: 'material-symbols:delete-outline-rounded',
                tooltip: { title: '删除', placement: 'top' },
                popConfirm: {
                  placement: 'topRight',
                  title: '是否确认删除该服务部署？',
                  confirm: handleDelete.bind(null, record),
                },
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>

    <div v-else class="deploy-list-card-wrap">
      <DeployCardList
        :params="params"
        :api="getVisualizeDeployPage"
        @get-method="getMethod"
        @delete="handleDelete"
        @view="handleView"
        @edit="handleEdit"
        @preview="handlePreview"
        @toggle-online="handleToggleOnline"
      >
        <template #header>
          <Button type="primary" @click="openModal(true, { isEdit: false, isView: false })">
            新建部署
          </Button>
          <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
            切换视图
          </Button>
        </template>
      </DeployCardList>
    </div>

    <DeployModal @register="registerModal" @success="handleSuccess" />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, reactive } from 'vue'
import { BasicTable, TableAction, useTable } from '@/components/Table'
import { useMessage } from '@/hooks/web/useMessage'
import { useDrawer } from '@/components/Drawer'
import { Button } from '@/components/Button'
import {
  deleteVisualizeDeploy,
  getVisualizeDeployPage,
  getVisualizeProject,
  offlineVisualizeDeploy,
  onlineVisualizeDeploy,
} from '@/api/device/visualize'
import { openVisualizeEditor } from '@/utils/visualizeEditor'
import { getBasicColumns, getFormConfig } from './data'
import DeployModal from '../DeployModal/index.vue'
import DeployCardList from '../DeployCardList/index.vue'

defineOptions({ name: 'VisualizeDeployList' })

const { createMessage } = useMessage()
const [registerModal, { openDrawer: openModal }] = useDrawer()

const state = reactive({
  isTableMode: true,
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
  title: '服务部署',
  api: getVisualizeDeployPage,
  columns: getBasicColumns(),
  useSearchForm: true,
  showTableSetting: false,
  pagination: true,
  formConfig: getFormConfig(),
  rowKey: 'id',
})

async function handleDelete(record: Recordable) {
  try {
    await deleteVisualizeDeploy(record.id)
    createMessage.success('删除成功')
    handleSuccess()
  } catch (error) {
    console.error(error)
  }
}

async function handleToggleOnline(record: Recordable) {
  try {
    if (Number(record.status) === 1) {
      await offlineVisualizeDeploy(record.id)
      createMessage.success('已下线')
    } else {
      await onlineVisualizeDeploy(record.id)
      createMessage.success('已上线')
    }
    handleSuccess()
  } catch (error) {
    console.error(error)
  }
}

async function handlePreview(record: Recordable) {
  if (!record?.projectId) {
    createMessage.warning('缺少关联项目')
    return
  }
  try {
    let projectType = record.projectType
    let editorRef = record.editorRef
    let projectName = record.projectName
    if (!projectType) {
      const project = await getVisualizeProject(record.projectId)
      projectType = project?.projectType
      editorRef = project?.editorRef
      projectName = project?.projectName
    }
    openVisualizeEditor(record.projectId, 'preview', { projectType, editorRef, projectName })
  } catch (e: any) {
    createMessage.error(e?.message || '打开预览失败')
  }
}
</script>

<style lang="less" scoped>
.deploy-list-container {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.deploy-list-card-wrap {
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

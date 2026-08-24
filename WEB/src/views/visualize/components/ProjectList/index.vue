<template>
  <div class="project-list-container">
    <BasicTable @register="registerTable" v-if="state.isTableMode">
      <template #toolbar>
        <Button type="primary" @click="openAddModal(true, { isEdit: false, isView: false })">
          新增项目
        </Button>
        <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
          切换视图
        </Button>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'projectName'">
          <a class="project-name-link" @click="handleView(record)">{{ record.projectName }}</a>
        </template>
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:fund-projection-screen-outlined',
                tooltip: {
                  title: isFuxaDemoProject(record)
                    ? '演示组态只读，请使用预览'
                    : record.projectType === 'scada'
                      ? '打开组态编辑器'
                      : '打开编辑器',
                  placement: 'top',
                },
                ifShow: !isFuxaDemoProject(record),
                onClick: handleOpenEditor.bind(null, record),
              },
              {
                icon: 'ant-design:eye-outlined',
                tooltip: { title: '预览', placement: 'top' },
                onClick: handleOpenPreview.bind(null, record),
              },
              {
                icon: 'ant-design:eye-filled',
                tooltip: { title: '详情', placement: 'top' },
                onClick: handleView.bind(null, record),
              },
              {
                icon: 'ant-design:edit-filled',
                tooltip: { title: '编辑信息', placement: 'top' },
                onClick: openAddModal.bind(null, true, { isEdit: true, isView: false, record }),
              },
              {
                icon:
                  Number(record.state) === 1
                    ? 'ant-design:stop-outlined'
                    : 'ant-design:check-circle-outlined',
                tooltip: {
                  title: Number(record.state) === 1 ? '取消发布' : '发布',
                  placement: 'top',
                },
                onClick: handleTogglePublish.bind(null, record),
              },
              {
                icon: 'material-symbols:delete-outline-rounded',
                tooltip: { title: '删除', placement: 'top' },
                popConfirm: {
                  placement: 'topRight',
                  title: `是否确认删除该${getProjectTypeLabel(record.projectType)}项目？`,
                  confirm: handleDelete.bind(null, record),
                },
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>

    <div v-else class="project-list-card-wrap">
      <ProjectCardList
        :params="params"
        :api="getVisualizeProjectPage"
        @get-method="getMethod"
        @delete="handleDelete"
        @view="handleView"
        @edit="handleEdit"
        @open-editor="handleOpenEditor"
        @preview="handleOpenPreview"
        @publish="handleTogglePublish"
      >
        <template #header>
          <Button type="primary" @click="openAddModal(true, { isEdit: false, isView: false })">
            新增项目
          </Button>
          <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
            切换视图
          </Button>
        </template>
      </ProjectCardList>
    </div>

    <ProjectModal @register="registerAddModel" @success="handleSuccess" />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, reactive } from 'vue'
import { BasicTable, TableAction, useTable } from '@/components/Table'
import { useMessage } from '@/hooks/web/useMessage'
import { getBasicColumns, getFormConfig } from './data'
import ProjectModal from '../ProjectModal/index.vue'
import ProjectCardList from '../ProjectCardList/index.vue'
import { useDrawer } from '@/components/Drawer'
import {
  deleteVisualizeProject,
  getVisualizeProjectPage,
  publishVisualizeProject,
} from '@/api/device/visualize'
import { getProjectTypeLabel, isFuxaDemoProject, openVisualizeEditor } from '@/utils/visualizeEditor'
import { Button } from '@/components/Button'

defineOptions({ name: 'VisualizeProjectList' })

const { createMessage } = useMessage()
const [registerAddModel, { openDrawer: openAddModal }] = useDrawer()

const state = reactive({
  isTableMode: false,
})

const params = {}
let cardListReload: (opts?: { resetPage?: boolean }) => void = () => {}

function getMethod(m: any) {
  cardListReload = m
}

function handleView(record) {
  openAddModal(true, { isEdit: false, isView: true, record })
}

function handleEdit(record) {
  openAddModal(true, { isEdit: true, isView: false, record })
}

function handleOpenEditor(record) {
  if (isFuxaDemoProject(record)) {
    createMessage.info('演示组态为只读，已打开运行态预览')
    handleOpenPreview(record)
    return
  }
  try {
    openVisualizeEditor(record.id, 'edit', {
      projectType: record.projectType,
      editorRef: record.editorRef,
      projectName: record.projectName,
    })
  } catch (e: any) {
    createMessage.error(e?.message || '打开编辑器失败')
  }
}

function handleOpenPreview(record) {
  try {
    openVisualizeEditor(record.id, 'preview', {
      projectType: record.projectType,
      editorRef: record.editorRef,
      projectName: record.projectName,
    })
  } catch (e: any) {
    createMessage.error(e?.message || '打开预览失败')
  }
}

async function handleTogglePublish(record) {
  const nextState = Number(record.state) === 1 ? -1 : 1
  try {
    await publishVisualizeProject({ id: record.id, state: nextState })
    createMessage.success(nextState === 1 ? '发布成功' : '已取消发布')
    handleSuccess()
  } catch (error) {
    console.error(error)
  }
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
  title: '可视化项目管理',
  api: getVisualizeProjectPage,
  columns: getBasicColumns(),
  useSearchForm: true,
  showTableSetting: false,
  pagination: true,
  formConfig: getFormConfig(),
  rowKey: 'id',
})

const handleDelete = async (record) => {
  try {
    await deleteVisualizeProject(record.id)
    createMessage.success('删除成功')
    handleSuccess()
  } catch (error) {
    console.error(error)
  }
}
</script>

<style lang="less" scoped>
.project-list-container {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.project-list-card-wrap {
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.project-name-link {
  color: #266cfb;
  cursor: pointer;

  &:hover {
    color: #4d8afb;
  }
}
</style>

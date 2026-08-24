<template>
  <div class="deploy-card-list-wrapper">
    <div class="search-bar">
      <BasicForm @register="registerForm" @reset="handleSubmit" />
    </div>
    <div class="list-panel">
      <Spin :spinning="state.loading">
        <List
          :grid="{ gutter: 18, xs: 2, sm: 3, md: 4, lg: 5, xl: 6, xxl: 6 }"
          :data-source="data"
          :pagination="paginationProp"
        >
          <template #header>
            <div class="list-header">
              <span class="list-title">部署列表</span>
              <div class="list-actions">
                <slot name="header"></slot>
              </div>
            </div>
          </template>
          <template #renderItem="{ item }">
            <ListItem class="deploy-list-item">
              <div class="deploy-card" @mouseenter="hoverId = item.id" @mouseleave="hoverId = null">
                <div class="deploy-card-cover" @click="emit('view', item)">
                  <div class="deploy-card-cover-inner">
                    <div class="cover-placeholder" :class="`status-${Number(item.status)}`">
                      <span class="cover-status-text">{{ getStatusText(item.status) }}</span>
                      <span class="cover-code" :title="item.deployCode">{{ item.deployCode || '--' }}</span>
                    </div>
                  </div>
                  <div
                    v-show="hoverId === item.id"
                    class="deploy-card-overlay"
                    @click="emit('view', item)"
                  >
                    <div class="overlay-actions" @click.stop>
                      <Tooltip title="打开预览">
                        <button class="overlay-btn" @click="emit('preview', item)">
                          <EyeOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip title="编辑">
                        <button class="overlay-btn" @click="emit('edit', item)">
                          <EditOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip :title="Number(item.status) === 1 ? '下线' : '上线'">
                        <button class="overlay-btn" @click="emit('toggle-online', item)">
                          <CloudUploadOutlined v-if="Number(item.status) !== 1" />
                          <StopOutlined v-else />
                        </button>
                      </Tooltip>
                      <Popconfirm title="是否确认删除？" @confirm="emit('delete', item)">
                        <Tooltip title="删除">
                          <button class="overlay-btn overlay-btn--danger">
                            <DeleteOutlined />
                          </button>
                        </Tooltip>
                      </Popconfirm>
                    </div>
                  </div>
                </div>

                <div class="deploy-card-badge">
                  <svg viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="20" cy="20" r="18" stroke="#266CFB" stroke-width="1.5" fill="#fff" />
                    <text
                      x="20"
                      y="24"
                      text-anchor="middle"
                      fill="#266CFB"
                      font-size="9"
                      font-weight="700"
                    >
                      DEP
                    </text>
                  </svg>
                </div>

                <div class="deploy-card-body">
                  <h3
                    class="deploy-card-title"
                    :title="item.deployName"
                    @click="emit('view', item)"
                  >
                    {{ item.deployName }}
                  </h3>
                  <p class="deploy-card-tags" :title="getTagsText(item)">
                    {{ getTagsText(item) }}
                  </p>
                </div>
              </div>
            </ListItem>
          </template>
        </List>
      </Spin>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { onMounted, reactive, ref } from 'vue'
import { List, Popconfirm, Spin, Tooltip } from 'ant-design-vue'
import {
  CloudUploadOutlined,
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
  StopOutlined,
} from '@ant-design/icons-vue'
import { BasicForm, useForm } from '@/components/Form'
import { propTypes } from '@/utils/propTypes'
import { isFunction } from '@/utils/is'

defineOptions({ name: 'VisualizeDeployCardList' })

const ListItem = List.Item

const STATUS_MAP: Record<number, string> = {
  0: '草稿',
  1: '已上线',
  2: '已下线',
}

const props = defineProps({
  params: propTypes.object.def({}),
  api: propTypes.func,
})

const emit = defineEmits(['getMethod', 'delete', 'edit', 'view', 'preview', 'toggle-online'])

const data = ref<any[]>([])
const hoverId = ref<number | null>(null)
const state = reactive({ loading: true })
const page = ref(1)
const pageSize = ref(12)
const total = ref(0)

const [registerForm, { validate }] = useForm({
  schemas: [
    {
      field: 'deployName',
      label: '部署名称',
      component: 'Input',
      componentProps: { placeholder: '请输入部署名称' },
    },
    {
      field: 'status',
      label: '状态',
      component: 'Select',
      componentProps: {
        allowClear: true,
        options: [
          { label: '草稿', value: 0 },
          { label: '已上线', value: 1 },
          { label: '已下线', value: 2 },
        ],
      },
    },
  ],
  labelWidth: 80,
  baseColProps: { span: 6 },
  actionColOptions: { span: 12 },
  autoSubmitOnEnter: true,
  submitFunc: handleSubmit,
})

onMounted(() => {
  fetch()
  emit('getMethod', reload)
})

async function handleSubmit() {
  const formData = await validate()
  page.value = 1
  await fetch(formData)
}

async function reload(opts?: { resetPage?: boolean }) {
  if (opts?.resetPage) page.value = 1
  state.loading = true
  await fetch()
}

async function fetch(p: Recordable = {}) {
  const { api, params } = props
  if (!api || !isFunction(api)) return
  try {
    state.loading = true
    const res = await api({ ...params, pageNo: page.value, pageSize: pageSize.value, ...p })
    data.value = res?.list ?? res?.data ?? []
    total.value = res?.total ?? 0
  } catch (error) {
    console.error(error)
    data.value = []
    total.value = 0
  } finally {
    state.loading = false
  }
}

const paginationProp = ref({
  showSizeChanger: false,
  showQuickJumper: true,
  pageSize,
  current: page,
  total,
  showTotal: (t: number) => `总 ${t} 条`,
  onChange: pageChange,
  onShowSizeChange: pageSizeChange,
})

function pageChange(p: number, pz: number) {
  page.value = p
  pageSize.value = pz
  fetch()
}

function pageSizeChange(_current: number, size: number) {
  pageSize.value = size
  page.value = 1
  fetch()
}

function getStatusText(status: number | string): string {
  return STATUS_MAP[Number(status)] || '--'
}

function getTagsText(item: any): string {
  const parts: string[] = []
  parts.push(getStatusText(item.status))
  if (item.projectName) parts.push(item.projectName)
  else if (item.accessPath) {
    const path = String(item.accessPath)
    parts.push(path.length <= 18 ? path : path.slice(0, 18) + '…')
  } else {
    parts.push(`ID: ${item.id}`)
  }
  return parts.join('  |  ')
}
</script>

<style lang="less" scoped>
.deploy-card-list-wrapper {
  background: #fff;
  height: 100%;
  min-height: 0;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.search-bar {
  padding: 16px 16px 0;
  margin-bottom: 10px;
  background: #fff;
  flex-shrink: 0;
}

.list-panel {
  background: #fff;
  padding: 0 8px 16px;
  flex: 1;
  min-height: 0;

  :deep(.ant-list-header) {
    border: 0;
    padding: 8px 12px 16px;
    background: transparent;
  }

  :deep(.ant-list) {
    padding: 0 8px;
  }

  :deep(.ant-row) {
    display: flex;
    flex-wrap: wrap;
    row-gap: 18px;
  }

  :deep(.ant-col) {
    display: flex;
  }

  :deep(.ant-list-item) {
    margin-bottom: 0;
    padding: 0 !important;
    border: none;
    width: 100%;
    height: 100%;
    display: flex;
  }

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    background: transparent;
  }

  :deep(.ant-list-pagination) {
    margin-top: 20px;
    text-align: center;
  }
}

.list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.list-title {
  padding-left: 4px;
  font-size: 16px;
  font-weight: 500;
  line-height: 24px;
  color: #181818;
}

.list-actions {
  display: flex;
  gap: 8px;
}

.deploy-list-item {
  width: 100%;
}

@cover-height: 200px;
@body-height: 96px;
@card-height: @cover-height + @body-height;

.deploy-card {
  position: relative;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: @card-height;
  background: #fff;
  border-radius: 6px;
  box-shadow: 0 1px 4px rgba(24, 24, 24, 0.1);
  overflow: hidden;
  transition: box-shadow 0.25s ease, transform 0.25s ease;

  &:hover {
    box-shadow: 0 3px 12px rgba(0, 0, 0, 0.12);
    transform: translateY(-1px);
  }
}

.deploy-card-cover {
  position: relative;
  width: 100%;
  height: @cover-height;
  flex-shrink: 0;
  overflow: hidden;
  cursor: pointer;
  background: #fafafa;
}

.deploy-card-cover-inner {
  position: absolute;
  inset: 0;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 0 16px;
  box-sizing: border-box;
  background: linear-gradient(145deg, #f0f2f5 0%, #e2e6eb 45%, #d3d9e0 100%);

  &.status-1 {
    background: linear-gradient(145deg, #eef8f3 0%, #d7efe4 45%, #bfe3d4 100%);
  }

  &.status-2 {
    background: linear-gradient(145deg, #fff4e8 0%, #ffe0c2 45%, #ffd0a0 100%);
  }
}

.cover-status-text {
  font-size: 18px;
  font-weight: 700;
  color: #266cfb;
}

.cover-code {
  max-width: 100%;
  font-size: 12px;
  color: #666;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.deploy-card-overlay {
  position: absolute;
  inset: 0;
  z-index: 3;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.45);
}

.overlay-actions {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: center;
  padding: 0 8px;
}

.overlay-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border: none;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.92);
  color: #266cfb;
  font-size: 16px;
  cursor: pointer;
  transition: background 0.2s, color 0.2s, transform 0.2s;

  &:hover {
    background: #fff;
    transform: scale(1.08);
  }

  &--danger {
    color: #f5222d;

    &:hover {
      background: #fff1f0;
    }
  }
}

.deploy-card-badge {
  position: absolute;
  top: @cover-height - 20px;
  right: 14px;
  z-index: 4;
  width: 40px;
  height: 40px;
  pointer-events: none;

  svg {
    width: 40px;
    height: 40px;
    filter: drop-shadow(0 2px 6px rgba(38, 108, 251, 0.2));
  }
}

.deploy-card-body {
  flex-shrink: 0;
  height: @body-height;
  padding: 24px 16px 14px;
  box-sizing: border-box;
  overflow: hidden;
}

.deploy-card-title {
  margin: 0 0 8px;
  font-size: 15px;
  font-weight: 600;
  line-height: 1.45;
  color: #181818;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;

  &:hover {
    color: #266cfb;
  }
}

.deploy-card-tags {
  margin: 0;
  font-size: 13px;
  line-height: 1.5;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

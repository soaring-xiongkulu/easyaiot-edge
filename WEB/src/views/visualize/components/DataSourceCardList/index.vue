<template>
  <div class="datasource-card-list-wrapper">
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
              <span class="list-title">数据源列表</span>
              <div class="list-actions">
                <slot name="header"></slot>
              </div>
            </div>
          </template>
          <template #renderItem="{ item }">
            <ListItem class="datasource-list-item">
              <div
                class="datasource-card"
                @mouseenter="hoverId = item.id"
                @mouseleave="hoverId = null"
              >
                <div class="datasource-card-cover" @click="emit('view', item)">
                  <div class="datasource-card-cover-inner">
                    <div class="cover-placeholder" :class="`type-${item.dsType || 'http'}`">
                      <span class="cover-type">{{ getTypeLabel(item.dsType) }}</span>
                      <span class="cover-status" :class="Number(item.status) === 1 ? 'off' : 'on'">
                        {{ Number(item.status) === 1 ? '停用' : '启用' }}
                      </span>
                    </div>
                  </div>
                  <div
                    v-show="hoverId === item.id"
                    class="datasource-card-overlay"
                    @click="emit('view', item)"
                  >
                    <div class="overlay-actions" @click.stop>
                      <Tooltip title="查看详情">
                        <button class="overlay-btn" @click="emit('view', item)">
                          <EyeOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip title="编辑数据源">
                        <button class="overlay-btn" @click="emit('edit', item)">
                          <EditOutlined />
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

                <div class="datasource-card-badge">
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
                      {{ getBadgeText(item.dsType) }}
                    </text>
                  </svg>
                </div>

                <div class="datasource-card-body">
                  <h3 class="datasource-card-title" :title="item.dsName" @click="emit('view', item)">
                    {{ item.dsName }}
                  </h3>
                  <p class="datasource-card-tags" :title="getTagsText(item)">
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
import { DeleteOutlined, EditOutlined, EyeOutlined } from '@ant-design/icons-vue'
import { BasicForm, useForm } from '@/components/Form'
import { propTypes } from '@/utils/propTypes'
import { isFunction } from '@/utils/is'

defineOptions({ name: 'VisualizeDataSourceCardList' })

const ListItem = List.Item

const DS_TYPE_MAP: Record<string, string> = {
  http: 'HTTP',
  sql: 'SQL',
  static: '静态数据',
  device: '设备数据',
}

const props = defineProps({
  params: propTypes.object.def({}),
  api: propTypes.func,
})

const emit = defineEmits(['getMethod', 'delete', 'edit', 'view'])

const data = ref<any[]>([])
const hoverId = ref<number | null>(null)
const state = reactive({ loading: true })
const page = ref(1)
const pageSize = ref(12)
const total = ref(0)

const [registerForm, { validate }] = useForm({
  schemas: [
    {
      field: 'dsName',
      label: '名称',
      component: 'Input',
      componentProps: { placeholder: '请输入名称' },
    },
    {
      field: 'dsType',
      label: '类型',
      component: 'Select',
      componentProps: {
        allowClear: true,
        options: [
          { label: 'HTTP', value: 'http' },
          { label: 'SQL', value: 'sql' },
          { label: '静态数据', value: 'static' },
          { label: '设备数据', value: 'device' },
        ],
      },
    },
    {
      field: 'status',
      label: '状态',
      component: 'Select',
      componentProps: {
        allowClear: true,
        options: [
          { label: '启用', value: 0 },
          { label: '停用', value: 1 },
        ],
      },
    },
  ],
  labelWidth: 80,
  baseColProps: { span: 6 },
  actionColOptions: { span: 6 },
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

function getTypeLabel(type?: string): string {
  return DS_TYPE_MAP[type || ''] || type || 'DATA'
}

function getBadgeText(type?: string): string {
  if (type === 'http') return 'HTTP'
  if (type === 'sql') return 'SQL'
  if (type === 'static') return 'ST'
  if (type === 'device') return 'DEV'
  return 'DS'
}

function getTagsText(item: any): string {
  const parts: string[] = []
  parts.push(getTypeLabel(item.dsType))
  parts.push(Number(item.status) === 1 ? '停用' : '启用')
  if (item.requestUrl) {
    const url = String(item.requestUrl)
    parts.push(url.length <= 20 ? url : url.slice(0, 20) + '…')
  }
  return parts.join('  |  ')
}
</script>

<style lang="less" scoped>
.datasource-card-list-wrapper {
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

.datasource-list-item {
  width: 100%;
}

@cover-height: 200px;
@body-height: 96px;
@card-height: @cover-height + @body-height;

.datasource-card {
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

.datasource-card-cover {
  position: relative;
  width: 100%;
  height: @cover-height;
  flex-shrink: 0;
  overflow: hidden;
  cursor: pointer;
  background: #fafafa;
}

.datasource-card-cover-inner {
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
  background: linear-gradient(145deg, #eef3ff 0%, #dce7ff 45%, #c5d6ff 100%);

  &.type-sql {
    background: linear-gradient(145deg, #eef8f3 0%, #d7efe4 45%, #bfe3d4 100%);
  }

  &.type-static {
    background: linear-gradient(145deg, #fff7e8 0%, #ffe9c2 45%, #ffdca0 100%);
  }

  &.type-device {
    background: linear-gradient(145deg, #f3f0ff 0%, #e4dcff 45%, #d0c4ff 100%);
  }
}

.cover-type {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 1px;
  color: #266cfb;
}

.cover-status {
  padding: 2px 10px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 500;
  background: rgba(255, 255, 255, 0.75);

  &.on {
    color: #389e0d;
  }

  &.off {
    color: #8c8c8c;
  }
}

.datasource-card-overlay {
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

.datasource-card-badge {
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

.datasource-card-body {
  flex-shrink: 0;
  height: @body-height;
  padding: 24px 16px 14px;
  box-sizing: border-box;
  overflow: hidden;
}

.datasource-card-title {
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

.datasource-card-tags {
  margin: 0;
  font-size: 13px;
  line-height: 1.5;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

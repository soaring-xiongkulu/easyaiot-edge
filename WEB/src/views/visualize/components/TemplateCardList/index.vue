<template>
  <div class="template-card-list-wrapper">
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
              <span class="list-title">模板列表</span>
              <div class="list-actions">
                <slot name="header"></slot>
              </div>
            </div>
          </template>
          <template #renderItem="{ item }">
            <ListItem class="template-list-item">
              <div
                class="template-card"
                @mouseenter="hoverId = item.id"
                @mouseleave="hoverId = null"
              >
                <div class="template-card-cover" @click="emit('view', item)">
                  <div class="template-card-cover-inner">
                    <img
                      v-if="item.coverImage"
                      :src="item.coverImage"
                      alt="封面"
                      class="template-card-image"
                      @error="onImageError"
                    />
                    <div v-else class="cover-placeholder">
                      <span class="cover-placeholder-label">TEMPLATE</span>
                    </div>
                  </div>
                  <div
                    v-show="hoverId === item.id"
                    class="template-card-overlay"
                    @click="emit('view', item)"
                  >
                    <div class="overlay-actions" @click.stop>
                      <Tooltip title="查看详情">
                        <button class="overlay-btn" @click="emit('view', item)">
                          <EyeOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip title="编辑模板">
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

                <div class="template-card-badge">
                  <svg viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="20" cy="20" r="18" stroke="#266CFB" stroke-width="1.5" fill="#fff" />
                    <text
                      x="20"
                      y="24"
                      text-anchor="middle"
                      fill="#266CFB"
                      font-size="11"
                      font-weight="700"
                    >
                      TPL
                    </text>
                  </svg>
                </div>

                <div class="template-card-body">
                  <h3
                    class="template-card-title"
                    :title="item.templateName"
                    @click="emit('view', item)"
                  >
                    {{ item.templateName }}
                  </h3>
                  <p class="template-card-tags" :title="getTagsText(item)">
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

defineOptions({ name: 'VisualizeTemplateCardList' })

const ListItem = List.Item

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
      field: 'templateName',
      label: '模板名称',
      component: 'Input',
      componentProps: { placeholder: '请输入模板名称' },
    },
    {
      field: 'category',
      label: '分类',
      component: 'Input',
      componentProps: { placeholder: '请输入分类' },
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

function getTagsText(item: any): string {
  const parts: string[] = []
  if (item.category) parts.push(item.category)
  if (item.remarks) {
    const desc = String(item.remarks).trim()
    parts.push(desc.length <= 18 ? desc : desc.slice(0, 18) + '…')
  }
  if (!parts.length) parts.push(`ID: ${item.id}`)
  return parts.join('  |  ')
}

function onImageError(e: Event) {
  const img = e.target as HTMLImageElement
  if (img) img.style.display = 'none'
}
</script>

<style lang="less" scoped>
.template-card-list-wrapper {
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

.template-list-item {
  width: 100%;
}

@cover-height: 200px;
@body-height: 96px;
@card-height: @cover-height + @body-height;

.template-card {
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

.template-card-cover {
  position: relative;
  width: 100%;
  height: @cover-height;
  flex-shrink: 0;
  overflow: hidden;
  cursor: pointer;
  background: #fafafa;
}

.template-card-cover-inner {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

.template-card-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(145deg, #f3f0ff 0%, #e4dcff 45%, #d0c4ff 100%);
}

.cover-placeholder-label {
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 2px;
  color: #5b6cff;
  opacity: 0.85;
}

.template-card-overlay {
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

.template-card-badge {
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

.template-card-body {
  flex-shrink: 0;
  height: @body-height;
  padding: 24px 16px 14px;
  box-sizing: border-box;
  overflow: hidden;
}

.template-card-title {
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

.template-card-tags {
  margin: 0;
  font-size: 13px;
  line-height: 1.5;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

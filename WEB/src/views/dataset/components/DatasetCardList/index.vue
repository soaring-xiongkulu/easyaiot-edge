<template>
  <div class="dataset-card-list-wrapper">
    <div class="search-bar">
      <BasicForm @register="registerForm" @reset="handleSubmit"/>
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
              <span class="list-title">数据集列表</span>
              <div class="list-actions">
                <slot name="header"></slot>
              </div>
            </div>
          </template>
          <template #renderItem="{ item }">
            <ListItem class="dataset-list-item">
              <div
                class="dataset-card"
                @mouseenter="hoverId = item.id"
                @mouseleave="hoverId = null"
              >
                <div class="dataset-card-cover" @click="handleView(item)">
                  <div class="dataset-card-cover-inner">
                    <img
                      :src="getCoverImage(item)"
                      alt="数据集封面"
                      class="dataset-card-image"
                      @error="onImageError"
                    />
                  </div>
                  <div
                    v-show="hoverId === item.id"
                    class="dataset-card-overlay"
                    @click="handleView(item)"
                  >
                    <div class="overlay-actions" @click.stop>
                      <Tooltip title="查看详情">
                        <button class="overlay-btn" @click="handleView(item)">
                          <EyeOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip title="编辑数据集">
                        <button class="overlay-btn" @click="handleEdit(item)">
                          <EditOutlined />
                        </button>
                      </Tooltip>
                      <Tooltip title="复制信息">
                        <button class="overlay-btn" @click="handleCopy(item)">
                          <CopyOutlined />
                        </button>
                      </Tooltip>
                      <Popconfirm title="是否确认删除？" @confirm="handleDelete(item)">
                        <Tooltip title="删除">
                          <button class="overlay-btn overlay-btn--danger">
                            <DeleteOutlined />
                          </button>
                        </Tooltip>
                      </Popconfirm>
                    </div>
                  </div>
                </div>

                <div class="dataset-card-badge">
                  <svg viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="20" cy="20" r="18" stroke="#266CFB" stroke-width="1.5" fill="#fff"/>
                    <text
                      x="20"
                      y="24"
                      text-anchor="middle"
                      fill="#266CFB"
                      font-size="12"
                      font-weight="700"
                    >{{ item.datasetType === 0 ? '图' : '文' }}</text>
                  </svg>
                </div>

                <div class="dataset-card-body">
                  <h3 class="dataset-card-title" :title="item.name" @click="handleView(item)">
                    {{ item.name }}
                  </h3>
                  <p class="dataset-card-tags" :title="getTagsText(item)">
                    {{ getTagsText(item) }}
                  </p>
                  <div class="dataset-card-progress">
                    <div class="progress-meta">
                      <span>标注进度</span>
                      <span>{{ item.annotatedImages || 0 }}/{{ item.totalImages || 0 }}</span>
                    </div>
                    <Progress
                      :percent="calculateAnnotationProgress(item)"
                      :stroke-color="getProgressColor(calculateAnnotationProgress(item))"
                      size="small"
                      :showInfo="false"
                    />
                  </div>
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
import {onMounted, reactive, ref} from 'vue';
import {List, Popconfirm, Progress, Spin, Tooltip} from 'ant-design-vue';
import {BasicForm, useForm} from '@/components/Form';
import {propTypes} from '@/utils/propTypes';
import {isFunction} from '@/utils/is';
import {
  CopyOutlined,
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
} from '@ant-design/icons-vue';
import {useMessage} from '@/hooks/web/useMessage';
import DEFAULT_COVER from '@/assets/images/video/ai-task.png';

defineOptions({name: 'DatasetCardList'});

const ListItem = List.Item;
const {createMessage} = useMessage();

const props = defineProps({
  params: propTypes.object.def({}),
  api: propTypes.func,
});

const emit = defineEmits(['getMethod', 'delete', 'edit', 'view']);

const data = ref([]);
const hoverId = ref<number | null>(null);
const state = reactive({
  loading: true,
});

const [registerForm, {validate}] = useForm({
  schemas: [
    {
      field: `name`,
      label: `数据集名称`,
      component: 'Input',
    },
  ],
  labelWidth: 80,
  baseColProps: {span: 6},
  actionColOptions: {span: 18},
  autoSubmitOnEnter: true,
  submitFunc: handleSubmit,
});

onMounted(() => {
  fetch();
  emit('getMethod', reload);
});

async function handleSubmit() {
  const formData = await validate();
  page.value = 1;
  await fetch(formData);
}

async function reload(opts?: { resetPage?: boolean }) {
  if (opts?.resetPage) {
    page.value = 1;
  }
  await fetch();
}

async function fetch(p = {}) {
  const {api, params} = props;
  if (api && isFunction(api)) {
    try {
      state.loading = true;
      const res = await api({...params, pageNo: page.value, pageSize: pageSize.value, ...p});
      data.value = res?.data?.list ?? [];
      total.value = res?.data?.total ?? 0;
    } catch (error) {
      console.error('获取数据集列表失败:', error);
      data.value = [];
      total.value = 0;
    } finally {
      state.loading = false;
    }
  }
}

const page = ref(1);
const pageSize = ref(12);
const total = ref(0);
const paginationProp = ref({
  showSizeChanger: false,
  showQuickJumper: true,
  pageSize,
  current: page,
  total,
  showTotal: (total: number) => `总 ${total} 条`,
  onChange: pageChange,
  onShowSizeChange: pageSizeChange,
});

function pageChange(p: number, pz: number) {
  page.value = p;
  pageSize.value = pz;
  fetch();
}

function pageSizeChange(_current: number, size: number) {
  pageSize.value = size;
  page.value = 1;
  fetch();
}

function getCoverImage(item: any): string {
  return item.coverPath || DEFAULT_COVER;
}

function onImageError(e: Event) {
  const img = e.target as HTMLImageElement;
  if (img && img.src !== DEFAULT_COVER) {
    img.src = DEFAULT_COVER;
  }
}

function calculateAnnotationProgress(item: any) {
  if (!item.totalImages || item.totalImages === 0) return 0;
  return Math.round(((item.annotatedImages || 0) / item.totalImages) * 100);
}

function getProgressColor(percent: number) {
  if (percent < 30) return '#ff4d4f';
  if (percent < 70) return '#faad14';
  return '#52c41a';
}

function getAuditText(audit: number) {
  if (audit === 0) return '待审核';
  if (audit === 1) return '审核通过';
  if (audit === 2) return '审核驳回';
  return '未知';
}

function getTagsText(item: any): string {
  const parts: string[] = [];
  parts.push(item.datasetType === 0 ? '图片' : '文本');
  parts.push(getAuditText(item.audit));
  if (item.version) parts.push(item.version);
  const progress = calculateAnnotationProgress(item);
  parts.push(`${progress}%`);
  return parts.join('  |  ');
}

function handleDelete(record: object) {
  emit('delete', record);
}

function handleView(record: object) {
  emit('view', record);
}

function handleEdit(record: object) {
  emit('edit', record);
}

async function handleCopy(record: object) {
  await navigator.clipboard.writeText(JSON.stringify(record));
  createMessage.success('复制成功');
}
</script>

<style lang="less" scoped>
.dataset-card-list-wrapper {
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

.dataset-list-item {
  width: 100%;
}

@cover-height: 200px;
@body-height: 118px;
@card-height: @cover-height + @body-height;

.dataset-card {
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
  cursor: default;

  &:hover {
    box-shadow: 0 3px 12px rgba(0, 0, 0, 0.12);
    transform: translateY(-1px);
  }
}

.dataset-card-cover {
  position: relative;
  width: 100%;
  height: @cover-height;
  flex-shrink: 0;
  overflow: hidden;
  cursor: pointer;
  background: #fafafa;
}

.dataset-card-cover-inner {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

.dataset-card-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  object-position: center;
  display: block;
}

.dataset-card-overlay {
  position: absolute;
  inset: 0;
  z-index: 3;
  border-radius: 6px 6px 0 0;
  overflow: hidden;
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

.dataset-card-badge {
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

.dataset-card-body {
  flex-shrink: 0;
  height: @body-height;
  padding: 24px 16px 12px;
  box-sizing: border-box;
  overflow: hidden;
}

.dataset-card-title {
  margin: 0 0 6px;
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

.dataset-card-tags {
  margin: 0 0 8px;
  font-size: 13px;
  line-height: 1.5;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dataset-card-progress {
  .progress-meta {
    display: flex;
    justify-content: space-between;
    margin-bottom: 4px;
    font-size: 12px;
    line-height: 1.4;
    color: #666;
  }

  :deep(.ant-progress) {
    margin: 0;
    line-height: 1;
  }

  :deep(.ant-progress-outer) {
    padding-right: 0;
    margin: 0;
  }
}
</style>

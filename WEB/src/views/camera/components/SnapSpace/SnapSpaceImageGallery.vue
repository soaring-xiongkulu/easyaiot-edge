<template>
  <div class="snap-image-gallery">
    <div class="snap-image-toolbar">
      <div class="toolbar-filters">
        <Input
          v-model:value="searchKeyword"
          placeholder="搜索文件名"
          allow-clear
          class="filter-input"
          @pressEnter="handleSearch"
        />
        <Select
          v-model:value="sourceFilter"
          :options="sourceOptions"
          placeholder="来源"
          allow-clear
          class="filter-select"
        />
        <RangePicker
          v-model:value="dateRange"
          value-format="YYYY-MM-DD"
          :placeholder="['开始日期', '结束日期']"
          class="filter-range"
          @change="handleDateRangeChange"
        />
        <div class="quick-dates">
          <span
            v-for="chip in quickDateOptions"
            :key="chip.key"
            class="date-chip"
            :class="{ active: activeQuickDate === chip.key }"
            @click="applyQuickDate(chip.key)"
          >
            {{ chip.label }}
          </span>
        </div>
      </div>
      <div class="toolbar-actions">
        <Button @click="handleReset">重置</Button>
        <Button type="primary" @click="handleSearch">查询</Button>
        <Button @click="handleSelectAll">{{ isAllSelected ? '取消全选' : '全选' }}</Button>
        <Button @click="handleRefresh">刷新</Button>
        <Button
          type="primary"
          danger
          :disabled="selectedRowKeys.length === 0"
          @click="handleBatchDelete"
        >
          批量删除 ({{ selectedRowKeys.length }})
        </Button>
      </div>
    </div>

    <div class="table-wrapper">
      <Table
        :columns="columns"
        :data-source="imageList"
        :loading="loading"
        :pagination="paginationProp"
        :row-selection="rowSelection"
        :row-key="(record: SnapImage) => record.object_name"
        size="middle"
        :scroll="{ y: 'calc(100vh - 360px)' }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'thumbnail'">
            <div class="thumb-cell" @click="openPreview(record)">
              <img
                :src="getImageUrl(record)"
                :alt="record.filename"
                class="thumb-image"
                loading="lazy"
              />
            </div>
          </template>
          <template v-else-if="column.key === 'filename'">
            <span class="filename-cell" :title="record.filename">{{ record.filename }}</span>
          </template>
          <template v-else-if="column.key === 'source'">
            <Tag :color="snapImageSourceColor(record.source)">
              {{ formatSnapImageSource(record.source) }}
            </Tag>
          </template>
          <template v-else-if="column.key === 'size'">
            {{ formatSize(record.size) }}
          </template>
          <template v-else-if="column.key === 'time'">
            {{ formatTime(record.captured_at || record.last_modified) }}
          </template>
          <template v-else-if="column.key === 'action'">
            <div class="row-actions">
              <Button type="link" size="small" @click="openPreview(record)">预览</Button>
              <Button type="link" size="small" @click="handleDownload(record)">下载</Button>
              <Button type="link" size="small" danger @click="handleDelete(record)">删除</Button>
            </div>
          </template>
        </template>
        <template #emptyText>
          <Empty description="暂无抓拍图片" />
        </template>
      </Table>
    </div>

    <BasicModal
      v-model:open="previewOpen"
      :title="previewItem?.filename || '图片预览'"
      width="960px"
      :show-ok-btn="false"
      :show-cancel-btn="false"
      :footer="null"
      destroy-on-close
      centered
    >
      <div v-if="previewItem" class="preview-body">
        <img :src="getImageUrl(previewItem)" :alt="previewItem.filename" class="preview-image" />
        <div class="preview-meta">
          <Tag :color="snapImageSourceColor(previewItem.source)">
            {{ formatSnapImageSource(previewItem.source) }}
          </Tag>
          <span>{{ formatTime(previewItem.captured_at || previewItem.last_modified) }}</span>
          <span>{{ formatSize(previewItem.size) }}</span>
        </div>
      </div>
    </BasicModal>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Table, Input, Select, DatePicker, Tag, Empty } from 'ant-design-vue';
import type { TableColumnsType } from 'ant-design-vue';
import { BasicModal } from '@/components/Modal';
import type { Dayjs } from 'dayjs';
import dayjs from 'dayjs';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getSnapImageList,
  deleteSnapImages,
  type SnapImage,
  type SnapImageSource,
} from '@/api/device/snap';
import { resolveAlertImageDisplayUrl } from '@/utils/alertMinioImage';
import { Button } from '@/components/Button';
import {
  SNAP_IMAGE_SOURCE_OPTIONS,
  formatSnapImageSource,
  snapImageSourceColor,
} from '@/views/camera/utils/snapImageSource';

defineOptions({ name: 'SnapSpaceImageGallery' });

const props = defineProps<{
  spaceId: number | null;
}>();

const { createMessage } = useMessage();
const { RangePicker } = DatePicker;

const columns: TableColumnsType<SnapImage> = [
  { title: '缩略图', key: 'thumbnail', width: 88, align: 'center' },
  { title: '文件名', key: 'filename', dataIndex: 'filename', ellipsis: true },
  { title: '来源', key: 'source', width: 110 },
  { title: '大小', key: 'size', width: 100 },
  { title: '抓拍时间', key: 'time', width: 140 },
  { title: '操作', key: 'action', width: 180, fixed: 'right' },
];

const sourceOptions = SNAP_IMAGE_SOURCE_OPTIONS.map((item) => ({
  label: item.label,
  value: item.value,
}));

const quickDateOptions = [
  { key: 'today', label: '今天' },
  { key: 'yesterday', label: '昨天' },
  { key: 'last7', label: '近7天' },
  { key: 'last30', label: '近30天' },
] as const;

type QuickDateKey = (typeof quickDateOptions)[number]['key'];

const imageList = ref<SnapImage[]>([]);
const loading = ref(false);
const searchKeyword = ref('');
const sourceFilter = ref<SnapImageSource | ''>('');
const dateRange = ref<[string, string] | null>(null);
const activeQuickDate = ref<QuickDateKey | ''>('');
const selectedRowKeys = ref<string[]>([]);
const page = ref(1);
const pageSize = ref(20);
const total = ref(0);
const previewOpen = ref(false);
const previewItem = ref<SnapImage | null>(null);

const paginationProp = computed(() => {
  if (total.value === 0) return false;
  return {
    showSizeChanger: true,
    showQuickJumper: true,
    pageSize: pageSize.value,
    current: page.value,
    total: total.value,
    pageSizeOptions: ['10', '20', '50', '100'],
    showTotal: (count: number) => `共 ${count} 张图片`,
    onChange: pageChange,
    onShowSizeChange: pageSizeChange,
  };
});

const rowSelection = computed(() => ({
  selectedRowKeys: selectedRowKeys.value,
  onChange: (keys: (string | number)[]) => {
    selectedRowKeys.value = keys.map(String);
  },
}));

function buildTimeRange(): { startTime?: string; endTime?: string } {
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) return {};
  return {
    startTime: `${dateRange.value[0]}T00:00:00`,
    endTime: `${dateRange.value[1]}T23:59:59`,
  };
}

function applyQuickDate(key: QuickDateKey) {
  activeQuickDate.value = key;
  const today = dayjs();
  let start: Dayjs;
  let end: Dayjs = today;
  if (key === 'today') {
    start = today;
  } else if (key === 'yesterday') {
    start = today.subtract(1, 'day');
    end = today.subtract(1, 'day');
  } else if (key === 'last7') {
    start = today.subtract(6, 'day');
  } else {
    start = today.subtract(29, 'day');
  }
  dateRange.value = [start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD')];
  handleSearch();
}

function pageChange(p: number, pz: number) {
  page.value = p;
  pageSize.value = pz;
  loadImageList();
}

function pageSizeChange(_current: number, size: number) {
  pageSize.value = size;
  page.value = 1;
  loadImageList();
}

function getImageUrl(record: SnapImage) {
  if (record.url) return resolveAlertImageDisplayUrl(record.url);
  if (!props.spaceId) return '';
  return resolveAlertImageDisplayUrl(
    `/video/snap/space/${props.spaceId}/image/${record.object_name}`,
  );
}

function formatSize(bytes: number) {
  if (!bytes) return '-';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function formatTime(timeStr?: string) {
  if (!timeStr) return '-';
  return dayjs(timeStr).format('MM-DD HH:mm:ss');
}

function openPreview(item: SnapImage) {
  previewItem.value = item;
  previewOpen.value = true;
}

async function loadImageList() {
  if (!props.spaceId) {
    imageList.value = [];
    total.value = 0;
    return;
  }
  loading.value = true;
  try {
    const timeRange = buildTimeRange();
    const response = await getSnapImageList(props.spaceId, {
      pageNo: page.value,
      pageSize: pageSize.value,
      search: searchKeyword.value.trim() || undefined,
      source: sourceFilter.value || undefined,
      ...timeRange,
    });
    if (response?.code === 0 && Array.isArray(response.data)) {
      imageList.value = response.data;
      total.value = response.total ?? 0;
    } else {
      createMessage.error(response?.msg || '加载图片列表失败');
      imageList.value = [];
      total.value = 0;
    }
  } catch (error) {
    console.error('加载图片列表失败', error);
    createMessage.error('加载图片列表失败');
    imageList.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
}

function handleDateRangeChange() {
  activeQuickDate.value = '';
}

function handleSearch() {
  page.value = 1;
  selectedRowKeys.value = [];
  loadImageList();
}

function handleReset() {
  searchKeyword.value = '';
  sourceFilter.value = '';
  dateRange.value = null;
  activeQuickDate.value = '';
  page.value = 1;
  selectedRowKeys.value = [];
  loadImageList();
}

function handleRefresh() {
  selectedRowKeys.value = [];
  loadImageList();
}

const isAllSelected = computed(() => {
  return imageList.value.length > 0 && selectedRowKeys.value.length === imageList.value.length;
});

function handleSelectAll() {
  selectedRowKeys.value = isAllSelected.value
    ? []
    : imageList.value.map((item) => item.object_name);
}

async function handleDownload(record: SnapImage) {
  const imageUrl = getImageUrl(record);
  if (!imageUrl) {
    createMessage.error('图片地址无效');
    return;
  }
  try {
    const token = localStorage.getItem('jwt_token');
    const response = await fetch(imageUrl, {
      method: 'GET',
      headers: { 'X-Authorization': `Bearer ${token}` },
    });
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.msg || `下载失败: ${response.statusText}`);
    }
    const blob = await response.blob();
    const contentDisposition = response.headers.get('Content-Disposition');
    let fileName = record.filename || 'snap-image.jpg';
    if (contentDisposition) {
      const fileNameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
      if (fileNameMatch?.[1]) {
        fileName = fileNameMatch[1].replace(/['"]/g, '');
        try {
          fileName = decodeURIComponent(fileName);
        } catch {
          /* keep raw */
        }
      }
    }
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    setTimeout(() => {
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    }, 100);
    createMessage.success('下载成功');
  } catch (error: unknown) {
    console.error('下载失败', error);
    createMessage.error(error instanceof Error ? error.message : '下载失败');
  }
}

async function handleDelete(record: SnapImage) {
  if (!props.spaceId) return;
  try {
    await deleteSnapImages(props.spaceId, [record.object_name]);
    createMessage.success('删除成功');
    if (previewItem.value?.object_name === record.object_name) {
      previewOpen.value = false;
      previewItem.value = null;
    }
    loadImageList();
  } catch (error: unknown) {
    console.error('删除失败', error);
    createMessage.error('删除失败');
  }
}

async function handleBatchDelete() {
  if (!props.spaceId || selectedRowKeys.value.length === 0) return;
  try {
    await deleteSnapImages(props.spaceId, selectedRowKeys.value);
    createMessage.success(`成功删除 ${selectedRowKeys.value.length} 张图片`);
    selectedRowKeys.value = [];
    loadImageList();
  } catch (error: unknown) {
    console.error('批量删除失败', error);
    createMessage.error('批量删除失败');
  }
}

function resetFilters() {
  searchKeyword.value = '';
  sourceFilter.value = '';
  dateRange.value = null;
  activeQuickDate.value = '';
  page.value = 1;
  selectedRowKeys.value = [];
}

function setDateFilter(date: string) {
  applyFilters({ date });
}

function applyFilters(filters: { date?: string; source?: SnapImageSource | '' }) {
  if (filters.date) {
    dateRange.value = [filters.date, filters.date];
    activeQuickDate.value = '';
  }
  if (filters.source !== undefined) {
    sourceFilter.value = filters.source;
  }
  page.value = 1;
  selectedRowKeys.value = [];
  loadImageList();
}

watch(
  () => props.spaceId,
  () => {
    resetFilters();
    loadImageList();
  },
  { immediate: true },
);

defineExpose({ refresh: handleRefresh, setDateFilter, applyFilters });
</script>

<style lang="less" scoped>
.snap-image-gallery {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  overflow: hidden;
}

.snap-image-toolbar {
  flex-shrink: 0;
  padding-bottom: 12px;
  margin-bottom: 12px;
  border-bottom: 1px solid #e8e8e8;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.toolbar-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;

  .filter-input {
    width: 200px;
  }

  .filter-select {
    width: 140px;
  }

  .filter-range {
    width: 260px;
  }
}

.quick-dates {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;

  .date-chip {
    font-size: 12px;
    padding: 2px 10px;
    border-radius: 4px;
    background: #f5f5f5;
    cursor: pointer;
    user-select: none;

    &:hover,
    &.active {
      background: #e6f4ff;
      color: #1677ff;
    }
  }
}

.toolbar-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.table-wrapper {
  flex: 1;
  min-height: 0;
  overflow: hidden;

  :deep(.ant-table-wrapper) {
    height: 100%;
  }

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    height: 100%;
  }
}

.thumb-cell {
  width: 56px;
  height: 42px;
  margin: 0 auto;
  border-radius: 4px;
  overflow: hidden;
  background: #fafafa;
  cursor: zoom-in;

  .thumb-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
}

.filename-cell {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
}

.preview-body {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;

  .preview-image {
    max-width: 100%;
    max-height: 70vh;
    object-fit: contain;
  }

  .preview-meta {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
    font-size: 13px;
    color: #595959;
  }
}
</style>

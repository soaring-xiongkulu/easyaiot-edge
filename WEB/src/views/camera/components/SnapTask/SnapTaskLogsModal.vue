<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    :title="modalTitle"
    width="960px"
    :footer="null"
    :mask-closable="true"
  >
    <div class="snap-task-logs">
      <div class="logs-toolbar">
        <Select
          v-model:value="levelFilter"
          allow-clear
          placeholder="日志级别"
          style="width: 140px"
          :options="levelOptions"
          @change="handleFilterChange"
        />
        <Switch
          v-model:checked="autoRefresh"
          checked-children="自动刷新"
          un-checked-children="手动"
          @change="handleAutoRefreshChange"
        />
        <Button :loading="loading" @click="loadLogs">
          <template #icon><ReloadOutlined /></template>
          刷新
        </Button>
      </div>

      <Spin :spinning="loading">
        <Empty v-if="!loading && logList.length === 0" description="暂无运行日志" />
        <div v-else class="logs-list">
          <div
            v-for="(item, index) in logList"
            :key="`${item.time}-${index}`"
            class="log-row"
            :class="`log-row--${normalizeLevel(item.level)}`"
          >
            <span class="log-time">{{ item.time }}</span>
            <Tag :color="levelColor(item.level)" class="log-level">{{ item.level }}</Tag>
            <span class="log-message">{{ item.message }}</span>
            <span v-if="item.file" class="log-file">{{ item.file }}</span>
          </div>
        </div>
      </Spin>

      <div v-if="total > pageSize" class="logs-pagination">
        <Pagination
          v-model:current="pageNo"
          v-model:page-size="pageSize"
          :total="total"
          :show-size-changer="true"
          :page-size-options="['50', '100', '200']"
          show-less-items
          @change="loadLogs"
        />
      </div>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, onUnmounted, ref } from 'vue';
import {
  Empty,
  Spin,
  Select,
  Switch,
  Tag,
  Pagination,
} from 'ant-design-vue';
import { ReloadOutlined } from '@ant-design/icons-vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { Button } from '@/components/Button';
import { getSnapTaskLogs, type SnapTaskLogItem } from '@/api/device/snap';

defineOptions({ name: 'SnapTaskLogsModal' });

defineEmits(['register']);

const loading = ref(false);
const logList = ref<SnapTaskLogItem[]>([]);
const total = ref(0);
const pageNo = ref(1);
const pageSize = ref(100);
const taskId = ref<number | null>(null);
const taskName = ref('');
const levelFilter = ref<string | undefined>(undefined);
const autoRefresh = ref(false);
let refreshTimer: ReturnType<typeof setInterval> | null = null;

const levelOptions = [
  { label: 'INFO', value: 'INFO' },
  { label: 'WARNING', value: 'WARNING' },
  { label: 'ERROR', value: 'ERROR' },
  { label: 'DEBUG', value: 'DEBUG' },
];

const modalTitle = computed(() =>
  taskName.value ? `任务日志 - ${taskName.value}` : '任务日志',
);

function normalizeLevel(level?: string) {
  return (level || 'info').toLowerCase();
}

function levelColor(level?: string) {
  const key = normalizeLevel(level);
  if (key.includes('error')) return 'red';
  if (key.includes('warn')) return 'orange';
  if (key.includes('debug')) return 'default';
  return 'blue';
}

function clearRefreshTimer() {
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
}

function startAutoRefresh() {
  clearRefreshTimer();
  if (!autoRefresh.value || !taskId.value) return;
  refreshTimer = setInterval(() => {
    void loadLogs();
  }, 5000);
}

async function loadLogs() {
  if (!taskId.value) return;
  loading.value = true;
  try {
    const res = await getSnapTaskLogs(taskId.value, {
      pageNo: pageNo.value,
      pageSize: pageSize.value,
      level: levelFilter.value,
    });
    if (res?.code === 0 && Array.isArray(res.data)) {
      logList.value = res.data;
      total.value = res.total ?? res.data.length;
    } else {
      logList.value = [];
      total.value = 0;
    }
  } catch (e) {
    console.error(e);
    logList.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
}

function handleFilterChange() {
  pageNo.value = 1;
  void loadLogs();
}

function handleAutoRefreshChange(checked: boolean) {
  autoRefresh.value = checked;
  if (checked) startAutoRefresh();
  else clearRefreshTimer();
}

const [register] = useModalInner(async (data) => {
  clearRefreshTimer();
  autoRefresh.value = false;
  pageNo.value = 1;
  levelFilter.value = undefined;
  taskId.value = data?.taskId ?? data?.record?.id ?? null;
  taskName.value = data?.taskName ?? data?.record?.task_name ?? '';
  await loadLogs();
  if (data?.autoRefresh) {
    autoRefresh.value = true;
    startAutoRefresh();
  }
});

onUnmounted(() => {
  clearRefreshTimer();
});
</script>

<style lang="less" scoped>
.snap-task-logs {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: 420px;
}

.logs-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
}

.logs-list {
  max-height: 56vh;
  overflow: auto;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  background: #fafafa;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
}

.log-row {
  display: grid;
  grid-template-columns: 170px 72px 1fr auto;
  gap: 8px;
  align-items: start;
  padding: 8px 12px;
  border-bottom: 1px solid #f0f0f0;
  background: #fff;

  &:last-child {
    border-bottom: none;
  }

  &--error {
    background: #fff2f0;
  }

  &--warning {
    background: #fffbe6;
  }
}

.log-time {
  color: #8c8c8c;
  white-space: nowrap;
}

.log-message {
  color: #262626;
  word-break: break-all;
}

.log-file {
  color: #bfbfbf;
  white-space: nowrap;
}

.logs-pagination {
  display: flex;
  justify-content: flex-end;
}
</style>

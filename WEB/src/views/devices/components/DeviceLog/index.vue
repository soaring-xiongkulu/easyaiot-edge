<template>
  <div class="ops-page">
    <div class="ops-header">
      <div class="ops-header-main">
        <h2 class="ops-header-title">{{ isIndustrialProtocol ? '通信日志' : '设备日志' }}</h2>
        <div class="ops-header-meta">
          <span class="ops-meta-item">共 <strong>{{ logList.length }}</strong> 条</span>
          <span class="ops-meta-item">错误 <strong>{{ errorCount }}</strong></span>
        </div>
      </div>
      <div class="ops-header-actions">
        <Button type="primary" @click="refreshLogs" :loading="loading" preIcon="ant-design:reload-outlined">
          刷新
        </Button>
      </div>
    </div>

    <div class="ops-toolbar">
      <div class="ops-field">
        <label>日志级别</label>
        <Select
          v-model:value="filterForm.level"
          placeholder="全部"
          allowClear
          style="width: 140px"
          @change="handleFilterChange"
        >
          <SelectOption value="INFO">信息</SelectOption>
          <SelectOption value="WARN">警告</SelectOption>
          <SelectOption value="ERROR">错误</SelectOption>
          <SelectOption value="DEBUG">调试</SelectOption>
        </Select>
      </div>
      <div class="ops-field ops-field-grow">
        <label>内容关键字</label>
        <Input
          v-model:value="filterForm.keyword"
          placeholder="搜索日志内容后回车"
          allowClear
          @pressEnter="handleFilterChange"
        />
      </div>
      <div class="ops-field ops-field-wide">
        <label>时间范围</label>
        <RangePicker
          v-model:value="filterForm.timeRange"
          show-time
          format="YYYY-MM-DD HH:mm:ss"
          style="width: 100%"
          @change="handleFilterChange"
        />
      </div>
      <div class="ops-toolbar-actions">
        <Button type="primary" @click="handleFilterChange" :loading="loading">查询</Button>
        <Button @click="handleReset">重置</Button>
      </div>
    </div>

    <div class="ops-surface">
      <div class="ops-surface-head">
        <div class="ops-surface-title">
          记录列表
          <span class="ops-count">({{ logList.length }})</span>
        </div>
      </div>
      <div class="ops-surface-body" ref="logContainerRef">
        <div v-if="logList.length === 0" class="ops-empty">
          <Icon icon="ant-design:inbox-outlined" class="ops-empty-icon" />
          <p>{{ isIndustrialProtocol ? '暂无原始通信报文，请等待点位采集' : '暂无设备日志' }}</p>
          <p class="ops-empty-hint">
            {{
              isIndustrialProtocol
                ? '工业协议原始通信报文会显示在此'
                : '请确认设备或 mqtt-demo 已上报 /log/upstream/report'
            }}
          </p>
        </div>
        <div v-else class="ops-list">
          <div
            v-for="(log, index) in logList"
            :key="log.id || index"
            class="ops-row"
            :class="getLogItemClass(log)"
          >
            <div class="ops-card">
              <div class="ops-card-top">
                <span class="ops-time">{{ formatTime(log.createTime) }}</span>
                <Tag :color="getLevelColor(log.level)">{{ log.level || 'INFO' }}</Tag>
                <Tag :color="getStatusColor(log.status)">{{ getStatusText(log.status) }}</Tag>
              </div>
              <div class="ops-preview">{{ formatLogContent(log) }}</div>
              <div class="ops-card-foot">
                <span>设备标识: {{ log.userName || '--' }}</span>
                <a class="expand-link" @click.prevent="toggleExpand(index)">
                  {{ expandedMap[index] ? '收起' : '展开' }}
                </a>
              </div>
              <pre v-if="expandedMap[index]" class="ops-detail">{{ formatLogContent(log) }}</pre>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { getLog } from '@/api/device/entity-views';
import moment from 'moment';
import { Input, Select, SelectOption, Tag, DatePicker } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button';

const { RangePicker } = DatePicker;

defineOptions({ name: 'DeviceLog' });

const props = defineProps<{ device?: Record<string, any> }>();
const isIndustrialProtocol = computed(() => {
  if (['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'].includes(props.device?.protocolType)) return true;
  try {
    const extension =
      props.device?.extension && props.device.extension !== '--'
        ? JSON.parse(props.device.extension)
        : {};
    return ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'].includes(extension.protocolConfig?.type);
  } catch (_) {
    return false;
  }
});

const route = useRoute();
const { createMessage } = useMessage();

const deviceId = computed(() => route.params?.id as string);

const filterForm = reactive({
  level: undefined as string | undefined,
  keyword: undefined as string | undefined,
  timeRange: undefined as any,
});

const logList = ref<any[]>([]);
const loading = ref(false);
const logContainerRef = ref<HTMLElement | null>(null);
const expandedMap = reactive<Record<number, boolean>>({});

const errorCount = computed(
  () => logList.value.filter((item) => String(item.level).toUpperCase() === 'ERROR').length,
);

const normalizeList = (response: any) => {
  if (Array.isArray(response)) return response;
  return response?.rows || response?.data || response?.list || [];
};

const fetchDeviceLogData = async () => {
  loading.value = true;
  try {
    const params: any = {
      page: 1,
      pageSize: 1000,
      actionType: 'REPORT',
    };

    if (filterForm.level) {
      params.level = filterForm.level;
    }
    if (filterForm.keyword) {
      params.keyword = filterForm.keyword;
    }
    if (filterForm.timeRange && filterForm.timeRange.length === 2) {
      params.startTime = moment(filterForm.timeRange[0]).format('YYYY-MM-DD HH:mm:ss');
      params.endTime = moment(filterForm.timeRange[1]).format('YYYY-MM-DD HH:mm:ss');
    }

    const response = await getLog({
      module: 'DEVICE',
      id: deviceId.value,
      params,
    });

    const data = normalizeList(response);
    logList.value = data.sort((a, b) => {
      const timeA = moment(a.createTime).valueOf();
      const timeB = moment(b.createTime).valueOf();
      return timeB - timeA;
    });
    Object.keys(expandedMap).forEach((k) => delete expandedMap[Number(k)]);
  } catch (error) {
    console.error('获取设备日志数据失败:', error);
    createMessage.error('获取设备日志失败');
    logList.value = [];
  } finally {
    loading.value = false;
  }
};

const handleFilterChange = () => {
  fetchDeviceLogData();
};

const handleReset = () => {
  filterForm.level = undefined;
  filterForm.keyword = undefined;
  filterForm.timeRange = undefined;
  fetchDeviceLogData();
};

const refreshLogs = () => {
  fetchDeviceLogData();
};

const formatTime = (time: string) => {
  if (!time) return '--';
  return moment(time).format('YYYY-MM-DD HH:mm:ss');
};

const formatLogContent = (log: any) => {
  if (log.content) {
    return typeof log.content === 'object' ? JSON.stringify(log.content, null, 2) : String(log.content);
  }
  if (log.actionData) {
    if (typeof log.actionData === 'object') {
      return JSON.stringify(log.actionData, null, 2);
    }
    return log.actionData;
  }
  return '--';
};

const getLevelColor = (level: string) => {
  const colorMap: Record<string, string> = {
    INFO: 'blue',
    WARN: 'orange',
    WARNING: 'orange',
    ERROR: 'red',
    DEBUG: 'default',
  };
  return colorMap[level] || 'blue';
};

const getStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    SUCCESS: '成功',
    FAILED: '失败',
  };
  return statusMap[status] || status || '--';
};

const getStatusColor = (status: string) => {
  const colorMap: Record<string, string> = {
    SUCCESS: 'green',
    FAILED: 'red',
  };
  return colorMap[status] || 'default';
};

const getLogItemClass = (log: any) => {
  const level = String(log.level || '').toUpperCase();
  return {
    'is-warn': level === 'WARN' || level === 'WARNING',
    'is-error': level === 'ERROR' || log.status === 'FAILED',
    'is-success': log.status === 'SUCCESS' && level !== 'ERROR',
  };
};

const toggleExpand = (index: number) => {
  expandedMap[index] = !expandedMap[index];
};

watch(
  logList,
  () => {
    if (logContainerRef.value) {
      logContainerRef.value.scrollTop = 0;
    }
  },
  { deep: true },
);

onMounted(() => {
  fetchDeviceLogData();
});
</script>

<style lang="less" scoped>
.expand-link {
  color: #1677ff;
  cursor: pointer;
  user-select: none;

  &:hover {
    color: #4096ff;
  }
}
</style>


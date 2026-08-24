<template>
  <div class="ops-page">
    <div class="ops-header">
      <div class="ops-header-main">
        <h2 class="ops-header-title">{{ isIndustrialProtocol ? '写入日志' : '指令日志' }}</h2>
        <p class="ops-header-desc">
          {{
            isIndustrialProtocol
              ? '寄存器与线圈写入请求和响应'
              : '跟踪属性设置与服务调用的 PENDING / ACK；下发请前往「功能调用」'
          }}
        </p>
        <div class="ops-header-meta">
          <span class="ops-meta-item">共 <strong>{{ logList.length }}</strong> 条</span>
          <span class="ops-meta-item">成功 <strong>{{ successCount }}</strong></span>
          <span class="ops-meta-item">处理中 <strong>{{ pendingCount }}</strong></span>
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
        <label>调用状态</label>
        <Select
          v-model:value="filterForm.status"
          placeholder="全部"
          allowClear
          style="width: 140px"
          @change="handleFilterChange"
        >
          <SelectOption value="SUCCESS">成功</SelectOption>
          <SelectOption value="FAILED">失败</SelectOption>
          <SelectOption value="PENDING">处理中</SelectOption>
        </Select>
      </div>
      <div class="ops-field">
        <label>类型</label>
        <Select
          v-model:value="filterForm.kind"
          placeholder="全部"
          allowClear
          style="width: 140px"
          @change="handleFilterChange"
        >
          <SelectOption value="SERVICE">服务</SelectOption>
          <SelectOption value="PROPERTY">属性</SelectOption>
        </Select>
      </div>
      <div class="ops-field ops-field-grow">
        <label>名称 / 标识</label>
        <Input
          v-model:value="filterForm.serviceName"
          placeholder="服务名或属性设置"
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
          <span class="ops-count">({{ filteredLogs.length }})</span>
        </div>
      </div>
      <div class="ops-surface-body" ref="logContainerRef">
        <div v-if="filteredLogs.length === 0" class="ops-empty">
          <Icon icon="ant-design:inbox-outlined" class="ops-empty-icon" />
          <p>{{ isIndustrialProtocol ? '暂无点位写入记录' : '暂无指令日志' }}</p>
          <p class="ops-empty-hint">
            {{
              isIndustrialProtocol
                ? '在「寄存器操作」写入点位后，此处显示请求与响应'
                : '在「功能调用」下发属性或服务后，此处显示 PENDING / 设备 ACK'
            }}
          </p>
        </div>
        <div v-else class="ops-list">
          <div
            v-for="(log, index) in filteredLogs"
            :key="log.id || index"
            class="ops-row"
            :class="getLogItemClass(log)"
          >
            <div class="ops-card">
              <div class="ops-card-top">
                <span class="ops-time">{{ formatTime(log.createTime) }}</span>
                <Tag :color="getStatusColor(log.status)">
                  {{ getStatusText(log.status) }}
                </Tag>
                <Tag v-if="log.kind === 'PROPERTY'" color="purple">属性</Tag>
                <Tag v-else color="blue">服务</Tag>
              </div>
              <h4 class="ops-name">
                {{ log.serviceName || '--' }}
                <span class="ops-code">({{ log.serviceIdentification || '--' }})</span>
              </h4>
              <div v-if="log.requestId" class="request-id">requestId: {{ log.requestId }}</div>
              <div class="param-grid">
                <div class="param-box">
                  <div class="param-label">调用参数</div>
                  <pre>{{ formatParam(log.inputParams) }}</pre>
                </div>
                <div class="param-box">
                  <div class="param-label">返回结果</div>
                  <pre>{{ formatParam(log.outputParams) }}</pre>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { getServices } from '@/api/device/entity-views';
import moment from 'moment';
import { Input, Select, SelectOption, Tag, DatePicker } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button';

const { RangePicker } = DatePicker;

defineOptions({ name: 'DeviceService' });

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
  status: undefined as string | undefined,
  kind: undefined as string | undefined,
  serviceName: undefined as string | undefined,
  timeRange: undefined as any,
});

const logList = ref<any[]>([]);
const loading = ref(false);
const logContainerRef = ref<HTMLElement | null>(null);
let pollTimer: ReturnType<typeof setInterval> | null = null;

const filteredLogs = computed(() => {
  if (!filterForm.kind) return logList.value;
  return logList.value.filter((item) => {
    const kind = item.kind || (item.serviceIdentification === '$property.set' ? 'PROPERTY' : 'SERVICE');
    return kind === filterForm.kind;
  });
});

const successCount = computed(
  () => filteredLogs.value.filter((item) => item.status === 'SUCCESS').length,
);
const pendingCount = computed(
  () => filteredLogs.value.filter((item) => item.status === 'PENDING').length,
);

const fetchServiceData = async (silent = false) => {
  if (!silent) loading.value = true;
  try {
    const params: any = {
      deviceId: deviceId.value,
      page: 1,
      pageSize: 1000,
    };

    if (filterForm.status) {
      params.status = filterForm.status;
    }
    if (filterForm.serviceName) {
      params.serviceName = filterForm.serviceName;
    }
    if (filterForm.timeRange && filterForm.timeRange.length === 2) {
      params.startTime = moment(filterForm.timeRange[0]).format('YYYY-MM-DD HH:mm:ss');
      params.endTime = moment(filterForm.timeRange[1]).format('YYYY-MM-DD HH:mm:ss');
    }

    const response = await getServices(params);
    const data = Array.isArray(response)
      ? response
      : response?.rows || response?.data || response?.list || [];

    logList.value = data.sort((a, b) => {
      const timeA = moment(a.createTime).valueOf();
      const timeB = moment(b.createTime).valueOf();
      return timeB - timeA;
    });
  } catch (error) {
    console.error('获取指令日志数据失败:', error);
    if (!silent) createMessage.error('获取指令日志失败');
    logList.value = [];
  } finally {
    if (!silent) loading.value = false;
  }
};

const handleFilterChange = () => {
  fetchServiceData();
};

const handleReset = () => {
  filterForm.status = undefined;
  filterForm.kind = undefined;
  filterForm.serviceName = undefined;
  filterForm.timeRange = undefined;
  fetchServiceData();
};

const refreshLogs = () => {
  fetchServiceData();
};

const formatTime = (time: string) => {
  if (!time) return '--';
  return moment(time).format('YYYY-MM-DD HH:mm:ss');
};

const formatParam = (param: any) => {
  if (!param) return '--';
  if (typeof param === 'object') {
    return JSON.stringify(param, null, 2);
  }
  return param;
};

const getStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    SUCCESS: '成功',
    FAILED: '失败',
    PENDING: '处理中',
  };
  return statusMap[status] || status || '--';
};

const getStatusColor = (status: string) => {
  const colorMap: Record<string, string> = {
    SUCCESS: 'green',
    FAILED: 'red',
    PENDING: 'blue',
  };
  return colorMap[status] || 'default';
};

const getLogItemClass = (log: any) => {
  return {
    'is-success': log.status === 'SUCCESS',
    'is-failed': log.status === 'FAILED',
    'is-pending': log.status === 'PENDING',
  };
};

watch(
  logList,
  () => {
    if (logContainerRef.value) {
      logContainerRef.value.scrollTop = 0;
    }
    const pending = logList.value.some((l) => l.status === 'PENDING');
    if (pending && !pollTimer) {
      pollTimer = setInterval(() => fetchServiceData(true), 3000);
    } else if (!pending && pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
    }
  },
  { deep: true },
);

onMounted(() => {
  fetchServiceData();
});

onUnmounted(() => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
});
</script>

<style lang="less" scoped>
.param-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;

  @media (max-width: 900px) {
    grid-template-columns: 1fr;
  }
}

.request-id {
  margin-bottom: 8px;
  font-size: 12px;
  color: #8c8c8c;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
}

.param-box {
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 4px;
  padding: 8px 10px;

  .param-label {
    font-size: 12px;
    font-weight: 500;
    color: #8c8c8c;
    margin-bottom: 4px;
  }

  pre {
    margin: 0;
    font-size: 12px;
    line-height: 1.55;
    color: #595959;
    white-space: pre-wrap;
    word-break: break-word;
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    max-height: 160px;
    overflow: auto;
  }
}
</style>

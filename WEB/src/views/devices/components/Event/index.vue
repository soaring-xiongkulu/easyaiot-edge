<template>
  <div class="ops-page">
    <div class="ops-header">
      <div class="ops-header-main">
        <h2 class="ops-header-title">{{ isIndustrialProtocol ? '采集事件' : '事件日志' }}</h2>
        <div class="ops-header-meta">
          <span class="ops-meta-item">共 <strong>{{ logList.length }}</strong> 条</span>
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
        <label>事件类型</label>
        <Select
          v-model:value="filterForm.eventType"
          placeholder="全部"
          allowClear
          style="width: 140px"
          @change="handleFilterChange"
        >
          <SelectOption value="INFO">信息</SelectOption>
          <SelectOption value="WARN">警告</SelectOption>
          <SelectOption value="ERROR">错误</SelectOption>
        </Select>
      </div>
      <div class="ops-field ops-field-grow">
        <label>事件名称</label>
        <Input
          v-model:value="filterForm.eventName"
          placeholder="输入事件名称后回车查询"
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
          <p>{{ isIndustrialProtocol ? '暂无采集异常，当前未产生工业协议事件' : '暂无事件日志' }}</p>
          <p class="ops-empty-hint">
            {{ isIndustrialProtocol ? '连接、轮询和点位采集异常会显示在此' : '请确认设备或 mqtt-demo 已上报 /event/upstream/report' }}
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
                <Tag :color="getEventTypeColor(log.eventType)">
                  {{ getEventTypeText(log.eventType) }}
                </Tag>
              </div>
              <h4 class="ops-name">{{ log.eventName || '--' }}</h4>
              <div class="ops-preview">{{ formatLogContent(log) }}</div>
              <div class="ops-card-foot">
                <span>设备标识: {{ log.deviceIdentification || '--' }}</span>
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
import { getEventList } from '@/api/device/entity-views';
import moment from 'moment';
import { Input, Select, SelectOption, Tag, DatePicker } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button';

const { RangePicker } = DatePicker;

defineOptions({ name: 'DeviceEvent' });

const props = defineProps<{ device?: Record<string, any> }>();
const isIndustrialProtocol = computed(() =>
  ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'].includes(props.device?.protocolType),
);

const route = useRoute();
const { createMessage } = useMessage();

const deviceId = computed(() => route.params?.id as string);

const filterForm = reactive({
  eventType: undefined,
  eventName: undefined,
  timeRange: undefined,
});

const logList = ref<any[]>([]);
const loading = ref(false);
const logContainerRef = ref<HTMLElement | null>(null);
const expandedMap = reactive<Record<number, boolean>>({});

const fetchEventData = async () => {
  loading.value = true;
  try {
    const params: any = {
      deviceId: deviceId.value,
      page: 1,
      pageSize: 1000,
    };

    if (filterForm.eventType) {
      params.eventType = filterForm.eventType;
    }
    if (filterForm.eventName) {
      params.eventName = filterForm.eventName;
    }
    if (filterForm.timeRange && filterForm.timeRange.length === 2) {
      params.startTime = moment(filterForm.timeRange[0]).format('YYYY-MM-DD HH:mm:ss');
      params.endTime = moment(filterForm.timeRange[1]).format('YYYY-MM-DD HH:mm:ss');
    }

    const response = await getEventList(params);
    const data = Array.isArray(response)
      ? response
      : response?.rows || response?.data || response?.list || [];

    logList.value = data.sort((a, b) => {
      const timeA = moment(a.createTime).valueOf();
      const timeB = moment(b.createTime).valueOf();
      return timeB - timeA;
    });
    Object.keys(expandedMap).forEach((k) => delete expandedMap[Number(k)]);
  } catch (error) {
    console.error('获取事件日志数据失败:', error);
    createMessage.error('获取事件日志失败');
    logList.value = [];
  } finally {
    loading.value = false;
  }
};

const handleFilterChange = () => {
  fetchEventData();
};

const handleReset = () => {
  filterForm.eventType = undefined;
  filterForm.eventName = undefined;
  filterForm.timeRange = undefined;
  fetchEventData();
};

const refreshLogs = () => {
  fetchEventData();
};

const formatTime = (time: string) => {
  if (!time) return '--';
  return moment(time).format('YYYY-MM-DD HH:mm:ss');
};

const formatLogContent = (log: any) => {
  const content = log.message ?? log.eventContent;
  if (content) {
    if (typeof content === 'object') {
      return JSON.stringify(content, null, 2);
    }
    return content;
  }
  return '--';
};

const getEventTypeText = (type: string) => {
  const typeMap: Record<string, string> = {
    INFO: '信息',
    WARN: '警告',
    ERROR: '错误',
  };
  return typeMap[type] || type || '--';
};

const getEventTypeColor = (type: string) => {
  const colorMap: Record<string, string> = {
    INFO: 'blue',
    WARN: 'orange',
    ERROR: 'red',
  };
  return colorMap[type] || 'default';
};

const getLogItemClass = (log: any) => {
  return {
    'is-warn': log.eventType === 'WARN',
    'is-error': log.eventType === 'ERROR',
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
  fetchEventData();
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


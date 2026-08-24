<template>
  <div class="ops-page shadow-page">
    <div class="ops-header">
      <div class="ops-header-main">
        <h2 class="ops-header-title">{{ isIndustrialProtocol ? '点位影子' : '设备影子' }}</h2>
        <div class="ops-header-meta">
          <span class="ops-meta-item">设备标识<strong>{{ deviceId || '--' }}</strong></span>
          <span class="ops-meta-item">版本<strong>{{ shadowVersion || '--' }}</strong></span>
          <span class="ops-meta-item">更新时间<strong>{{ lastUpdateTime || '--' }}</strong></span>
          <span class="ops-meta-item">上报<strong>{{ reportedEntries.length }}</strong></span>
          <span class="ops-meta-item">期望<strong>{{ desiredEntries.length }}</strong></span>
          <span class="ops-meta-item">差异<strong>{{ deltaEntries.length }}</strong></span>
        </div>
      </div>
      <div class="ops-header-actions">
        <Button @click="copyJson" :disabled="!shadowData" preIcon="ant-design:copy-outlined">
          复制 JSON
        </Button>
        <Button @click="isFormatted = !isFormatted" :disabled="!shadowData" preIcon="ant-design:format-painter-outlined">
          {{ isFormatted ? '压缩' : '格式化' }}
        </Button>
        <Button type="primary" @click="refreshShadow" :loading="loading" preIcon="ant-design:reload-outlined">
          刷新
        </Button>
      </div>
    </div>

    <div class="ops-split">
      <div class="ops-surface">
        <div class="ops-surface-head">
          <div class="ops-surface-title">
            影子对比
            <span class="ops-count">(上报 {{ reportedEntries.length }} / 期望 {{ desiredEntries.length }})</span>
          </div>
          <Segmented
            v-model:value="viewScope"
            :options="[
              { label: '上报', value: 'reported' },
              { label: '期望', value: 'desired' },
              { label: '差异', value: 'delta' },
            ]"
            size="small"
          />
        </div>
        <div class="ops-surface-body">
          <div v-if="scopedEntries.length === 0" class="ops-empty">
            <Icon icon="ant-design:cloud-outlined" class="ops-empty-icon" />
            <p>{{ emptyHint }}</p>
            <p class="ops-empty-hint">在「功能调用」下发属性后，期望值会出现在此；设备上报后进入上报态</p>
          </div>
          <div v-else class="ops-grid">
            <div
              v-for="item in scopedEntries"
              :key="item.key"
              class="ops-kv-card"
              :class="{ 'is-delta': viewScope === 'delta' }"
            >
              <div class="ops-kv-key">{{ item.key }}</div>
              <div class="ops-kv-val">{{ formatValue(item.value) }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="ops-surface json-surface">
        <div class="ops-surface-head">
          <div class="ops-surface-title">原始 JSON</div>
        </div>
        <div class="json-body">
          <div v-if="!shadowData" class="ops-empty dark">
            <Icon icon="ant-design:inbox-outlined" class="ops-empty-icon" />
            <p>等待数据加载</p>
          </div>
          <pre v-else class="ops-json">{{ displayJson }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { Segmented } from 'ant-design-vue';
import { defHttp } from '@/utils/http/axios';
import moment from 'moment';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button';
import { getDevicethingModels } from '@/api/device/devices';

defineOptions({ name: 'DeviceShadow' });

const props = defineProps<{ device?: Record<string, any> }>();

const route = useRoute();
const { createMessage } = useMessage();

const deviceId = computed(() => route.params?.id as string);
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

const shadowData = ref<any>(null);
const reportedData = ref<Record<string, any>>({});
const desiredData = ref<Record<string, any>>({});
const deltaData = ref<Record<string, any>>({});
const shadowVersion = ref<string>('');
const lastUpdateTime = ref<string>('');
const loading = ref(false);
const isFormatted = ref(true);
const viewScope = ref<'reported' | 'desired' | 'delta'>('reported');

const toEntries = (source: Record<string, any>) =>
  Object.entries(source || {})
    .filter(([key]) => !['version', 'timestamp', 'updateTime', 'desired', 'reported', 'metadata'].includes(key))
    .map(([key, value]) => ({ key, value }));

const reportedEntries = computed(() => toEntries(reportedData.value));
const desiredEntries = computed(() => toEntries(desiredData.value));
const deltaEntries = computed(() => toEntries(deltaData.value));

const scopedEntries = computed(() => {
  if (viewScope.value === 'desired') return desiredEntries.value;
  if (viewScope.value === 'delta') return deltaEntries.value;
  return reportedEntries.value;
});

const emptyHint = computed(() => {
  if (viewScope.value === 'desired') return '暂无期望值';
  if (viewScope.value === 'delta') return '上报与期望已对齐';
  return '暂无上报影子';
});

const displayJson = computed(() => {
  const payload = {
    reported: reportedData.value,
    desired: desiredData.value,
    delta: deltaData.value,
    shadow: shadowData.value,
  };
  try {
    return isFormatted.value
      ? JSON.stringify(payload, null, 2)
      : JSON.stringify(payload);
  } catch {
    return String(shadowData.value);
  }
});

const formatValue = (value: any) => {
  if (value === null || value === undefined) return '--';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
};

async function fetchIndustrialShadow() {
  const response: any = await getDevicethingModels({ id: deviceId.value, pageNum: 1, pageSize: 1000 });
  const reported: Record<string, any> = {};
  let latestTimestamp = 0;
  (response?.data || []).forEach((item) => {
    reported[item.propertyCode] = {
      value: item.dataValue,
      timestamp: item.ts || null,
      unit: item.unit || '',
      status: item.dataValue == null ? 'NO_DATA' : 'REPORTED',
      rawData: item.rawData || null,
    };
    latestTimestamp = Math.max(latestTimestamp, Number(item.ts || 0));
  });
  let protocolConfig: Record<string, any> = {};
  try {
    protocolConfig = JSON.parse(props.device?.extension || '{}').protocolConfig || {};
  } catch (_) {
    protocolConfig = {};
  }
  reportedData.value = reported;
  desiredData.value = {};
  deltaData.value = {};
  shadowData.value = {
    protocol: protocolConfig.type || props.device?.protocolType,
    connection: {
      status: props.device?.connectStatus,
      host: protocolConfig.host,
      port: protocolConfig.port,
      serialPort: protocolConfig.serialPort,
      unitId: protocolConfig.unitId,
      endpointUrl: protocolConfig.endpointUrl,
      pollIntervalMs: protocolConfig.pollIntervalMs,
    },
    reported,
  };
  shadowVersion.value = String(latestTimestamp || '--');
  lastUpdateTime.value = latestTimestamp ? moment(latestTimestamp).format('YYYY-MM-DD HH:mm:ss') : '--';
}

const fetchShadowData = async () => {
  loading.value = true;
  try {
    shadowVersion.value = '';
    lastUpdateTime.value = '';
    if (isIndustrialProtocol.value) {
      await fetchIndustrialShadow();
      return;
    }
    defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });

    const response = await defHttp.get(
      { url: `/shadow/${deviceId.value}` },
      { isTransformResponse: true },
    );

    let data = null;
    if (Array.isArray(response)) {
      const obj: any = {};
      response.forEach((item: any) => {
        if (item.key && item.value !== undefined) {
          obj[item.key] = item.value;
        }
      });
      data = obj;
      if (response.length > 0) {
        const firstItem = response[0];
        shadowVersion.value = firstItem.version || '';
        lastUpdateTime.value = firstItem.updateTime
          ? moment(firstItem.updateTime).format('YYYY-MM-DD HH:mm:ss')
          : '';
      }
    } else if (typeof response === 'object' && response !== null) {
      const hasMetadata = Object.prototype.hasOwnProperty.call(response, 'shadow');
      data = hasMetadata ? response.shadow || {} : response;
      shadowVersion.value = response.version ?? data?.version ?? '';
      const updateTime = response.updateTime ?? data?.updateTime ?? data?.timestamp;
      if (updateTime) {
        lastUpdateTime.value = moment(updateTime).format('YYYY-MM-DD HH:mm:ss');
      }
      reportedData.value = response.reported || data?.reported || {};
      desiredData.value = response.desired || data?.desired || {};
      deltaData.value = response.delta || {};
      if (!Object.keys(reportedData.value).length && data && typeof data === 'object') {
        const flat: Record<string, any> = {};
        Object.entries(data).forEach(([k, v]) => {
          if (!['desired', 'reported', 'metadata', 'version', 'timestamp', 'updateTime'].includes(k)) {
            flat[k] = v;
          }
        });
        reportedData.value = flat;
      }
      if (!Object.keys(deltaData.value).length) {
        const delta: Record<string, any> = {};
        Object.keys(desiredData.value || {}).forEach((k) => {
          if (String(desiredData.value[k]) !== String(reportedData.value[k])) {
            delta[k] = desiredData.value[k];
          }
        });
        deltaData.value = delta;
      }
    }

    shadowData.value = data;

    if (
      !Object.keys(reportedData.value || {}).length &&
      !Object.keys(desiredData.value || {}).length
    ) {
      createMessage.warning('设备影子数据为空');
    }
  } catch (error) {
    console.error('获取设备影子数据失败:', error);
    createMessage.error('获取设备影子失败');
    shadowData.value = null;
  } finally {
    loading.value = false;
  }
};

const refreshShadow = () => {
  fetchShadowData();
};

const copyJson = async () => {
  if (!displayJson.value) return;
  try {
    await navigator.clipboard.writeText(displayJson.value);
    createMessage.success('已复制到剪贴板');
  } catch {
    const textArea = document.createElement('textarea');
    textArea.value = displayJson.value;
    textArea.style.position = 'fixed';
    textArea.style.opacity = '0';
    document.body.appendChild(textArea);
    textArea.select();
    try {
      document.execCommand('copy');
      createMessage.success('已复制到剪贴板');
    } catch {
      createMessage.error('复制失败');
    }
    document.body.removeChild(textArea);
  }
};

onMounted(() => {
  fetchShadowData();
});
</script>

<style lang="less" scoped>
.json-surface {
  .json-body {
    flex: 1;
    min-height: 0;
    overflow: auto;
    background: #1e1e1e;
  }

  .ops-empty.dark {
    color: #8c8c8c;
    p {
      color: #8c8c8c;
    }
  }
}

.prop-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.prop-list-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 10px 12px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 4px;

  .prop-list-key {
    font-size: 13px;
    color: #8c8c8c;
    min-width: 0;
    word-break: break-all;
  }

  .prop-list-val {
    font-size: 13px;
    font-weight: 600;
    color: #262626;
    text-align: right;
    word-break: break-all;
  }
}

:deep(.ops-kv-card.is-delta) {
  background: #fffbe6;
  border-color: #ffe58f;
}
</style>

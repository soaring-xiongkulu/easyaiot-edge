<template>
  <div class="operation-page">
    <section class="operation-form">
      <div class="section-heading">
        <div class="heading-icon">
          <Icon icon="ant-design:control-outlined" />
        </div>
        <div>
          <h3>{{ isIndustrialProtocol ? '寄存器操作' : '设备指令下发' }}</h3>
          <p>{{ isIndustrialProtocol ? '向可写保持寄存器或线圈下发点位值' : '调用设备物模型服务或发送自定义服务指令' }}</p>
        </div>
        <Tag :color="device.connectStatus === 'ONLINE' ? 'success' : 'error'">
          {{ device.connectStatus === 'ONLINE' ? '设备在线' : '设备离线' }}
        </Tag>
      </div>

      <div class="form-body">
        <div class="operation-guide">
          <div class="guide-title">
            <Icon icon="ant-design:info-circle-outlined" />
            <span>调用说明</span>
          </div>
          <div class="guide-items">
            <template v-if="isIndustrialProtocol">
              <span><b>1</b> 选择可写点位（保持寄存器 / 线圈 / OPC UA 可写节点）</span>
              <span><b>2</b> 写入参数为属性 JSON，例如 { "setpoint": 30 }</span>
              <span><b>3</b> 平台经 Sink 写入现场设备，右侧可查看下发记录与 ACK</span>
            </template>
            <template v-else>
              <span><b>1</b> 选择物模型服务或填写自定义指令标识</span>
              <span><b>2</b> 指令参数必须是合法的 JSON 对象</span>
              <span><b>3</b> 发送成功后，在右侧记录中查看设备响应</span>
            </template>
          </div>
        </div>

        <div v-if="!isIndustrialProtocol" class="form-item">
          <label>指令类型</label>
          <Segmented
            v-model:value="operationType"
            :options="[
              { label: '物模型服务', value: 'model' },
              { label: '自定义指令', value: 'custom' },
            ]"
            @change="handleTypeChange"
          />
        </div>

        <div v-if="operationType === 'model'" class="form-item">
          <label>{{ isIndustrialProtocol ? '选择可写点位' : '选择服务' }} <span>*</span></label>
          <Select
            v-model:value="selectedServiceCode"
            :loading="serviceLoading"
            :placeholder="isIndustrialProtocol ? '请选择可写寄存器或线圈' : '请选择物模型服务'"
            show-search
            option-filter-prop="label"
            :options="serviceOptions"
            @change="handleServiceChange"
          />
          <div v-if="selectedService" class="field-hint">
            {{ selectedService.description || '该服务未配置描述' }}
          </div>
        </div>

        <div v-else class="form-item">
          <label>指令标识 <span>*</span></label>
          <Input
            v-model:value="customServiceCode"
            placeholder="例如：restart、set_mode"
            :maxlength="100"
          />
          <div class="field-hint">支持英文、数字、下划线和中划线</div>
        </div>

        <div class="form-item params-item">
          <div class="label-row">
            <label>{{ isIndustrialProtocol ? '写入参数' : '指令参数' }}</label>
            <Button type="link" size="small" @click="formatParams">格式化 JSON</Button>
          </div>
          <Textarea
            v-model:value="paramsText"
            :rows="10"
            placeholder='请输入 JSON 参数，例如：{ "mode": "auto" }'
            class="json-editor"
          />
          <div v-if="jsonError" class="field-error">{{ jsonError }}</div>
        </div>

        <div class="topic-preview">
          <span>下发 Topic</span>
          <code>{{ topicPreview }}</code>
        </div>

        <div class="form-actions">
          <Button @click="resetForm">重置</Button>
          <Button
            type="primary"
            :loading="submitting"
            :disabled="device.connectStatus !== 'ONLINE'"
            @click="handleSubmit"
          >
            <Icon icon="ant-design:send-outlined" />
            下发指令
          </Button>
        </div>

      </div>
    </section>

    <aside class="operation-records">
      <div class="records-heading">
        <div>
          <h3>指令记录</h3>
          <p>展示本设备最近的指令下发及设备响应</p>
        </div>
        <Button size="small" :loading="recordLoading" @click="fetchRecords">
          <Icon icon="ant-design:reload-outlined" />
          刷新
        </Button>
      </div>

      <div v-if="records.length" class="record-list">
        <div v-for="record in records" :key="record.id" class="record-item">
          <div class="record-summary">
            <div class="record-main">
              <div class="record-name">
                <strong>{{ record.serviceName || record.serviceIdentification || '--' }}</strong>
                <Tag :color="record.thingModel ? 'blue' : 'default'">
                  {{ record.thingModel ? '物模型服务' : '自定义指令' }}
                </Tag>
                <Tag :color="getStatusColor(record.status)">{{ getStatusText(record.status) }}</Tag>
              </div>
              <div class="record-meta">{{ formatRecordTime(record.createTime) }}</div>
            </div>
          </div>

          <div class="record-detail">
            <div class="detail-block">
              <span>下发信息</span>
              <pre>{{ formatRecordData(record.inputParams) }}</pre>
            </div>
            <div class="detail-block response-block">
              <span>设备响应</span>
              <pre>{{ formatRecordData(record.outputParams) }}</pre>
            </div>
          </div>
        </div>
      </div>
      <div v-else class="records-empty">
        <Icon icon="ant-design:inbox-outlined" />
        <span>暂无指令记录</span>
      </div>
    </aside>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import moment from 'moment';
import {
  Input,
  Segmented,
  Select,
  Tag,
  Textarea,
} from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { getServicesList } from '@/api/device/phsyicalModal';
import { getServices } from '@/api/device/entity-views';
import { invokeDeviceService, setDeviceProperties } from '@/api/device/devices';

defineOptions({ name: 'DeviceOperation' });

const props = defineProps<{ device: Record<string, any> }>();
const { createMessage } = useMessage();

const operationType = ref<'model' | 'custom'>('model');
const services = ref<any[]>([]);
const selectedServiceCode = ref<string>();
const customServiceCode = ref('');
const paramsText = ref('{}');
const jsonError = ref('');
const serviceLoading = ref(false);
const submitting = ref(false);
const records = ref<any[]>([]);
const recordLoading = ref(false);
let refreshTimer: ReturnType<typeof setTimeout> | undefined;

const industrialConfig = computed(() => {
  try {
    return JSON.parse(props.device.extension || '{}').protocolConfig || {};
  } catch (_) {
    return {};
  }
});
const isIndustrialProtocol = computed(() =>
  ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'].includes(
    industrialConfig.value.type || props.device.protocolType,
  ),
);

const serviceOptions = computed(() =>
  services.value.map((item) => ({ label: `${item.serviceName}（${item.serviceCode}）`, value: item.serviceCode })),
);
const selectedService = computed(() =>
  services.value.find((item) => item.serviceCode === selectedServiceCode.value),
);
const serviceIdentifier = computed(() =>
  operationType.value === 'model' ? selectedServiceCode.value || '' : customServiceCode.value.trim(),
);
const topicPreview = computed(() => {
  const product = props.device.productIdentification || '{product}';
  const device = props.device.deviceIdentification || '{device}';
  if (isIndustrialProtocol.value) {
    return `/iot/${product}/${device}/property/downstream/desired/set`;
  }
  const identifier = serviceIdentifier.value || '{identifier}';
  return `/iot/${product}/${device}/service/downstream/invoke/${identifier}`;
});

async function loadServices() {
  if (isIndustrialProtocol.value) {
    const protocolType = industrialConfig.value.type || props.device.protocolType;
    services.value = (industrialConfig.value.points || [])
      .filter((point) => point.writable)
      .map((point) => {
        const propertyCode = String(point.propertyCode || point.identifier || '').trim();
        const pointName = String(point.identifier || propertyCode).trim();
        return {
          serviceName: pointName,
          serviceCode: propertyCode,
          description:
            protocolType === 'OPCUA'
              ? `绑定 ${propertyCode} · NodeId ${point.nodeId || '--'} · ${point.dataType || 'AUTO'}`
              : `绑定 ${propertyCode} · ${point.function || 'HOLDING_REGISTER'} · 地址 ${point.address ?? '--'} · ${point.dataType || '--'}`,
          industrialPoint: point,
        };
      });
    operationType.value = 'model';
    return;
  }
  if (!props.device.productIdentification) return;
  serviceLoading.value = true;
  try {
    const response = await getServicesList({
      productIdentification: props.device.productIdentification,
      status: '0',
      pageNum: 1,
      pageSize: 1000,
    });
    services.value = response?.data || [];
  } catch (error) {
    services.value = [];
    createMessage.error('获取物模型服务失败');
  } finally {
    serviceLoading.value = false;
  }
}

async function fetchRecords() {
  if (!props.device.id) return;
  recordLoading.value = true;
  try {
    const response = await getServices({ deviceId: props.device.id, page: 1, pageSize: 20 });
    const fetchedRecords = response?.data || response?.list || [];
    const unresolved = records.value.filter(
      (pending) =>
        pending.status === 'PENDING' &&
        !fetchedRecords.some(
          (record) =>
            (record.serviceIdentification || record.serviceName) === pending.serviceIdentification &&
            moment(record.createTime).valueOf() >= moment(pending.createTime).valueOf(),
        ),
    );
    records.value = [...unresolved, ...fetchedRecords].sort(
      (a, b) => moment(b.createTime).valueOf() - moment(a.createTime).valueOf(),
    );
  } catch (error) {
    records.value = [];
    createMessage.error('获取指令记录失败');
  } finally {
    recordLoading.value = false;
  }
}

function getStatusText(status: string) {
  return { SUCCESS: '响应成功', FAILED: '响应失败', PENDING: '等待响应' }[status] || status || '--';
}

function getStatusColor(status: string) {
  return { SUCCESS: 'success', FAILED: 'error', PENDING: 'processing' }[status] || 'default';
}

function formatRecordTime(time: string) {
  return time ? moment(time).format('YYYY-MM-DD HH:mm:ss') : '--';
}

function formatRecordData(value: any) {
  if (value === undefined || value === null || value === '') return '暂无数据';
  if (typeof value === 'object') return JSON.stringify(value, null, 2);
  try {
    return JSON.stringify(JSON.parse(value), null, 2);
  } catch (error) {
    return String(value);
  }
}

function parseParams() {
  jsonError.value = '';
  try {
    const value = JSON.parse(paramsText.value || '{}');
    if (!value || Array.isArray(value) || typeof value !== 'object') {
      throw new Error('指令参数必须是 JSON 对象');
    }
    return value;
  } catch (error: any) {
    jsonError.value = error.message || 'JSON 格式不正确';
    return null;
  }
}

function formatParams() {
  const value = parseParams();
  if (value) paramsText.value = JSON.stringify(value, null, 2);
}

function handleTypeChange() {
  jsonError.value = '';
}

function handleServiceChange() {
  jsonError.value = '';
  if (isIndustrialProtocol.value && selectedServiceCode.value) {
    const point = selectedService.value?.industrialPoint || {};
    const defaultValue =
      String(point.function || '').toUpperCase() === 'COIL' ||
      String(point.dataType || '').toUpperCase() === 'BOOLEAN'
        ? false
        : 0;
    paramsText.value = JSON.stringify({ [selectedServiceCode.value]: defaultValue }, null, 2);
  }
}

function resetForm() {
  selectedServiceCode.value = undefined;
  customServiceCode.value = '';
  paramsText.value = '{}';
  jsonError.value = '';
}

function normalizeIndustrialPayload(params: Record<string, any>) {
  if (params.properties && typeof params.properties === 'object' && !Array.isArray(params.properties)) {
    return params.properties as Record<string, any>;
  }
  return params;
}

async function handleSubmit() {
  if (!serviceIdentifier.value) {
    createMessage.warning(
      isIndustrialProtocol.value ? '请选择可写点位' : '请选择服务或填写指令标识',
    );
    return;
  }
  const params = parseParams();
  if (!params) return;

  submitting.value = true;
  try {
    const submittedAt = moment().format('YYYY-MM-DD HH:mm:ss');
    if (isIndustrialProtocol.value) {
      const payload = normalizeIndustrialPayload(params);
      if (!(serviceIdentifier.value in payload)) {
        payload[serviceIdentifier.value] = Object.values(payload)[0] ?? 0;
      }
      await setDeviceProperties(props.device.id, payload);
    } else {
      await invokeDeviceService(props.device.id, serviceIdentifier.value, params);
    }
    records.value.unshift({
      id: `pending-${Date.now()}`,
      serviceName: serviceIdentifier.value,
      serviceIdentification: isIndustrialProtocol.value
        ? '$property.set'
        : serviceIdentifier.value,
      thingModel: operationType.value === 'model' || isIndustrialProtocol.value,
      status: 'PENDING',
      createTime: submittedAt,
      inputParams: { topic: topicPreview.value, params },
      outputParams: null,
    });
    createMessage.success('指令已发送，设备响应将自动更新到下方记录');
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(fetchRecords, 1200);
    setTimeout(fetchRecords, 4000);
  } catch (error) {
    createMessage.error('指令发送失败');
  } finally {
    submitting.value = false;
  }
}

watch(
  () => props.device.productIdentification,
  (productIdentification) => {
    if (productIdentification && productIdentification !== '--') loadServices();
  },
  { immediate: true },
);

watch(
  () => props.device.id,
  (deviceId) => {
    if (deviceId && deviceId !== '--') fetchRecords();
  },
  { immediate: true },
);

onBeforeUnmount(() => clearTimeout(refreshTimer));
</script>

<style lang="less" scoped>
.operation-page {
  display: grid;
  grid-template-columns: minmax(520px, 0.95fr) minmax(460px, 1.05fr);
  gap: 16px;
  height: 100%;
  min-height: 520px;
  padding-top: 4px;
}

.operation-records {
  min-width: 0;
  overflow: hidden;
  border: 1px solid #e8ebf0;
  border-radius: 6px;
  background: #fff;
}

.records-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
  border-bottom: 1px solid #eef0f3;
}

.records-heading h3,
.records-heading p {
  margin: 0;
}

.records-heading h3 {
  color: #182230;
  font-size: 15px;
}

.records-heading p {
  margin-top: 3px;
  color: #8a94a6;
  font-size: 12px;
}

.record-list {
  max-height: 680px;
  overflow-y: auto;
}

.record-item {
  padding: 16px 18px;
  border-bottom: 1px solid #eef0f3;
}

.record-item:last-child {
  border-bottom: 0;
}

.record-summary,
.record-name {
  display: flex;
  align-items: center;
}

.record-summary {
  justify-content: space-between;
}

.record-name {
  gap: 8px;
}

.record-name strong {
  color: #182230;
  font-size: 14px;
}

.record-meta {
  margin-top: 5px;
  color: #98a2b3;
  font-size: 12px;
}

.record-detail {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-top: 14px;
}

.detail-block {
  min-width: 0;
  padding: 12px;
  border: 1px solid #e8ebf0;
  border-radius: 6px;
  background: #f8fafc;
}

.detail-block > span {
  display: block;
  margin-bottom: 8px;
  color: #667085;
  font-size: 12px;
  font-weight: 500;
}

.detail-block pre {
  margin: 0;
  overflow: auto;
  color: #344054;
  font-family: Consolas, 'Courier New', monospace;
  font-size: 12px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-all;
}

.response-block {
  border-color: #d9eadf;
  background: #f6fbf7;
}

.records-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 8px;
  min-height: 150px;
  color: #98a2b3;
}

.records-empty .app-iconify {
  font-size: 28px;
}

.operation-form,
.operation-records {
  overflow: hidden;
  border: 1px solid #e8ebf0;
  border-radius: 6px;
  background: #fff;
}

.section-heading {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px 20px;
  border-bottom: 1px solid #eef0f3;
}

.section-heading h3,
.section-heading p {
  margin: 0;
}

.section-heading h3 {
  color: #182230;
  font-size: 16px;
}

.section-heading p {
  margin-top: 3px;
  color: #8a94a6;
  font-size: 12px;
}

.section-heading .ant-tag {
  margin-left: auto;
}

.heading-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 6px;
  color: #1677ff;
  background: #eaf3ff;
  font-size: 18px;
}

.form-body {
  max-width: 760px;
  padding: 20px;
}

.form-item {
  margin-bottom: 18px;
}

.form-item > label,
.label-row label {
  display: block;
  margin-bottom: 8px;
  color: #344054;
  font-size: 13px;
  font-weight: 500;
}

.form-item label span {
  color: #ff4d4f;
}

.form-item :deep(.ant-select),
.form-item :deep(.ant-input) {
  width: 100%;
}

.label-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.field-hint {
  margin-top: 6px;
  color: #98a2b3;
  font-size: 12px;
}

.field-error {
  margin-top: 6px;
  color: #ff4d4f;
  font-size: 12px;
}

.json-editor {
  font-family: Consolas, 'Courier New', monospace;
  line-height: 1.6;
}

.topic-preview {
  padding: 12px 14px;
  border: 1px solid #d9e8ff;
  border-radius: 6px;
  background: #f6f9ff;
}

.topic-preview span {
  display: block;
  margin-bottom: 6px;
  color: #667085;
  font-size: 12px;
}

.topic-preview code {
  color: #175cd3;
  word-break: break-all;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 20px;
}

.operation-guide {
  margin-bottom: 18px;
  padding: 12px 14px;
  border: 1px solid #d9e8ff;
  border-radius: 6px;
  background: #f6f9ff;
}

.guide-title {
  display: flex;
  align-items: center;
  gap: 7px;
  color: #175cd3;
  font-size: 13px;
  font-weight: 600;
}

.guide-items {
  display: flex;
  flex-direction: column;
  gap: 7px;
  margin-top: 10px;
  color: #667085;
  font-size: 12px;
}

.guide-items b {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  margin-right: 5px;
  border-radius: 50%;
  color: #1677ff;
  background: #e5efff;
  font-size: 11px;
}

@media (max-width: 1000px) {
  .operation-page {
    grid-template-columns: 1fr;
  }

  .record-detail {
    grid-template-columns: 1fr;
  }
}
</style>

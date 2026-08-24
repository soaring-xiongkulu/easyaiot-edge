<template>
  <div class="ops-page control-page">
    <div class="control-toolbar">
      <div class="ops-header-meta">
        <span class="ops-meta-item">
          连接
          <Tag :color="isOnline ? 'success' : 'default'" class="status-tag">
            {{ isOnline ? '在线' : '离线' }}
          </Tag>
        </span>
        <span class="ops-meta-item">可写属性<strong>{{ writableProps.length }}</strong></span>
        <span class="ops-meta-item">未同步<strong>{{ dirtyCount }}</strong></span>
        <span class="ops-meta-item">服务<strong>{{ services.length }}</strong></span>
      </div>
      <div class="ops-header-actions">
        <Button @click="loadAll" :loading="loadingMeta || loadingShadow" preIcon="ant-design:reload-outlined">
          刷新
        </Button>
        <Button
          type="primary"
          :disabled="dirtyCount === 0"
          :loading="settingProps"
          @click="handleSetChanged"
        >
          下发变更 ({{ dirtyCount }})
        </Button>
      </div>
    </div>

    <Alert
      v-if="isSubset"
      type="info"
      show-icon
      class="offline-alert"
      message="子设备经网关代理控制"
      :description="subsetControlHint"
    />
    <Alert
      v-else-if="!isOnline"
      type="warning"
      show-icon
      class="offline-alert"
      message="设备当前离线"
      :description="
        cameraMode
          ? '指令仍会下发并写入期望影子；设备上线后可按协议拉取/接收。'
          : '指令仍会下发并写入期望影子；设备上线后可按协议拉取/接收。请在右侧「最近指令」跟踪 PENDING/ACK。'
      "
    />

    <div class="ops-split control-split" :class="{ 'camera-mode': cameraMode }">
      <div class="control-main">
        <div class="ops-surface section-surface">
          <div class="ops-surface-head">
            <div class="ops-surface-title">
              可写属性
              <span class="ops-count">({{ writableProps.length }})</span>
            </div>
            <div class="head-actions">
              <Button size="small" type="link" :disabled="dirtyCount === 0" @click="resetDirty">
                重置变更
              </Button>
            </div>
          </div>
          <div class="ops-surface-body">
            <div v-if="writableProps.length === 0" class="ops-empty compact">
              <Icon icon="ant-design:edit-outlined" class="ops-empty-icon" />
              <p>暂无可写属性</p>
              <p class="ops-empty-hint">物模型访问模式含 W（RW / RWE）的属性会出现在这里</p>
            </div>
            <div v-else class="prop-table">
              <div class="prop-table-head">
                <span class="col-name">属性</span>
                <span class="col-reported">上报值</span>
                <span class="col-desired">期望值</span>
                <span class="col-input">设定值</span>
                <span class="col-action">操作</span>
              </div>
              <div
                v-for="prop in writableProps"
                :key="prop.propertyCode"
                class="prop-row"
                :class="{ dirty: isDirty(prop.propertyCode) }"
              >
                <div class="col-name">
                  <div class="prop-title">
                    {{ prop.propertyName || prop.propertyCode }}
                    <span v-if="prop.unit" class="prop-unit">{{ prop.unit }}</span>
                  </div>
                  <div class="prop-meta">
                    <code>{{ prop.propertyCode }}</code>
                    <Tag>{{ datatypeLabel(prop.datatype) }}</Tag>
                  </div>
                </div>
                <div class="col-reported mono">{{ formatDisplayValue(reportedMap[prop.propertyCode]) }}</div>
                <div class="col-desired mono" :class="{ gap: hasDelta(prop.propertyCode) }">
                  {{ formatDisplayValue(desiredMap[prop.propertyCode]) }}
                </div>
                <div class="col-input">
                  <Switch
                    v-if="resolveWidget(propMeta(prop)) === 'switch'"
                    v-model:checked="propValues[prop.propertyCode]"
                  />
                  <InputNumber
                    v-else-if="resolveWidget(propMeta(prop)) === 'number'"
                    v-model:value="propValues[prop.propertyCode]"
                    style="width: 100%"
                    :min="prop.min != null ? Number(prop.min) : undefined"
                    :max="prop.max != null ? Number(prop.max) : undefined"
                    :step="prop.step != null ? Number(prop.step) : 1"
                  />
                  <Select
                    v-else-if="resolveWidget(propMeta(prop)) === 'select'"
                    v-model:value="propValues[prop.propertyCode]"
                    style="width: 100%"
                    allow-clear
                    :options="parseEnumOptions(prop.enumlist)"
                    placeholder="请选择"
                  />
                  <Textarea
                    v-else-if="resolveWidget(propMeta(prop)) === 'json'"
                    v-model:value="propValues[prop.propertyCode]"
                    :rows="3"
                    placeholder="{ }"
                  />
                  <Input
                    v-else
                    v-model:value="propValues[prop.propertyCode]"
                    :maxlength="prop.maxlength || undefined"
                    allow-clear
                    :placeholder="`当前 ${formatDisplayValue(reportedMap[prop.propertyCode])}`"
                  />
                </div>
                <div class="col-action">
                  <Button
                    size="small"
                    type="primary"
                    ghost
                    :loading="settingCode === prop.propertyCode"
                    @click="handleSetOne(prop)"
                  >
                    下发
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="ops-surface section-surface">
          <div class="ops-surface-head">
            <div class="ops-surface-title">
              物模型服务
              <span class="ops-count">({{ services.length }})</span>
            </div>
          </div>
          <div class="ops-surface-body">
            <div v-if="services.length === 0" class="ops-empty compact">
              <Icon icon="ant-design:api-outlined" class="ops-empty-icon" />
              <p>暂无服务定义</p>
            </div>
            <div v-else class="service-grid">
              <div v-for="svc in services" :key="svc.serviceCode" class="service-card">
                <div class="service-head">
                  <div>
                    <div class="service-name">
                      {{ svc.serviceName || svc.serviceCode }}
                      <Tag v-if="(serviceSchemas[svc.serviceCode] || []).length" color="blue">
                        {{ (serviceSchemas[svc.serviceCode] || []).length }} 个入参
                      </Tag>
                      <Tag v-else>无参</Tag>
                    </div>
                    <div class="service-code">{{ svc.serviceCode }}</div>
                  </div>
                  <Button
                    type="primary"
                    :loading="invokingCode === svc.serviceCode"
                    @click="handleInvoke(svc)"
                  >
                    {{ (serviceSchemas[svc.serviceCode] || []).length ? '填写并调用' : '立即调用' }}
                  </Button>
                </div>
                <div v-if="svc._description || svc.description" class="service-desc">
                  {{ svc._description || svc.description }}
                </div>

                <div v-if="(serviceSchemas[svc.serviceCode] || []).length" class="param-fields">
                  <div
                    v-for="field in serviceSchemas[svc.serviceCode]"
                    :key="field.code"
                    class="param-field"
                  >
                    <div class="param-label">
                      {{ field.name || field.code }}
                      <span class="param-type">{{ datatypeLabel(field.datatype) }}</span>
                      <span v-if="field.unit" class="prop-unit">{{ field.unit }}</span>
                      <span v-if="field.required === 1 || field.required === true" class="req">*</span>
                    </div>
                    <Switch
                      v-if="resolveWidget(field) === 'switch'"
                      v-model:checked="serviceForm[svc.serviceCode][field.code]"
                    />
                    <InputNumber
                      v-else-if="resolveWidget(field) === 'number'"
                      v-model:value="serviceForm[svc.serviceCode][field.code]"
                      style="width: 100%"
                      :min="field.min != null ? Number(field.min) : undefined"
                      :max="field.max != null ? Number(field.max) : undefined"
                    />
                    <Select
                      v-else-if="resolveWidget(field) === 'select'"
                      v-model:value="serviceForm[svc.serviceCode][field.code]"
                      style="width: 100%"
                      allow-clear
                      :options="parseEnumOptions(field.enumlist)"
                    />
                    <Textarea
                      v-else-if="resolveWidget(field) === 'json'"
                      v-model:value="serviceForm[svc.serviceCode][field.code]"
                      :rows="2"
                    />
                    <Input
                      v-else
                      v-model:value="serviceForm[svc.serviceCode][field.code]"
                      allow-clear
                      :placeholder="field.code"
                    />
                  </div>
                </div>
                <div v-else class="no-param-hint">
                  该服务无入参定义，可直接调用；如需传参请展开下方 JSON。
                  <Collapse ghost class="json-fallback">
                    <CollapsePanel key="json" header="高级：自定义参数 JSON">
                      <Textarea
                        v-model:value="serviceParamsJson[svc.serviceCode]"
                        :rows="3"
                        placeholder='{"action":"on"}'
                      />
                    </CollapsePanel>
                  </Collapse>
                </div>
              </div>
            </div>

            <Collapse ghost class="advanced-collapse">
              <CollapsePanel key="advanced" header="高级：自定义服务标识下发">
                <Form layout="vertical">
                  <FormItem label="服务标识" required>
                    <Input v-model:value="advanced.serviceIdentifier" placeholder="如 reboot / switch" />
                  </FormItem>
                  <FormItem label="参数 JSON">
                    <Textarea v-model:value="advanced.paramsJson" :rows="4" />
                  </FormItem>
                  <Button type="dashed" block :loading="invokingAdvanced" @click="handleAdvancedInvoke">
                    下发自定义服务
                  </Button>
                </Form>
              </CollapsePanel>
            </Collapse>
          </div>
        </div>
      </div>

      <div v-if="!cameraMode" class="ops-surface result-surface">
        <div class="ops-surface-head">
          <div class="ops-surface-title">最近指令</div>
          <Button size="small" type="link" :loading="loadingLogs" @click="refreshLogs">刷新</Button>
        </div>
        <div class="ops-surface-body result-body">
          <div v-if="recentLogs.length === 0" class="result-placeholder">
            下发后将显示 PENDING / ACK；完整记录见「指令日志」
          </div>
          <div v-else class="ops-list compact-list">
            <div
              v-for="log in recentLogs"
              :key="log.id || log.requestId"
              class="ops-row"
              :class="logRowClass(log)"
            >
              <div class="ops-card">
                <div class="ops-card-top">
                  <span class="ops-time">{{ formatTime(log.createTime) }}</span>
                  <Tag :color="statusColor(log.status)">{{ statusText(log.status) }}</Tag>
                  <Tag v-if="log.kind === 'PROPERTY'" color="purple">属性</Tag>
                </div>
                <h4 class="ops-name">
                  {{ log.serviceName || '--' }}
                  <span class="ops-code">{{ log.requestId ? `#${String(log.requestId).slice(0, 8)}` : '' }}</span>
                </h4>
                <div class="ops-preview">{{ formatParamPreview(log.inputParams) }}</div>
              </div>
            </div>
          </div>

          <div class="result-block grow">
            <div class="block-label">期望差异 (delta)</div>
            <div v-if="deltaEntries.length === 0" class="result-placeholder">上报值与期望值已对齐</div>
            <div v-else class="delta-list">
              <div v-for="item in deltaEntries" :key="item.key" class="delta-item">
                <span class="delta-key">{{ item.key }}</span>
                <span class="delta-val mono">{{ formatDisplayValue(item.value) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="ops-surface monitor-surface">
        <div class="ops-surface-head">
          <div class="ops-surface-title">分屏监控</div>
          <span class="monitor-head-hint">设备目录为当前设备的关联摄像头</span>
        </div>
        <div class="ops-surface-body monitor-body">
          <DeviceSplitMonitor :iot-device-id="deviceId" />
        </div>
      </div>
    </div>

    <button
      type="button"
      class="camera-mode-fab"
      :class="{ active: cameraMode }"
      :title="cameraMode ? '切换回最近指令' : '切换摄像头模式'"
      @click="cameraMode = !cameraMode"
    >
      <Icon :icon="cameraMode ? 'ant-design:unordered-list-outlined' : 'ant-design:video-camera-outlined'" />
      <span class="fab-label">{{ cameraMode ? '指令' : '监控' }}</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue';
import { useRoute } from 'vue-router';
import {
  Alert,
  Collapse,
  CollapsePanel,
  Form,
  FormItem,
  Input,
  InputNumber,
  Select,
  Switch,
  Tag,
  Textarea,
} from 'ant-design-vue';
import moment from 'moment';
import { Icon } from '@/components/Icon';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import { defHttp } from '@/utils/http/axios';
import { getPhsyicalServiceDetail, getPropertiesList, getServicesList } from '@/api/device/phsyicalModal';
import { getServices } from '@/api/device/entity-views';
import { getDevicesInfo, invokeDeviceService, setDeviceProperties } from '@/api/device/devices';
import {
  coerceAndValidate,
  datatypeLabel,
  formatDisplayValue,
  parseEnumOptions,
  resolveWidget,
  toFormValue,
  valuesEqual,
  type ThingFieldMeta,
} from './thingModelForm';
import DeviceSplitMonitor from './DeviceSplitMonitor.vue';

defineOptions({ name: 'DeviceControl' });

const route = useRoute();
const { createMessage } = useMessage();

/** 摄像头模式：右侧「最近指令」替换为关联摄像头分屏监控 */
const cameraMode = ref(false);

const deviceId = computed(() => route.params?.id as string);
const productIdentification = ref('');
const connectStatus = ref('');
const deviceType = ref('');
const parentIdentification = ref('');

const isSubset = computed(() => String(deviceType.value).toUpperCase() === 'SUBSET');
const subsetControlHint = computed(() => {
  const gw = parentIdentification.value || '未绑定';
  return `当前为子设备，下行将发到网关 Topic（/iot/{网关}/sub/...）。所属网关：${gw}。请确保网关在线并已订阅 sub 下行 Topic。`;
});

const loadingMeta = ref(false);
const loadingShadow = ref(false);
const loadingLogs = ref(false);
const settingProps = ref(false);
const settingCode = ref('');
const invokingCode = ref('');
const invokingAdvanced = ref(false);

const writableProps = ref<any[]>([]);
const services = ref<any[]>([]);
const propValues = reactive<Record<string, any>>({});
const baselineValues = reactive<Record<string, any>>({});
const serviceForm = reactive<Record<string, Record<string, any>>>({});
const serviceParamsJson = reactive<Record<string, string>>({});
const serviceSchemas = reactive<Record<string, ThingFieldMeta[]>>({});
const advanced = reactive({
  serviceIdentifier: '',
  paramsJson: '{\n  "action": "on"\n}',
});

const reportedMap = reactive<Record<string, any>>({});
const desiredMap = reactive<Record<string, any>>({});
const deltaMap = reactive<Record<string, any>>({});
const recentLogs = ref<any[]>([]);

let pollTimer: ReturnType<typeof setInterval> | null = null;

const isOnline = computed(() => String(connectStatus.value).toUpperCase() === 'ONLINE');

const dirtyCount = computed(() =>
  writableProps.value.filter((p) => isDirty(p.propertyCode)).length,
);

const deltaEntries = computed(() =>
  Object.entries(deltaMap).map(([key, value]) => ({ key, value })),
);

const normalizeList = (response: any) => {
  if (Array.isArray(response)) return response;
  return response?.rows || response?.data || response?.list || [];
};

const isWritable = (prop: any) => {
  const mode = String(prop.method || prop.accessMode || prop.readWrite || '').toUpperCase();
  return mode.includes('W');
};

const propMeta = (prop: any): ThingFieldMeta => ({
  code: prop.propertyCode,
  name: prop.propertyName,
  datatype: prop.datatype,
  unit: prop.unit,
  min: prop.min,
  max: prop.max,
  step: prop.step,
  maxlength: prop.maxlength,
  enumlist: prop.enumlist,
  required: prop.required,
  description: prop.description,
});

const isDirty = (code: string) => !valuesEqual(propValues[code], baselineValues[code]);

const hasDelta = (code: string) =>
  Object.prototype.hasOwnProperty.call(deltaMap, code) ||
  !valuesEqual(reportedMap[code], desiredMap[code]);

const clearMaps = (target: Record<string, any>) => {
  Object.keys(target).forEach((k) => delete target[k]);
};

const applyShadowMaps = (payload: any) => {
  clearMaps(reportedMap);
  clearMaps(desiredMap);
  clearMaps(deltaMap);

  const reported = payload?.reported || payload?.shadow?.reported || {};
  const desired = payload?.desired || payload?.shadow?.desired || {};
  const delta = payload?.delta || {};

  const flatShadow =
    !payload?.reported &&
    payload?.shadow &&
    typeof payload.shadow === 'object' &&
    !payload.shadow.reported
      ? payload.shadow
      : null;

  const reportedSrc = Object.keys(reported || {}).length
    ? reported
    : flatShadow || {};

  Object.entries(reportedSrc || {}).forEach(([k, v]) => {
    if (!['desired', 'reported', 'metadata', 'version', 'timestamp', 'updateTime'].includes(k)) {
      reportedMap[k] = v;
    }
  });
  Object.entries(desired || {}).forEach(([k, v]) => {
    desiredMap[k] = v;
  });
  Object.entries(delta || {}).forEach(([k, v]) => {
    deltaMap[k] = v;
  });
  if (Object.keys(deltaMap).length === 0) {
    Object.keys(desiredMap).forEach((k) => {
      if (!valuesEqual(reportedMap[k], desiredMap[k])) {
        deltaMap[k] = desiredMap[k];
      }
    });
  }
};

const refreshShadow = async () => {
  if (!deviceId.value) return;
  loadingShadow.value = true;
  try {
    const res: any = await defHttp.get(
      { url: `/shadow/${deviceId.value}` },
      { isTransformResponse: true },
    );
    applyShadowMaps(res || {});
    if (res?.connectStatus) {
      connectStatus.value = res.connectStatus;
    }
  } catch (e) {
    console.error(e);
  } finally {
    loadingShadow.value = false;
  }
};

const loadServiceSchemas = async (svcList: any[]) => {
  await Promise.all(
    svcList.map(async (svc) => {
      const code = svc.serviceCode;
      if (!code) return;
      if (!serviceForm[code]) serviceForm[code] = {};
      if (!serviceParamsJson[code]) serviceParamsJson[code] = '{\n  \n}';
      serviceSchemas[code] = [];

      if (!svc.id) return;
      try {
        const detail: any = await getPhsyicalServiceDetail(svc.id);
        const inputs = detail?.inputParams || [];
        const fields: ThingFieldMeta[] = inputs
          .map((p: any) => ({
            code: p.parameterCode || p.propertyCode || p.parameterName || p.propertyName,
            name: p.parameterName || p.propertyName || p.parameterCode || p.propertyCode,
            datatype: p.datatype,
            unit: p.unit,
            min: p.min,
            max: p.max,
            step: p.step,
            maxlength: p.maxlength,
            enumlist: p.enumlist,
            required: p.required,
            description: p.parameterDescription || p.description,
          }))
          .filter((f: ThingFieldMeta) => !!f.code);

        fields.forEach((field) => {
          if (serviceForm[code][field.code] === undefined) {
            serviceForm[code][field.code] = toFormValue(field, undefined);
          }
        });
        serviceSchemas[code] = fields;
        svc._inputCount = fields.length;
        svc._description = detail?.description || svc.description;
      } catch (e) {
        console.warn('load service schema failed', code, e);
      }
    }),
  );
};

const loadMeta = async () => {
  if (!productIdentification.value || !connectStatus.value || !deviceType.value) {
    const info: any = await getDevicesInfo(deviceId.value);
    const device = info?.device || info;
    productIdentification.value =
      device?.productIdentification || info?.product?.productIdentification || '';
    connectStatus.value = device?.connectStatus || '';
    deviceType.value = device?.deviceType || info?.product?.productType || '';
    parentIdentification.value = device?.parentIdentification || '';
  }
  if (!productIdentification.value) {
    createMessage.warning('无法获取产品标识，物模型列表为空');
    return;
  }

  loadingMeta.value = true;
  try {
    const [propRes, svcRes] = await Promise.all([
      getPropertiesList({
        productIdentification: productIdentification.value,
        pageNum: 1,
        pageSize: 200,
      }),
      getServicesList({
        productIdentification: productIdentification.value,
        pageNum: 1,
        pageSize: 200,
      }),
    ]);
    const props = normalizeList(propRes);
    writableProps.value = props.filter(isWritable);
    writableProps.value.forEach((p) => {
      const meta = propMeta(p);
      const seed =
        desiredMap[p.propertyCode] !== undefined
          ? desiredMap[p.propertyCode]
          : reportedMap[p.propertyCode];
      const formVal = toFormValue(meta, seed);
      propValues[p.propertyCode] = formVal;
      baselineValues[p.propertyCode] =
        seed !== undefined && seed !== null ? toFormValue(meta, seed) : formVal;
    });

    services.value = normalizeList(svcRes);
    await loadServiceSchemas(services.value);
  } catch (e) {
    console.error(e);
    createMessage.error('加载物模型失败');
  } finally {
    loadingMeta.value = false;
  }
};

const refreshLogs = async () => {
  if (!deviceId.value) return;
  loadingLogs.value = true;
  try {
    const response = await getServices({
      deviceId: deviceId.value,
      page: 1,
      pageSize: 12,
    });
    const data = normalizeList(response);
    recentLogs.value = data.sort(
      (a: any, b: any) => moment(b.createTime).valueOf() - moment(a.createTime).valueOf(),
    );
  } catch (e) {
    console.error(e);
  } finally {
    loadingLogs.value = false;
  }
};

const loadAll = async () => {
  await refreshShadow();
  await loadMeta();
  await refreshLogs();
};

const resetDirty = () => {
  writableProps.value.forEach((p) => {
    propValues[p.propertyCode] = baselineValues[p.propertyCode];
  });
};

const buildPayload = (codes: string[]) => {
  const payload: Record<string, any> = {};
  for (const code of codes) {
    const prop = writableProps.value.find((p) => p.propertyCode === code);
    if (!prop) continue;
    const result = coerceAndValidate(propMeta(prop), propValues[code]);
    if (!result.ok) {
      if (result.message !== 'empty') {
        createMessage.warning(result.message);
        return null;
      }
      continue;
    }
    payload[code] = result.value;
  }
  if (Object.keys(payload).length === 0) {
    createMessage.warning('请至少设定一个属性值');
    return null;
  }
  return payload;
};

const afterDownlink = async (res: any, label: string, payload: any) => {
  const data = res?.data || res || {};
  const requestId = data.requestId || '';
  if (data.viaGateway) {
    createMessage.success(
      `${label}已经网关下发${data.gatewayIdentification ? `（网关 ${data.gatewayIdentification}）` : ''}`,
    );
  } else if (data.offline) {
    createMessage.warning(`${label}已下发（设备离线，已记入期望/指令日志）`);
  } else {
    createMessage.success(`${label}已下发`);
  }
  if (requestId) {
    // 同步基线：已下发的值视为新期望
    Object.keys(payload || {}).forEach((code) => {
      desiredMap[code] = payload[code];
      baselineValues[code] = propValues[code];
      if (!valuesEqual(reportedMap[code], desiredMap[code])) {
        deltaMap[code] = desiredMap[code];
      } else {
        delete deltaMap[code];
      }
    });
  }
  await refreshLogs();
  startPollingIfNeeded();
};

const handleSetOne = async (prop: any) => {
  const payload = buildPayload([prop.propertyCode]);
  if (!payload) return;
  settingCode.value = prop.propertyCode;
  try {
    const res = await setDeviceProperties(deviceId.value, payload);
    await afterDownlink(res, `属性 ${prop.propertyCode}`, payload);
    await refreshShadow();
  } catch (e: any) {
    createMessage.error(e?.message || '属性下发失败');
  } finally {
    settingCode.value = '';
  }
};

const handleSetChanged = async () => {
  const codes = writableProps.value.filter((p) => isDirty(p.propertyCode)).map((p) => p.propertyCode);
  const payload = buildPayload(codes);
  if (!payload) return;
  settingProps.value = true;
  try {
    const res = await setDeviceProperties(deviceId.value, payload);
    await afterDownlink(res, '属性变更', payload);
    await refreshShadow();
  } catch (e: any) {
    createMessage.error(e?.message || '属性下发失败');
  } finally {
    settingProps.value = false;
  }
};

const buildServiceParams = (svc: any) => {
  const code = svc.serviceCode;
  const schema = serviceSchemas[code] || [];
  if (!schema.length) {
    const text = (serviceParamsJson[code] || '').trim();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      createMessage.error('服务参数不是合法 JSON');
      return null;
    }
  }
  const params: Record<string, any> = {};
  for (const field of schema) {
    const result = coerceAndValidate(field, serviceForm[code]?.[field.code]);
    if (!result.ok) {
      if (result.message === 'empty') continue;
      createMessage.warning(result.message);
      return null;
    }
    params[field.code] = result.value;
  }
  return params;
};

const handleInvoke = async (svc: any) => {
  const params = buildServiceParams(svc);
  if (params === null) return;
  invokingCode.value = svc.serviceCode;
  try {
    const res = await invokeDeviceService(deviceId.value, svc.serviceCode, params);
    await afterDownlink(res, `服务 ${svc.serviceCode}`, params);
  } catch (e: any) {
    createMessage.error(e?.message || '服务调用失败');
  } finally {
    invokingCode.value = '';
  }
};

const handleAdvancedInvoke = async () => {
  if (!advanced.serviceIdentifier.trim()) {
    createMessage.warning('请填写服务标识');
    return;
  }
  let params: any = {};
  try {
    const text = (advanced.paramsJson || '').trim();
    params = text ? JSON.parse(text) : {};
  } catch {
    createMessage.error('参数必须是合法 JSON');
    return;
  }
  invokingAdvanced.value = true;
  try {
    const res = await invokeDeviceService(
      deviceId.value,
      advanced.serviceIdentifier.trim(),
      params,
    );
    await afterDownlink(res, `服务 ${advanced.serviceIdentifier}`, params);
  } catch (e: any) {
    createMessage.error(e?.message || '服务调用失败');
  } finally {
    invokingAdvanced.value = false;
  }
};

const formatTime = (time: string) => (time ? moment(time).format('MM-DD HH:mm:ss') : '--');

const formatParamPreview = (param: any) => {
  if (param == null) return '--';
  try {
    const text = typeof param === 'string' ? param : JSON.stringify(param);
    return text.length > 120 ? `${text.slice(0, 120)}…` : text;
  } catch {
    return String(param);
  }
};

const statusText = (status: string) =>
  ({ SUCCESS: '成功', FAILED: '失败', PENDING: '处理中' } as any)[status] || status || '--';

const statusColor = (status: string) =>
  ({ SUCCESS: 'green', FAILED: 'red', PENDING: 'blue' } as any)[status] || 'default';

const logRowClass = (log: any) => ({
  'is-success': log.status === 'SUCCESS',
  'is-failed': log.status === 'FAILED',
  'is-pending': log.status === 'PENDING',
});

const hasPending = () => recentLogs.value.some((l) => l.status === 'PENDING');

const startPollingIfNeeded = () => {
  if (pollTimer || !hasPending()) return;
  pollTimer = setInterval(async () => {
    await refreshLogs();
    if (!hasPending() && pollTimer) {
      clearInterval(pollTimer);
      pollTimer = null;
      await refreshShadow();
    }
  }, 2500);
};

onMounted(async () => {
  await loadAll();
  startPollingIfNeeded();
});

onUnmounted(() => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
});
</script>

<style lang="less" scoped>
.control-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  padding: 14px 20px;
  background: #ffffff;
  border: 1px solid #f0f0f0;
  border-radius: 8px;

  .ops-header-meta {
    margin-top: 0;
    gap: 8px 24px;
  }

  .ops-header-actions {
    margin-left: auto;
  }
}

.control-page {
  position: relative;
}

.control-split {
  align-items: stretch;

  &.camera-mode {
    grid-template-columns: minmax(0, 0.95fr) minmax(420px, 1.15fr);
    min-height: 520px;

    @media (max-width: 1100px) {
      grid-template-columns: 1fr;
    }
  }
}

.control-main {
  display: flex;
  flex-direction: column;
  gap: 20px;
  min-width: 0;
  min-height: 0;
  overflow: auto;
}

.monitor-surface {
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;

  .ops-surface-head {
    flex-shrink: 0;
  }
}

.monitor-head-hint {
  font-size: 12px;
  color: #8c8c8c;
}

.monitor-body {
  flex: 1;
  min-height: 0;
  padding: 0 !important;
  overflow: hidden;
}

.camera-mode-fab {
  position: absolute;
  right: 20px;
  bottom: 24px;
  z-index: 20;
  display: inline-flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  width: 56px;
  height: 56px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: #1677ff;
  color: #fff;
  box-shadow: 0 6px 16px rgba(22, 119, 255, 0.35);
  cursor: pointer;
  transition: transform 0.15s, background 0.15s, box-shadow 0.15s;

  &:hover {
    background: #4096ff;
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(22, 119, 255, 0.42);
  }

  &.active {
    background: #595959;
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.22);

    &:hover {
      background: #434343;
      box-shadow: 0 8px 20px rgba(0, 0, 0, 0.28);
    }
  }

  .fab-label {
    font-size: 11px;
    line-height: 1;
    font-weight: 500;
  }
}

.section-surface {
  flex: none;
}

.status-tag {
  margin-left: 6px;
}

.offline-alert {
  margin: 0;
}

.ops-empty.compact {
  min-height: 140px;
}

.head-actions {
  display: flex;
  gap: 4px;
}

.prop-table {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.prop-table-head,
.prop-row {
  display: grid;
  grid-template-columns: minmax(140px, 1.2fr) 0.8fr 0.8fr minmax(160px, 1.2fr) 72px;
  gap: 12px;
  align-items: center;
}

.prop-table-head {
  padding: 0 12px 8px;
  font-size: 12px;
  color: #8c8c8c;
  border-bottom: 1px solid #f0f0f0;
}

.prop-row {
  padding: 12px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 6px;
  transition: border-color 0.2s, background 0.2s;

  &.dirty {
    border-color: #91caff;
    background: #f0f7ff;
  }

  @media (max-width: 1100px) {
    grid-template-columns: 1fr;
    gap: 8px;

    .col-action {
      justify-self: start;
    }
  }
}

.prop-title {
  font-size: 13px;
  font-weight: 600;
  color: #262626;
}

.prop-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
  margin-top: 4px;

  code {
    font-size: 12px;
    color: #8c8c8c;
    background: transparent;
  }
}

.prop-unit {
  margin-left: 4px;
  font-size: 12px;
  font-weight: 400;
  color: #8c8c8c;
}

.mono {
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 12px;
  color: #595959;
  word-break: break-all;
}

.col-desired.gap {
  color: #d48806;
  font-weight: 600;
}

.service-grid {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.service-card {
  padding: 12px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 6px;

  .service-head {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
  }

  .service-name {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    font-weight: 600;
    color: #262626;
  }

  .service-code {
    margin-top: 2px;
    font-size: 12px;
    color: #8c8c8c;
  }

  .service-desc {
    margin-top: 6px;
    font-size: 12px;
    color: #8c8c8c;
  }
}

.no-param-hint {
  margin-top: 10px;
  font-size: 12px;
  color: #8c8c8c;
  line-height: 1.5;
}

.param-label .req {
  color: #ff4d4f;
  margin-left: 2px;
}

.param-fields {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 10px;
  margin-top: 12px;
}

.param-field {
  .param-label {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
    font-size: 12px;
    color: #595959;
  }

  .param-type {
    color: #bfbfbf;
  }
}

.json-fallback,
.advanced-collapse {
  margin-top: 10px;
  background: #fff;
  border-radius: 6px;
}

.result-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.compact-list {
  max-height: 320px;
  overflow: auto;
}

.result-block {
  &.grow {
    flex: 1;
    min-height: 0;
  }

  .block-label {
    font-size: 13px;
    font-weight: 600;
    color: #262626;
    margin-bottom: 8px;
  }
}

.result-placeholder {
  padding: 12px;
  border-radius: 4px;
  background: #fafafa;
  border: 1px dashed #d9d9d9;
  color: #8c8c8c;
  font-size: 13px;
  line-height: 1.5;
}

.delta-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.delta-item {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 10px;
  background: #fffbe6;
  border: 1px solid #ffe58f;
  border-radius: 4px;

  .delta-key {
    font-size: 12px;
    color: #8c8c8c;
  }
}
</style>

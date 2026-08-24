<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="drawerTitle"
    width="1280"
    placement="right"
    :showFooter="true"
    :showOkBtn="false"
    cancelText="关闭"
    @close="handleClose"
  >
    <Spin :spinning="state.scanning || state.registering">
      <div class="segment-scan-modal">
        <Alert
          type="info"
          show-icon
          class="scan-tip"
          message="填写网段与 Web 登录凭证后扫描；扫描完成后可一键批量注册凭证可访问且有 RTSP 的设备，也可在结果列表中逐台注册。"
        />
        <Form layout="vertical" class="scan-form">
          <Row :gutter="16">
            <Col :span="24" class="scan-form-field-line">
              <FormItem label="扫描目标" name="targets" required :rules="targetsFormRules">
                <SegmentScanTargetsField
                  v-model:value="form.targets"
                  :mode="state.mode"
                  :disabled="state.scanning || state.registering"
                  :refresh-token="historyRefreshToken"
                  @apply-history="applyHistoryEntry"
                />
              </FormItem>
            </Col>
            <Col :span="12" class="scan-form-field-half">
              <FormItem label="端口">
                <Input v-model:value="form.ports" placeholder="80,443,8000,8443" :disabled="state.scanning" />
              </FormItem>
            </Col>
            <Col :span="24" class="scan-form-field-line">
              <FormItem label="Web 登录凭证" required>
                <div class="credentials-block">
                  <div
                    v-for="(cred, idx) in form.credentials"
                    :key="idx"
                    class="credential-row"
                  >
                    <span class="cred-order">{{ idx + 1 }}</span>
                    <Input
                      v-model:value="cred.username"
                      placeholder="用户名"
                      :disabled="state.scanning"
                      class="cred-user"
                    />
                    <Input.Password
                      v-model:value="cred.password"
                      :placeholder="state.mode === 'nvr' ? '密码（必填）' : '密码'"
                      :disabled="state.scanning"
                      class="cred-pass"
                    />
                    <Button
                      type="link"
                      danger
                      size="small"
                      :disabled="state.scanning || form.credentials.length <= 1"
                      @click="removeCredential(idx)"
                    >
                      删除
                    </Button>
                  </div>
                  <Button type="dashed" block :disabled="state.scanning" @click="addCredential">
                    添加凭证
                  </Button>
                  <div class="cred-hint">
                    {{
                      state.mode === 'nvr'
                        ? '登记 NVR 及枚举通道须填写正确密码；按列表顺序从上到下依次尝试'
                        : '按列表顺序从上到下依次尝试，留空用户名的行将被忽略'
                    }}
                  </div>
                </div>
              </FormItem>
            </Col>
            <Col :span="6">
              <FormItem label="并发数">
                <InputNumber v-model:value="form.concurrency" :min="1" :max="2000" style="width: 100%" />
              </FormItem>
            </Col>
            <Col :span="6">
              <FormItem label="单点超时(秒)">
                <InputNumber v-model:value="form.timeout" :min="0.5" :max="30" :step="0.5" style="width: 100%" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label=" ">
                <Checkbox v-model:checked="form.only_hits">仅显示已识别的摄像头/录像机</Checkbox>
              </FormItem>
            </Col>
          </Row>
          <div class="scan-actions">
            <Button type="primary" :loading="state.scanning" @click="handleScan">
              <template #icon><SearchOutlined /></template>
              开始扫描
            </Button>
            <span v-if="state.scanProgress" class="progress-text">{{ state.scanProgress }}</span>
          </div>
        </Form>

        <Alert
          v-if="hasScanResult"
          type="success"
          show-icon
          class="result-hint"
          :message="resultHintText"
        >
          <template #action>
            <Button type="primary" size="small" @click="openResultModal(true)">查看扫描结果</Button>
          </template>
        </Alert>
      </div>
    </Spin>
  </BasicDrawer>

  <BasicModal
    @register="registerResultModal"
    :title="resultModalTitle"
    :width="1500"
    :canFullscreen="true"
    :showOkBtn="false"
    cancelText="关闭"
    :destroyOnClose="false"
    @cancel="handleResultModalClose"
  >
    <Spin :spinning="state.registering">
      <div class="segment-scan-result-modal">
        <div v-if="state.devices.length" class="result-toolbar">
          <Button
            type="primary"
            :loading="state.batchRegistering"
            :disabled="registrableCount === 0"
            @click="handleBatchRegister"
          >
            {{ batchRegisterButtonText }}
          </Button>
          <span v-if="state.batchProgress" class="batch-progress">{{ state.batchProgress }}</span>
          <span v-else-if="registrableCount > 0" class="batch-hint">
            共 {{ registrableCount }} 台可通过凭证访问{{ resultTableKind === 'camera' ? '，可批量或逐台注册' : '，可批量或逐台登记' }}
          </span>
        </div>

        <Table
          v-if="resultTableKind === 'camera'"
          :columns="cameraColumns"
          :data-source="state.devices"
          :pagination="tablePagination"
          :scroll="{ x: 1300 }"
          row-key="ip"
          size="middle"
          bordered
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.dataIndex === 'register_status'">
              <Tag :color="registerStatusColor(record.ip)">{{ registerStatusLabel(record.ip, record) }}</Tag>
            </template>
            <template v-else-if="column.dataIndex === 'action'">
              <Button
                type="link"
                size="small"
                :disabled="!canRegisterRecord(record)"
                :loading="state.registeringIp === record.ip"
                @click="handleRegisterCamera(record)"
              >
                注册
              </Button>
            </template>
          </template>
        </Table>

        <Table
          v-else-if="resultTableKind === 'nvr'"
          :columns="nvrColumns"
          :data-source="state.devices"
          :pagination="tablePagination"
          :scroll="{ x: 1200 }"
          row-key="ip"
          size="middle"
          bordered
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.dataIndex === 'register_status'">
              <Tag :color="registerStatusColor(record.ip)">{{ registerStatusLabel(record.ip, record) }}</Tag>
            </template>
            <template v-else-if="column.dataIndex === 'action'">
              <Button
                type="link"
                size="small"
                :disabled="!canRegisterRecord(record)"
                :loading="state.registeringIp === record.ip"
                @click="handleRegisterNvrWithChannels(record)"
              >
                登记NVR及通道
              </Button>
            </template>
          </template>
        </Table>
      </div>
    </Spin>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, reactive, ref } from 'vue';
import {
  Alert,
  Checkbox,
  Col,
  Form,
  FormItem,
  Input,
  InputNumber,
  Row,
  Spin,
  Table,
  Tag,
} from 'ant-design-vue';
import { SearchOutlined } from '@ant-design/icons-vue';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { BasicModal, useModal } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import {
  registerDevice,
  registerNvrWithChannels,
  type NvrInfo,
  scanSegmentDevices,
  type CredentialPair,
  type SegmentScanDeviceRow,
} from '@/api/device/camera';
import {
  getCameraScanColumns,
  getNvrScanColumns,
} from './Data';
import {
  hasSegmentScanRegisterPayload,
  isSegmentScanCredentialAccessible,
  resolveSegmentScanRtsp,
} from '@/views/camera/utils/segmentScanRegister';
import {
  cloneCredentials,
  saveSegmentScanHistory,
  type SegmentScanHistoryEntry,
} from '@/views/camera/utils/segmentScanHistory';
import {
  formatNvrRegisterHint,
  nvrRegisterRegisteredCount,
} from '@/views/camera/utils/nvrRegisterMessage';
import SegmentScanTargetsField from '@/views/camera/components/DeviceCreate/SegmentScanTargetsField.vue';
import { Button } from '@/components/Button'
import {
computeSegmentScanWallSeconds,
  segmentScanTargetsFormRule,
  validateSegmentScanTargets,
} from '@/views/camera/utils/segmentScanTargetsValidate';

defineOptions({ name: 'SegmentScanModal' });

const props = defineProps<{
  mode?: 'camera' | 'nvr';
}>();

const emit = defineEmits(['success']);

const { createMessage } = useMessage();

type RegisterStatus = 'idle' | 'success' | 'failed' | 'skipped';

const state = reactive({
  mode: 'camera' as 'camera' | 'nvr',
  scanning: false,
  registering: false,
  batchRegistering: false,
  registeringIp: '' as string,
  devices: [] as SegmentScanDeviceRow[],
  scanProgress: '',
  batchProgress: '',
  /** ip -> 注册结果 */
  registerStatusMap: {} as Record<string, RegisterStatus>,
});

const form = reactive({
  targets: '',
  ports: '80,443,8000,8443',
  credentials: [{ username: 'admin', password: '' }] as CredentialPair[],
  concurrency: 200,
  timeout: 3,
  only_hits: true,
});

const historyRefreshToken = ref(0);

const targetsFormRules = [
  segmentScanTargetsFormRule(() => form.ports.trim() || undefined),
];

function applyHistoryEntry(entry: SegmentScanHistoryEntry) {
  form.targets = entry.targets;
  form.ports = entry.ports;
  form.concurrency = entry.concurrency;
  form.timeout = entry.timeout;
  form.only_hits = entry.only_hits;
  const creds = cloneCredentials(entry.credentials);
  form.credentials.splice(0, form.credentials.length, ...(creds.length ? creds : [{ username: 'admin', password: '' }]));
  state.devices = [];
  resetRegisterStatus();
}

function persistScanHistory(deviceCount: number) {
  saveSegmentScanHistory({
    mode: state.mode,
    targets: form.targets.trim(),
    ports: form.ports.trim() || '80,443,8000,8443',
    credentials: getValidCredentials(),
    concurrency: form.concurrency,
    timeout: form.timeout,
    only_hits: form.only_hits,
    lastDeviceCount: deviceCount,
  });
  historyRefreshToken.value += 1;
}

function getValidCredentials(): CredentialPair[] {
  return form.credentials
    .map((c) => ({ username: (c.username || '').trim(), password: c.password || '' }))
    .filter((c) => c.username);
}

function hasNvrRegisterPassword(): boolean {
  return getValidCredentials().some((c) => !!c.password);
}

function resolveCredential(authUsername?: string): CredentialPair {
  const list = getValidCredentials();
  if (authUsername) {
    const found = list.find((c) => c.username === authUsername);
    if (found) return found;
  }
  return list[0];
}

function hasFormCredentials(): boolean {
  return getValidCredentials().length > 0;
}

function isCredentialAccessible(record: SegmentScanDeviceRow): boolean {
  return isSegmentScanCredentialAccessible(record, state.mode, hasFormCredentials());
}

function hasRegisterPayload(record: SegmentScanDeviceRow): boolean {
  const cred = resolveCredential(record.auth_username);
  return hasSegmentScanRegisterPayload(
    record,
    state.mode,
    cred,
    isCredentialAccessible(record),
  );
}

function isAlreadyRegistered(ip: string): boolean {
  return state.registerStatusMap[ip] === 'success';
}

function isRecordRegistrable(record: SegmentScanDeviceRow): boolean {
  if (isAlreadyRegistered(record.ip)) return false;
  return hasRegisterPayload(record);
}

function canRegisterRecord(record: SegmentScanDeviceRow): boolean {
  if (state.batchRegistering || state.registering) return false;
  return isRecordRegistrable(record);
}

function warnCannotRegisterNvr(record: SegmentScanDeviceRow) {
  if (!hasFormCredentials()) {
    createMessage.warning('请至少填写一组登录凭证');
  } else if (state.mode === 'nvr' && !hasNvrRegisterPassword()) {
    createMessage.warning('登记 NVR 须填写 Web 登录密码');
  } else if (isAlreadyRegistered(record.ip)) {
    createMessage.warning('该 NVR 已登记');
  } else if (!record.is_nvr && !record.is_recognized && !record.vendor) {
    createMessage.warning('该设备未识别为 NVR，无法登记');
  } else {
    createMessage.warning('缺少登记所需信息，请确认登录凭证与扫描结果');
  }
}

function getRegistrableDevices(): SegmentScanDeviceRow[] {
  return state.devices.filter((d) => isRecordRegistrable(d));
}

const registrableCount = computed(() => getRegistrableDevices().length);

const batchRegisterButtonText = computed(() => {
  const n = registrableCount.value;
  if (state.mode === 'nvr') {
    return n > 0 ? `一键批量登记 NVR 及通道（${n}）` : '一键批量登记 NVR 及通道';
  }
  return n > 0 ? `一键批量注册（${n}）` : '一键批量注册';
});

function registerStatusLabel(ip: string, record: SegmentScanDeviceRow): string {
  const st = state.registerStatusMap[ip];
  if (st === 'success') return '已注册';
  if (st === 'failed') return '注册失败';
  if (st === 'skipped') return '已跳过';
  if (!isCredentialAccessible(record)) {
    return state.mode === 'nvr' && hasFormCredentials() ? '待凭证探测' : '未认证';
  }
  if (!hasRegisterPayload(record)) return state.mode === 'nvr' ? '不可登记' : '无 RTSP';
  return state.mode === 'nvr' ? '可登记' : '可注册';
}

function registerStatusColor(ip: string): string {
  const st = state.registerStatusMap[ip];
  if (st === 'success') return 'success';
  if (st === 'failed') return 'error';
  if (st === 'skipped') return 'default';
  return 'processing';
}

function resetRegisterStatus() {
  state.registerStatusMap = {};
  state.batchProgress = '';
  state.registeringIp = '';
}

function addCredential() {
  form.credentials.push({ username: '', password: '' });
}

function removeCredential(index: number) {
  if (form.credentials.length <= 1) return;
  form.credentials.splice(index, 1);
}

const cameraColumns = getCameraScanColumns();
const nvrColumns = getNvrScanColumns();

function segmentScanDrawerTitle(mode: 'camera' | 'nvr') {
  return mode === 'nvr' ? '跨网段扫描并注册 NVR' : '跨网段扫描并注册摄像头';
}

const drawerTitle = computed(() => segmentScanDrawerTitle(state.mode));

const tablePagination = {
  pageSize: 20,
  showSizeChanger: true,
  pageSizeOptions: ['10', '20', '50', '100'],
  showQuickJumper: true,
  showTotal: (total: number) => `共 ${total} 条`,
};

const [registerResultModal, { openModal: openResultModal, closeModal: closeResultModal }] = useModal();

const resultTableKind = computed<'camera' | 'nvr'>(() =>
  state.mode === 'camera' ? 'camera' : 'nvr',
);

const hasScanResult = computed(() => state.devices.length > 0);

const resultHintText = computed(() => {
  const unit = state.mode === 'nvr' ? '台 NVR' : '台摄像头';
  const reg = registrableCount.value;
  const regHint = reg > 0 ? `，其中 ${reg} 台凭证可访问可批量注册` : '';
  return `已发现 ${state.devices.length} ${unit}${regHint}，可在结果弹窗中一键批量或逐台注册`;
});

const resultModalTitle = computed(() => {
  if (state.mode === 'camera') {
    return `扫描结果 — 摄像头（${state.devices.length}）`;
  }
  return `扫描结果 — NVR（${state.devices.length}）`;
});

const [register, { closeDrawer, setDrawerProps }] = useDrawerInner((data?: { mode?: 'camera' | 'nvr' }) => {
  const mode = data?.mode || props.mode || 'camera';
  state.mode = mode;
  state.devices = [];
  state.scanProgress = '';
  resetRegisterStatus();
  setDrawerProps({ title: segmentScanDrawerTitle(mode) });
});

function vendorToCameraType(vendor?: string): string {
  if (vendor === 'hikvision') return 'hikvision';
  if (vendor === 'dahua') return 'dahua';
  return 'custom';
}

async function handleScan() {
  const targetCheck = validateSegmentScanTargets(form.targets, form.ports.trim() || undefined);
  if (!targetCheck.valid) {
    createMessage.warning(targetCheck.message || '扫描目标格式无效');
    return;
  }
  const credentials = getValidCredentials();
  if (!credentials.length) {
    createMessage.warning('请至少填写一组用户名');
    return;
  }
  if (state.mode === 'nvr' && !hasNvrRegisterPassword()) {
    createMessage.warning('NVR 模式请填写 Web 登录密码后再扫描/登记');
    return;
  }
  const scanPayload = {
    targets: form.targets.trim(),
    credentials,
    ports: form.ports.trim() || undefined,
    concurrency: form.concurrency,
    timeout: form.timeout,
    only_hits: form.only_hits,
    nvr_only: state.mode === 'nvr',
    exclude_nvr: state.mode === 'camera',
  };
  state.scanning = true;
  state.scanProgress = `正在扫描，预计最多 ${computeSegmentScanWallSeconds(scanPayload)} 秒…`;
  state.devices = [];
  resetRegisterStatus();
  try {
    const res = await scanSegmentDevices(scanPayload);
    const list = (res as { data?: SegmentScanDeviceRow[] })?.data ?? (res as SegmentScanDeviceRow[]) ?? [];
    state.devices = Array.isArray(list) ? list : [];
    persistScanHistory(state.devices.length);
    if (!state.devices.length) {
      createMessage.info(state.mode === 'nvr' ? '未发现 NVR 设备' : '未发现可识别设备');
    } else {
      createMessage.success(`扫描完成，共 ${state.devices.length} 台`);
      openResultModal(true);
    }
  } catch (e: unknown) {
    const err = e as { msg?: string; message?: string };
    createMessage.error(err?.msg || err?.message || '扫描失败');
  } finally {
    state.scanning = false;
    state.scanProgress = '';
  }
}

async function registerOneNvr(record: SegmentScanDeviceRow, silent = false): Promise<boolean> {
  if (!isRecordRegistrable(record)) {
    if (!silent) warnCannotRegisterNvr(record);
    return false;
  }
  const cred = resolveCredential(record.auth_username);
  if (!cred.password) {
    if (!silent) createMessage.warning('登记 NVR 须填写 Web 登录密码');
    return false;
  }
  const credentials = getValidCredentials();
  const nvrTimeout = Math.max(Number(form.timeout) || 3, 15);
  state.registeringIp = record.ip;
  if (!state.batchRegistering) state.registering = true;
  try {
    const res = await registerNvrWithChannels({
      ip: record.ip,
      port: record.port || 80,
      username: cred.username,
      password: cred.password,
      credentials,
      timeout: nvrTimeout,
      vendor: record.vendor,
      name: record.device_name,
      model: record.model,
      serial_number: record.serial,
      rtsp_url: record.rtsp_url,
      scheme: record.port && [443, 8443].includes(record.port) ? 'https' : 'http',
    });
    const n = nvrRegisterRegisteredCount(res);
    if (n > 0) {
      state.registerStatusMap[record.ip] = 'success';
      if (!silent) {
        createMessage.success(`NVR ${record.ip} 已登记，已挂载 ${n} 路通道`);
      }
      return true;
    }
    state.registerStatusMap[record.ip] = 'failed';
    if (!silent) {
      createMessage.warning(`NVR ${record.ip} 登记失败：${formatNvrRegisterHint(res)}`);
    }
    return false;
  } catch (e: unknown) {
    state.registerStatusMap[record.ip] = 'failed';
    if (!silent) {
      const err = e as { msg?: string; message?: string };
      createMessage.error(err?.msg || err?.message || `NVR ${record.ip} 登记失败`);
    }
    return false;
  } finally {
    if (state.registeringIp === record.ip) state.registeringIp = '';
    if (!state.batchRegistering) state.registering = false;
  }
}

async function registerOneCamera(record: SegmentScanDeviceRow, silent = false): Promise<boolean> {
  if (!isRecordRegistrable(record)) {
    if (!silent) {
      if (!isCredentialAccessible(record)) {
        createMessage.warning('该设备未通过凭证认证，无法注册');
      } else {
        createMessage.warning('无 RTSP 地址，请确认凭证正确或设备已识别');
      }
    }
    return false;
  }
  const cred = resolveCredential(record.auth_username);
  const source = resolveSegmentScanRtsp(record, cred);
  if (!source) {
    if (!silent) createMessage.warning('无法生成 RTSP 地址');
    return false;
  }
  state.registeringIp = record.ip;
  if (!state.batchRegistering) state.registering = true;
  try {
    await registerDevice({
      name: record.device_name || `${record.vendor_label || '设备'}-${record.ip}`,
      source,
      ip: record.ip,
      port: 554,
      username: cred.username,
      password: cred.password,
      cameraType: vendorToCameraType(record.vendor),
      skip_onvif: true,
      stream: 0,
      manufacturer: record.vendor_label,
      model: record.model,
      serial_number: record.serial,
    });
    state.registerStatusMap[record.ip] = 'success';
    if (!silent) createMessage.success(`摄像头 ${record.ip} 注册成功`);
    return true;
  } catch (e: unknown) {
    state.registerStatusMap[record.ip] = 'failed';
    if (!silent) {
      const err = e as { msg?: string; message?: string };
      createMessage.error(err?.msg || err?.message || `摄像头 ${record.ip} 注册失败`);
    }
    return false;
  } finally {
    if (state.registeringIp === record.ip) state.registeringIp = '';
    if (!state.batchRegistering) state.registering = false;
  }
}

async function handleRegisterNvrWithChannels(record: SegmentScanDeviceRow) {
  if (await registerOneNvr(record)) emit('success');
}

async function handleRegisterCamera(record: SegmentScanDeviceRow) {
  if (await registerOneCamera(record)) emit('success');
}

async function handleBatchRegister() {
  const list = getRegistrableDevices();
  if (!list.length) {
    createMessage.warning('没有可通过凭证访问且待注册的设备');
    return;
  }
  state.batchRegistering = true;
  state.registering = true;
  let okCount = 0;
  let failCount = 0;
  const total = list.length;
  const isNvr = state.mode === 'nvr';
  try {
    for (let i = 0; i < list.length; i++) {
      const record = list[i];
      state.batchProgress = `正在${isNvr ? '登记' : '注册'} ${i + 1}/${total}：${record.ip}`;
      const ok = isNvr ? await registerOneNvr(record, true) : await registerOneCamera(record, true);
      if (ok) okCount += 1;
      else failCount += 1;
    }
    if (okCount > 0) emit('success');
    const action = isNvr ? '登记' : '注册';
    if (failCount === 0) {
      createMessage.success(`批量${action}完成：成功 ${okCount} 台`);
    } else {
      createMessage.warning(`批量${action}完成：成功 ${okCount} 台，失败 ${failCount} 台`);
    }
  } finally {
    state.batchRegistering = false;
    state.registering = false;
    state.batchProgress = '';
    state.registeringIp = '';
  }
}

function handleResultModalClose() {
  closeResultModal();
}

function handleClose() {
  closeResultModal();
  state.devices = [];
  resetRegisterStatus();
  closeDrawer();
}
</script>

<style lang="less" scoped>
.segment-scan-modal {
  .scan-tip {
    margin-bottom: 12px;
  }
  .scan-form {
    margin-bottom: 8px;
    max-width: 680px;

    .scan-form-field-line {
      max-width: 560px;
    }

    .scan-form-field-half {
      max-width: 480px;
    }
  }
  .scan-actions {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
    .progress-text {
      color: #666;
      font-size: 13px;
    }
  }
  .credentials-block {
    .credential-row {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 8px;
      .cred-order {
        flex: 0 0 20px;
        text-align: center;
        color: #999;
        font-size: 12px;
      }
      .cred-user {
        flex: 1;
        min-width: 120px;
      }
      .cred-pass {
        flex: 1;
        min-width: 120px;
      }
    }
    .cred-hint {
      margin-top: 6px;
      color: #999;
      font-size: 12px;
    }
  }
  .result-hint {
    margin-top: 12px;
  }
}

.segment-scan-result-modal {
  .result-toolbar {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
    margin-bottom: 12px;
    .batch-progress {
      color: #1890ff;
      font-size: 13px;
    }
    .batch-hint {
      color: #666;
      font-size: 13px;
    }
  }
}

</style>

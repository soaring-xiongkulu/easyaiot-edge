<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    :width="modalWidth"
    :min-height="640"
    :can-fullscreen="true"
    :default-fullscreen="false"
    :show-ok-btn="false"
    :show-cancel-btn="false"
    :footer="null"
    destroy-on-close
    wrap-class-name="geo-loc-modal-wrap"
    @cancel="onModalClose"
  >
    <template #title>
      <div v-if="deviceId" class="geo-loc-modal-head">
        <span class="geo-loc-modal-head__title">地图坐标</span>
        <span class="geo-loc-modal-head__line" />
        <span class="geo-loc-modal-head__device">{{ deviceName || '未命名设备' }}</span>
        <span class="geo-loc-modal-head__tag">{{ deviceKindLabel }}</span>
        <span
          class="geo-loc-modal-head__badge"
          :class="{ 'is-on': hasCurrentLocation }"
        >
          {{ hasCurrentLocation ? '已配置' : '未配置' }}
        </span>
      </div>
      <span v-else>地图坐标</span>
    </template>

    <a-spin :spinning="loading" wrapper-class-name="geo-loc-spin">
      <div v-if="deviceId" class="geo-loc">
        <p class="geo-loc__device-id" :title="deviceId">{{ deviceId }}</p>

        <a-alert
          v-if="loadHint"
          :message="loadHint"
          type="warning"
          show-icon
          banner
          class="geo-loc__alert"
        />

        <div class="geo-loc__workspace">
          <section class="geo-loc__map-area" aria-label="地图选点">
            <MapLocationPicker
              v-model="pickDraft"
              embedded
              height="100%"
              @confirm="onMapPickConfirm"
            />
          </section>

          <aside class="geo-loc-panel" aria-label="位置属性">
            <div class="geo-loc-panel__header">
              <h3 class="geo-loc-panel__title">位置属性</h3>
              <span class="geo-loc-panel__coord-sys">WGS84</span>
            </div>

            <div
              class="geo-loc-panel__preview"
              :class="{ 'is-empty': !hasCurrentLocation, 'is-active': hasCurrentLocation }"
            >
              <template v-if="hasCurrentLocation">
                <div class="geo-loc-panel__preview-coord">
                  <span class="label">经度</span>
                  <span class="value">{{ formatCoord(form.longitude) }}</span>
                </div>
                <div class="geo-loc-panel__preview-coord">
                  <span class="label">纬度</span>
                  <span class="value">{{ formatCoord(form.latitude) }}</span>
                </div>
                <p v-if="form.address" class="geo-loc-panel__preview-address">
                  {{ form.address }}
                </p>
              </template>
              <p v-else class="geo-loc-panel__preview-placeholder">
                在地图点选或搜索定位后，此处显示坐标摘要
              </p>
            </div>

            <div class="geo-loc-panel__body">
              <section class="geo-loc-panel__section">
                <h4 class="geo-loc-panel__section-title">坐标</h4>
                <a-form layout="vertical" class="geo-loc-panel__form">
                  <a-form-item label="经度" required>
                    <a-input-number
                      v-model:value="form.longitude"
                      :precision="6"
                      :step="0.000001"
                      :min="-180"
                      :max="180"
                      placeholder="114.057868"
                      :controls="false"
                      class="geo-loc-input geo-loc-input--mono"
                    />
                  </a-form-item>
                  <a-form-item label="纬度" required>
                    <a-input-number
                      v-model:value="form.latitude"
                      :precision="6"
                      :step="0.000001"
                      :min="-90"
                      :max="90"
                      placeholder="22.543099"
                      :controls="false"
                      class="geo-loc-input geo-loc-input--mono"
                    />
                  </a-form-item>
                </a-form>
              </section>

              <section class="geo-loc-panel__section">
                <h4 class="geo-loc-panel__section-title">扩展</h4>
                <a-form layout="vertical" class="geo-loc-panel__form">
                  <div class="geo-loc-panel__row-2">
                    <a-form-item label="海拔 (m)">
                      <a-input-number
                        v-model:value="form.altitude"
                        :precision="1"
                        :step="0.1"
                        placeholder="可选"
                        :controls="false"
                        class="geo-loc-input"
                      />
                    </a-form-item>
                    <a-form-item label="朝向 (°)">
                      <a-input-number
                        v-model:value="form.heading"
                        :min="0"
                        :max="360"
                        :precision="1"
                        placeholder="0=北"
                        :controls="false"
                        class="geo-loc-input"
                      />
                    </a-form-item>
                  </div>
                  <p v-if="headingPreview" class="geo-loc-panel__heading-note">
                    {{ headingPreview }}
                  </p>
                </a-form>
              </section>

              <section class="geo-loc-panel__section">
                <h4 class="geo-loc-panel__section-title">安装地址</h4>
                <a-textarea
                  v-model:value="form.address"
                  :rows="3"
                  placeholder="地图选点后可自动填充"
                  class="geo-loc-panel__textarea"
                />
              </section>

              <section class="geo-loc-panel__section geo-loc-panel__section--meta">
                <div class="geo-loc-panel__meta-item">
                  <span class="meta-label">坐标来源</span>
                  <span class="meta-value">{{ locationSourceLabel }}</span>
                </div>
                <div v-if="form.location_updated_at" class="geo-loc-panel__meta-item">
                  <span class="meta-label">更新时间</span>
                  <span class="meta-value">{{ formatUpdatedAt(form.location_updated_at) }}</span>
                </div>
              </section>
            </div>

            <footer class="geo-loc-panel__footer">
              <Button
                class="geo-loc-action geo-loc-action--clear"
                :disabled="saving"
                @click="handleClearLocation"
              >
                清除坐标
              </Button>
              <div class="geo-loc-panel__footer-group">
                <Button
                  class="geo-loc-action geo-loc-action--cancel"
                  :disabled="saving"
                  @click="handleCancel"
                >
                  取消
                </Button>
                <Button
                  type="primary"
                  class="geo-loc-action geo-loc-action--save"
                  :loading="saving"
                  :disabled="!canSave"
                  @click="handleSave"
                >
                  保存坐标
                </Button>
              </div>
            </footer>
          </aside>
        </div>
      </div>
      <a-empty v-else class="geo-loc__empty" description="未选择设备" />
    </a-spin>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, reactive, ref, watch } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import { MapLocationPicker } from '@/components/TiandituMap';
import type { MapPickResult } from '@/components/TiandituMap';
import {
  getDeviceLocation,
  updateDeviceLocation,
  type DeviceLocationInfo,
} from '@/api/device/camera';
import { Button } from '@/components/Button'
import {
formatHeadingSummary,
  hasDeviceLocation,
  LOCATION_SOURCE_LABEL,
  type DeviceLocationDrawerRecord,
} from '@/views/camera/utils/deviceLocation';

defineOptions({ name: 'DeviceLocationDrawer' });

const emit = defineEmits<{ success: [] }>();

const { createMessage } = useMessage();

const modalWidth = '1180px';

const DEVICE_KIND_LABEL: Record<string, string> = {
  direct: '直连',
  gb28181: 'GB28181',
  nvr_channel: 'NVR 通道',
};

const loading = ref(false);
const saving = ref(false);
const loadHint = ref('');
const deviceId = ref('');
const deviceName = ref('');
const deviceKind = ref('');
const pickDraft = ref<MapPickResult | null>(null);

const locationSourceLabel = computed(() => {
  const src = form.location_source;
  if (!src) return '—';
  return LOCATION_SOURCE_LABEL[src] || src;
});

const deviceKindLabel = computed(() => {
  const kind = deviceKind.value;
  if (!kind) return '摄像头';
  return DEVICE_KIND_LABEL[kind] || kind;
});

const hasCurrentLocation = computed(() => hasDeviceLocation(form));

const headingPreview = computed(() => formatHeadingSummary(form.heading));

const form = reactive({
  longitude: null as number | null,
  latitude: null as number | null,
  altitude: null as number | null,
  address: '' as string | null,
  heading: null as number | null,
  location_source: null as string | null,
  location_updated_at: null as string | null,
});

const canSave = computed(() => {
  const hasLng = form.longitude != null;
  const hasLat = form.latitude != null;
  return hasLng === hasLat;
});

function formatCoord(v: number | null | undefined) {
  if (v == null || Number.isNaN(Number(v))) return '—';
  return Number(v).toFixed(6);
}

function formatUpdatedAt(iso: string | null) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleString('zh-CN', { hour12: false });
  } catch {
    return iso;
  }
}

function applyRecordToForm(record?: DeviceLocationDrawerRecord | DeviceLocationInfo | null) {
  if (!record) return;
  if (record.name) deviceName.value = record.name;
  if (record.device_kind) deviceKind.value = record.device_kind;
  if ('longitude' in record) form.longitude = record.longitude ?? null;
  if ('latitude' in record) form.latitude = record.latitude ?? null;
  if ('altitude' in record) form.altitude = record.altitude ?? null;
  if ('address' in record) form.address = record.address ?? '';
  if ('heading' in record) form.heading = record.heading ?? null;
  if ('location_source' in record) form.location_source = record.location_source ?? null;
  if ('location_updated_at' in record) {
    form.location_updated_at = record.location_updated_at ?? null;
  }
  syncPickDraftFromForm();
}

function syncPickDraftFromForm() {
  if (form.longitude != null && form.latitude != null) {
    pickDraft.value = {
      lng: Number(form.longitude),
      lat: Number(form.latitude),
      address: form.address || undefined,
    };
  } else {
    pickDraft.value = null;
  }
}

function applyPickToForm(result: MapPickResult) {
  form.longitude = result.lng;
  form.latitude = result.lat;
  if (result.address) {
    form.address = result.address;
  }
}

function onMapPickConfirm(result: MapPickResult) {
  applyPickToForm(result);
}

watch(pickDraft, (v) => {
  if (!v?.lng || v.lat == null) return;
  if (form.longitude === v.lng && form.latitude === v.lat) return;
  form.longitude = v.lng;
  form.latitude = v.lat;
  if (v.address) form.address = v.address;
});

watch(
  () => [form.longitude, form.latitude] as const,
  () => syncPickDraftFromForm(),
);

function locationQueryParams(record?: DeviceLocationDrawerRecord | null) {
  const name = (record?.name || deviceName.value || '').trim();
  return name ? { name } : undefined;
}

function unwrapApiEnvelope<T>(res: unknown): { code?: number; data?: T; msg?: string } {
  if (!res || typeof res !== 'object') return {};
  const outer = res as { data?: { code?: number; data?: T; msg?: string } };
  if (outer.data && typeof outer.data === 'object' && 'code' in outer.data) {
    return outer.data;
  }
  return res as { code?: number; data?: T; msg?: string };
}

function parseLocationResponse(res: unknown): DeviceLocationInfo | null {
  const r = unwrapApiEnvelope<DeviceLocationInfo>(res);
  if (r.code != null && r.code !== 0) return null;
  return r.data ?? null;
}

async function loadDevice(id: string, record?: DeviceLocationDrawerRecord | null) {
  loading.value = true;
  loadHint.value = '';
  try {
    const res = await getDeviceLocation(id, locationQueryParams(record));
    const data = parseLocationResponse(res);
    if (!data?.id) {
      const fail = unwrapApiEnvelope(res);
      throw new Error(fail.msg || '加载失败');
    }
    if (data.name) deviceName.value = data.name;
    if (data.device_kind) deviceKind.value = data.device_kind;
    form.longitude = data.longitude ?? null;
    form.latitude = data.latitude ?? null;
    form.altitude = data.altitude ?? null;
    form.address = data.address ?? '';
    form.heading = data.heading ?? null;
    form.location_source = data.location_source ?? null;
    form.location_updated_at = data.location_updated_at ?? null;
    syncPickDraftFromForm();
  } catch (e: unknown) {
    console.error(e);
    const msg = e instanceof Error ? e.message : '';
    if (record && (hasDeviceLocation(record) || record.name)) {
      loadHint.value = msg
        ? `${msg}；已载入列表数据，保存后写入设备库。`
        : '已载入列表数据，保存后同步至服务端。';
      applyRecordToForm(record);
    } else {
      createMessage.error(msg || '加载坐标失败');
    }
  } finally {
    loading.value = false;
  }
}

async function handleSave() {
  if (!deviceId.value) return;
  if (form.longitude != null && form.latitude == null) {
    createMessage.warning('经纬度需成对填写');
    return;
  }
  if (form.latitude != null && form.longitude == null) {
    createMessage.warning('经纬度需成对填写');
    return;
  }
  saving.value = true;
  try {
    const payload = {
      longitude: form.longitude,
      latitude: form.latitude,
      altitude: form.altitude,
      address: form.address || null,
      heading: form.heading,
      location_source: hasDeviceLocation(form) ? 'manual' : undefined,
      name: (deviceName.value || '').trim() || undefined,
    };
    const res = await updateDeviceLocation(deviceId.value, payload);
    const envelope = unwrapApiEnvelope<DeviceLocationInfo>(res);
    if (envelope.code != null && envelope.code !== 0) {
      createMessage.error(envelope.msg || '保存失败');
      return;
    }
    const data = envelope.data;
    if (data) {
      form.location_source = data.location_source ?? form.location_source;
      form.location_updated_at = data.location_updated_at ?? form.location_updated_at;
      if (data.name) deviceName.value = data.name;
    }
    createMessage.success('已保存');
    emit('success');
    closeModal();
    onModalClose();
  } catch (e) {
    console.error(e);
    createMessage.error('保存失败');
  } finally {
    saving.value = false;
  }
}

async function handleClearLocation() {
  if (!deviceId.value) return;
  saving.value = true;
  try {
    const res = await updateDeviceLocation(deviceId.value, {
      longitude: null,
      latitude: null,
      altitude: null,
      address: null,
      heading: null,
      name: (deviceName.value || '').trim() || undefined,
    });
    const envelope = unwrapApiEnvelope(res);
    if (envelope.code != null && envelope.code !== 0) {
      createMessage.error(envelope.msg || '清除失败');
      return;
    }
    form.longitude = null;
    form.latitude = null;
    form.altitude = null;
    form.address = '';
    form.heading = null;
    form.location_source = null;
    form.location_updated_at = null;
    pickDraft.value = null;
    loadHint.value = '';
    createMessage.success('已清除');
    emit('success');
    closeModal();
    onModalClose();
  } catch (e) {
    console.error(e);
    createMessage.error('清除失败');
  } finally {
    saving.value = false;
  }
}

function handleCancel() {
  closeModal();
  onModalClose();
}

const [register, { setModalProps, closeModal }] = useModalInner(
  async (data: { deviceId?: string; record?: DeviceLocationDrawerRecord }) => {
    const id = data?.deviceId || data?.record?.id || '';
    deviceId.value = id;
    deviceName.value = data?.record?.name || '';
    deviceKind.value = data?.record?.device_kind || '';
    pickDraft.value = null;
    loadHint.value = '';
    form.longitude = null;
    form.latitude = null;
    form.altitude = null;
    form.address = '';
    form.heading = null;
    form.location_source = null;
    form.location_updated_at = null;
    setModalProps({ confirmLoading: false });
    applyRecordToForm(data?.record);
    if (id) {
      await loadDevice(id, data?.record);
    }
  },
);

function onModalClose() {
  deviceId.value = '';
  deviceKind.value = '';
  pickDraft.value = null;
  loadHint.value = '';
}
</script>

<style scoped lang="less">
@primary: #266cfb;
@primary-hover: #4287fc;
@primary-soft: rgba(38, 108, 251, 0.08);
@primary-line: rgba(38, 108, 251, 0.35);
@surface: #fff;
@border: #e4e9f2;
@divider: #f0f2f7;
@text: rgba(0, 0, 0, 0.88);
@text-2: rgba(0, 0, 0, 0.55);
@text-3: rgba(0, 0, 0, 0.35);
@success: #16a34a;
@success-soft: rgba(22, 163, 74, 0.1);
@panel-width: 420px;

.geo-loc-modal-head {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
  padding-right: 48px;

  &__title {
    flex-shrink: 0;
    font-size: 18px;
    font-weight: 600;
    color: @text;
    letter-spacing: -0.02em;
  }

  &__line {
    width: 1px;
    height: 20px;
    background: @divider;
    flex-shrink: 0;
  }

  &__device {
    min-width: 0;
    font-size: 16px;
    font-weight: 500;
    color: @text;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  &__tag {
    flex-shrink: 0;
    padding: 4px 12px;
    font-size: 13px;
    color: @primary;
    background: @primary-soft;
    border-radius: 8px;
  }

  &__badge {
    flex-shrink: 0;
    margin-left: auto;
    padding: 5px 14px;
    font-size: 13px;
    color: @text-2;
    background: #f4f5f7;
    border-radius: 20px;
    border: 1px solid rgba(228, 233, 242, 0.9);
    transition: background 0.2s ease, color 0.2s ease;

    &.is-on {
      color: @success;
      background: @success-soft;
      border-color: rgba(22, 163, 74, 0.2);
    }
  }
}

.geo-loc-spin {
  display: block;
  height: 100%;
  min-height: 640px;

  :deep(.ant-spin-container) {
    height: 100%;
    min-height: inherit;
  }
}

.geo-loc {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 640px;
  background: @surface;
  animation: geo-loc-in 0.32s cubic-bezier(0.22, 1, 0.36, 1);

  &__device-id {
    flex-shrink: 0;
    margin: 0;
    padding: 8px 24px;
    font-size: 12px;
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    color: @text-3;
    background: linear-gradient(180deg, #fcfdff 0%, #f8f9fc 100%);
    border-bottom: 1px solid rgba(228, 233, 242, 0.9);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  &__alert {
    flex-shrink: 0;
    margin: 0;
  }

  &__workspace {
    flex: 1;
    min-height: 0;
    display: flex;
    overflow: hidden;
  }

  &__map-area {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    background: #e8ebf2;

    :deep(.map-location-picker) {
      height: 100% !important;
      min-height: 100%;
      border-radius: 0;
    }

    :deep(.basic-tianditu-map) {
      min-height: 100%;
    }
  }

  &__empty {
    padding: 120px 0;
  }
}

@keyframes geo-loc-in {
  from {
    opacity: 0;
    transform: translateY(6px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.geo-loc-panel {
  width: @panel-width;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  background: linear-gradient(180deg, #fff 0%, #fafbfd 100%);
  border-left: 1px solid rgba(228, 233, 242, 0.85);
  box-shadow: -6px 0 28px rgba(15, 23, 42, 0.04);
  overflow: hidden;

  &__header {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 20px 24px 16px;
    border-bottom: 1px solid @divider;
  }

  &__title {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: @text;
    letter-spacing: -0.02em;
  }

  &__coord-sys {
    padding: 4px 10px;
    font-size: 12px;
    font-weight: 500;
    color: @text-2;
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    background: #f6f7fb;
    border-radius: 6px;
    border: 1px solid @border;
  }

  &__preview {
    flex-shrink: 0;
    margin: 20px 24px 0;
    padding: 16px 18px;
    border-radius: 8px;
    border: 1px solid @border;
    background: #fafbfd;
    transition:
      border-color 0.2s,
      background 0.2s;

    &.is-empty {
      border-style: dashed;
      border-color: #d8dde8;
      background: transparent;
      padding: 20px 18px;
    }

    &.is-active {
      border-color: rgba(38, 108, 251, 0.22);
      background: linear-gradient(145deg, rgba(38, 108, 251, 0.07) 0%, rgba(255, 255, 255, 0.9) 100%);
      box-shadow: 0 4px 16px rgba(38, 108, 251, 0.1);
    }
  }

  &__preview-coord {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 16px;
    font-size: 14px;
    line-height: 1.7;

    & + & {
      margin-top: 4px;
    }

    .label {
      font-size: 13px;
      color: @text-2;
      flex-shrink: 0;
    }

    .value {
      font-family: 'SF Mono', Menlo, Consolas, monospace;
      font-size: 15px;
      font-weight: 600;
      color: @primary;
      text-align: right;
      word-break: break-all;
    }
  }

  &__preview-address {
    margin: 12px 0 0;
    padding-top: 12px;
    border-top: 1px solid rgba(38, 108, 251, 0.12);
    font-size: 13px;
    line-height: 1.6;
    color: @text-2;
  }

  &__preview-placeholder {
    margin: 0;
    font-size: 13px;
    line-height: 1.65;
    color: @text-3;
    text-align: center;
  }

  &__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: 8px 24px 12px;

    &::-webkit-scrollbar {
      width: 8px;
    }

    &::-webkit-scrollbar-thumb {
      background: #d0d5df;
      border-radius: 4px;
    }
  }

  &__section {
    padding: 18px 0;
    border-bottom: 1px solid @divider;

    &:last-child {
      border-bottom: none;
    }

    &--meta {
      padding-bottom: 8px;
    }
  }

  &__section-title {
    margin: 0 0 16px;
    font-size: 13px;
    font-weight: 600;
    color: @text-2;
    line-height: 1.4;
  }

  &__form {
    :deep(.ant-form-item) {
      margin-bottom: 12px;
    }

    :deep(.ant-form-item:last-child) {
      margin-bottom: 0;
    }

    :deep(.ant-form-item-label > label) {
      font-size: 12px;
      color: @text-2;
      height: auto;

      &::before {
        color: #f53f3f !important;
      }
    }
  }

  &__row-2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;

    :deep(.ant-form-item) {
      margin-bottom: 0;
    }
  }

  &__heading-note {
    margin: 10px 0 0;
    padding: 6px 10px;
    font-size: 12px;
    color: @text-2;
    background: #f6f7fb;
    border-radius: 4px;
  }

  &__textarea {
    resize: none;
    border-radius: 6px;
  }

  &__meta-item {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 0;
    font-size: 12px;

    .meta-label {
      color: @text-3;
    }

    .meta-value {
      color: @text;
      text-align: right;
    }
  }

  &__footer {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 16px 24px 20px;
    background: #fff;
    border-top: 1px solid #eef1f6;
  }

  &__footer-group {
    display: flex;
    align-items: center;
    gap: 10px;
  }
}

.geo-loc-action {
  height: 40px !important;
  padding: 0 18px !important;
  font-size: 14px !important;
  font-weight: 500 !important;
  line-height: 38px !important;
  border-radius: 10px !important;
  transition:
    color 0.2s ease,
    background 0.2s ease,
    border-color 0.2s ease,
    box-shadow 0.2s ease,
    transform 0.2s ease !important;
  box-shadow: none !important;

  &--clear {
    color: @text-2 !important;
    background: transparent !important;
    border: none !important;
    box-shadow: none !important;
    padding-inline: 4px !important;

    &:hover:not(:disabled) {
      color: #cf1322 !important;
      background: transparent !important;
    }

    &:disabled {
      opacity: 0.45;
    }
  }

  &--cancel {
    color: @text-2 !important;
    background: transparent !important;
    border: 1px solid #dce3ef !important;

    &:hover:not(:disabled) {
      color: @primary !important;
      border-color: rgba(38, 108, 251, 0.45) !important;
      background: transparent !important;
    }
  }

  &--save {
    min-width: 108px;
    padding-inline: 22px !important;
    color: #fff !important;
    border: none !important;
    background: linear-gradient(180deg, #4d8bff 0%, #266cfb 100%) !important;
    box-shadow: 0 2px 10px rgba(38, 108, 251, 0.28) !important;

    &:hover:not(:disabled) {
      background: linear-gradient(180deg, #5c96ff 0%, #4287fc 100%) !important;
      box-shadow: 0 4px 14px rgba(38, 108, 251, 0.34) !important;
      transform: translateY(-1px);
    }

    &:active:not(:disabled) {
      transform: translateY(0);
      box-shadow: 0 2px 6px rgba(38, 108, 251, 0.25) !important;
    }

    &:disabled {
      background: #c5cdd9 !important;
      box-shadow: none !important;
    }
  }
}

.geo-loc-input {
  width: 100%;

  :deep(.ant-input-number),
  :deep(.ant-input),
  :deep(.ant-input-affix-wrapper) {
    width: 100%;
    border-radius: 8px;
    border-color: #e8ecf4;
    transition:
      border-color 0.22s ease,
      box-shadow 0.22s ease;

    &:hover {
      border-color: #d0d7e2;
    }
  }

  :deep(.ant-input-number),
  :deep(.ant-input-number-input-wrap) {
    height: 36px;
  }

  :deep(.ant-input-number-input) {
    height: 34px;
  }

  :deep(.ant-input-number-focused),
  :deep(.ant-input:focus) {
    border-color: rgba(38, 108, 251, 0.55);
    box-shadow: 0 0 0 3px rgba(38, 108, 251, 0.1);
  }

  &--mono :deep(.ant-input-number-input) {
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    font-size: 13px;
    letter-spacing: 0.02em;
  }
}

@media (max-width: 1024px) {
  .geo-loc__workspace {
    flex-direction: column;
  }

  .geo-loc-panel {
    width: 100%;
    max-height: 46vh;
    box-shadow: none;
    border-left: none;
    border-top: 1px solid @border;
  }

  .geo-loc-modal-head__badge {
    margin-left: 0;
  }
}
</style>

<style lang="less">
@primary: #266cfb;

.geo-loc-modal-wrap {
  .ant-modal {
    top: 40px;
    max-width: calc(100vw - 48px);
    padding-bottom: 0;
    margin: 0 auto;
  }

  .ant-modal-content {
    border-radius: 12px;
    overflow: hidden;
    min-height: 720px;
    max-height: calc(100vh - 80px);
    display: flex;
    flex-direction: column;
    box-shadow: 0 16px 48px rgba(15, 23, 42, 0.18);
    transition: opacity 0.25s ease;
  }

  .ant-modal-header {
    flex-shrink: 0;
    padding: 16px 24px;
    margin-bottom: 0;
    background: linear-gradient(180deg, #fff 0%, #fafbfd 100%);
    border-bottom: 1px solid rgba(228, 233, 242, 0.9);
  }

  .ant-modal-title {
    width: 100%;
  }

  .ant-modal-body {
    flex: 1;
    min-height: 0;
    padding: 0;
    overflow: hidden;
    background: #fff;
  }

  .scroll-container {
    height: 100% !important;
    max-height: none !important;
  }

  .ant-modal-footer {
    display: none;
  }

  .ant-modal-close {
    top: 16px;
    inset-inline-end: 20px;
    width: 40px;
    height: 40px;
    line-height: 40px;
    color: rgba(0, 0, 0, 0.45);

    &:hover {
      color: @primary;
      background: rgba(38, 108, 251, 0.06);
      border-radius: 8px;
    }
  }

  .geo-loc-panel__textarea.ant-input {
    border-color: #e4e9f2;
    border-radius: 8px;

    &:hover {
      border-color: #c5cdd9;
    }

    &:focus {
      border-color: @primary;
      box-shadow: 0 0 0 2px rgba(38, 108, 251, 0.12);
    }
  }

  &.fullscreen-modal {
    .ant-modal {
      top: 0 !important;
      max-width: 100vw !important;
      width: 100vw !important;
      padding: 0;
      margin: 0;
    }

    .ant-modal-content {
      border-radius: 0;
      min-height: 100vh;
      max-height: 100vh;
      box-shadow: none;
    }

    .ant-modal-body {
      flex: 1;
      min-height: 0;
      max-height: none;
    }
  }
}
</style>

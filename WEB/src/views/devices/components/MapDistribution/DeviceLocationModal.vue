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
        <span class="geo-loc-modal-head__tag">{{ deviceTypeLabel }}</span>
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
        <p class="geo-loc__device-id" :title="String(deviceIdentification || deviceId)">
          {{ deviceIdentification || deviceId }}
        </p>

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
                  <span class="meta-label">设备类型</span>
                  <span class="meta-value">{{ deviceTypeLabel }}</span>
                </div>
                <div v-if="form.locationUpdatedAt" class="geo-loc-panel__meta-item">
                  <span class="meta-label">更新时间</span>
                  <span class="meta-value">{{ formatUpdatedAt(form.locationUpdatedAt) }}</span>
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
import { Button } from '@/components/Button';
import { MapLocationPicker } from '@/components/TiandituMap';
import type { MapPickResult } from '@/components/TiandituMap';
import {
  getIotDeviceLocation,
  updateIotDeviceLocation,
} from '@/api/device/devices';
import { useMessage } from '@/hooks/web/useMessage';

defineOptions({ name: 'DeviceLocationModal' });

const emit = defineEmits<{ success: [] }>();
const { createMessage } = useMessage();

const modalWidth = '1180px';

const DEVICE_TYPE_LABEL: Record<string, string> = {
  GATEWAY: '网关设备',
  COMMON: '普通设备',
  VIDEO_COMMON: '视频设备',
  SUBSET: '子设备',
};

const loading = ref(false);
const saving = ref(false);
const deviceId = ref<string | number>('');
const deviceName = ref('');
const deviceIdentification = ref('');
const deviceType = ref('');
const pickDraft = ref<MapPickResult | null>(null);

const form = reactive({
  longitude: null as number | null,
  latitude: null as number | null,
  address: '' as string,
  locationUpdatedAt: null as string | null,
});

const deviceTypeLabel = computed(() => DEVICE_TYPE_LABEL[deviceType.value] || 'IoT 设备');

const hasCurrentLocation = computed(
  () => form.longitude != null && form.latitude != null,
);

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

function onMapPickConfirm(result: MapPickResult) {
  form.longitude = result.lng;
  form.latitude = result.lat;
  if (result.address) form.address = result.address;
}

watch(pickDraft, (v) => {
  if (!v || v.lng == null || v.lat == null) return;
  if (form.longitude === v.lng && form.latitude === v.lat) return;
  form.longitude = v.lng;
  form.latitude = v.lat;
  if (v.address) form.address = v.address;
});

watch(
  () => [form.longitude, form.latitude] as const,
  () => syncPickDraftFromForm(),
);

const [register, { setModalProps, closeModal }] = useModalInner(async (data) => {
  deviceId.value = data?.id ?? '';
  deviceName.value = data?.deviceName || data?.name || '';
  deviceIdentification.value = data?.deviceIdentification || '';
  deviceType.value = data?.deviceType || '';
  pickDraft.value = null;
  form.longitude = null;
  form.latitude = null;
  form.address = '';
  form.locationUpdatedAt = null;
  setModalProps({ confirmLoading: false });

  if (!deviceId.value) return;
  loading.value = true;
  try {
    const res = (await getIotDeviceLocation(deviceId.value)) as any;
    const loc = res?.data ?? res;
    if (loc?.deviceName) deviceName.value = loc.deviceName;
    if (loc?.deviceIdentification) deviceIdentification.value = loc.deviceIdentification;
    if (loc?.deviceType) deviceType.value = loc.deviceType;
    if (loc?.longitude != null && loc?.latitude != null) {
      form.longitude = Number(loc.longitude);
      form.latitude = Number(loc.latitude);
      form.address = loc.address || '';
      form.locationUpdatedAt = loc.locationUpdatedAt || null;
      syncPickDraftFromForm();
    }
  } catch (e) {
    console.error(e);
    createMessage.error('加载坐标失败');
  } finally {
    loading.value = false;
  }
});

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
  if (form.longitude == null || form.latitude == null) {
    createMessage.warning('请先在地图选点或填写经纬度');
    return;
  }
  saving.value = true;
  try {
    await updateIotDeviceLocation(deviceId.value, {
      longitude: Number(form.longitude),
      latitude: Number(form.latitude),
      address: form.address || null,
    });
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
    await updateIotDeviceLocation(deviceId.value, {
      longitude: null,
      latitude: null,
      address: null,
    });
    form.longitude = null;
    form.latitude = null;
    form.address = '';
    form.locationUpdatedAt = null;
    pickDraft.value = null;
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

function onModalClose() {
  deviceId.value = '';
  deviceIdentification.value = '';
  deviceType.value = '';
  pickDraft.value = null;
}
</script>

<style scoped lang="less">
@primary: #266cfb;
@primary-soft: rgba(38, 108, 251, 0.08);
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
    }
  }

  &__textarea {
    resize: none;
    border-radius: 8px;
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
  border-radius: 10px !important;

  &--clear {
    color: @text-2 !important;
    background: transparent !important;
    border: none !important;
    padding-inline: 4px !important;

    &:hover:not(:disabled) {
      color: #cf1322 !important;
    }
  }

  &--cancel {
    color: @text-2 !important;
    background: transparent !important;
    border: 1px solid #dce3ef !important;

    &:hover:not(:disabled) {
      color: @primary !important;
      border-color: rgba(38, 108, 251, 0.45) !important;
    }
  }

  &--save {
    min-width: 108px;
    color: #fff !important;
    border: none !important;
    background: linear-gradient(180deg, #4d8bff 0%, #266cfb 100%) !important;
    box-shadow: 0 2px 10px rgba(38, 108, 251, 0.28) !important;

    &:hover:not(:disabled) {
      background: linear-gradient(180deg, #5c96ff 0%, #4287fc 100%) !important;
    }

    &:disabled {
      background: #c5cdd9 !important;
      box-shadow: none !important;
    }
  }
}

.geo-loc-input {
  width: 100%;

  :deep(.ant-input-number) {
    width: 100%;
    border-radius: 8px;
    border-color: #e8ecf4;
    height: 36px;
  }

  :deep(.ant-input-number-input) {
    height: 34px;
  }

  &--mono :deep(.ant-input-number-input) {
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    font-size: 13px;
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

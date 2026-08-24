<template>
  <div class="device-location-fields">
    <Divider orientation="left" plain>
      位置信息
      <span class="section-hint">（选填，用于地图与轨迹回放）</span>
    </Divider>

    <template v-if="disabled && !expanded && !hasAnyValue">
      <div class="location-empty">暂未设置位置信息</div>
    </template>
    <template v-else>
      <Row v-if="disabled && locationSourceLabel" :gutter="12">
        <Col :span="24">
          <div class="location-meta">
            来源：{{ locationSourceLabel }}
            <span v-if="locationUpdatedAt"> · 更新于 {{ locationUpdatedAt }}</span>
          </div>
        </Col>
      </Row>
      <Row :gutter="12">
        <Col :span="12">
          <FormItem label="经度" name="longitude" :rules="longitudeRules">
            <InputNumber
              v-model:value="localLongitude"
              :disabled="disabled"
              :precision="6"
              :step="0.000001"
              placeholder="WGS84，如 116.397128"
              style="width: 100%"
              @change="emitChange"
            />
          </FormItem>
        </Col>
        <Col :span="12">
          <FormItem label="纬度" name="latitude" :rules="latitudeRules">
            <InputNumber
              v-model:value="localLatitude"
              :disabled="disabled"
              :precision="6"
              :step="0.000001"
              placeholder="WGS84，如 39.916527"
              style="width: 100%"
              @change="emitChange"
            />
          </FormItem>
        </Col>
        <Col :span="12">
          <FormItem label="海拔(米)" name="altitude" :rules="altitudeRules">
            <InputNumber
              v-model:value="localAltitude"
              :disabled="disabled"
              :precision="1"
              :step="0.1"
              placeholder="可选"
              style="width: 100%"
              @change="emitChange"
            />
          </FormItem>
        </Col>
        <Col :span="12">
          <FormItem label="位置摘要">
            <Input :value="summaryText" disabled placeholder="填写经纬度后自动生成" />
          </FormItem>
        </Col>
        <Col :span="12">
          <FormItem label="朝向(°)" name="heading" :rules="headingRules">
            <InputNumber
              v-model:value="localHeading"
              :disabled="disabled"
              :min="0"
              :max="360"
              :precision="1"
              :step="1"
              placeholder="0=正北，顺时针"
              style="width: 100%"
              @change="emitChange"
            />
          </FormItem>
        </Col>
        <Col :span="12">
          <FormItem label="朝向预览">
            <div class="heading-preview">
              <div
                class="heading-preview__compass"
                :style="{ transform: `rotate(${localHeading ?? 0}deg)` }"
              >
                <span class="heading-preview__arrow" />
              </div>
              <span class="heading-preview__text">{{ headingSummaryText || '未设置' }}</span>
            </div>
          </FormItem>
        </Col>
        <Col :span="24">
          <FormItem label="安装地址" name="address">
            <Input.TextArea
              v-model:value="localAddress"
              :disabled="disabled"
              :rows="2"
              placeholder="如：北京市东城区XX路XX号 / 1号楼主入口"
              @change="emitChange"
            />
          </FormItem>
        </Col>
      </Row>
      <div v-if="!disabled" class="location-tip">
        坐标采用 WGS84（GPS）标准；朝向以正北为 0°，顺时针增加（90°=正东）。枪机安装朝向将显示在地图上。
      </div>
    </template>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Col, Divider, FormItem, Input, InputNumber, Row } from 'ant-design-vue';
import {
  formatHeadingSummary,
  formatLocationSummary,
  hasDeviceLocation,
  LOCATION_SOURCE_LABEL,
  validateAltitude,
  validateHeading,
  validateLatitude,
  validateLocationPair,
  validateLongitude,
} from '@/views/camera/utils/deviceLocation';

defineOptions({ name: 'DeviceLocationFields' });

const props = withDefaults(
  defineProps<{
    longitude?: number | null;
    latitude?: number | null;
    altitude?: number | null;
    address?: string | null;
    heading?: number | null;
    locationSource?: string | null;
    locationUpdatedAt?: string | null;
    disabled?: boolean;
    expanded?: boolean;
  }>(),
  {
    longitude: null,
    latitude: null,
    altitude: null,
    address: null,
    heading: null,
    locationSource: null,
    locationUpdatedAt: null,
    disabled: false,
    expanded: true,
  },
);

const emit = defineEmits<{
  'update:longitude': [value: number | null];
  'update:latitude': [value: number | null];
  'update:altitude': [value: number | null];
  'update:address': [value: string | null];
  'update:heading': [value: number | null];
}>();

const localLongitude = ref<number | null>(props.longitude ?? null);
const localLatitude = ref<number | null>(props.latitude ?? null);
const localAltitude = ref<number | null>(props.altitude ?? null);
const localAddress = ref<string>(props.address ?? '');
const localHeading = ref<number | null>(props.heading ?? null);

watch(
  () => [props.longitude, props.latitude, props.altitude, props.address, props.heading],
  () => {
    localLongitude.value = props.longitude ?? null;
    localLatitude.value = props.latitude ?? null;
    localAltitude.value = props.altitude ?? null;
    localAddress.value = props.address ?? '';
    localHeading.value = props.heading ?? null;
  },
);

const hasAnyValue = computed(() =>
  hasDeviceLocation({ longitude: localLongitude.value, latitude: localLatitude.value })
    || localAltitude.value != null
    || localHeading.value != null
    || !!localAddress.value?.trim(),
);

const summaryText = computed(() =>
  formatLocationSummary({
    longitude: localLongitude.value,
    latitude: localLatitude.value,
    heading: localHeading.value,
  }),
);

const headingSummaryText = computed(() => formatHeadingSummary(localHeading.value));

const locationSourceLabel = computed(() => {
  const src = props.locationSource;
  if (!src) return '';
  return LOCATION_SOURCE_LABEL[src] || src;
});

const locationUpdatedAt = computed(() => props.locationUpdatedAt || '');

const longitudeRules = [
  { validator: validateLongitude, trigger: 'change' },
  {
    validator: () => validateLocationPair(localLongitude.value, localLatitude.value),
    trigger: 'change',
  },
];

const latitudeRules = [
  { validator: validateLatitude, trigger: 'change' },
  {
    validator: () => validateLocationPair(localLongitude.value, localLatitude.value),
    trigger: 'change',
  },
];

const altitudeRules = [{ validator: validateAltitude, trigger: 'change' }];
const headingRules = [{ validator: validateHeading, trigger: 'change' }];

function emitChange() {
  emit('update:longitude', localLongitude.value);
  emit('update:latitude', localLatitude.value);
  emit('update:altitude', localAltitude.value);
  emit('update:address', localAddress.value?.trim() || null);
  emit('update:heading', localHeading.value);
}
</script>

<style scoped lang="less">
.device-location-fields {
  .section-hint {
    margin-left: 8px;
    font-size: 12px;
    font-weight: normal;
    color: rgba(0, 0, 0, 0.45);
  }

  .location-empty {
    padding: 8px 0 16px;
    color: rgba(0, 0, 0, 0.45);
  }

  .location-meta {
    margin-bottom: 12px;
    font-size: 12px;
    color: rgba(0, 0, 0, 0.55);
  }

  .location-tip {
    margin-top: -4px;
    margin-bottom: 8px;
    font-size: 12px;
    line-height: 1.5;
    color: rgba(0, 0, 0, 0.45);
  }

  .heading-preview {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 32px;
  }

  .heading-preview__compass {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    border: 1px solid #d9d9d9;
    background: #fafafa;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.2s;
  }

  .heading-preview__arrow {
    display: block;
    width: 0;
    height: 0;
    border-left: 5px solid transparent;
    border-right: 5px solid transparent;
    border-bottom: 12px solid #4287fc;
    transform: translateY(-2px);
  }

  .heading-preview__text {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.65);
  }
}
</style>

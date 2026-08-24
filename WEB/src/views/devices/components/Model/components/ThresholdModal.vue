<template>
  <ThresholdRuleModal
    v-model:visible="visible"
    :parameter="propertyCode"
    :property-name="propertyName"
    :current-value="currentValue"
    :rules="editingRules"
    :alarm-level="alarmLevel"
    :enabled="enabled"
    :confirm-loading="saving"
    @save="handleSaveRules"
  />
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useMessage } from '@/hooks/web/useMessage';
import { getDeviceThreshold, saveDeviceThreshold } from '@/api/device/devices';
import ThresholdRuleModal from '../../ThresholdRuleModal.vue';
import type { ThresholdRule } from '../../healthIndex';
import { getDefaultHealthWeight, isDefaultCriticalProperty } from '../../healthIndex';

const emit = defineEmits(['saved']);
const { createMessage } = useMessage();

const visible = ref(false);
const saving = ref(false);
const propertyCode = ref('');
const propertyName = ref('');
const deviceIdentification = ref('');
const currentValue = ref<any>(null);
const thresholdId = ref<number | null>(null);
const editingRules = ref<ThresholdRule[]>([]);
const alarmLevel = ref('WARNING');
const enabled = ref(true);

function deriveMinMax(rules: ThresholdRule[]) {
  let minValue: number | undefined;
  let maxValue: number | undefined;
  for (const rule of rules) {
    const num = Number(rule.value);
    if (!Number.isFinite(num)) continue;
    if (rule.operator === '>' || rule.operator === '>=') {
      maxValue = maxValue == null ? num : Math.min(maxValue, num);
    }
    if (rule.operator === '<' || rule.operator === '<=') {
      minValue = minValue == null ? num : Math.max(minValue, num);
    }
  }
  return { minValue, maxValue };
}

async function open(payload: {
  deviceIdentification: string;
  propertyCode: string;
  propertyName?: string;
  currentValue?: any;
}) {
  deviceIdentification.value = payload.deviceIdentification;
  propertyCode.value = payload.propertyCode;
  propertyName.value = payload.propertyName || payload.propertyCode;
  currentValue.value = payload.currentValue;
  thresholdId.value = null;
  editingRules.value = [];
  alarmLevel.value = 'WARNING';
  enabled.value = true;
  visible.value = true;
  try {
    const res = await getDeviceThreshold(payload.deviceIdentification, payload.propertyCode);
    const data = res?.data || res;
    if (data?.id) {
      thresholdId.value = data.id;
      alarmLevel.value = data.alarmLevel || 'WARNING';
      enabled.value = data.enabled !== 0;
      if (data.rulesJson) {
        try {
          editingRules.value = JSON.parse(data.rulesJson) || [];
        } catch {
          editingRules.value = [];
        }
      }
      if (!editingRules.value.length) {
        const rules: ThresholdRule[] = [];
        const weight = data.healthWeight || getDefaultHealthWeight(payload.propertyCode);
        const criticalFlag = data.critical === 1;
        if (data.minValue != null) {
          rules.push({
            operator: '<',
            value: data.minValue,
            weight,
            critical: criticalFlag,
          });
        }
        if (data.maxValue != null) {
          rules.push({
            operator: '>',
            value: data.maxValue,
            weight,
            critical: criticalFlag,
          });
        }
        editingRules.value = rules;
      }
    } else {
      editingRules.value = [];
      enabled.value = true;
      alarmLevel.value = isDefaultCriticalProperty(payload.propertyCode) ? 'CRITICAL' : 'WARNING';
    }
  } catch (e) {
    console.error(e);
  }
}

async function handleSaveRules(payload: {
  rules: ThresholdRule[];
  healthWeight: number;
  critical: boolean;
  alarmLevel: string;
  enabled: boolean;
  clear?: boolean;
}) {
  saving.value = true;
  try {
    const rules = payload.rules || [];
    const { minValue, maxValue } = deriveMinMax(rules);
    await saveDeviceThreshold({
      id: thresholdId.value || undefined,
      deviceIdentification: deviceIdentification.value,
      propertyCode: propertyCode.value,
      propertyName: propertyName.value,
      minValue,
      maxValue,
      rulesJson: JSON.stringify(rules),
      healthWeight: payload.healthWeight,
      critical: payload.critical ? 1 : 0,
      alarmLevel: payload.alarmLevel || 'WARNING',
      enabled: payload.clear || !payload.enabled || !rules.length ? 0 : 1,
    });
    createMessage.success(
      payload.clear || !rules.length || !payload.enabled ? '阈值已关闭/清空' : '阈值配置已保存',
    );
    visible.value = false;
    emit('saved');
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
  } finally {
    saving.value = false;
  }
}

defineExpose({ open });
</script>

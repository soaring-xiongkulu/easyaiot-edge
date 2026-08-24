<template>
  <Drawer
    v-model:open="visibleModel"
    placement="right"
    :width="1400"
    :destroy-on-close="true"
    :mask-closable="!confirmLoading"
    root-class-name="threshold-config-drawer"
    @close="close"
  >
    <template #title>
      <div class="drawer-title">
        <div class="drawer-title-icon">
          <Icon icon="ant-design:sliders-outlined" :size="22" />
        </div>
        <div>
          <div class="drawer-title-main">参数阈值配置</div>
          <div class="drawer-title-sub">设定越限条件，触发后按设备告警策略推送通知</div>
        </div>
      </div>
    </template>

    <div class="drawer-body">
      <section class="hero">
        <div class="hero-left">
          <div class="prop-name">{{ propertyName || parameter || '--' }}</div>
          <div class="prop-meta">
            <span class="mono">{{ parameter || '--' }}</span>
            <span class="dot" />
            <span>{{ editingRules.length }} 条条件</span>
            <span class="dot" />
            <span :class="enabled ? 'on' : 'off'">{{ enabled ? '已启用' : '已关闭' }}</span>
          </div>
        </div>
        <div class="hero-value" :class="previewStatus">
          <span class="label">当前值</span>
          <strong>{{ formatValue(currentValue) }}</strong>
          <em>{{ previewStatusText }}</em>
        </div>
      </section>

      <section class="section">
        <div class="section-head">
          <div>
            <h3>判定条件</h3>
            <p>满足任一条件即判定超限，可组合上下限</p>
          </div>
          <div class="presets">
            <Button size="small" @click="applyPreset('upper')">仅上限</Button>
            <Button size="small" @click="applyPreset('lower')">仅下限</Button>
            <Button size="small" @click="applyPreset('range')">上下限</Button>
            <Button size="small" @click="applyPreset('equal')">等于</Button>
          </div>
        </div>

        <div v-if="editingRules.length" class="rule-list">
          <div v-for="(rule, index) in editingRules" :key="index" class="rule-row">
            <span class="rule-idx">{{ index + 1 }}</span>
            <span class="rule-when">当实际值</span>
            <Select v-model:value="rule.operator" :options="operatorOptions" class="rule-op" />
            <Input
              v-model:value="rule.valueText"
              class="rule-val"
              placeholder="比较值：数字 / true / false / 文本"
              allow-clear
            />
            <Button
              danger
              type="text"
              size="small"
              preIcon="ant-design:delete-outlined"
              @click="removeRule(index)"
            />
          </div>
        </div>
        <div v-else class="empty">
          <Icon icon="ant-design:sliders-outlined" />
          <p>尚未配置判定条件，可使用上方预设快速生成</p>
        </div>
        <Button type="dashed" block preIcon="ant-design:plus-outlined" @click="addRule">
          添加条件
        </Button>
      </section>

      <section class="section">
        <div class="section-head">
          <div>
            <h3>健康与告警</h3>
            <p>权重影响健康评分；关键属性超限会使健康指数归零</p>
          </div>
        </div>
        <div class="options-grid">
          <div class="field">
            <label>健康权重</label>
            <InputNumber
              v-model:value="healthWeight"
              :min="1"
              :max="100"
              :precision="0"
              style="width: 100%"
              placeholder="1–100"
            />
          </div>
          <div class="field">
            <label>告警级别</label>
            <Select
              v-model:value="alarmLevel"
              :options="alarmLevelOptions"
              style="width: 100%"
              :disabled="critical"
            />
          </div>
          <div class="toggle">
            <div>
              <strong>启用阈值</strong>
              <span>关闭后不参与判定与推送</span>
            </div>
            <Switch v-model:checked="enabled" checked-children="开" un-checked-children="关" />
          </div>
          <div class="toggle">
            <div>
              <strong>关键属性</strong>
              <span>超限时健康指数直接归零</span>
            </div>
            <Switch v-model:checked="critical" checked-children="是" un-checked-children="否" />
          </div>
        </div>
      </section>
    </div>

    <template #footer>
      <div class="drawer-footer">
        <Button @click="handleClear" :disabled="!editingRules.length && !enabled">清空阈值</Button>
        <div class="footer-right">
          <Button @click="close">取消</Button>
          <Button type="primary" :loading="confirmLoading" @click="handleSave">保存配置</Button>
        </div>
      </div>
    </template>
  </Drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { Drawer, Input, InputNumber, Select, Switch } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getDefaultHealthWeight,
  isDefaultCriticalProperty,
  type ThresholdOperator,
  type ThresholdRule,
} from './healthIndex';

interface EditingThresholdRule {
  operator: ThresholdOperator;
  valueText: string;
}

const props = withDefaults(
  defineProps<{
    visible: boolean;
    parameter: string;
    propertyName?: string;
    currentValue: any;
    rules?: ThresholdRule[];
    confirmLoading?: boolean;
    alarmLevel?: string;
    enabled?: boolean;
  }>(),
  {
    propertyName: '',
    rules: () => [],
    confirmLoading: false,
    alarmLevel: 'WARNING',
    enabled: true,
  },
);

const emit = defineEmits<{
  (event: 'update:visible', visible: boolean): void;
  (
    event: 'save',
    payload: {
      rules: ThresholdRule[];
      healthWeight: number;
      critical: boolean;
      alarmLevel: string;
      enabled: boolean;
      clear?: boolean;
    },
  ): void;
}>();

const { createMessage } = useMessage();
const editingRules = ref<EditingThresholdRule[]>([]);
const healthWeight = ref(10);
const critical = ref(false);
const enabled = ref(true);
const alarmLevel = ref('WARNING');

const operatorOptions = [
  { label: '> 大于', value: '>' },
  { label: '≥ 大于等于', value: '>=' },
  { label: '< 小于', value: '<' },
  { label: '≤ 小于等于', value: '<=' },
  { label: '= 等于', value: '=' },
];

const alarmLevelOptions = [
  { label: '提示 INFO', value: 'INFO' },
  { label: '警告 WARNING', value: 'WARNING' },
  { label: '严重 CRITICAL', value: 'CRITICAL' },
];

const visibleModel = computed({
  get: () => props.visible,
  set: (visible: boolean) => emit('update:visible', visible),
});

function close() {
  visibleModel.value = false;
}

function toEditingText(value: any) {
  if (typeof value === 'string') return value;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function parseEditingValue(valueText: string) {
  const text = valueText.trim();
  if (!text) throw new Error('比较值不能为空');
  if (text === 'true') return true;
  if (text === 'false') return false;
  const asNumber = Number(text);
  if (text !== '' && Number.isFinite(asNumber) && String(asNumber) === text) return asNumber;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function formatValue(value: any) {
  if (value == null || value === '') return '--';
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
  return String(value);
}

function compareValue(actual: any, operator: ThresholdOperator, expected: any) {
  const leftNum = Number(actual);
  const rightNum = Number(expected);
  if (Number.isFinite(leftNum) && Number.isFinite(rightNum)) {
    if (operator === '>') return leftNum > rightNum;
    if (operator === '>=') return leftNum >= rightNum;
    if (operator === '<') return leftNum < rightNum;
    if (operator === '<=') return leftNum <= rightNum;
    if (operator === '=') return leftNum === rightNum;
  }
  const left = String(actual);
  const right = String(expected);
  if (operator === '=') return left === right;
  return false;
}

const draftRules = computed<ThresholdRule[]>(() => {
  return editingRules.value
    .map((rule) => {
      try {
        return {
          operator: rule.operator,
          value: parseEditingValue(rule.valueText),
          weight: Math.round(healthWeight.value),
          critical: critical.value,
        } as ThresholdRule;
      } catch {
        return null;
      }
    })
    .filter(Boolean) as ThresholdRule[];
});

const isBreachedNow = computed(() => {
  if (!enabled.value || !draftRules.value.length) return false;
  if (props.currentValue == null || props.currentValue === '') return false;
  return draftRules.value.some((rule) => compareValue(props.currentValue, rule.operator, rule.value));
});

const previewStatus = computed(() => {
  if (!editingRules.value.length || !enabled.value) return 'idle';
  if (props.currentValue == null || props.currentValue === '') return 'unknown';
  return isBreachedNow.value ? 'breach' : 'normal';
});

const previewStatusText = computed(() => {
  if (previewStatus.value === 'breach') return '当前已超限';
  if (previewStatus.value === 'normal') return '当前正常';
  if (previewStatus.value === 'unknown') return '无当前值';
  return '未启用判定';
});

function syncRules() {
  const configuredRule = props.rules[0];
  healthWeight.value = configuredRule?.weight ?? getDefaultHealthWeight(props.parameter);
  critical.value = configuredRule?.critical ?? isDefaultCriticalProperty(props.parameter);
  alarmLevel.value = props.alarmLevel || (critical.value ? 'CRITICAL' : 'WARNING');
  enabled.value = props.enabled !== false;
  editingRules.value = (props.rules || []).map((rule) => ({
    operator: rule.operator,
    valueText: toEditingText(rule.value),
  }));
}

function suggestSeedValue() {
  const num = Number(props.currentValue);
  if (Number.isFinite(num)) return String(num);
  if (typeof props.currentValue === 'boolean') return String(props.currentValue);
  return '';
}

function applyPreset(type: 'upper' | 'lower' | 'range' | 'equal') {
  const seed = suggestSeedValue();
  if (type === 'upper') {
    editingRules.value = [{ operator: '>', valueText: seed }];
  } else if (type === 'lower') {
    editingRules.value = [{ operator: '<', valueText: seed }];
  } else if (type === 'equal') {
    editingRules.value = [{ operator: '=', valueText: seed || 'true' }];
  } else {
    const n = Number(seed);
    if (Number.isFinite(n)) {
      editingRules.value = [
        { operator: '<', valueText: String(Math.round(n * 0.8 * 100) / 100) },
        { operator: '>', valueText: String(Math.round(n * 1.2 * 100) / 100) },
      ];
    } else {
      editingRules.value = [
        { operator: '<', valueText: '' },
        { operator: '>', valueText: '' },
      ];
    }
  }
}

function addRule() {
  if (editingRules.value.length >= 20) {
    createMessage.warning('单个参数最多配置 20 条规则');
    return;
  }
  editingRules.value.push({ operator: '>', valueText: suggestSeedValue() });
}

function removeRule(index: number) {
  editingRules.value.splice(index, 1);
}

function handleClear() {
  emit('save', {
    rules: [],
    healthWeight: Math.round(healthWeight.value),
    critical: critical.value,
    alarmLevel: alarmLevel.value,
    enabled: false,
    clear: true,
  });
}

function handleSave() {
  try {
    if (!Number.isFinite(healthWeight.value) || healthWeight.value < 1 || healthWeight.value > 100) {
      throw new Error('健康权重必须是 1 到 100 的整数');
    }
    if (enabled.value && !editingRules.value.length) {
      throw new Error('启用阈值时请至少添加一条判定条件');
    }
    const rules = editingRules.value.map((rule) => ({
      operator: rule.operator,
      value: parseEditingValue(rule.valueText),
      weight: Math.round(healthWeight.value),
      critical: critical.value,
    }));
    emit('save', {
      rules,
      healthWeight: Math.round(healthWeight.value),
      critical: critical.value,
      alarmLevel: critical.value ? 'CRITICAL' : alarmLevel.value,
      enabled: enabled.value,
    });
  } catch (error: any) {
    createMessage.warning(error?.message || '请检查阈值规则');
  }
}

watch(
  [() => props.visible, () => props.parameter, () => props.rules],
  ([visible]) => {
    if (visible) syncRules();
  },
);
</script>

<style lang="less" scoped>
.drawer-title {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-right: 28px;
}

.drawer-title-icon {
  width: 42px;
  height: 42px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(145deg, #edf3ff, #d9e6ff);
  color: #1677ff;
}

.drawer-title-main {
  font-size: 17px;
  font-weight: 600;
  color: #111827;
}

.drawer-title-sub {
  margin-top: 2px;
  font-size: 13px;
  color: #8c8c8c;
}

.drawer-body {
  display: flex;
  flex-direction: column;
  gap: 24px;
  max-width: 1280px;
  margin: 0 auto;
}

.hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 32px;
  padding: 28px 32px;
  border-radius: 16px;
  background: linear-gradient(135deg, #f7faff 0%, #ffffff 55%);
  border: 1px solid #e8eef7;
}

.prop-name {
  font-size: 24px;
  font-weight: 650;
  color: #111827;
  letter-spacing: -0.02em;
}

.prop-meta {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 13px;
  color: #8c8c8c;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  color: #64748b;
}

.dot {
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: #cbd5e1;
}

.on {
  color: #389e0d;
}
.off {
  color: #8c8c8c;
}

.hero-value {
  min-width: 150px;
  text-align: right;
  padding: 12px 16px;
  border-radius: 12px;
  background: #fff;
  border: 1px solid #e8ecf2;

  .label {
    display: block;
    font-size: 12px;
    color: #8c8c8c;
  }

  strong {
    display: block;
    margin-top: 4px;
    font-size: 28px;
    line-height: 1.15;
    color: #1677ff;
  }

  em {
    display: block;
    margin-top: 4px;
    font-style: normal;
    font-size: 12px;
    color: #8c8c8c;
  }

  &.normal {
    border-color: #b7eb8f;
    background: #f6ffed;
    strong,
    em {
      color: #389e0d;
    }
  }

  &.breach {
    border-color: #ffa39e;
    background: #fff2f0;
    strong,
    em {
      color: #cf1322;
    }
  }
}

.section {
  padding: 28px 32px;
  border-radius: 16px;
  background: #fff;
  border: 1px solid #e8ecf2;
}

.section-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20px;
  margin-bottom: 22px;

  h3 {
    margin: 0;
    font-size: 17px;
    font-weight: 600;
    color: #111827;
  }

  p {
    margin: 8px 0 0;
    font-size: 13px;
    color: #8c8c8c;
  }
}

.presets {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.rule-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}

.rule-row {
  display: grid;
  grid-template-columns: 40px 80px 180px 1fr 48px;
  gap: 12px;
  align-items: center;
  padding: 14px 18px;
  border-radius: 12px;
  background: #f8fafc;
  border: 1px solid #eef2f7;
}

.rule-idx {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: #e8f1ff;
  color: #1677ff;
  font-size: 13px;
  font-weight: 600;
}

.rule-when {
  color: #64748b;
  font-size: 13px;
}

.empty {
  margin-bottom: 12px;
  padding: 40px 16px;
  text-align: center;
  border: 1px dashed #d9d9d9;
  border-radius: 12px;
  color: #8c8c8c;
  background: #fafafa;

  :deep(svg) {
    font-size: 28px;
    color: #bfbfbf;
    margin-bottom: 8px;
  }

  p {
    margin: 0;
    font-size: 13px;
  }
}

.options-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 18px 24px;
}

.field {
  label {
    display: block;
    margin-bottom: 8px;
    font-size: 13px;
    color: #595959;
  }
}

.toggle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  border-radius: 10px;
  background: #f8fafc;
  border: 1px solid #eef2f7;

  strong {
    display: block;
    font-size: 14px;
    color: #111827;
  }

  span {
    display: block;
    margin-top: 2px;
    font-size: 12px;
    color: #8c8c8c;
  }
}

.drawer-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.footer-right {
  display: flex;
  gap: 12px;
}

@media (max-width: 720px) {
  .hero {
    flex-direction: column;
    align-items: stretch;
  }

  .hero-value {
    text-align: left;
  }

  .options-grid,
  .rule-row {
    grid-template-columns: 1fr;
  }

  .section-head {
    flex-direction: column;
  }
}
</style>

<style lang="less">
.threshold-config-drawer {
  .ant-drawer-header {
    padding: 20px 36px;
    border-bottom: 1px solid #eef0f4;
  }

  .ant-drawer-body {
    padding: 28px 36px 36px;
    background: #f5f7fb;
  }

  .ant-drawer-footer {
    padding: 16px 36px;
    border-top: 1px solid #eef0f4;
    background: #fff;
  }
}
</style>

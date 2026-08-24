<template>
  <div class="ops-page product-script">
    <div class="script-bar">
      <div class="script-bar-items">
        <div class="bar-item">
          <span class="bar-label">启用脚本</span>
          <BasicHelp
            class="bar-help"
            text="标准 JSON 可不配脚本；私有协议需实现 rawDataToProtocol / protocolToRawData 后保存热加载。"
            placement="top"
          />
          <BasicForm
            class="switch-form"
            @register="registerConfigForm"
            @field-value-change="onConfigFieldChange"
          />
        </div>
        <span class="bar-sep" />
        <div class="bar-item">
          <span class="bar-label">脚本版本</span>
          <span class="bar-text">{{ versionLabel }}</span>
        </div>
        <span class="bar-sep" />
        <div class="bar-item">
          <span class="bar-label">运行状态</span>
          <span :class="['status-pill', runtimeLoaded ? 'is-ok' : 'is-muted']">
            {{ runtimeLoaded ? '已热加载' : '未加载' }}
          </span>
        </div>
        <span class="bar-sep" />
        <div class="bar-item bar-item-templates">
          <span class="bar-label">协议模板</span>
          <BasicHelp
            class="bar-help"
            text="选择模板会覆盖编辑器内容，保存后才会写入运行时"
            placement="top"
          />
          <div class="template-actions">
            <Button
              v-for="t in templates"
              :key="t.id"
              size="small"
              :type="activeTemplateId === t.id ? 'primary' : 'default'"
              :title="t.description"
              @click="applyTemplate(t.id)"
            >
              {{ templateShortName(t.id) }}
            </Button>
          </div>
        </div>
      </div>
      <div class="script-bar-actions">
        <Button size="small" @click="handleCheck" :loading="checking">校验</Button>
        <Button
          size="small"
          type="primary"
          @click="handleSave"
          :loading="saving"
          title="保存并热加载"
        >
          保存
        </Button>
        <PopConfirmButton
          size="small"
          danger
          :disabled="!form.id"
          :loading="deleting"
          title="确定删除协议脚本？将从数据库删除并卸载运行时脚本。"
          @confirm="handleDelete"
        >
          删除
        </PopConfirmButton>
        <Button size="small" @click="loadScript" :loading="loading">刷新</Button>
      </div>
    </div>

    <!-- 主体：左编辑 + 右调试 -->
    <div class="script-body">
      <div class="ops-surface panel-editor">
        <div class="ops-surface-head editor-head">
          <div class="ops-surface-title">
            脚本编辑
            <BasicHelp class="title-help" :text="fnHelpLines" placement="right" />
          </div>
        </div>
        <div class="ops-surface-body editor-box">
          <CodeEditor
            v-model:value="form.scriptContent"
            :mode="MODE.JS"
            :auto-format="false"
            bordered
          />
        </div>
      </div>

      <div class="ops-surface panel-sim">
        <div class="ops-surface-head">
          <div class="ops-surface-title">即时调试</div>
          <div class="head-actions">
            <RadioButtonGroup
              v-model:value="simDirection"
              :options="directionOptions"
              button-style="solid"
              size="small"
            />
            <Button
              @click="fillSample"
              preIcon="ant-design:file-text-outlined"
            >
              填入示例
            </Button>
            <Button
              type="primary"
              @click="runSimulate"
              :loading="simulating"
              preIcon="ant-design:play-circle-outlined"
            >
              运行
            </Button>
          </div>
        </div>

        <BasicForm @register="registerSimForm" class="sim-form" />

        <div class="sim-output">
          <div class="output-head">
            <span>输出结果</span>
            <span v-if="simResult?.success" class="output-meta ok">
              {{ simResult.elapsedMs }}ms · {{ simResult.outputLength }} bytes
            </span>
            <span v-else-if="simResult && !simResult.success" class="output-meta err">
              {{ simResult.message }}
            </span>
          </div>

          <div v-if="!simResult" class="output-empty">
            <Icon icon="ant-design:experiment-outlined" :size="28" class="output-empty-icon" />
            <p>填写输入后点「运行」或 Ctrl+Enter</p>
          </div>

          <template v-else>
            <div class="output-switch">
              <RadioButtonGroup
                v-model:value="outputTab"
                :options="outputTabOptions"
                button-style="solid"
                size="small"
              />
            </div>
            <ScrollContainer class="output-scroll">
              <JsonPreview v-if="outputTab === 'json' && simResult.outputJson" :data="simResult.outputJson" />
              <pre v-else class="mono-block">{{ outputContent }}</pre>
            </ScrollContainer>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { Button, PopConfirmButton } from '@/components/Button';
import { BasicHelp } from '@/components/Basic';
import { CodeEditor, JsonPreview, MODE } from '@/components/CodeEditor';
import { ScrollContainer } from '@/components/Container';
import { BasicForm, RadioButtonGroup, useForm } from '@/components/Form';
import type { FormSchema } from '@/components/Form';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import {
  checkProductScript,
  deleteProductScript,
  getProductScript,
  getProductScriptTemplates,
  saveProductScript,
  simulateProductScript,
} from '@/api/device/product';
import { DEFAULT_SCRIPT_SKELETON, resolveScriptContent } from '../data/productScriptTemplate';

const props = defineProps({
  productId: { type: [Number, String], default: undefined },
  productIdentification: { type: String, default: '' },
});

const { createMessage, createConfirm } = useMessage();

const saving = ref(false);
const checking = ref(false);
const loading = ref(false);
const deleting = ref(false);
const simulating = ref(false);
const runtimeLoaded = ref(false);
const activeTemplateId = ref<string>();
const templates = ref<Array<{ id: string; name: string; description: string; content: string }>>([]);
const simDirection = ref<'uplink' | 'downlink'>('uplink');
const simResult = ref<SimResult | null>(null);
const outputTab = ref('text');

interface SimResult {
  success: boolean;
  message?: string;
  elapsedMs?: number;
  outputLength?: number;
  outputText?: string;
  outputHex?: string;
  outputJson?: Record<string, unknown>;
}

const form = reactive({
  id: undefined as number | undefined,
  productId: undefined as number | undefined,
  productIdentification: '',
  scriptEnabled: false,
  scriptContent: DEFAULT_SCRIPT_SKELETON,
  scriptVersion: undefined as number | undefined,
});

const fnHelpLines = [
  'rawDataToProtocol(topic, bytes) — 上行：设备原始 → 平台 JSON',
  'protocolToRawData(topic, message) — 下行：平台消息 → 设备原始',
  '返回 byte[] 或 UTF-8 字符串；Java Map 请用 jsUtil.toJsonString',
];

const TEMPLATE_SHORT: Record<string, string> = {
  skeleton: '默认骨架',
  compact_text: 'EA 文本',
  binary: '二进制',
  passthrough: '透传',
};

const directionOptions = [
  { label: '上行解码', value: 'uplink' },
  { label: '下行编码', value: 'downlink' },
];

const outputTabOptions = computed(() => {
  const opts = [
    { label: '文本', value: 'text' },
    { label: 'Hex', value: 'hex' },
  ];
  if (simResult.value?.outputJson) {
    opts.push({ label: 'JSON', value: 'json' });
  }
  return opts;
});

/** 脚本版本仅在「保存并热加载」后由后端写入，应用模板不会生成版本号 */
const versionLabel = computed(() => {
  if (form.scriptVersion != null && form.scriptVersion > 0) {
    return `v${form.scriptVersion}`;
  }
  return '未保存';
});

function normalizeProductScript(data: Recordable | null | undefined) {
  if (!data) return null;
  if (data.productIdentification) return data;
  if (data.data?.productIdentification) return data.data;
  return null;
}

const [registerConfigForm, { setFieldsValue: setConfigFields }] = useForm({
  showActionButtonGroup: false,
  compact: true,
  labelWidth: 0,
  baseColProps: { span: 24 },
  schemas: [
    {
      field: 'scriptEnabled',
      label: '',
      component: 'Switch',
      componentProps: {
        checkedChildren: '开',
        unCheckedChildren: '关',
        size: 'small',
      },
    },
  ],
});

function onConfigFieldChange(key: string, value: unknown) {
  if (key === 'scriptEnabled') {
    form.scriptEnabled = !!value;
  }
}

async function syncConfigForm() {
  await setConfigFields({ scriptEnabled: form.scriptEnabled });
}

const topicPlaceholder = computed(() =>
  simDirection.value === 'uplink'
    ? '/iot/{product}/{device}/property/upstream/report'
    : '/iot/{product}/{device}/service/downstream/invoke/reboot',
);

const simSchemas = computed((): FormSchema[] => {
  const topicField: FormSchema = {
    field: 'topic',
    label: 'Topic',
    component: 'Input',
    componentProps: {
      placeholder: topicPlaceholder.value,
    },
    colProps: { span: 24 },
  };
  if (simDirection.value === 'uplink') {
    return [
      topicField,
      {
        field: 'payloadText',
        label: '设备载荷',
        component: 'InputTextArea',
        componentProps: {
          rows: 4,
          placeholder: 'EA|UP|1|req|PROP|Vbatt=3.72;RSSI=-62',
          class: 'mono-input',
        },
        colProps: { span: 24 },
      },
      {
        field: 'payloadHex',
        label: 'Hex（优先）',
        component: 'Input',
        componentProps: {
          allowClear: true,
          placeholder: 'ea0150...',
          class: 'mono-input',
        },
        helpMessage: '可选；填写后优先于上方文本',
        colProps: { span: 24 },
      },
    ];
  }
  return [
    topicField,
    {
      field: 'messageJson',
      label: '平台消息',
      component: 'InputTextArea',
      componentProps: {
        rows: 5,
        class: 'mono-input',
      },
      colProps: { span: 24 },
    },
  ];
});

const [registerSimForm, { setFieldsValue, getFieldsValue, resetSchema }] = useForm({
  labelWidth: 72,
  showActionButtonGroup: false,
  compact: true,
  baseColProps: { span: 24 },
  schemas: simSchemas.value,
});

const outputContent = computed(() => {
  if (!simResult.value) return '';
  if (outputTab.value === 'hex') return simResult.value.outputHex || '(空)';
  return simResult.value.outputText || '(空)';
});

function templateShortName(id: string) {
  return TEMPLATE_SHORT[id] || id;
}

function buildDefaultSimValues() {
  const p = props.productIdentification || 'PRODUCT';
  const d = 'DEVICE';
  return {
    topic:
      simDirection.value === 'uplink'
        ? `/iot/${p}/${d}/property/upstream/report`
        : `/iot/${p}/${d}/service/downstream/invoke/reboot`,
    payloadText: `EA|UP|1|demoReq001|PROP|deviceId=${d};serviceId=demo-svc;Vbatt=3.72;RSSI=-62;PVAngle_X=1.2;PVAngle_Y=-0.4;PVAngle_Z=0.1;eventTime=${new Date().toISOString()}`,
    payloadHex: '',
    messageJson: JSON.stringify(
      {
        tenantId: 1,
        requestId: 'demoDown001',
        method: 'thing.service.invoke',
        params: { action: 'on', from: 'product-script-ui' },
      },
      null,
      2,
    ),
  };
}

async function syncSimFormSchema() {
  await resetSchema(simSchemas.value);
  await nextTick();
  await setFieldsValue(buildDefaultSimValues());
}

async function fillSample() {
  await setFieldsValue(buildDefaultSimValues());
  createMessage.success('已填入示例');
}

async function loadTemplates() {
  try {
    const data = await getProductScriptTemplates();
    templates.value = Array.isArray(data) ? data : [];
  } catch (e) {
    console.warn('加载脚本模板失败', e);
  }
}

async function loadScript() {
  if (!props.productIdentification) return;
  loading.value = true;
  try {
    const data = normalizeProductScript(await getProductScript(props.productIdentification));
    if (data) {
      form.id = data.id;
      form.productId = data.productId;
      form.productIdentification = data.productIdentification;
      form.scriptEnabled = !!data.scriptEnabled;
      form.scriptContent = resolveScriptContent(data.scriptContent);
      form.scriptVersion = data.scriptVersion;
      runtimeLoaded.value = !!data.scriptEnabled && !!data.scriptContent;
      if (!data.scriptContent?.trim()) {
        activeTemplateId.value = 'skeleton';
      }
    } else {
      form.id = undefined;
      form.productId = props.productId ? Number(props.productId) : undefined;
      form.productIdentification = props.productIdentification;
      form.scriptEnabled = false;
      form.scriptContent = DEFAULT_SCRIPT_SKELETON;
      form.scriptVersion = undefined;
      runtimeLoaded.value = false;
      activeTemplateId.value = 'skeleton';
    }
    await syncConfigForm();
    await syncSimFormSchema();
  } catch (e) {
    console.warn('加载产品脚本失败', e);
  } finally {
    loading.value = false;
  }
}

function applyTemplate(id: string) {
  const t = templates.value.find((x) => x.id === id);
  if (!t) return;
  createConfirm({
    title: `应用「${t.name}」？`,
    iconType: 'warning',
    content: '将覆盖当前编辑器内容，未保存前可点刷新还原。',
    async onOk() {
      form.scriptContent = t.content;
      form.scriptEnabled = true;
      activeTemplateId.value = id;
      simResult.value = null;
      await syncConfigForm();
      createMessage.success('已应用模板，可右侧试运行后保存');
    },
  });
}

async function handleCheck() {
  if (!form.scriptContent?.trim()) {
    createMessage.warning('请先填写脚本');
    return;
  }
  checking.value = true;
  try {
    const res = await checkProductScript(form.scriptContent);
    createMessage.success(res?.message || '校验通过');
  } catch (e: any) {
    createMessage.error(e?.message || '校验失败');
  } finally {
    checking.value = false;
  }
}

async function handleSave() {
  if (!props.productIdentification) {
    createMessage.warning('缺少产品标识');
    return;
  }
  if (form.scriptEnabled && !form.scriptContent?.trim()) {
    createMessage.warning('启用时脚本不能为空');
    return;
  }
  saving.value = true;
  try {
    const res = await saveProductScript({
      id: form.id,
      productId: form.productId || (props.productId ? Number(props.productId) : undefined),
      productIdentification: props.productIdentification,
      scriptEnabled: form.scriptEnabled,
      scriptContent: form.scriptContent,
    });
    runtimeLoaded.value = !!res?.loaded;
    if (res?.scriptVersion != null) {
      form.scriptVersion = res.scriptVersion;
    }
    createMessage.success(
      form.scriptEnabled ? `已保存并热加载 v${res?.scriptVersion || ''}` : '已保存（未启用）',
    );
    await loadScript();
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
  } finally {
    saving.value = false;
  }
}

async function handleDelete() {
  if (!form.id && !form.productId) return;
  deleting.value = true;
  try {
    await deleteProductScript(Number(form.productId || props.productId), props.productIdentification);
    createMessage.success('已删除');
    form.scriptContent = DEFAULT_SCRIPT_SKELETON;
    form.scriptEnabled = false;
    form.id = undefined;
    form.scriptVersion = undefined;
    runtimeLoaded.value = false;
    activeTemplateId.value = 'skeleton';
    simResult.value = null;
    await syncConfigForm();
  } catch (e: any) {
    createMessage.error(e?.message || '删除失败');
  } finally {
    deleting.value = false;
  }
}

async function runSimulate() {
  if (!form.scriptContent?.trim()) {
    createMessage.warning('请先填写或应用模板');
    return;
  }
  const direction = simDirection.value;
  const values = await getFieldsValue();
  simulating.value = true;
  simResult.value = null;
  try {
    const body: {
      scriptContent: string;
      direction: string;
      topic: string;
      payloadText?: string;
      payloadHex?: string;
      message?: Record<string, unknown>;
    } = {
      scriptContent: form.scriptContent,
      direction,
      topic: values.topic || topicPlaceholder.value,
    };
    if (direction === 'uplink') {
      body.payloadText = values.payloadText;
      body.payloadHex = values.payloadHex || undefined;
    } else {
      try {
        body.message = JSON.parse(values.messageJson || '{}');
      } catch {
        createMessage.error('JSON 格式错误');
        simulating.value = false;
        return;
      }
    }
    const data = await simulateProductScript(body);
    simResult.value = data;
    outputTab.value = data?.outputJson ? 'json' : 'text';
    if (data?.success) {
      createMessage.success('运行成功');
    }
  } catch (e: any) {
    simResult.value = {
      success: false,
      message: e?.message || '运行失败',
      elapsedMs: 0,
      outputLength: 0,
    };
    createMessage.error(e?.message || '运行失败');
  } finally {
    simulating.value = false;
  }
}

function onKeydown(e: KeyboardEvent) {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    e.preventDefault();
    runSimulate();
  }
}

watch(simDirection, async () => {
  simResult.value = null;
  await syncSimFormSchema();
});

watch(
  () => props.productIdentification,
  () => {
    activeTemplateId.value = undefined;
    simResult.value = null;
    loadScript();
  },
);

onMounted(async () => {
  window.addEventListener('keydown', onKeydown);
  await loadTemplates();
  await loadScript();
});

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown);
});
</script>

<style scoped lang="less">
@import '@/views/devices/components/styles/device-ops.less';

.product-script {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0 !important;
  gap: 8px;
  padding: 0;
  overflow: hidden;
  box-sizing: border-box;
}

.script-bar {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 6px 10px;
  background: @ops-surface;
  border: 1px solid @ops-border;
  border-radius: 6px;
}

.script-bar-items {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  min-width: 0;
  overflow: hidden;
}

.script-bar-actions {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.bar-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.bar-item-templates {
  flex: 1;
  min-width: 0;
  overflow: hidden;
}

.bar-sep {
  width: 1px;
  height: 14px;
  background: @ops-border;
  flex-shrink: 0;
}

.bar-label {
  font-size: 12px;
  color: @ops-muted;
  white-space: nowrap;
}

.bar-help {
  margin: 0;
}

.bar-text {
  font-size: 12px;
  color: @ops-ink;
  white-space: nowrap;
}

.switch-form {
  margin: 0;

  :deep(.ant-form-item) {
    margin-bottom: 0;
  }

  :deep(.ant-form-item-control-input) {
    min-height: auto;
  }
}

.status-pill {
  display: inline-block;
  padding: 0 6px;
  font-size: 11px;
  line-height: 18px;
  border-radius: 3px;
  white-space: nowrap;
  background: #f5f5f5;
  color: @ops-subtle;

  &.is-ok {
    background: fade(@ops-success, 12%);
    color: @ops-success;
  }
}

.template-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 0;
  overflow-x: auto;
  flex-wrap: nowrap;

  &::-webkit-scrollbar {
    height: 0;
  }
}

.head-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.script-body {
  flex: 1 1 0;
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr);
  grid-template-rows: minmax(0, 1fr);
  align-items: stretch;
  gap: 8px;
  overflow: hidden;
}

.panel-editor,
.panel-sim {
  height: 100%;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.panel-editor {
  .editor-head {
    flex-shrink: 0;
    min-height: 36px;
    padding: 6px 12px;
  }
}

.panel-sim {
  .ops-surface-head {
    flex-wrap: wrap;
    gap: 8px;
    min-height: 36px;
    padding: 6px 12px;
  }
}

.title-help {
  margin-left: 6px;
}

.editor-box {
  flex: 1 1 0;
  min-height: 0;
  overflow: hidden;
  padding: 8px;
  display: flex;
  flex-direction: column;

  :deep(> .h-full) {
    flex: 1 1 0;
    min-height: 0;
    height: 100% !important;
    overflow: hidden;
    position: relative;
  }

  :deep(.relative) {
    height: 100% !important;
    min-height: 0;
  }

  :deep(.CodeMirror) {
    height: 100% !important;
    box-sizing: border-box;
  }

  :deep(.CodeMirror-scroll) {
    height: 100% !important;
    max-height: none;
    overflow: auto !important;
  }
}

.sim-form {
  flex: 0 1 auto;
  min-height: 0;
  max-height: 42%;
  padding: 8px 12px 0;
  overflow-y: auto;

  :deep(.ant-form-item) {
    margin-bottom: 10px;
  }

  :deep(.mono-input) {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 12px;
  }
}

.sim-output {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
  border-top: 1px solid @ops-border;
  background: @ops-canvas;
  overflow: hidden;
}

.output-head {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  font-size: 13px;
  font-weight: 500;
  color: @ops-ink;
}

.output-meta {
  font-weight: 400;
  font-size: 12px;

  &.ok {
    color: @ops-success;
  }

  &.err {
    color: @ops-danger;
  }
}

.output-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 16px;
  text-align: center;
  font-size: 13px;
  color: @ops-subtle;
  line-height: 1.6;

  p {
    margin: 0;
  }
}

.output-empty-icon {
  color: #d9d9d9;
}

.output-switch {
  flex-shrink: 0;
  padding: 0 12px 8px;
}

.output-scroll {
  flex: 1 1 0;
  min-height: 0;
  margin: 0 8px 8px;
  overflow: hidden;
}

.mono-block {
  margin: 0;
  padding: 8px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 12px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-all;
}

@media (max-width: 1100px) {
  .script-body {
    grid-template-columns: 1fr;
    grid-template-rows: minmax(0, 1fr) minmax(0, 1fr);
  }
}
</style>

<template>
  <DeviceCreatePanelLayout result-title="接入参数">
    <template #form>
      <BasicForm @register="registerForm">
        <template #submitBefore>
          <Button type="primary" :loading="regenLoading" class="mr-2" @click="handleRegenerate">
            生成配置
          </Button>
          <Button v-if="content" preIcon="ant-design:copy-outlined" @click="copyContent">复制全部</Button>
        </template>
      </BasicForm>
    </template>
    <template #result>
      <Row v-if="parsedGroups.length > 0" :gutter="[12, 12]">
        <Col v-for="(group, idx) in parsedGroups" :key="idx" :xs="24" :xl="12">
          <Card size="small" :title="group.title || `#${idx + 1}`">
            <Descriptions :column="1" size="small" bordered>
              <Descriptions.Item v-for="(row, rowIdx) in group.rows" :key="rowIdx" :label="row.label">
                <Typography.Text copyable>{{ row.value }}</Typography.Text>
              </Descriptions.Item>
            </Descriptions>
          </Card>
        </Col>
      </Row>
      <Card v-else-if="content" size="small">
        <pre class="access-raw-text">{{ content }}</pre>
      </Card>
      <Empty v-else description="设置组数并点击「生成配置」" />
    </template>
  </DeviceCreatePanelLayout>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';
import { Card, Col, Descriptions, Empty, Row, Typography } from 'ant-design-vue';
import { BasicForm, useForm } from '@/components/Form';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import { generateDeviceAccessInfo } from '@/api/device/gb28181';
import DeviceCreatePanelLayout from '../DeviceCreatePanelLayout.vue';
import { DEVICE_CREATE_FORM_GRID, DEVICE_CREATE_NUMBER_PROPS } from '../deviceCreateForm';

const { createMessage } = useMessage();
const content = ref('');
const regenLoading = ref(false);

const [registerForm, { getFieldsValue }] = useForm({
  ...DEVICE_CREATE_FORM_GRID,
  showActionButtonGroup: true,
  showResetButton: false,
  showSubmitButton: false,
  showAdvancedButton: false,
  actionColOptions: { span: 12, style: { textAlign: 'left' } },
  schemas: [
    {
      field: 'generateCount',
      label: '生成组数',
      component: 'InputNumber',
      defaultValue: 10,
      componentProps: {
        min: 1,
        max: 100,
        precision: 0,
        ...DEVICE_CREATE_NUMBER_PROPS,
      },
    },
  ],
});

interface ConfigRow {
  label: string;
  value: string;
}

interface ParsedGroup {
  title: string;
  rows: ConfigRow[];
}

const groupTitleRe = /^==========\s*(.+?)\s*==========$/;
const keyValueRe = /^([^：:]+)[：:]\s*(.*)$/;
const opensslErrorRe = /openssl:.*error/i;
const backupSipRe = /^---\s*备用SIP服务器地址/;
const completeTitleRe = /^生成完成，共\s*\d+\s*组$/;

function extractAccessInfoText(res: unknown): string {
  if (res == null) return '';
  const body = (res as { data?: unknown })?.data ?? res;
  if (typeof body === 'string') return body;
  if (body && typeof (body as { data?: unknown }).data === 'string') return (body as { data: string }).data;
  if (body && (body as { data?: unknown }).data != null) {
    const d = (body as { data: unknown; msg?: string }).data;
    return typeof d === 'string' ? d : ((body as { msg?: string }).msg ?? '');
  }
  return (body as { msg?: string })?.msg ? String((body as { msg: string }).msg) : '';
}

function normalizeContent(text: string): string {
  if (!text || typeof text !== 'string') return '';
  return text
    .split(/\r?\n/)
    .filter((line) => {
      const t = line.trim();
      if (opensslErrorRe.test(t)) return false;
      if (backupSipRe.test(t)) return false;
      return true;
    })
    .join('\n');
}

function parseContent(text: string): ParsedGroup[] {
  const raw = normalizeContent(text);
  if (!raw) return [];
  const groups: ParsedGroup[] = [];
  const lines = raw.split(/\r?\n/).map((l) => l.trim());
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    const titleMatch = line.match(groupTitleRe);
    if (titleMatch) {
      const title = titleMatch[1].trim();
      if (completeTitleRe.test(title)) {
        i++;
        continue;
      }
      const rows: ConfigRow[] = [];
      i++;
      while (i < lines.length && !lines[i].match(groupTitleRe)) {
        const rowLine = lines[i];
        if (opensslErrorRe.test(rowLine) || backupSipRe.test(rowLine)) {
          i++;
          continue;
        }
        if (rowLine.startsWith('---')) {
          i++;
          continue;
        }
        if (rowLine) {
          const kv = rowLine.match(keyValueRe);
          if (kv) rows.push({ label: kv[1].trim(), value: kv[2].trim() });
        }
        i++;
      }
      groups.push({ title, rows });
      continue;
    }
    i++;
  }

  if (groups.length === 0) {
    const rows: ConfigRow[] = [];
    for (const line of lines) {
      if (opensslErrorRe.test(line) || backupSipRe.test(line) || line.startsWith('---')) continue;
      const kv = line.match(keyValueRe);
      if (kv) rows.push({ label: kv[1].trim(), value: kv[2].trim() });
    }
    if (rows.length > 0) groups.push({ title: '接入参数', rows });
  }

  return groups;
}

const parsedGroups = computed(() => parseContent(content.value));

onMounted(() => {
  handleRegenerate();
});

async function handleRegenerate() {
  regenLoading.value = true;
  try {
    const values = getFieldsValue();
    const count = Math.min(100, Math.max(1, Number(values.generateCount) || 10));
    const res = await generateDeviceAccessInfo(count);
    content.value = extractAccessInfoText(res) || '未获取到内容';
    createMessage.success('已生成');
  } catch (e: unknown) {
    const err = e as { message?: string; msg?: string };
    content.value = '生成失败：' + (err?.message || err?.msg || String(e));
    createMessage.error('生成失败');
  } finally {
    regenLoading.value = false;
  }
}

async function copyContent() {
  if (!content.value) return;
  try {
    const toCopy = normalizeContent(content.value);
    await navigator.clipboard.writeText(toCopy || content.value);
    createMessage.success('已复制');
  } catch {
    createMessage.error('复制失败');
  }
}
</script>

<style lang="less" scoped>
.access-raw-text {
  margin: 0;
  white-space: pre-wrap;
  font-size: 12px;
  line-height: 1.6;
}
</style>

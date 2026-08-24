<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="国标设备接入配置"
    width="800px"
    :footer="null"
    :maskClosable="true"
  >
    <div class="access-info-wrap">
      <div class="access-info-desc">
        <span class="desc-icon">
          <Icon icon="ant-design:info-circle-outlined" />
        </span>
        <span>下方为设备接入平台所需的 SIP 参数，可复制到设备侧或文档中使用。每组包含设备国标 ID、认证密码及服务器信息。</span>
      </div>

      <div class="access-info-toolbar">
        <span class="toolbar-label">生成组数</span>
        <InputNumber
          v-model:value="generateCount"
          :min="1"
          :max="100"
          :precision="0"
          class="toolbar-input-number"
          placeholder="1～100"
        />
        <span class="toolbar-hint">（1～100 组）</span>
      </div>

      <template v-if="parsedGroups.length > 0">
        <div v-if="summaryLine" class="access-info-summary">
          {{ summaryLine }}
        </div>
        <div class="access-info-groups">
          <div
            v-for="(group, idx) in parsedGroups"
            :key="idx"
            class="access-info-card"
          >
            <div class="card-header">
              <Icon icon="ant-design:video-camera-outlined" class="card-header-icon" />
              <span class="card-title">{{ group.title || `设备组 #${idx + 1}` }}</span>
            </div>
            <div class="card-body">
              <div
                v-for="(row, rowIdx) in group.rows"
                :key="rowIdx"
                class="config-row"
              >
                <span class="config-label">{{ row.label }}</span>
                <span class="config-value" :title="row.value">{{ row.value }}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="access-info-actions">
          <Button
            type="primary"
            @click="copyContent"
            preIcon="ant-design:copy-outlined"
            size="middle"
          >
            复制全部配置
          </Button>
          <Button
            @click="handleRegenerate"
            :loading="regenLoading"
            preIcon="ant-design:reload-outlined"
            size="middle"
          >
            重新生成
          </Button>
        </div>
      </template>

      <template v-else-if="content">
        <div class="access-info-raw-box">
          <pre class="access-info-text">{{ content }}</pre>
        </div>
        <div class="access-info-actions">
          <Button
            type="primary"
            @click="copyContent"
            preIcon="ant-design:copy-outlined"
            size="middle"
          >
            复制
          </Button>
          <Button
            @click="handleRegenerate"
            :loading="regenLoading"
            preIcon="ant-design:reload-outlined"
            size="middle"
          >
            重新生成
          </Button>
        </div>
      </template>

      <div v-else class="access-info-empty">
        <Icon icon="ant-design:inbox-outlined" class="empty-icon" />
        <p>未获取到内容</p>
        <p class="empty-hint">请重试「导出接入配置」或检查服务端脚本是否可用。</p>
        <Button
          type="primary"
          @click="handleRegenerate"
          :loading="regenLoading"
          preIcon="ant-design:reload-outlined"
          size="middle"
          class="empty-regen-btn"
        >
          重新生成
        </Button>
      </div>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup name="AccessInfoModal">
import { ref, computed } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import { Icon } from '@/components/Icon';
import { InputNumber } from 'ant-design-vue';
import { generateDeviceAccessInfo } from '@/api/device/gb28181';
import { Button } from '@/components/Button'
defineOptions({ name: 'AccessInfoModal' });

const { createMessage } = useMessage();
const content = ref('');
const regenLoading = ref(false);
const generateCount = ref(10);

function extractAccessInfoText(res: any): string {
  if (res == null) return '';
  const body = res?.data ?? res;
  if (typeof body === 'string') return body;
  if (body && typeof body.data === 'string') return body.data;
  if (body && body.data != null) return typeof body.data === 'string' ? body.data : (body.msg ?? '');
  return (body && body.msg) ? String(body.msg) : '';
}

interface ConfigRow {
  label: string;
  value: string;
}

interface ParsedGroup {
  title: string;
  rows: ConfigRow[];
  extra?: string;
}

const groupTitleRe = /^==========\s*(.+?)\s*==========$/;
const keyValueRe = /^([^：:]+)[：:]\s*(.*)$/;
const opensslErrorRe = /openssl:.*error/i;
const backupSipRe = /^---\s*备用SIP服务器地址/;
const summaryLineRe = /^生成\s*GB28181\s*设备接入信息/;
const completeTitleRe = /^生成完成，共\s*\d+\s*组$/;

/** 规范化后台返回文本：去掉 openssl 报错行、备用SIP说明行，便于解析与展示 */
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

/** 提取首行摘要（如：生成 GB28181 设备接入信息，共 10 组（SIP 服务器: ...）） */
function extractSummaryLine(text: string): string {
  if (!text || typeof text !== 'string') return '';
  const first = text.trim().split(/\r?\n/)[0]?.trim() || '';
  return summaryLineRe.test(first) ? first : '';
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
          if (kv) {
            rows.push({ label: kv[1].trim(), value: kv[2].trim() });
          }
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
    if (rows.length > 0) {
      groups.push({ title: '设备接入参数', rows });
    }
  }

  return groups;
}

const parsedGroups = computed(() => parseContent(content.value));
const summaryLine = computed(() => extractSummaryLine(content.value));

const [register] = useModalInner((data: { content?: string; count?: number } | undefined) => {
  content.value = (data?.content != null && data.content !== '') ? String(data.content) : '';
  if (data?.count != null && data.count >= 1 && data.count <= 100) {
    generateCount.value = data.count;
  }
  // 打开时若尚无内容，则用当前「生成组数」自动请求一次（保证使用弹窗内的组数且每次随机）
  if (!content.value) {
    handleRegenerate();
  }
});

async function handleRegenerate() {
  regenLoading.value = true;
  try {
    const count = Math.min(100, Math.max(1, Number(generateCount.value) || 10));
    const res = await generateDeviceAccessInfo(count);
    const text = extractAccessInfoText(res) || '未获取到内容';
    content.value = text;
    createMessage.success('已重新生成接入配置');
  } catch (e: any) {
    const errMsg = '生成失败：' + (e?.message || e?.msg || String(e));
    content.value = errMsg;
    createMessage.error('重新生成失败');
  } finally {
    regenLoading.value = false;
  }
}

async function copyContent() {
  if (!content.value) return;
  try {
    const toCopy = normalizeContent(content.value);
    await navigator.clipboard.writeText(toCopy || content.value);
    createMessage.success('已复制到剪贴板');
  } catch {
    createMessage.error('复制失败');
  }
}
</script>

<style lang="less" scoped>
.access-info-wrap {
  padding: 4px 0;
  min-height: 120px;
}

.access-info-desc {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 12px 14px;
  margin-bottom: 16px;
  background: linear-gradient(135deg, #f0f7ff 0%, #e8f4fd 100%);
  border: 1px solid #d6e9ff;
  border-radius: 8px;
  font-size: 13px;
  color: #1d4ed8;
  line-height: 1.55;

  .desc-icon {
    flex-shrink: 0;
    font-size: 16px;
    margin-top: 1px;
  }
}

.access-info-toolbar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
  padding: 10px 14px;
  background: #fafafa;
  border: 1px solid #e8e8e8;
  border-radius: 8px;

  .toolbar-label {
    font-size: 13px;
    color: #262626;
    font-weight: 500;
  }

  .toolbar-select,
  .toolbar-input-number {
    width: 88px;
  }

  .toolbar-hint {
    font-size: 12px;
    color: #8c8c8c;
  }
}

.access-info-summary {
  padding: 10px 14px;
  margin-bottom: 12px;
  background: #f6ffed;
  border: 1px solid #b7eb8f;
  border-radius: 8px;
  font-size: 13px;
  color: #389e0d;
  line-height: 1.5;
}

.access-info-groups {
  max-height: 420px;
  overflow-y: auto;
  padding-right: 4px;
  margin-bottom: 16px;

  &::-webkit-scrollbar {
    width: 6px;
  }
  &::-webkit-scrollbar-thumb {
    background: #c5c5c5;
    border-radius: 3px;
  }
  &::-webkit-scrollbar-track {
    background: #f5f5f5;
    border-radius: 3px;
  }
}

.access-info-card {
  background: #fafafa;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  margin-bottom: 12px;
  overflow: hidden;

  &:last-child {
    margin-bottom: 0;
  }
}

.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: #fff;
  border-bottom: 1px solid #e8e8e8;
  font-weight: 600;
  font-size: 13px;
  color: #262626;

  .card-header-icon {
    font-size: 14px;
    color: #1890ff;
  }

  .card-title {
    flex: 1;
  }
}

.card-body {
  padding: 12px 14px;
}

.config-row {
  display: flex;
  align-items: baseline;
  margin-bottom: 8px;
  font-size: 12px;
  line-height: 1.5;

  &:last-of-type {
    margin-bottom: 0;
  }

  .config-label {
    flex: 0 0 140px;
    color: #595959;
    margin-right: 12px;
  }

  .config-value {
    flex: 1;
    min-width: 0;
    color: #262626;
    font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
    font-size: 12px;
    word-break: break-all;
  }
}

.access-info-raw-box {
  max-height: 420px;
  overflow: auto;
  margin-bottom: 16px;
  background: #1e1e1e;
  border-radius: 8px;
  padding: 14px;

  .access-info-text {
    margin: 0;
    padding: 0;
    font-size: 12px;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-all;
    color: #d4d4d4;
    font-family: 'SF Mono', 'Monaco', 'Consolas', monospace;
  }
}

.access-info-actions {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
  padding-top: 8px;
}

.access-info-empty {
  text-align: center;
  padding: 40px 24px;
  color: #8c8c8c;

  .empty-icon {
    font-size: 48px;
    color: #d9d9d9;
    margin-bottom: 12px;
  }

  p {
    margin: 0 0 8px 0;
    font-size: 14px;
  }

  .empty-hint {
    font-size: 12px;
    color: #bfbfbf;
    margin-bottom: 16px;
  }

  .empty-regen-btn {
    margin-top: 8px;
  }
}
</style>

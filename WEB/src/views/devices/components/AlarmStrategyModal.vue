<template>
  <Drawer
    v-model:open="visible"
    placement="right"
    :width="1400"
    :destroy-on-close="true"
    :mask-closable="!saving"
    root-class-name="alarm-strategy-drawer"
    @close="close"
  >
    <template #title>
      <div class="drawer-title">
        <div class="drawer-title-icon">
          <Icon icon="ant-design:alert-outlined" :size="22" />
        </div>
        <div>
          <div class="drawer-title-main">设备告警策略</div>
          <div class="drawer-title-sub">选择通知渠道并绑定消息模板，阈值越限后自动推送</div>
        </div>
      </div>
    </template>

    <Spin :spinning="loading">
      <div class="drawer-body">
        <section class="hero">
          <div class="hero-main">
            <div class="hero-label">适用设备</div>
            <div class="hero-device" :title="deviceIdentification">
              {{ deviceIdentification || '--' }}
            </div>
          </div>
          <div class="hero-side">
            <div class="hero-meta">
              <span>静默 {{ silenceLabel }}</span>
              <span class="sep">·</span>
              <span>已选 {{ selectedChannels.length }} 个渠道</span>
            </div>
            <div class="hero-switch">
              <span>{{ enabled ? '策略已启用' : '策略已停用' }}</span>
              <Switch
                v-model:checked="enabled"
                checked-children="启用"
                un-checked-children="停用"
              />
            </div>
          </div>
        </section>

        <section class="section">
          <div class="section-head">
            <h3>基础设置</h3>
            <p>策略名称与通知抑制间隔</p>
          </div>
          <div class="form-grid">
            <div class="field">
              <label>策略名称</label>
              <Input
                v-model:value="form.strategyName"
                placeholder="例如：产线关键告警策略"
                maxlength="64"
                allow-clear
              />
            </div>
            <div class="field">
              <label>通知间隔</label>
              <div class="silence-row">
                <Select
                  v-model:value="silencePreset"
                  :options="silenceOptions"
                  style="width: 140px"
                  @change="onSilencePresetChange"
                />
                <InputNumber
                  v-model:value="form.silenceSeconds"
                  :min="0"
                  :max="86400"
                  style="flex: 1"
                  addon-after="秒"
                  @change="silencePreset = 'custom'"
                />
              </div>
            </div>
          </div>
        </section>

        <section class="section">
          <div class="section-head">
            <h3>通知渠道与模板</h3>
            <p>点击选择渠道，并为每个渠道绑定消息中心模板</p>
          </div>

          <div class="channel-grid">
            <button
              v-for="item in methodOptions"
              :key="item.value"
              type="button"
              class="channel-card"
              :class="{ active: selectedChannels.includes(item.value) }"
              @click="toggleChannel(item.value)"
            >
              <span class="channel-icon">
                <Icon :icon="item.icon" />
              </span>
              <span class="channel-text">
                <strong>{{ item.label }}</strong>
                <small>{{ item.desc }}</small>
              </span>
              <Icon
                class="channel-check"
                :icon="
                  selectedChannels.includes(item.value)
                    ? 'ant-design:check-circle-filled'
                    : 'ant-design:border-outlined'
                "
              />
            </button>
          </div>

          <div v-if="selectedChannels.length" class="template-block">
            <div class="template-grid">
              <div v-for="channel in selectedChannels" :key="channel" class="template-card">
                <div class="template-head">
                  <span>
                    <Icon :icon="channelIcon(channel)" />
                    {{ getChannelLabel(channel) }}模板
                  </span>
                  <em>必选</em>
                </div>
                <Select
                  v-model:value="channelTemplates[channel]"
                  show-search
                  allow-clear
                  :placeholder="`选择${getChannelLabel(channel)}模板`"
                  :loading="templateLoading[channel]"
                  :options="templateOptions(channel)"
                  :filter-option="filterOption"
                  style="width: 100%"
                  @focus="loadTemplates(channel)"
                />
              </div>
            </div>
          </div>
          <div v-else class="empty">
            <Icon icon="ant-design:notification-outlined" />
            <p>请选择至少一个通知渠道</p>
          </div>
        </section>

        <section class="section">
          <div class="section-head">
            <h3>健康评估与备注</h3>
            <p>可选配置，不影响通知发送</p>
          </div>
          <div class="toggle">
            <div>
              <strong>离线纳入健康评估</strong>
              <span>开启后，设备离线将降低健康评分</span>
            </div>
            <Switch v-model:checked="includeOffline" />
          </div>
          <div class="field remark">
            <label>备注</label>
            <Input.TextArea
              v-model:value="form.remark"
              :rows="3"
              placeholder="可选：值班说明、通知对象等"
              maxlength="200"
              show-count
            />
          </div>
        </section>
      </div>
    </Spin>

    <template #footer>
      <div class="drawer-footer">
        <Button @click="close">取消</Button>
        <Button type="primary" :loading="saving" @click="handleOk">保存策略</Button>
      </div>
    </template>
  </Drawer>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { Drawer, Input, InputNumber, Select, Spin, Switch } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { getDeviceAlarmStrategy, saveDeviceAlarmStrategy } from '@/api/device/devices';
import { notifyTemplateQueryByType } from '@/api/device/notice';

const { createMessage } = useMessage();

const visible = ref(false);
const loading = ref(false);
const saving = ref(false);
const enabled = ref(false);
const includeOffline = ref(true);
const deviceIdentification = ref('');
const selectedChannels = ref<string[]>([]);
const channelTemplates = ref<Record<string, string | number>>({});
const templates = ref<Record<string, any[]>>({});
const templateLoading = ref<Record<string, boolean>>({});
const silencePreset = ref<string>('300');

const form = reactive({
  strategyName: '默认告警策略',
  silenceSeconds: 300,
  remark: '',
});

const methodOptions = [
  { label: '短信', value: 'sms', icon: 'ant-design:message-outlined', desc: '短信网关通知' },
  { label: '邮件', value: 'email', icon: 'ant-design:mail-outlined', desc: '发送至邮箱' },
  { label: '企业微信', value: 'wxcp', icon: 'ant-design:comment-outlined', desc: '应用 / 群机器人' },
  { label: 'HTTP', value: 'http', icon: 'ant-design:api-outlined', desc: 'Webhook 回调' },
  { label: '钉钉', value: 'ding', icon: 'ant-design:bell-outlined', desc: '工作通知 / 群机器人' },
  { label: '飞书', value: 'feishu', icon: 'ant-design:cloud-outlined', desc: '应用 / 群机器人' },
];

const channelToMsgType: Record<string, number> = {
  sms: 1,
  email: 3,
  wxcp: 4,
  http: 5,
  ding: 6,
  feishu: 7,
};

const silenceOptions = [
  { label: '不静默', value: '0' },
  { label: '1 分钟', value: '60' },
  { label: '5 分钟', value: '300' },
  { label: '15 分钟', value: '900' },
  { label: '1 小时', value: '3600' },
  { label: '自定义', value: 'custom' },
];

const silenceLabel = computed(() =>
  form.silenceSeconds > 0 ? formatSilence(form.silenceSeconds) : '不静默',
);

function formatSilence(seconds: number) {
  if (seconds >= 3600 && seconds % 3600 === 0) return `${seconds / 3600} 小时`;
  if (seconds >= 60 && seconds % 60 === 0) return `${seconds / 60} 分钟`;
  return `${seconds} 秒`;
}

function getChannelLabel(channel: string) {
  return methodOptions.find((m) => m.value === channel)?.label || channel;
}

function channelIcon(channel: string) {
  return methodOptions.find((m) => m.value === channel)?.icon || 'ant-design:bell-outlined';
}

function templateOptions(channel: string) {
  return (templates.value[channel] || []).map((t) => ({ label: t.name, value: t.id }));
}

function filterOption(input: string, option: any) {
  const label = option?.label || option?.children || '';
  return String(label).toLowerCase().includes(String(input || '').toLowerCase());
}

function onSilencePresetChange(val: string) {
  if (val === 'custom') return;
  form.silenceSeconds = Number(val) || 0;
}

function syncSilencePreset() {
  const match = silenceOptions.find(
    (item) => item.value !== 'custom' && Number(item.value) === form.silenceSeconds,
  );
  silencePreset.value = match ? match.value : 'custom';
}

async function loadTemplates(channel: string) {
  if (templates.value[channel]?.length) return;
  templateLoading.value[channel] = true;
  try {
    const msgType = channelToMsgType[channel];
    if (!msgType) return;
    const response = await notifyTemplateQueryByType({ msgType });
    if (response?.code === 0 && response.data) {
      templates.value[channel] = Array.isArray(response.data) ? response.data : [];
    } else if (Array.isArray(response)) {
      templates.value[channel] = response;
    } else if (Array.isArray(response?.data)) {
      templates.value[channel] = response.data;
    } else {
      templates.value[channel] = [];
    }
  } catch (e) {
    console.error(e);
    templates.value[channel] = [];
  } finally {
    templateLoading.value[channel] = false;
  }
}

function toggleChannel(channel: string) {
  const set = new Set(selectedChannels.value);
  if (set.has(channel)) {
    set.delete(channel);
    delete channelTemplates.value[channel];
  } else {
    set.add(channel);
    loadTemplates(channel);
  }
  selectedChannels.value = Array.from(set);
}

function buildChannelsPayload() {
  return selectedChannels.value.map((method) => {
    const templateId = channelTemplates.value[method];
    const template = templates.value[method]?.find((t) => t.id === templateId);
    return {
      method,
      template_id: templateId,
      template_name: template?.name || '',
    };
  });
}

function resetForm() {
  form.strategyName = '默认告警策略';
  form.silenceSeconds = 300;
  form.remark = '';
  enabled.value = false;
  includeOffline.value = true;
  selectedChannels.value = [];
  channelTemplates.value = {};
  templates.value = {};
  syncSilencePreset();
}

async function open(id: string) {
  deviceIdentification.value = id;
  visible.value = true;
  resetForm();
  loading.value = true;
  try {
    const res = await getDeviceAlarmStrategy(id);
    const data = res?.data || res;
    if (data) {
      form.strategyName = data.strategyName || '默认告警策略';
      form.silenceSeconds = data.silenceSeconds ?? 300;
      form.remark = data.remark || '';
      enabled.value = data.enabled === 1;
      includeOffline.value = data.includeOffline !== 0;
      syncSilencePreset();

      let channels: Array<{ method: string; template_id?: string | number; template_name?: string }> =
        [];
      try {
        channels = data.channels ? JSON.parse(data.channels) : [];
      } catch {
        channels = [];
      }
      if (!Array.isArray(channels) || !channels.length) {
        try {
          const methods = data.notifyMethods ? JSON.parse(data.notifyMethods) : [];
          if (Array.isArray(methods) && methods.length) {
            channels = methods.map((method: string) => ({ method }));
          }
        } catch {
          channels = [];
        }
      }

      selectedChannels.value = channels.map((c) => c.method).filter(Boolean);
      const nextTemplates: Record<string, string | number> = {};
      channels.forEach((c) => {
        if (c.method && c.template_id != null && c.template_id !== '') {
          nextTemplates[c.method] = c.template_id;
        }
      });
      channelTemplates.value = nextTemplates;
      await Promise.all(selectedChannels.value.map((channel) => loadTemplates(channel)));
    }
  } catch (e) {
    console.error(e);
  } finally {
    loading.value = false;
  }
}

function close() {
  visible.value = false;
}

async function handleOk() {
  if (!form.strategyName?.trim()) {
    createMessage.warning('请填写策略名称');
    return;
  }
  if (enabled.value) {
    if (!selectedChannels.value.length) {
      createMessage.warning('启用策略时请至少选择一种通知渠道');
      return;
    }
    const missing = selectedChannels.value.filter(
      (c) => channelTemplates.value[c] == null || channelTemplates.value[c] === '',
    );
    if (missing.length) {
      createMessage.warning(`请为以下渠道选择模板：${missing.map(getChannelLabel).join('、')}`);
      return;
    }
  }

  const channels = buildChannelsPayload();
  saving.value = true;
  try {
    await saveDeviceAlarmStrategy({
      deviceIdentification: deviceIdentification.value,
      strategyName: form.strategyName.trim(),
      enabled: enabled.value ? 1 : 0,
      notifyMethods: JSON.stringify(selectedChannels.value || []),
      channels: JSON.stringify(channels),
      silenceSeconds: form.silenceSeconds ?? 0,
      includeOffline: includeOffline.value ? 1 : 0,
      remark: form.remark,
    });
    createMessage.success('告警策略已保存');
    close();
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
  } finally {
    saving.value = false;
  }
}

defineExpose({ open });
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

.hero-label {
  font-size: 12px;
  color: #8c8c8c;
}

.hero-device {
  margin-top: 8px;
  font-size: 22px;
  font-weight: 650;
  color: #111827;
  max-width: 720px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hero-side {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 12px;
}

.hero-meta {
  font-size: 13px;
  color: #64748b;

  .sep {
    margin: 0 8px;
    color: #cbd5e1;
  }
}

.hero-switch {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 13px;
  color: #595959;
}

.section {
  padding: 28px 32px;
  border-radius: 16px;
  background: #fff;
  border: 1px solid #e8ecf2;
}

.section-head {
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

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px 28px;
}

.field {
  label {
    display: block;
    margin-bottom: 8px;
    font-size: 13px;
    color: #595959;
  }
}

.silence-row {
  display: flex;
  gap: 10px;
}

.channel-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.channel-card {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
  padding: 18px 20px;
  border: 1px solid #e8ecf2;
  border-radius: 14px;
  background: #fff;
  text-align: left;
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    border-color: #91caff;
  }

  &.active {
    border-color: #1677ff;
    background: #f0f7ff;
    box-shadow: 0 0 0 1px rgba(22, 119, 255, 0.08);
  }
}

.channel-icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: #f0f5ff;
  color: #1677ff;
  flex-shrink: 0;
}

.channel-text {
  flex: 1;
  min-width: 0;

  strong {
    display: block;
    font-size: 14px;
    color: #111827;
  }

  small {
    display: block;
    margin-top: 2px;
    font-size: 12px;
    color: #8c8c8c;
  }
}

.channel-check {
  color: #d9d9d9;
  font-size: 16px;

  .active & {
    color: #1677ff;
  }
}

.template-block {
  margin-top: 16px;
}

.template-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.template-card {
  padding: 18px 20px;
  border-radius: 14px;
  background: #f8fafc;
  border: 1px solid #eef2f7;
}

.template-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  font-size: 13px;
  font-weight: 600;
  color: #111827;

  span {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  em {
    font-style: normal;
    font-weight: 400;
    font-size: 12px;
    color: #fa8c16;
  }
}

.empty {
  margin-top: 16px;
  padding: 36px 16px;
  text-align: center;
  border: 1px dashed #d9d9d9;
  border-radius: 12px;
  color: #8c8c8c;
  background: #fafafa;

  p {
    margin: 8px 0 0;
    font-size: 13px;
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

.remark {
  margin-top: 16px;
}

.drawer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

@media (max-width: 1200px) {
  .channel-grid,
  .template-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .channel-grid,
  .template-grid,
  .form-grid {
    grid-template-columns: 1fr;
  }

  .hero {
    flex-direction: column;
    align-items: stretch;
  }

  .hero-side {
    align-items: flex-start;
  }
}
</style>

<style lang="less">
.alarm-strategy-drawer {
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

<template>
  <div class="nvr-device-detail">
    <PageHeader
      class="nvr-detail-header"
      :title="title || `NVR ${nvrId}`"
      sub-title="点击下方摄像头卡片进行管理或播放"
      @back="emit('back')"
    />
    <Spin :spinning="loading">
      <div class="channel-section">
        <div class="section-header">
          <span class="section-title">挂载摄像头（{{ cameras.length }}）</span>
          <div class="section-actions">
            <Checkbox v-model:checked="enableAiModel">启用 AI</Checkbox>
            <Button
            type="primary"
            size="small"
            :loading="syncing"
            :disabled="!nvrInfo"
            @click="handleSyncChannels"
          >
            同步通道
          </Button>
          </div>
        </div>
        <Empty v-if="!cameras.length" description="暂无挂载摄像头，可通过网段扫描 NVR 登记并同步通道" />
        <List
          v-else
          :grid="{ gutter: 12, xs: 1, sm: 2, md: 3, lg: 5, xl: 5, xxl: 5 }"
          :data-source="cameras"
          :pagination="paginationProp"
        >
          <template #renderItem="{ item }">
            <ListItem class="nvr-channel-list-item">
              <NvrChannelCard
                :item="item"
                :play-button-title="playButtonTitle"
                @view="emit('view', $event)"
                @edit="emit('edit', $event)"
                @set-location="emit('setLocation', $event)"
                @play="emit('play', $event)"
                @delete="emit('delete', $event)"
              />
            </ListItem>
          </template>
        </List>
      </div>
    </Spin>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref, watch } from 'vue';
import { Empty, List, PageHeader, Spin, Checkbox } from 'ant-design-vue';
import { getNvrDetail, registerNvrWithChannels, type DeviceInfo, type NvrInfo } from '@/api/device/camera';
import { nvrRegisterRegisteredCount } from '@/views/camera/utils/nvrRegisterMessage';
import NvrChannelCard from '@/views/camera/components/NvrChannelCard/index.vue';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button'
const ListItem = List.Item;

const props = defineProps<{
  nvrId: number;
  title?: string;
  playButtonTitle?: string;
  enableAi?: boolean;
}>();

const enableAiModel = computed({
  get: () => props.enableAi ?? true,
  set: (value: boolean) => emit('update:enableAi', value),
});

const emit = defineEmits<{
  back: [];
  view: [device: DeviceInfo];
  edit: [device: DeviceInfo];
  setLocation: [device: DeviceInfo];
  play: [device: DeviceInfo];
  delete: [device: DeviceInfo];
  'update:enableAi': [value: boolean];
}>();

const { createMessage } = useMessage();
const loading = ref(false);
const syncing = ref(false);
const nvrInfo = ref<NvrInfo | null>(null);
const cameras = ref<Array<DeviceInfo & { online_text?: string; rtsp_url?: string }>>([]);

const page = ref(1);
const pageSize = ref(10);

const paginationProp = computed(() => ({
  showSizeChanger: true,
  showQuickJumper: true,
  pageSize: pageSize.value,
  current: page.value,
  total: cameras.value.length,
  showTotal: (total: number) => `共 ${total} 路`,
  onChange: (p: number, pz: number) => {
    page.value = p;
    pageSize.value = pz;
  },
}));

function mapCameras(data: NvrInfo | null) {
  return (data?.cameras || []).map((c) => ({
    ...c,
    id: c.id,
    name: c.name || '',
    source: c.source || c.rtsp_url || '',
    rtmp_stream: c.rtmp_stream,
    http_stream: c.http_stream,
    ai_rtmp_stream: c.ai_rtmp_stream,
    ai_http_stream: c.ai_http_stream,
    device_kind: 'nvr_channel',
    nvr_id: props.nvrId,
    nvr_channel: c.nvr_channel,
    channel_online: c.online,
  })) as DeviceInfo[];
}

async function load() {
  loading.value = true;
  try {
    const res = await getNvrDetail(props.nvrId, true);
    const data = (res as NvrInfo) || (res as { data?: NvrInfo })?.data;
    nvrInfo.value = data || null;
    cameras.value = mapCameras(data || null);
  } catch (e) {
    console.error(e);
    createMessage.error('加载 NVR 详情失败');
  } finally {
    loading.value = false;
  }
}

async function handleSyncChannels() {
  const nvr = nvrInfo.value;
  if (!nvr?.ip) {
    createMessage.warning('NVR 信息不完整');
    return;
  }
  if (!nvr.username) {
    createMessage.warning('请先在 NVR 编辑中填写 Web 登录用户名');
    return;
  }
  if (!nvr.has_password && !nvr.password) {
    createMessage.warning('请先在 NVR 编辑中填写 Web 登录密码后再同步通道');
    return;
  }
  syncing.value = true;
  try {
    const res = await registerNvrWithChannels({
      ip: nvr.ip,
      port: nvr.port ?? 80,
      username: nvr.username,
      ...(nvr.password ? { password: nvr.password } : {}),
      vendor: nvr.vendor,
      name: nvr.name,
      model: nvr.model,
      serial_number: nvr.serial_number,
      scheme: nvr.scheme,
      ...(nvr.rtsp_template ? { rtsp_template: nvr.rtsp_template } : {}),
      ...(nvr.rtsp_port ? { rtsp_port: nvr.rtsp_port } : {}),
    });
    nvrInfo.value = { ...(res || nvr), has_password: true };
    cameras.value = mapCameras(res || null);
    const n = nvrRegisterRegisteredCount(res);
    createMessage.success(`已同步 ${n} 路通道`);
  } catch (e: unknown) {
    const err = e as { msg?: string; message?: string };
    createMessage.error(err?.msg || err?.message || '同步通道失败');
  } finally {
    syncing.value = false;
  }
}

onMounted(load);
watch(() => props.nvrId, load);

defineExpose({ load });
</script>

<style lang="less" scoped>
.nvr-device-detail {
  display: flex;
  flex-direction: column;
  min-height: 520px;
  background: #f5f5f5;

  .nvr-detail-header {
    background: #fff;
    margin-bottom: 12px;
    padding: 8px 16px;
  }

  .channel-section {
    background: #fff;
    padding: 16px;
    border-radius: 8px;
    flex: 1;

    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 12px;
    }

    .section-actions {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .section-title {
      font-weight: 600;
      font-size: 16px;
    }
  }

  :deep(.ant-list) {
    padding: 6px;
  }

  :deep(.ant-list-item) {
    margin: 6px;
    padding: 0;
  }

}
</style>

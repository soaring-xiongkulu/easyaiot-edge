<template>
  <div ref="assocPageRef" class="assoc-page" :class="{ 'is-fullscreen': isFullscreen }">
    <div class="assoc-layout">
      <aside class="device-rail">
        <div class="rail-head">
          <div class="rail-title">
            <Icon icon="ant-design:apartment-outlined" />
            <span>设备总览</span>
          </div>
          <Button size="small" type="link" @click="openBindModal">添加</Button>
        </div>

        <div class="rail-scroll">
          <button
            type="button"
            class="rail-item all-item"
            :class="{ active: selectedKey === 'ALL' }"
            @click="selectedKey = 'ALL'"
          >
            <span class="all-icon">
              <Icon icon="ant-design:appstore-outlined" :size="15" />
            </span>
            <span class="rail-copy">
              <strong>全部设备</strong>
              <small>共 {{ deviceList.length }} 台</small>
            </span>
          </button>

          <button
            v-for="item in deviceList"
            :key="item.deviceIdentification"
            type="button"
            class="rail-item"
            :class="{ active: selectedKey === item.deviceIdentification }"
            @click="selectedKey = item.deviceIdentification"
          >
            <span
              class="status-dot"
              :class="item.connectStatus === 'ONLINE' ? 'online' : 'offline'"
            ></span>
            <span class="rail-copy">
              <strong :title="item.deviceName">
                {{ item.deviceName }}
                <em v-if="item._isCenter">中心</em>
              </strong>
              <small :title="item.deviceIdentification">{{ item.deviceIdentification }}</small>
            </span>
            <Tag :color="item.connectStatus === 'ONLINE' ? 'success' : 'error'" class="status-tag">
              {{ item.connectStatus === 'ONLINE' ? '在线' : '离线' }}
            </Tag>
          </button>
        </div>
      </aside>

      <section class="status-panel">
        <div class="panel-toolbar">
          <div class="panel-heading">
            <h3>设备状态</h3>
            <p>{{ selectedLabel }}</p>
          </div>
          <div class="panel-actions">
            <label class="threshold-filter">
              <Checkbox v-model:checked="onlyThreshold">仅显示配置阈值的属性</Checkbox>
            </label>
            <Button @click="openAlarmStrategy" preIcon="ant-design:alert-outlined">告警策略</Button>
            <Button @click="reloadAll" :loading="loading" preIcon="ant-design:reload-outlined">刷新</Button>
            <Button
              @click="toggleFullscreen"
              :preIcon="isFullscreen ? 'ant-design:fullscreen-exit-outlined' : 'ant-design:fullscreen-outlined'"
            >
              {{ isFullscreen ? '退出全屏' : '全屏' }}
            </Button>
            <Button type="primary" @click="openBindModal" preIcon="ant-design:link-outlined">关联设备</Button>
          </div>
        </div>

        <div class="panel-scroll">
          <Spin :spinning="loading">
            <div v-if="displayDevices.length === 0" class="empty-wrap">
              <Icon icon="ant-design:cluster-outlined" class="empty-icon" />
              <p>暂无设备</p>
              <p class="hint">可添加任意已存在设备；网关拓扑子设备会自动合并显示</p>
            </div>

            <div class="device-sections">
              <article
                v-for="dev in displayDevices"
                :key="dev.deviceIdentification"
                class="device-section"
              >
                <header class="section-head">
                  <div class="section-title">
                    <span
                      class="status-dot"
                      :class="dev.connectStatus === 'ONLINE' ? 'online' : 'offline'"
                    ></span>
                    <strong>{{ dev.deviceName }}</strong>
                    <Tag v-if="dev._isCenter" color="blue">中心设备</Tag>
                    <Tag :color="dev.connectStatus === 'ONLINE' ? 'success' : 'error'">
                      {{ dev.connectStatus === 'ONLINE' ? '在线' : '离线' }}
                    </Tag>
                    <span class="device-id">{{ dev.deviceIdentification }}</span>
                  </div>
                  <div class="section-actions">
                    <a @click="openDeviceThresholdStrategy(dev)">告警策略</a>
                    <a @click="jumpDevice(dev)">完整详情</a>
                    <a v-if="!dev._isCenter" class="danger" @click="unbindOne(dev)">解除关联</a>
                  </div>
                </header>

                <div class="prop-panel">
                  <TingModelCardList
                    v-if="dev.id"
                    :key="dev.deviceIdentification"
                    :params="{ id: dev.id }"
                    :api="fetchThingModels"
                    :threshold-map="thresholdMaps[dev.deviceIdentification] || {}"
                    :only-threshold="onlyThreshold"
                    @getMethod="(reload) => onCardMethod(dev.deviceIdentification, reload)"
                    @view="(item) => openHistory(dev, item)"
                    @threshold="(item) => openThreshold(dev, item)"
                    @refresh="() => loadThresholds(dev)"
                  />
                  <div v-else class="prop-empty">设备主键缺失，无法加载运行状态</div>
                </div>
              </article>
            </div>
          </Spin>
        </div>
      </section>
    </div>

    <Modal
      v-model:visible="bindVisible"
      title="关联设备"
      :width="'90vw'"
      :style="{ maxWidth: '1200px' }"
      :confirmLoading="binding"
      destroy-on-close
      @ok="handleBind"
      @cancel="bindVisible = false"
    >
      <div class="bind-toolbar">
        <Input
          v-model:value="bindKeyword"
          allow-clear
          placeholder="搜索设备名称，回车查询"
          style="max-width: 320px"
          @pressEnter="loadCandidates"
        />
        <Button type="primary" :loading="bindLoading" @click="loadCandidates">查询</Button>
      </div>
      <Table
        rowKey="id"
        size="middle"
        :loading="bindLoading"
        :columns="bindColumns"
        :dataSource="candidateList"
        :rowSelection="{ selectedRowKeys: bindSelectedKeys, onChange: onBindSelect }"
        :pagination="{
          current: bindPagination.current,
          pageSize: bindPagination.pageSize,
          total: bindPagination.total,
          showSizeChanger: true,
          onChange: onBindPage,
        }"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'connectStatus'">
            <Tag :color="record.connectStatus === 'ONLINE' ? 'green' : 'red'">
              {{ record.connectStatus === 'ONLINE' ? '在线' : '离线' }}
            </Tag>
          </template>
          <template v-else-if="column.key === 'deviceType'">
            {{ deviceTypeLabel(record.deviceType) }}
          </template>
        </template>
      </Table>
    </Modal>

    <ThresholdModal ref="thresholdModalRef" @saved="reloadAll" />
    <AlarmStrategyModal ref="alarmStrategyRef" />
    <Detail @register="registerHistoryModal" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { Checkbox, Input, Modal, Spin, Table, Tag } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { useModal } from '@/components/Modal';
import {
  associateDevices,
  disassociateDevices,
  getAssociatedCandidates,
  getAssociatedDevices,
  getDeviceThresholds,
  getDevicethingModels,
} from '@/api/device/devices';
import ThresholdModal from '../Model/components/ThresholdModal.vue';
import AlarmStrategyModal from '../AlarmStrategyModal.vue';
import Detail from '../Model/components/Detail.vue';
import TingModelCardList from '../Model/components/CardList/TingModelCardList.vue';

defineOptions({ name: 'DeviceAssociatedSubDevice' });

const props = defineProps<{
  centerDeviceIdentification: string;
  centerDeviceId?: string | number;
  centerDeviceName?: string;
  centerConnectStatus?: string;
}>();

const { createMessage } = useMessage();
const router = useRouter();
const [registerHistoryModal, { openModal: openHistoryModal }] = useModal();

const loading = ref(false);
const binding = ref(false);
const bindLoading = ref(false);
const bindVisible = ref(false);
const bindKeyword = ref('');
const onlyThreshold = ref(false);
const selectedKey = ref('ALL');
const isFullscreen = ref(false);
const assocPageRef = ref<HTMLElement | null>(null);
const associatedList = ref<any[]>([]);
const candidateList = ref<any[]>([]);
const bindSelectedKeys = ref<Array<string | number>>([]);
const thresholdMaps = reactive<Record<string, Record<string, any>>>({});
const cardReloadMap = reactive<Record<string, Function>>({});
const thresholdModalRef = ref<any>(null);
const alarmStrategyRef = ref<any>(null);
let refreshTimer: any = null;

const bindPagination = reactive({ current: 1, pageSize: 10, total: 0 });

const bindColumns = [
  { title: '设备名称', dataIndex: 'deviceName', key: 'deviceName', ellipsis: true },
  { title: '设备标识', dataIndex: 'deviceIdentification', key: 'deviceIdentification', ellipsis: true },
  { title: '设备类型', dataIndex: 'deviceType', key: 'deviceType', width: 110 },
  { title: '连接状态', dataIndex: 'connectStatus', key: 'connectStatus', width: 90 },
];

const centerDevice = computed(() => ({
  id: props.centerDeviceId,
  deviceIdentification: props.centerDeviceIdentification,
  deviceName: props.centerDeviceName || '中心设备',
  connectStatus: props.centerConnectStatus || 'OFFLINE',
  _isCenter: true,
}));

const deviceList = computed(() => {
  const list = [centerDevice.value, ...associatedList.value.map((d) => ({ ...d, _isCenter: false }))];
  return list.filter((d) => d.deviceIdentification);
});

const displayDevices = computed(() => {
  if (selectedKey.value === 'ALL') return deviceList.value;
  return deviceList.value.filter((d) => d.deviceIdentification === selectedKey.value);
});

const selectedLabel = computed(() => {
  if (selectedKey.value === 'ALL') return `全部设备 · 共 ${deviceList.value.length} 台`;
  const hit = deviceList.value.find((d) => d.deviceIdentification === selectedKey.value);
  return hit ? `${hit.deviceName} · ${hit.deviceIdentification}` : selectedKey.value;
});

function deviceTypeLabel(t: string) {
  return ({ GATEWAY: '网关', COMMON: '普通设备', SUBSET: '子设备', VIDEO_COMMON: '视频设备' } as any)[t] || t || '--';
}

async function fetchThingModels(params: Record<string, any>) {
  return getDevicethingModels(params);
}

function onCardMethod(deviceIdentification: string, reload: Function) {
  cardReloadMap[deviceIdentification] = reload;
}

function handleFullscreenChange() {
  isFullscreen.value = !!document.fullscreenElement;
}

async function toggleFullscreen() {
  try {
    if (!document.fullscreenElement) {
      const el = assocPageRef.value;
      if (el?.requestFullscreen) {
        await el.requestFullscreen();
      } else {
        isFullscreen.value = true;
      }
    } else {
      await document.exitFullscreen?.();
      isFullscreen.value = false;
    }
  } catch (e) {
    // 浏览器不支持 Fullscreen API 时，退化为 CSS 全屏
    isFullscreen.value = !isFullscreen.value;
  }
}

async function loadAssociated() {
  if (!props.centerDeviceIdentification || props.centerDeviceIdentification === '--') return;
  loading.value = true;
  try {
    const res = await getAssociatedDevices({
      centerDeviceIdentification: props.centerDeviceIdentification,
    });
    associatedList.value = res?.data || res?.rows || [];
  } catch (e) {
    console.error(e);
    createMessage.error('加载设备总览失败');
  } finally {
    loading.value = false;
  }
}

async function loadThresholds(dev: any) {
  if (!dev?.deviceIdentification) return;
  try {
    const thRes = await getDeviceThresholds(dev.deviceIdentification);
    const thList = thRes?.data || thRes || [];
    const map: Record<string, any> = {};
    (Array.isArray(thList) ? thList : []).forEach((t: any) => {
      if (t?.propertyCode) map[t.propertyCode] = t;
    });
    thresholdMaps[dev.deviceIdentification] = map;
  } catch (e) {
    console.error(e);
    thresholdMaps[dev.deviceIdentification] = {};
  }
}

async function reloadAll() {
  await loadAssociated();
  await Promise.all(deviceList.value.map((d) => loadThresholds(d)));
  // 属性卡自行拉取；关联列表变化后强制刷新已挂载卡片
  deviceList.value.forEach((d) => {
    cardReloadMap[d.deviceIdentification]?.({}, { silent: true });
  });
}

function jumpDevice(dev: any) {
  if (!dev?.id) {
    createMessage.warning('设备主键缺失，无法跳转');
    return;
  }
  router.push({ name: 'DeviceDetail', params: { id: String(dev.id) } });
}

function openThreshold(dev: any, prop: any) {
  thresholdModalRef.value?.open({
    deviceIdentification: dev.deviceIdentification,
    propertyCode: prop.propertyCode,
    propertyName: prop.propertyName,
    currentValue: prop.dataValue,
  });
}

function openHistory(dev: any, prop: any) {
  openHistoryModal(true, {
    data: {
      ...prop,
      deviceIdentification: dev.deviceIdentification,
    },
  });
}

function openAlarmStrategy() {
  alarmStrategyRef.value?.open(props.centerDeviceIdentification);
}

function openDeviceThresholdStrategy(dev: any) {
  alarmStrategyRef.value?.open(dev.deviceIdentification);
}

async function unbindOne(dev: any) {
  if (!dev?.id) return;
  try {
    await disassociateDevices([dev.id], props.centerDeviceIdentification);
    createMessage.success('已解除关联');
    if (selectedKey.value === dev.deviceIdentification) selectedKey.value = 'ALL';
    await reloadAll();
  } catch (e: any) {
    createMessage.error(e?.message || '解绑失败');
  }
}

function openBindModal() {
  bindVisible.value = true;
  bindSelectedKeys.value = [];
  bindKeyword.value = '';
  bindPagination.current = 1;
  loadCandidates();
}

function onBindSelect(keys: Array<string | number>) {
  bindSelectedKeys.value = keys;
}

function onBindPage(page: number, pageSize: number) {
  bindPagination.current = page;
  bindPagination.pageSize = pageSize;
  loadCandidates();
}

async function loadCandidates() {
  bindLoading.value = true;
  try {
    const res = await getAssociatedCandidates({
      centerDeviceIdentification: props.centerDeviceIdentification,
      deviceName: bindKeyword.value || undefined,
      pageNum: bindPagination.current,
      pageSize: bindPagination.pageSize,
    });
    candidateList.value = res?.data || res?.rows || [];
    bindPagination.total = res?.total || 0;
  } catch (e) {
    console.error(e);
    createMessage.error('加载候选设备失败');
  } finally {
    bindLoading.value = false;
  }
}

async function handleBind() {
  if (!bindSelectedKeys.value.length) {
    createMessage.warning('请选择要关联的设备');
    return;
  }
  binding.value = true;
  try {
    await associateDevices(bindSelectedKeys.value, props.centerDeviceIdentification);
    createMessage.success('关联成功');
    bindVisible.value = false;
    await reloadAll();
  } catch (e: any) {
    createMessage.error(e?.message || '关联失败');
  } finally {
    binding.value = false;
  }
}

watch(
  () => props.centerDeviceIdentification,
  async (val) => {
    if (val && val !== '--') {
      selectedKey.value = 'ALL';
      await reloadAll();
    }
  },
);

onMounted(async () => {
  await reloadAll();
  document.addEventListener('fullscreenchange', handleFullscreenChange);
  refreshTimer = setInterval(() => {
    deviceList.value.forEach((d) => {
      loadThresholds(d);
      cardReloadMap[d.deviceIdentification]?.({}, { silent: true });
    });
  }, 8000);
});

onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
  if (document.fullscreenElement) {
    document.exitFullscreen?.();
  }
  if (refreshTimer) clearInterval(refreshTimer);
});
</script>

<style lang="less" scoped>
@ink: #17233d;
@muted: #8c8c8c;
@line: #e8ecf2;
@accent: #266cfb;
@surface: #ffffff;

.assoc-page {
  height: 100%;
  min-height: 0;
  background: @surface;
  overflow: hidden;
  display: flex;
  flex-direction: column;

  &.is-fullscreen {
    position: fixed;
    inset: 0;
    z-index: 1000;
    height: 100vh;
    max-height: 100vh;
    padding: 12px;
    background: @surface;
  }
}

.assoc-layout {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 12px;
  height: 100%;
  overflow: hidden;
}

.device-rail {
  display: flex;
  flex-direction: column;
  min-height: 0;
  height: 100%;
  background: @surface;
  border: 1px solid @line;
  border-radius: 10px;
  overflow: hidden;
  padding: 10px 10px 0;
}

.rail-head {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 6px 12px;
  border-bottom: 1px solid @line;
  margin-bottom: 10px;

  .rail-title {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
    color: @ink;
  }
}

.rail-scroll {
  flex: 1;
  min-height: 0;
  overflow-x: hidden;
  overflow-y: auto;
  padding-bottom: 10px;
}

.rail-item {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 11px 10px;
  margin-bottom: 8px;
  border: 1px solid @line;
  border-radius: 8px;
  background: @surface;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s, box-shadow 0.2s;

  &:hover,
  &.active {
    border-color: #7aa5ff;
    background: #eef4ff;
    box-shadow: 0 2px 8px rgba(38, 108, 251, 0.08);
  }

  &.all-item .all-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: 6px;
    color: @accent;
    background: #eaf1ff;
    flex-shrink: 0;
  }
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;

  &.online {
    background: #52c41a;
    box-shadow: 0 0 0 3px rgba(82, 196, 26, 0.15);
  }
  &.offline {
    background: #ff4d4f;
    box-shadow: 0 0 0 3px rgba(255, 77, 79, 0.15);
  }
}

.rail-copy {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;

  strong,
  small {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  strong {
    color: @ink;
    font-size: 13px;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    gap: 6px;

    em {
      font-style: normal;
      font-size: 11px;
      font-weight: 500;
      color: @accent;
      background: #eaf1ff;
      border-radius: 4px;
      padding: 0 5px;
      line-height: 18px;
    }
  }

  small {
    margin-top: 2px;
    color: @muted;
    font-size: 11px;
  }
}

.status-tag {
  flex-shrink: 0;
  margin: 0;
  transform: scale(0.92);
}

.status-panel {
  display: flex;
  flex-direction: column;
  min-height: 0;
  height: 100%;
  background: @surface;
  border: 1px solid @line;
  border-radius: 10px;
  padding: 16px 18px 0;
  min-width: 0;
  overflow: hidden;
}

.panel-toolbar {
  flex-shrink: 0;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  padding-bottom: 14px;
  margin-bottom: 12px;
  border-bottom: 1px solid @line;
  flex-wrap: wrap;
}

.panel-heading {
  h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: @ink;
    line-height: 24px;
  }
  p {
    margin: 4px 0 0;
    font-size: 12px;
    color: @muted;
  }
}

.panel-actions {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.threshold-filter {
  margin-right: 4px;
  color: #595959;
  font-size: 13px;
}

.panel-scroll {
  flex: 1;
  min-height: 0;
  overflow-x: hidden;
  overflow-y: auto;
  padding-bottom: 16px;

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    min-height: 100%;
  }
}

.device-sections {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.device-section {
  border: 1px solid @line;
  border-radius: 10px;
  overflow: hidden;
  background: @surface;
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  background: @surface;
  border-bottom: 1px solid @line;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;

  strong {
    color: @ink;
    font-size: 15px;
    font-weight: 600;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .device-id {
    color: @muted;
    font-size: 12px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.section-actions {
  display: flex;
  gap: 14px;
  flex-shrink: 0;

  a {
    font-size: 13px;
    color: @accent;
  }
  .danger {
    color: #ff4d4f;
  }
}

.prop-panel {
  padding: 14px;
  background: @surface;
  min-width: 0;
}

.prop-empty,
.empty-wrap {
  text-align: center;
  color: @muted;
  padding: 36px 0;
}

.empty-wrap .empty-icon {
  font-size: 40px;
  color: #d0d5dd;
  margin-bottom: 10px;
}

.empty-wrap .hint {
  margin-top: 6px;
  font-size: 12px;
  color: #bfbfbf;
}

.bind-toolbar {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}

@media (max-width: 960px) {
  .assoc-layout {
    grid-template-columns: 1fr;
    grid-template-rows: minmax(180px, 32%) minmax(0, 1fr);
  }
}
</style>

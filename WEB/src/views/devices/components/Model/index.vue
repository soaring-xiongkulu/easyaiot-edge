<template>
  <div class="model-wrapper">
    <div class="tab-content">
      <!-- 共享的搜索表单 -->
      <div class="search-form-wrapper">
        <BasicForm @register="registerForm"/>
      </div>

      <!-- 统一的标题和工具栏 -->
      <div class="view-header">
        <div class="view-title">
          设备属性
          <span class="count">({{ propertyTotal }})</span>
        </div>
        <div class="view-actions">
          <label class="threshold-filter">
            <input v-model="onlyThreshold" type="checkbox" />
            仅显示配置阈值的属性
          </label>
          <Button @click="openAlarmStrategy" preIcon="ant-design:alert-outlined">
            告警策略
          </Button>
          <Button @click="handleRefresh" preIcon="ant-design:reload-outlined">
            刷新
          </Button>
          <Button type="default" preIcon="ant-design:swap-outlined" @click="handleViewSwap">
            切换视图
          </Button>
        </div>
      </div>

      <!-- 卡片视图：v-if 避免与表格同时挂载导致重复请求 -->
      <div v-if="activeKey === 'card'">
        <TingModelCardList 
          :params="params" 
          :api="fetchThingModels" 
          :active-key="activeKey"
          :search-params="searchParams"
          :threshold-map="thresholdMap"
          :only-threshold="onlyThreshold"
          @get-method="getMethod"
          @refresh="handleRefresh" 
          @view="handleView"
          @threshold="handleThreshold"
          @tab-change="handleTabChange"
          @loaded="onCardLoaded"
        />
      </div>

      <!-- 表格视图 -->
      <div v-if="activeKey === 'table'">
        <BasicTable @register="registerTable">
          <template #action="{ record }">
            <TableAction
              :actions="[
                {
                  tooltip: { title: '阈值', placement: 'top' },
                  icon: 'ant-design:setting-outlined',
                  onClick: () => handleThreshold(record),
                },
                {
                  tooltip: {
                    title: '刷新',
                    placement: 'top',
                  },
                  icon: 'ant-design:redo-outlined',
                  onClick: () => handleRefresh(),
                },
                {
                  icon: 'ant-design:eye-filled',
                  tooltip: {
                    title: '详情',
                    placement: 'top',
                  },
                  onClick: handleView.bind(null, record),
                },
              ]"
            />
          </template>
        </BasicTable>
      </div>
    </div>
    <Detail @register="registerModal"/>
    <ThresholdModal ref="thresholdModalRef" @saved="loadThresholds" />
    <AlarmStrategyModal ref="alarmStrategyRef" />
  </div>
</template>

<script lang="ts" setup>
import { ref, reactive, onMounted, onUnmounted, onActivated, onDeactivated } from "vue";
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { BasicForm, useForm } from '@/components/Form';
import { getBasicColumns, getFormConfig } from './tableData';
import { getDeviceThresholds, getDevicethingModels } from '@/api/device/devices';
import Detail from './components/Detail.vue';
import ThresholdModal from './components/ThresholdModal.vue';
import AlarmStrategyModal from '../AlarmStrategyModal.vue';
import { useModal } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import { useRoute } from "vue-router";
import TingModelCardList from "./components/CardList/TingModelCardList.vue";
import { Button } from '@/components/Button'

const AUTO_REFRESH_MS = 5000;

const route = useRoute();
const { createMessage } = useMessage();

const activeKey = ref<string>('card');
const searchParams = reactive({});
const propertyTotal = ref(0);
const onlyThreshold = ref(false);
const thresholdMap = reactive<Record<string, any>>({});
const thresholdModalRef = ref<any>(null);
const alarmStrategyRef = ref<any>(null);

function onCardLoaded(total: number) {
  propertyTotal.value = total ?? 0;
}

// 共享的搜索表单
const [registerForm, { validate, getFieldsValue, resetFields }] = useForm({
  schemas: [
    {
      field: `name`,
      label: `键/名称`,
      component: 'Input',
    }
  ],
  labelWidth: 70,
  baseColProps: {span: 10},
  actionColOptions: {span: 6, offset: 8},
  autoSubmitOnEnter: true,
  submitFunc: handleSearchSubmit,
});

// 搜索表单提交
async function handleSearchSubmit() {
  const formData = await validate();
  Object.assign(searchParams, formData);
  // 触发当前视图的刷新
  if (activeKey.value === 'table') {
    reload();
  } else {
    cardListReload();
  }
}

async function fetchThingModels(params) {
  const res = await getDevicethingModels(params);
  propertyTotal.value = res?.total ?? 0;
  return res;
}

const [registerTable, { reload }] = useTable({
  resizeHeightOffset: 16,
  api: fetchThingModels,
  beforeFetch: (data) => {
    data['id'] = route.params.id;
    return {
      ...data,
      ...searchParams,
    };
  },
  columns: getBasicColumns(),
  formConfig: getFormConfig(),
  useSearchForm: false,
  showIndexColumn: false,
  showTableSetting: false,
  tableSetting: { fullScreen: true },
  fetchSetting: {
    listField: 'data',
    totalField: 'total',
  },
  actionColumn: {
    title: '操作',
    dataIndex: 'action',
    fixed: 'right',
    slots: { customRender: 'action' },
  },
});

const [registerModal, { openModal }] = useModal();

// 请求api时附带参数
const params = {
  id: route.params.id,
};

type CardReload = (p?: Record<string, any>, options?: { silent?: boolean }) => Promise<void> | void;
let cardListReload: CardReload = () => {};

// 获取内部fetch方法;
function getMethod(m: CardReload) {
  cardListReload = m;
}

function refreshData(options: { silent?: boolean } = {}) {
  if (activeKey.value === 'table') {
    return reload();
  }
  return cardListReload({}, { silent: !!options.silent });
}

// 手动刷新
const handleRefresh = () => {
  refreshData();
  createMessage.success('刷新成功');
};

//详情按钮事件
function handleView(record) {
  openModal(true, {
    data: {
      ...record,
      deviceIdentification:
        record?.deviceIdentification || route.params.deviceIdentification || '',
    },
  });
}

function handleThreshold(record) {
  const deviceIdentification =
    record?.deviceIdentification || String(route.params.deviceIdentification || '');
  thresholdModalRef.value?.open({
    deviceIdentification,
    propertyCode: record.propertyCode,
    propertyName: record.propertyName,
    currentValue: record.dataValue,
  });
}

function openAlarmStrategy() {
  const id = String(route.params.deviceIdentification || '');
  if (!id) {
    createMessage.warning('设备标识缺失');
    return;
  }
  alarmStrategyRef.value?.open(id);
}

async function loadThresholds() {
  const id = String(route.params.deviceIdentification || '');
  if (!id) return;
  try {
    const res = await getDeviceThresholds(id);
    const list = res?.data || res || [];
    Object.keys(thresholdMap).forEach((k) => delete thresholdMap[k]);
    (Array.isArray(list) ? list : []).forEach((item: any) => {
      if (item?.propertyCode) {
        thresholdMap[item.propertyCode] = item;
      }
    });
  } catch (e) {
    console.error(e);
  }
}

// 切换卡片/表格视图
function handleTabChange(key: string) {
  activeKey.value = key;
}

function handleViewSwap() {
  handleTabChange(activeKey.value === 'card' ? 'table' : 'card');
}

// ---- 5s 自动刷新：仅当前 Tab 可见时运行 ----
let autoTimer: ReturnType<typeof setInterval> | null = null;
let autoRefreshing = false;

async function silentAutoRefresh() {
  if (autoRefreshing || document.hidden) return;
  autoRefreshing = true;
  try {
    await refreshData({ silent: true });
  } catch {
    // 轮询失败不打断后续周期
  } finally {
    autoRefreshing = false;
  }
}

function startAutoRefresh() {
  stopAutoRefresh();
  autoTimer = setInterval(() => {
    silentAutoRefresh();
  }, AUTO_REFRESH_MS);
}

function stopAutoRefresh() {
  if (autoTimer != null) {
    clearInterval(autoTimer);
    autoTimer = null;
  }
}

function onVisibilityChange() {
  if (document.hidden) {
    stopAutoRefresh();
  } else {
    startAutoRefresh();
  }
}

onMounted(() => {
  loadThresholds();
  startAutoRefresh();
  document.addEventListener('visibilitychange', onVisibilityChange);
});

onActivated(() => {
  startAutoRefresh();
});

onDeactivated(() => {
  stopAutoRefresh();
});

onUnmounted(() => {
  stopAutoRefresh();
  document.removeEventListener('visibilitychange', onVisibilityChange);
});
</script>

<style lang="less" scoped>
.model-wrapper {
  background-color: #ffffff;
  border-radius: 12px;
  overflow: hidden;
  min-height: 100%;

  .tab-content {
    padding: 8px 4px 16px;
    background: #ffffff;
    min-height: 400px;
    animation: fadeIn 0.3s ease-in-out;

    .search-form-wrapper {
      margin-bottom: 8px;
    }

    .view-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 16px;

      .view-title {
        font-size: 16px;
        font-weight: 500;
        line-height: 24px;
        color: #262626;

        .count {
          margin-left: 4px;
          color: #8c8c8c;
          font-weight: 400;
        }
      }

      .view-actions {
        display: flex;
        align-items: center;
        gap: 8px;
        flex-shrink: 0;
        flex-wrap: wrap;

        .threshold-filter {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          font-size: 13px;
          color: #595959;
          cursor: pointer;
          user-select: none;
          white-space: nowrap;
        }
      }
    }
  }
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>


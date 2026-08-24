<template>
  <div class="ops-page">
    <div class="ops-toolbar">
      <div class="ops-field">
        <label>设备名称</label>
        <Input
          v-model:value="filters.deviceName"
          allowClear
          placeholder="请输入设备名称"
          style="width: 180px"
          @pressEnter="handleSearch"
        />
      </div>
      <div class="ops-field">
        <label>设备标识</label>
        <Input
          v-model:value="filters.deviceIdentification"
          allowClear
          placeholder="请输入设备标识"
          style="width: 180px"
          @pressEnter="handleSearch"
        />
      </div>
      <div class="ops-field">
        <label>连接状态</label>
        <Select
          v-model:value="filters.connectStatus"
          allowClear
          placeholder="全部"
          style="width: 140px"
          :options="connectStatusOptions"
        />
      </div>
      <div class="ops-toolbar-actions">
        <Button type="primary" @click="handleSearch" preIcon="ant-design:search-outlined">
          查询
        </Button>
        <Button @click="handleReset" preIcon="ant-design:clear-outlined">重置</Button>
        <Button @click="loadList" :loading="loading" preIcon="ant-design:reload-outlined">
          刷新
        </Button>
      </div>
    </div>

    <div class="ops-surface">
      <div class="ops-surface-head">
        <div class="ops-surface-title">
          设备列表
          <span class="ops-count">({{ pagination.total }})</span>
        </div>
      </div>
      <div class="ops-surface-body">
        <Table
          rowKey="id"
          size="middle"
          :loading="loading"
          :columns="columns"
          :dataSource="deviceList"
          :pagination="false"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'deviceType'">
              <Tag :color="deviceTypeColor(record.deviceType)">
                {{ deviceTypeLabel(record.deviceType) }}
              </Tag>
            </template>
            <template v-else-if="column.key === 'connectStatus'">
              <Tag :color="record.connectStatus === 'ONLINE' ? 'green' : 'red'">
                {{ record.connectStatus === 'ONLINE' ? '在线' : '离线' }}
              </Tag>
            </template>
            <template v-else-if="column.key === 'activeStatus'">
              <Tag :color="record.activeStatus === 1 ? 'green' : 'red'">
                {{ record.activeStatus === 1 ? '已激活' : '未激活' }}
              </Tag>
            </template>
            <template v-else-if="column.key === 'lastOnlineTime'">
              {{ formatTime(record.lastOnlineTime) }}
            </template>
            <template v-else-if="column.key === 'action'">
              <a @click="goDeviceDetail(record)">详情</a>
            </template>
          </template>
        </Table>
        <div v-if="!loading && deviceList.length === 0" class="ops-empty">
          <Icon icon="ant-design:cluster-outlined" class="ops-empty-icon" />
          <p>暂无使用该产品的设备</p>
          <p class="ops-empty-hint">设备上线或自动注册后，将按产品标识出现在此列表</p>
        </div>
        <div v-if="pagination.total > 0" class="table-pagination">
          <Pagination
            v-model:current="pagination.current"
            v-model:pageSize="pagination.pageSize"
            :total="pagination.total"
            :showSizeChanger="true"
            :showTotal="(total) => `共 ${total} 条`"
            @change="handlePageChange"
            @showSizeChange="handlePageChange"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { Input, Pagination, Select, Table, Tag } from 'ant-design-vue';
import moment from 'moment';
import { useRouter } from 'vue-router';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { getProductRelatedDevices } from '@/api/device/product';

defineOptions({ name: 'ProductRelatedDevices' });

const props = defineProps<{
  productIdentification: string;
  productName?: string;
  appId?: string;
}>();

const router = useRouter();
const { createMessage } = useMessage();

const loading = ref(false);
const deviceList = ref<any[]>([]);

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
});

const filters = reactive({
  deviceName: '',
  deviceIdentification: '',
  connectStatus: undefined as string | undefined,
});

const connectStatusOptions = [
  { value: 'ONLINE', label: '在线' },
  { value: 'OFFLINE', label: '离线' },
];

const productIdentification = computed(() => props.productIdentification || '');

const columns = [
  { title: '设备名称', dataIndex: 'deviceName', key: 'deviceName', ellipsis: true },
  { title: '设备标识', dataIndex: 'deviceIdentification', key: 'deviceIdentification', ellipsis: true },
  { title: '设备SN号', dataIndex: 'deviceSn', key: 'deviceSn', ellipsis: true, width: 140 },
  { title: '产品类型', dataIndex: 'deviceType', key: 'deviceType', width: 110 },
  { title: '连接状态', dataIndex: 'connectStatus', key: 'connectStatus', width: 100 },
  { title: '激活状态', dataIndex: 'activeStatus', key: 'activeStatus', width: 100 },
  { title: '最后上线时间', dataIndex: 'lastOnlineTime', key: 'lastOnlineTime', width: 170 },
  { title: '操作', key: 'action', width: 80 },
];

function deviceTypeLabel(type: string) {
  if (type === 'COMMON') return '普通产品';
  if (type === 'GATEWAY') return '网关产品';
  if (type === 'VIDEO_COMMON') return '视频产品';
  return '子设备';
}

function deviceTypeColor(type: string) {
  if (type === 'COMMON') return 'blue';
  if (type === 'GATEWAY') return 'purple';
  if (type === 'VIDEO_COMMON') return 'cyan';
  return 'cyan';
}

function formatTime(value: string | null) {
  if (!value) return '--';
  return moment(value).format('YYYY-MM-DD HH:mm:ss');
}

async function loadList() {
  if (!productIdentification.value) {
    deviceList.value = [];
    pagination.total = 0;
    return;
  }
  loading.value = true;
  try {
    const res = await getProductRelatedDevices(productIdentification.value, {
      pageNum: pagination.current,
      pageSize: pagination.pageSize,
      deviceName: filters.deviceName || undefined,
      deviceIdentification: filters.deviceIdentification || undefined,
      connectStatus: filters.connectStatus || undefined,
    });
    deviceList.value = res?.data || res?.rows || [];
    pagination.total = res?.total || 0;
  } catch (e) {
    console.error(e);
    createMessage.error('加载关联设备失败');
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  pagination.current = 1;
  loadList();
}

function handleReset() {
  filters.deviceName = '';
  filters.deviceIdentification = '';
  filters.connectStatus = undefined;
  pagination.current = 1;
  loadList();
}

function handlePageChange(page: number, pageSize: number) {
  pagination.current = page;
  pagination.pageSize = pageSize;
  loadList();
}

function goDeviceDetail(record: any) {
  router.push({
    name: 'DeviceDetail',
    params: {
      id: record.id,
      productIdentification: record.productIdentification,
      deviceIdentification: record.deviceIdentification,
      deviceType: record.deviceType,
    },
  });
}

watch(
  () => props.productIdentification,
  (val) => {
    if (val) {
      pagination.current = 1;
      loadList();
    }
  },
);

onMounted(() => {
  loadList();
});
</script>

<style lang="less" scoped>
@import '@/views/devices/components/styles/device-ops.less';

.table-pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
</style>

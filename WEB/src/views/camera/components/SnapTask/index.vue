<template>
  <div class="snap-task-container" :class="{ 'snap-task-container--embedded': embedded }">
    <div class="toolbar">
      <Button type="primary" @click="handleCreate">
        <template #icon>
          <PlusOutlined />
        </template>
        新建抓拍任务
      </Button>
      <Button type="default" @click="handleClickSwap">
        <template #icon>
          <SwapOutlined />
        </template>
        切换视图
      </Button>
      <span v-if="activeSpaceFilterLabel" class="filter-hint">
        已筛选空间：{{ activeSpaceFilterLabel }}
        <a class="clear-filter" @click="clearSpaceFilter">清除</a>
      </span>
      <span v-if="activeDeviceFilterLabel" class="filter-hint">
        已筛选设备：{{ activeDeviceFilterLabel }}
        <a class="clear-filter" @click="clearDeviceFilter">清除</a>
      </span>
    </div>

    <BasicTable v-if="viewMode === 'table'" @register="registerTable">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'status'">
          <a-tag :color="record.status === 0 ? 'green' : 'red'">
            {{ record.status === 0 ? '正常' : '异常' }}
          </a-tag>
        </template>
        <template v-else-if="column.dataIndex === 'is_enabled'">
          <a-switch :checked="record.is_enabled" @change="handleToggleEnabled(record)" />
        </template>
        <template v-else-if="column.dataIndex === 'capture_type'">
          <a-tag>{{ record.capture_type === 0 ? '抽帧' : '抓拍' }}</a-tag>
        </template>
        <template v-else-if="column.dataIndex === 'action'">
          <TableAction :actions="getTableActions(record)" />
        </template>
      </template>
    </BasicTable>

    <div v-else class="card-list">
      <a-row :gutter="[16, 16]">
        <a-col :xs="24" :sm="12" :md="8" :lg="6" v-for="item in taskList" :key="item.id">
          <a-card :hoverable="true" class="task-card">
            <template #title>
              <div class="card-title">
                <span>{{ item.task_name }}</span>
                <a-tag :color="item.status === 0 ? 'green' : 'red'" size="small">
                  {{ item.status === 0 ? '正常' : '异常' }}
                </a-tag>
              </div>
            </template>
            <template #extra>
              <a-dropdown>
                <template #overlay>
                  <a-menu>
                    <a-menu-item @click="handleViewLogs(item)">
                      <FileTextOutlined /> 运行日志
                    </a-menu-item>
                    <a-menu-item @click="handleViewGallery(item)">
                      <PictureOutlined /> 查看图库
                    </a-menu-item>
                    <a-menu-item @click="handleView(item)">
                      <EyeOutlined /> 查看
                    </a-menu-item>
                    <a-menu-item @click="handleEdit(item)">
                      <EditOutlined /> 编辑
                    </a-menu-item>
                    <a-menu-item @click="handleToggleEnabled(item)">
                      {{ item.is_enabled ? '停用' : '启用' }}
                    </a-menu-item>
                    <a-menu-item @click="handleDelete(item)" danger>
                      <DeleteOutlined /> 删除
                    </a-menu-item>
                  </a-menu>
                </template>
                <MoreOutlined />
              </a-dropdown>
            </template>
            <div class="card-content">
              <div class="info-item">
                <span class="label">空间:</span>
                <span class="value">{{ item.space_name }}</span>
              </div>
              <div class="info-item">
                <span class="label">设备:</span>
                <span class="value">{{ item.device_name }}</span>
              </div>
              <div class="info-item">
                <span class="label">类型:</span>
                <a-tag size="small">{{ item.capture_type === 0 ? '抽帧' : '抓拍' }}</a-tag>
              </div>
              <div class="info-item">
                <span class="label">Cron:</span>
                <span class="value">{{ item.cron_expression }}</span>
              </div>
              <div class="info-item">
                <span class="label">状态:</span>
                <a-switch :checked="item.is_enabled" size="small" @change="handleToggleEnabled(item)" />
              </div>
              <div class="info-item">
                <span class="label">抓拍次数:</span>
                <span class="value">{{ item.total_captures || 0 }}</span>
              </div>
            </div>
          </a-card>
        </a-col>
      </a-row>
      <a-empty v-if="taskList.length === 0" description="暂无抓拍任务" />
    </div>

    <SnapTaskModal @register="registerModal" @success="handleSuccess" />
    <SnapTaskLogsModal @register="registerLogsModal" />
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import {
  PlusOutlined,
  SwapOutlined,
  EyeOutlined,
  EditOutlined,
  DeleteOutlined,
  MoreOutlined,
  PictureOutlined,
  FileTextOutlined,
} from '@ant-design/icons-vue';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { useDrawer } from '@/components/Drawer';
import { useModal } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getSnapSpaceList,
  getSnapTaskList,
  deleteSnapTask,
  startSnapTask,
  stopSnapTask,
  type SnapTask,
} from '@/api/device/snap';
import { getDeviceList } from '@/api/device/camera';
import SnapTaskModal from './SnapTaskModal.vue';
import SnapTaskLogsModal from './SnapTaskLogsModal.vue';
import { Button } from '@/components/Button';

defineOptions({ name: 'SnapTask' });

const props = defineProps<{
  embedded?: boolean;
  initialSpaceId?: number | null;
  initialDeviceId?: string | null;
}>();

const router = useRouter();
const { createMessage } = useMessage();
const [registerModal, { openDrawer }] = useDrawer();
const [registerLogsModal, { openModal: openLogsModal }] = useModal();

const viewMode = ref<'table' | 'card'>('table');
const taskList = ref<SnapTask[]>([]);
const spaceOptions = ref<Array<{ label: string; value: number }>>([]);
const deviceOptions = ref<Array<{ label: string; value: string }>>([]);
const spaceFilterId = ref<number | undefined>(undefined);
const deviceFilterId = ref<string | undefined>(undefined);

const activeSpaceFilterLabel = computed(() => {
  if (spaceFilterId.value == null) return '';
  return spaceOptions.value.find((item) => item.value === spaceFilterId.value)?.label ?? `#${spaceFilterId.value}`;
});

const activeDeviceFilterLabel = computed(() => {
  if (!deviceFilterId.value) return '';
  return deviceOptions.value.find((item) => item.value === deviceFilterId.value)?.label ?? deviceFilterId.value;
});

async function loadSpaceOptions() {
  try {
    const response = await getSnapSpaceList({ pageNo: 1, pageSize: 1000, scope: 'leaves' });
    const items = response.data || [];
    spaceOptions.value = items
      .filter((item) => item.id != null)
      .map((item) => ({
        label: item.space_name,
        value: item.id!,
      }));
  } catch (error) {
    console.error('加载抓拍空间列表失败', error);
  }
}

async function loadDeviceOptions() {
  try {
    const response = await getDeviceList({ pageNo: 1, pageSize: 1000 });
    const items = response.data || [];
    deviceOptions.value = items.map((item) => ({
      label: item.name ? `${item.name} (${item.id})` : item.id,
      value: item.id,
    }));
  } catch (error) {
    console.error('加载设备列表失败', error);
  }
}

function applySpaceFilter(spaceId?: number | null) {
  spaceFilterId.value = spaceId ?? undefined;
  getForm?.()?.setFieldsValue?.({ space_id: spaceFilterId.value });
  refresh();
}

function applyDeviceFilter(deviceId?: string | null) {
  deviceFilterId.value = deviceId ?? undefined;
  getForm?.()?.setFieldsValue?.({ device_id: deviceFilterId.value });
  refresh();
}

function clearSpaceFilter() {
  applySpaceFilter(undefined);
}

function clearDeviceFilter() {
  applyDeviceFilter(undefined);
}

const getBasicColumns = () => [
  { title: '任务名称', dataIndex: 'task_name', width: 150 },
  { title: '空间名称', dataIndex: 'space_name', width: 120 },
  { title: '设备名称', dataIndex: 'device_name', width: 120 },
  { title: '抓拍类型', dataIndex: 'capture_type', width: 80 },
  { title: 'Cron表达式', dataIndex: 'cron_expression', width: 150 },
  { title: '状态', dataIndex: 'status', width: 80 },
  { title: '启用', dataIndex: 'is_enabled', width: 80 },
  { title: '抓拍次数', dataIndex: 'total_captures', width: 100 },
  { title: '操作', dataIndex: 'action', width: 220, fixed: 'right' as const },
];

const [registerTable, { reload, getForm }] = useTable({
  title: '抓拍任务列表',
  api: async (params) => {
    const response = await getSnapTaskList({
      ...params,
      space_id: params.space_id ?? spaceFilterId.value,
      device_id: params.device_id ?? deviceFilterId.value,
    });
    return {
      items: response.data || [],
      total: response.total || 0,
    };
  },
  columns: getBasicColumns(),
  useSearchForm: true,
  formConfig: {
    labelWidth: 80,
    schemas: [
      {
        field: 'search',
        label: '任务名称',
        component: 'Input',
        componentProps: { placeholder: '请输入任务名称' },
      },
      {
        field: 'space_id',
        label: '抓拍空间',
        component: 'Select',
        componentProps: {
          placeholder: '请选择抓拍空间',
          allowClear: true,
          showSearch: true,
          optionFilterProp: 'label',
          options: spaceOptions,
        },
      },
      {
        field: 'device_id',
        label: '设备',
        component: 'Select',
        componentProps: {
          placeholder: '请选择设备',
          allowClear: true,
          showSearch: true,
          optionFilterProp: 'label',
          options: deviceOptions,
        },
      },
      {
        field: 'status',
        label: '状态',
        component: 'Select',
        componentProps: {
          placeholder: '请选择状态',
          allowClear: true,
          options: [
            { label: '正常', value: 0 },
            { label: '异常', value: 1 },
          ],
        },
      },
    ],
  },
  pagination: true,
  rowKey: 'id',
  fetchSetting: {
    listField: 'items',
    totalField: 'total',
  },
});

function handleViewGallery(record: SnapTask) {
  if (!record.space_id) {
    createMessage.warning('该任务未关联抓拍空间');
    return;
  }
  router.push({
    path: `/snap-space-manage/${record.space_id}`,
    query: { view: 'images' },
  });
}

function handleViewLogs(record: SnapTask) {
  openLogsModal(true, {
    taskId: record.id,
    taskName: record.task_name,
    autoRefresh: !!record.is_enabled,
  });
}

function getTableActions(record: SnapTask) {
  return [
    {
      icon: 'ant-design:picture-outlined',
      tooltip: '查看图库',
      onClick: () => handleViewGallery(record),
    },
    {
      icon: 'ant-design:file-text-outlined',
      tooltip: '运行日志',
      onClick: () => handleViewLogs(record),
    },
    {
      icon: 'ant-design:eye-filled',
      tooltip: '查看',
      onClick: () => handleView(record),
    },
    {
      icon: 'ant-design:edit-filled',
      tooltip: '编辑',
      onClick: () => handleEdit(record),
    },
    {
      icon: record.is_enabled ? 'ant-design:pause-circle-outlined' : 'ant-design:play-circle-outlined',
      tooltip: record.is_enabled ? '停用' : '启用',
      onClick: () => handleToggleEnabled(record),
    },
    {
      icon: 'material-symbols:delete-outline-rounded',
      tooltip: '删除',
      popConfirm: {
        title: '确定删除此抓拍任务？',
        confirm: () => handleDelete(record),
      },
    },
  ];
}

async function loadTaskList() {
  try {
    const response = await getSnapTaskList({
      pageNo: 1,
      pageSize: 1000,
      space_id: spaceFilterId.value,
      device_id: deviceFilterId.value,
    });
    if (response.code === 0) {
      taskList.value = response.data || [];
    } else {
      createMessage.error(response.msg || '加载抓拍任务列表失败');
      taskList.value = [];
    }
  } catch (error) {
    console.error('加载抓拍任务列表失败', error);
    createMessage.error('加载抓拍任务列表失败');
    taskList.value = [];
  }
}

const handleClickSwap = () => {
  viewMode.value = viewMode.value === 'table' ? 'card' : 'table';
  if (viewMode.value === 'card') {
    void loadTaskList();
  } else {
    reload();
  }
};

const handleCreate = () => {
  openDrawer(true, {
    type: 'create',
    space_id: spaceFilterId.value,
    device_id: deviceFilterId.value,
  });
};

const handleView = (record: SnapTask) => {
  openDrawer(true, { type: 'view', record });
};

const handleEdit = (record: SnapTask) => {
  openDrawer(true, { type: 'edit', record });
};

const handleDelete = async (record: SnapTask) => {
  try {
    const response = await deleteSnapTask(record.id);
    if (response.code === 0) {
      createMessage.success('删除成功');
      handleSuccess();
    } else {
      createMessage.error(response.msg || '删除失败');
    }
  } catch (error) {
    console.error('删除失败', error);
    createMessage.error('删除失败');
  }
};

const handleToggleEnabled = async (record: SnapTask) => {
  try {
    const response = record.is_enabled
      ? await stopSnapTask(record.id)
      : await startSnapTask(record.id);
    if (response.code === 0) {
      createMessage.success(record.is_enabled ? '任务已停用' : '任务已启用');
      handleSuccess();
    } else {
      createMessage.error(response.msg || '操作失败');
    }
  } catch (error) {
    console.error('操作失败', error);
    createMessage.error('操作失败');
  }
};

function handleSuccess() {
  if (viewMode.value === 'table') {
    reload();
  } else {
    void loadTaskList();
  }
}

function refresh() {
  if (viewMode.value === 'table') {
    reload();
  } else {
    void loadTaskList();
  }
}

async function initFilters() {
  await Promise.all([loadSpaceOptions(), loadDeviceOptions()]);
  if (props.initialSpaceId != null) {
    spaceFilterId.value = props.initialSpaceId;
  }
  if (props.initialDeviceId) {
    deviceFilterId.value = props.initialDeviceId;
  }
  await getForm?.()?.setFieldsValue?.({
    space_id: spaceFilterId.value,
    device_id: deviceFilterId.value,
  });
  refresh();
}

watch(
  () => props.initialSpaceId,
  (spaceId) => {
    applySpaceFilter(spaceId);
  },
);

watch(
  () => props.initialDeviceId,
  (deviceId) => {
    applyDeviceFilter(deviceId);
  },
);

onMounted(() => {
  void initFilters();
});

defineExpose({ refresh });
</script>

<style lang="less" scoped>
.snap-task-container {
  padding: 16px;
  background: #f0f2f5;
  min-height: calc(100vh - 200px);

  &--embedded {
    padding: 0;
    background: transparent;
    min-height: 0;
    height: 100%;
    display: flex;
    flex-direction: column;
    overflow: hidden;

    .toolbar {
      flex-shrink: 0;
      margin: 0 0 12px;
      box-shadow: none;
      border: 1px solid #f0f0f0;
    }

    :deep(.vben-basic-table) {
      flex: 1;
      min-height: 0;
    }

    .card-list {
      flex: 1;
      min-height: 0;
      overflow: auto;
      box-shadow: none;
      border: 1px solid #f0f0f0;
    }
  }

  .toolbar {
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    background: #fff;
    padding: 16px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  .filter-hint {
    margin-left: auto;
    font-size: 13px;
    color: #8c8c8c;

    .clear-filter {
      margin-left: 8px;
    }
  }

  .card-list {
    background: #fff;
    padding: 16px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    min-height: 400px;

    .task-card {
      height: 100%;
      transition: all 0.3s;

      &:hover {
        transform: translateY(-4px);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
      }

      .card-title {
        display: flex;
        align-items: center;
        gap: 8px;
        justify-content: space-between;
      }

      .card-content {
        .info-item {
          margin-bottom: 12px;
          display: flex;
          align-items: center;
          line-height: 1.6;

          .label {
            font-weight: 500;
            margin-right: 8px;
            min-width: 90px;
            color: #595959;
          }

          .value {
            flex: 1;
            color: #262626;
            word-break: break-all;
          }
        }
      }
    }
  }
}
</style>

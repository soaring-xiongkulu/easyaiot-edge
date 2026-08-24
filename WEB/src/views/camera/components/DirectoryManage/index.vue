<template>
  <div :class="['directory-manage-wrapper', { 'is-embedded': embedded }]">
    <div class="directory-layout">
      <!-- 左侧：目录树 -->
      <div class="directory-sidebar">
        <div class="sidebar-tree">
          <div class="tree-header">
            <div class="tree-header-button">
              <Space :size="6" :wrap="false">
                <Button type="primary" preIcon="ant-design:plus-outlined" @click="handleAddDirectory">
                  添加目录
                </Button>
                <Button preIcon="ant-design:code-outlined" @click="handleOpenJsonEditor">
                  JSON 编辑
                </Button>
              </Space>
              <Button
                :loading="treeLoading || treeRefreshing"
                preIcon="ant-design:reload-outlined"
                @click="handleRefreshTree"
              >
                刷新
              </Button>
            </div>
          </div>
          <div class="tree-content">
            <div v-if="selectedDirectoryId && !selectedDirectoryIsDefault" class="tree-dir-actions">
              <Button type="link" size="small" @click="handleEditSelectedDirectory">
                编辑目录
              </Button>
              <a-popconfirm title="确定删除此目录？" @confirm="handleDeleteSelectedDirectory">
                <Button type="link" size="small" danger>删除目录</Button>
              </a-popconfirm>
            </div>
            <BasicTree
              search
              :showIcon="true"
              :indent="12"
              v-model:selectedKeys="treeSelectedKeys"
              :expanded-keys="treeExpandedKeys"
              :tree-data="monitorTreeItems"
              :load-data="onLoadGbDeviceChannels"
              :field-names="{ key: 'key', title: 'title' }"
              class="directory-monitor-tree"
              :loading="treeLoading"
              @select="handleMonitorTreeSelect"
              @update:expanded-keys="treeExpandedKeys = $event"
            />
          </div>
        </div>
      </div>

      <!-- 右侧：设备列表 -->
      <div class="device-content">
        <Space wrap :size="8" class="device-button-group">
          <Button type="primary" :loading="syncCamerasLoading" preIcon="ant-design:cloud-sync-outlined" @click="handleSyncCameras">
            同步摄像头
          </Button>
          <Button
            :disabled="!selectedDirectoryId || !checkedKeys.length"
            preIcon="ant-design:folder-open-outlined"
            @click="handleBatchMoveToDirectory"
          >
            批量移动到目录
          </Button>
        </Space>
        <BasicTable @register="registerTable">
          <template #bodyCell="{ column, record }">
            <!-- 统一复制功能组件 -->
            <template v-if="column.key === 'name'">
              <span style="cursor: pointer" @click="handleCopy(record.name)">
                <Icon icon="tdesign:copy-filled" color="#4287FCFF"/>
                {{ formatCameraDeviceLabel(record) }}
              </span>
            </template>
            <template v-else-if="column.key === 'id'">
              <span style="cursor: pointer" @click="handleCopy(record.id)">
                <Icon icon="tdesign:copy-filled" color="#4287FCFF"/> {{ record.id }}
              </span>
            </template>
            <template v-else-if="column.key === 'model'">
              <span
                v-if="hasCopyableDeviceModel(record.model)"
                style="cursor: pointer"
                @click="handleCopy(record.model)"
              >
                <Icon icon="tdesign:copy-filled" color="#4287FCFF"/> {{ record.model }}
              </span>
              <span v-else>{{ record.model || '-' }}</span>
            </template>
            <template v-else-if="column.key === 'manufacturer'">
              <span
                v-if="hasCopyableManufacturer(record.manufacturer)"
                style="cursor: pointer"
                @click="handleCopy(record.manufacturer)"
              >
                <Icon icon="tdesign:copy-filled" color="#4287FCFF"/> {{ record.manufacturer }}
              </span>
              <span v-else>{{ record.manufacturer || '-' }}</span>
            </template>
            <template v-else-if="column.key === 'ip'">
              <span
                v-if="hasCopyableDeviceIp(record.ip)"
                style="cursor: pointer"
                @click="handleCopy(record.ip)"
              >
                <Icon icon="tdesign:copy-filled" color="#4287FCFF"/> {{ record.ip }}
              </span>
              <span v-else>{{ record.ip || '-' }}</span>
            </template>

            <!-- 在线状态显示 -->
            <template v-else-if="column.dataIndex === 'online'">
              <a-tag :color="record.online ? 'green' : 'red'">
                {{ record.online ? '在线' : '离线' }}
              </a-tag>
            </template>

            <template v-else-if="column.dataIndex === 'action'">
              <TableAction :actions="getTableActions(record)" />
            </template>
          </template>
        </BasicTable>
      </div>
    </div>

    <!-- 目录编辑/创建模态框 -->
    <DirectoryModal
      @register="registerDirectoryModal"
      @success="handleDirectorySuccess"
    />

    <!-- JSON 编辑设备目录 -->
    <DirectoryJsonModal
      @register="registerJsonModal"
      @success="handleDirectorySuccess"
    />

    <MoveDevicesToDirectoryModal
      @register="registerMoveModal"
      @success="handleMoveDevicesSuccess"
    />
  </div>
</template>

<script lang="ts" setup>
import { ref, onMounted, computed } from 'vue';
import { useMessage } from '@/hooks/web/useMessage';
import { useModal } from '@/components/Modal';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { BasicTree, type TreeItem } from '@/components/Tree';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { Tag as ATag, Input as AInput, Space } from 'ant-design-vue';
import {
  deleteDirectory,
  getStreamStatus,
  moveDeviceToDirectory,
  refreshDevices,
  syncGb28181Devices,
  type DeviceDirectory,
  type DeviceInfo,
  type MonitorTreeDirectoryNode,
  type StreamStatusResponse,
} from '@/api/device/camera';
import { getDeviceChannels } from '@/api/device/gb28181';
import type { TreeProps } from 'ant-design-vue';
import DirectoryModal from './DirectoryModal.vue';
import DirectoryJsonModal from './DirectoryJsonModal.vue';
import MoveDevicesToDirectoryModal from './MoveDevicesToDirectoryModal.vue';
import {
  formatCameraDeviceLabel,
  hasCopyableDeviceIp,
  hasCopyableDeviceModel,
  hasCopyableManufacturer,
  isNvrChannelDevice,
} from '@/views/camera/utils/deviceLabel';
import { isGb28181SipListRow } from '@/views/camera/utils/gb28181DeviceGroup';
import { buildDirectoryDeviceTableRows } from '@/views/camera/utils/nvrDeviceGroup';
import { collectWvpGbChannelsForSync } from '@/views/camera/utils/wvpGbSync';
import {
  buildWvpChannelTreeNodes,
} from '@/views/camera/utils/gb28181Tree';
import { enrichWvpChannelTreeNodes } from '@/views/camera/utils/monitorGbDisplay';
import {
  collectMonitorTreeExpandedKeys,
  parseMonitorDirectoryId,
  withDirectoryTreeSelectable,
} from '@/views/camera/utils/monitorDeviceTree';
import { getCachedMonitorDirectoryTreeBundle } from '@/views/camera/utils/monitorDirectoryTreeCache';
import {
  buildDirectoryDevicesForTable,
  findMonitorDirectoryNode,
  invalidateMonitorDirectoryTreeCache,
  loadMonitorDirectoryTreeWithCache,
  mapMonitorTreeToDeviceDirectories,
  type MonitorDirectoryTreeBundle,
} from '@/views/camera/utils/monitorDirectoryTreeLoad';

const props = withDefaults(
  defineProps<{
    /** 嵌入分屏监控配置态时减少外边距 */
    embedded?: boolean;
  }>(),
  { embedded: false },
);

const { createMessage } = useMessage();
const [registerDirectoryModal, { openModal: openDirectoryModal }] = useModal();
const [registerJsonModal, { openModal: openJsonModal }] = useModal();
const [registerMoveModal, { openModal: openMoveModal }] = useModal();

const checkedKeys = ref<string[]>([]);
const checkedRows = ref<DeviceInfo[]>([]);

// 目录相关
const selectedDirectoryId = ref<number | null>(null);
const selectedDirectoryName = ref<string>('');
const directoryTree = ref<DeviceDirectory[]>([]);
const syncCamerasLoading = ref(false);
const treeLoading = ref(false);
/** 有缓存时后台静默刷新 */
const treeRefreshing = ref(false);
const monitorTreeRaw = ref<MonitorTreeDirectoryNode[]>([]);
const monitorTreeItems = ref<TreeItem[]>([]);
const monitorWvpDevices = ref<Record<string, any>[]>([]);
const treeSelectedKeys = ref<string[]>([]);
const treeExpandedKeys = ref<string[]>([]);

const selectedDirectoryIsDefault = computed(() => {
  if (selectedDirectoryId.value == null) return false;
  const dir = findMonitorDirectoryNode(monitorTreeRaw.value, selectedDirectoryId.value);
  return !!dir?.is_default;
});

// 设备流状态映射
const deviceStreamStatuses = ref<Record<string, string>>({});
/** 与 monitor-tree 一并缓存的 NVR 元数据 */
let cachedMonitorBundle: MonitorDirectoryTreeBundle | null = null;

// 查找默认分组（根级）
const findDefaultDirectory = (nodes: DeviceDirectory[]): DeviceDirectory | null => {
  for (const node of nodes) {
    if (node.is_default) return node;
    if (node.children?.length) {
      const found = findDefaultDirectory(node.children);
      if (found) return found;
    }
  }
  return nodes.find((n) => n.name === '默认分组') || null;
};

const onLoadGbDeviceChannels: TreeProps['loadData'] = (treeNode) => {
  return new Promise<void>((resolve) => {
    const key = String(treeNode?.key ?? treeNode?.eventKey ?? '');
    if (!key.startsWith('gb_dev_')) {
      resolve();
      return;
    }
    const sipDeviceId = key.slice('gb_dev_'.length);
    const dataRef = (treeNode.dataRef ?? treeNode) as TreeItem;
    if (dataRef?.children?.length) {
      resolve();
      return;
    }
    getDeviceChannels(sipDeviceId)
      .then((res) => {
        const list = res.data || res.list || [];
        dataRef.children = enrichWvpChannelTreeNodes(
          buildWvpChannelTreeNodes(list, sipDeviceId),
          monitorTreeItems.value,
        );
        dataRef.isLeaf = !dataRef.children?.length;
        monitorTreeItems.value = [...monitorTreeItems.value];
        if (!treeExpandedKeys.value.includes(key)) {
          treeExpandedKeys.value = [...treeExpandedKeys.value, key];
        }
        resolve();
      })
      .catch(() => resolve());
  });
};

function applyDirectorySelection(
  directoryId: number,
  directoryName: string,
  options?: { highlightInTree?: boolean },
) {
  selectedDirectoryId.value = directoryId;
  selectedDirectoryName.value = directoryName;
  checkedKeys.value = [];
  checkedRows.value = [];
  treeSelectedKeys.value = options?.highlightInTree === false ? [] : [`dir_${directoryId}`];
  reloadDeviceTable();
}

function handleMonitorTreeSelect(keys: string[]) {
  const key = keys[0];
  if (!key?.startsWith('dir_')) return;
  const dirId = parseMonitorDirectoryId(key);
  if (dirId == null) return;
  const dir = findMonitorDirectoryNode(monitorTreeRaw.value, dirId);
  if (!dir) return;
  applyDirectorySelection(dir.id, dir.name, { highlightInTree: true });
}

function applyMonitorBundle(bundle: MonitorDirectoryTreeBundle) {
  cachedMonitorBundle = bundle;
  monitorTreeRaw.value = bundle.rawTree;
  monitorTreeItems.value = withDirectoryTreeSelectable(bundle.treeItems);
  monitorWvpDevices.value = bundle.wvpDevices;
  directoryTree.value = mapMonitorTreeToDeviceDirectories(bundle.rawTree);
  treeExpandedKeys.value = collectMonitorTreeExpandedKeys(monitorTreeItems.value);
}

function afterMonitorBundleLoaded(bundle: MonitorDirectoryTreeBundle) {
  const defaultDir = findDefaultDirectory(directoryTree.value);
  const hadTreeHighlight = treeSelectedKeys.value.some((k) => k.startsWith('dir_'));

  if (!selectedDirectoryId.value) {
    if (defaultDir) {
      applyDirectorySelection(defaultDir.id, defaultDir.name, { highlightInTree: false });
    }
    return;
  }

  const still = findMonitorDirectoryNode(bundle.rawTree, selectedDirectoryId.value);
  if (still) {
    selectedDirectoryName.value = still.name;
    treeSelectedKeys.value = hadTreeHighlight ? [`dir_${still.id}`] : [];
    reloadDeviceTable();
  } else if (defaultDir) {
    applyDirectorySelection(defaultDir.id, defaultDir.name, { highlightInTree: false });
  }
}

/** 与分屏监控一致：缓存优先 + 后台刷新 */
const loadDirectoryList = async (options?: { force?: boolean }) => {
  const hasCache =
    !options?.force && !!getCachedMonitorDirectoryTreeBundle()?.treeItems?.length;
  if (!hasCache) treeLoading.value = true;

  await loadMonitorDirectoryTreeWithCache({
    force: options?.force,
    skipSync: true,
    onBundle: (bundle) => {
      applyMonitorBundle(bundle);
      if (!selectedDirectoryId.value) {
        afterMonitorBundleLoaded(bundle);
      } else {
        reloadDeviceTable();
      }
    },
    onError: (error) => {
      console.error('加载设备目录树失败', error);
      if (!monitorTreeItems.value.length) {
        directoryTree.value = [];
        monitorTreeItems.value = [];
        monitorTreeRaw.value = [];
      }
      treeLoading.value = false;
    },
    onRefreshingChange: (v) => {
      treeRefreshing.value = v;
      if (!hasCache && !v) treeLoading.value = false;
    },
  });
  if (!hasCache) treeLoading.value = false;
};

/** 仅刷新目录树（不触发国标全量同步，与分屏监控左侧「刷新」区分） */
function handleRefreshTree() {
  loadDirectoryList({ force: true });
}

function findDirectoryMeta(directoryId: number, nodes: DeviceDirectory[] = directoryTree.value): DeviceDirectory | null {
  for (const node of nodes) {
    if (node.id === directoryId) return node;
    if (node.children?.length) {
      const found = findDirectoryMeta(directoryId, node.children);
      if (found) return found;
    }
  }
  return null;
}

const handleEditSelectedDirectory = () => {
  if (selectedDirectoryId.value == null) return;
  const record = findDirectoryMeta(selectedDirectoryId.value);
  if (record) handleEditDirectory(record);
};

const handleDeleteSelectedDirectory = () => {
  if (selectedDirectoryId.value == null) return;
  const record = findDirectoryMeta(selectedDirectoryId.value);
  if (record) handleDeleteDirectory(record);
};

// 编辑目录
const handleEditDirectory = (directory: DeviceDirectory) => {
  openDirectoryModal(true, {
    type: 'edit',
    record: directory,
  });
};

// 删除目录
const handleDeleteDirectory = async (directory: DeviceDirectory) => {
  try {
    const response = await deleteDirectory(directory.id);
    const result = response.code !== undefined ? response : { code: 0, msg: '删除成功' };
    if (result.code === 0) {
      createMessage.success('删除成功');
      invalidateMonitorDirectoryTreeCache();
      loadDirectoryList({ force: true });
      // 如果删除的是当前选中的目录，清空选择
      if (selectedDirectoryId.value === directory.id) {
        selectedDirectoryId.value = null;
        selectedDirectoryName.value = '';
        treeSelectedKeys.value = [];
        reloadDeviceTable();
      }
    } else {
      createMessage.error(result.msg || '删除失败');
    }
  } catch (error) {
    console.error('删除目录失败', error);
    createMessage.error('删除失败');
  }
};

// 获取设备表格列配置
const getDeviceColumns = () => {
  return [
    {
      title: '设备ID',
      dataIndex: 'id',
      width: 120,
    },
    {
      title: '设备名称',
      dataIndex: 'name',
      width: 120,
    },
    {
      title: '设备型号',
      dataIndex: 'model',
      width: 120,
    },
    {
      title: '在线状态',
      dataIndex: 'online',
      width: 100,
    },
    {
      title: '制造商',
      dataIndex: 'manufacturer',
      width: 90,
    },
    {
      title: 'IP地址',
      dataIndex: 'ip',
      width: 120,
    },
    {
      title: '端口',
      dataIndex: 'port',
      width: 80,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 140,
      fixed: 'right',
    },
  ];
};

// 设备表格配置
const [registerTable, { reload: reloadDeviceTable }] = useTable({
  title: '设备列表',
  api: async (params) => {
    if (!selectedDirectoryId.value) {
      return { data: [], total: 0 };
    }

    try {
      const dirNode = findMonitorDirectoryNode(monitorTreeRaw.value, selectedDirectoryId.value);
      if (!dirNode) {
        return { data: [], total: 0 };
      }

      const nvrs = cachedMonitorBundle?.nvrs ?? [];
      let filteredData = buildDirectoryDeviceTableRows(
        buildDirectoryDevicesForTable(dirNode, monitorWvpDevices.value),
        nvrs,
      );
        
        if (params.name) {
          filteredData = filteredData.filter((device: DeviceInfo) => 
            device.name && device.name.toLowerCase().includes(params.name.toLowerCase())
          );
        }
        
        if (params.online !== undefined && params.online !== '') {
          filteredData = filteredData.filter((device: DeviceInfo) => 
            device.online === params.online
          );
        }
        
        if (params.model) {
          filteredData = filteredData.filter((device: DeviceInfo) => 
            device.model && device.model.toLowerCase().includes(params.model.toLowerCase())
          );
        }
        
        // 初始化设备流状态
        const devicesWithStatus = filteredData.map((device: DeviceInfo) => {
          if (!deviceStreamStatuses.value[device.id]) {
            deviceStreamStatuses.value[device.id] = 'unknown';
          }
          return {
            ...device,
            stream_status: deviceStreamStatuses.value[device.id] || 'unknown',
          };
        });
        
        // 检查设备流状态
        // 已禁用自动检查设备流状态
        // checkAllDevicesStreamStatus(filteredData);
        
        const pageNo = params.pageNo || 1;
        const pageSize = params.pageSize || 10;
        const start = (pageNo - 1) * pageSize;
        const pageData = devicesWithStatus.slice(start, start + pageSize);

        return {
          data: pageData,
          total: devicesWithStatus.length,
        };
    } catch (error) {
      console.error('加载设备列表失败', error);
      return { data: [], total: 0 };
    }
  },
  fetchSetting: {
    listField: 'data',
    totalField: 'total',
  },
  columns: getDeviceColumns(),
  useSearchForm: true,
  formConfig: {
    labelWidth: 80,
    baseColProps: { span: 6 },
    actionColOptions: {
      span: 6,
      style: { textAlign: 'right' }
    },
    schemas: [
      {
        field: 'name',
        label: '设备名称',
        component: 'Input',
        componentProps: {
          placeholder: '请输入设备名称',
        },
      },
      {
        field: 'online',
        label: '在线状态',
        component: 'Select',
        componentProps: {
          placeholder: '请选择在线状态',
          allowClear: true,
          options: [
            { label: '在线', value: true },
            { label: '离线', value: false },
          ],
        },
      },
      {
        field: 'model',
        label: '设备型号',
        component: 'Input',
        componentProps: {
          placeholder: '请输入设备型号',
        },
      },
    ],
  },
  showTableSetting: true,
  pagination: true,
  rowKey: 'id',
  isTreeTable: true,
  defaultExpandAllRows: false,
  canResize: true,
  rowSelection: {
    type: 'checkbox',
    // 勿传 selectedRowKeys：与 useTable 内部 watch 会形成 onChange 死循环导致页面卡死
    onChange: (keys: string[], rows: DeviceInfo[]) => {
      const nextKeys = keys.filter((k) => !String(k).startsWith('nvr_group_'));
      const nextRows = rows.filter((r) => !(r as DeviceInfo & { _isNvrGroup?: boolean })._isNvrGroup);
      if (
        nextKeys.length === checkedKeys.value.length &&
        nextKeys.every((k, i) => k === checkedKeys.value[i])
      ) {
        return;
      }
      checkedKeys.value = nextKeys;
      checkedRows.value = nextRows;
    },
    getCheckboxProps: (record: DeviceInfo & { _isNvrGroup?: boolean }) => ({
      disabled:
        !!record._isNvrGroup ||
        isNvrChannelDevice(record) ||
        isGb28181SipListRow(record),
    }),
  },
});

// 获取流状态文本
const getStreamStatusText = (status: string) => {
  const statusMap: Record<string, string> = {
    'running': '运行中',
    'stopped': '已停止',
    'error': '错误',
    'unknown': '未知'
  };
  return statusMap[status] || status || '未知';
};

// 获取流状态颜色
const getStreamStatusColor = (status: string) => {
  const colorMap: Record<string, string> = {
    'running': 'green',
    'stopped': 'red',
    'error': 'orange',
    'unknown': 'default'
  };
  return colorMap[status] || 'default';
};

// 安全获取设备流状态
const getDeviceStreamStatus = (deviceId: string) => {
  if (!deviceStreamStatuses.value || !deviceStreamStatuses.value[deviceId]) {
    return 'unknown';
  }
  return deviceStreamStatuses.value[deviceId];
};

// 检查单个设备的流状态
const checkDeviceStreamStatus = async (deviceId: string) => {
  try {
    if (!deviceStreamStatuses.value) {
      deviceStreamStatuses.value = {};
    }
    const response: StreamStatusResponse = await getStreamStatus(deviceId);
    if (response.code === 0) {
      deviceStreamStatuses.value[deviceId] = response.data.status;
    } else {
      deviceStreamStatuses.value[deviceId] = 'error';
    }
  } catch (error) {
    console.error(`检查设备 ${deviceId} 流状态失败`, error);
    if (!deviceStreamStatuses.value) {
      deviceStreamStatuses.value = {};
    }
    deviceStreamStatuses.value[deviceId] = 'error';
  }
};

// 检查所有设备的流状态
const checkAllDevicesStreamStatus = async (devices: DeviceInfo[]) => {
  try {
    const deviceIds = devices.map(device => device.id);
    for (const deviceId of deviceIds) {
      await checkDeviceStreamStatus(deviceId);
    }
  } catch (error) {
    console.error('检查设备流状态失败', error);
  }
};

const openMoveDevicesModal = (devices: DeviceInfo[]) => {
  if (!devices.length) {
    createMessage.warning('请先选择摄像头');
    return;
  }
  openMoveModal(true, {
    deviceIds: devices.map((d) => d.id),
  });
};

const handleBatchMoveToDirectory = () => {
  if (!selectedDirectoryId.value) {
    createMessage.warning('请先选择目录');
    return;
  }
  const movable = checkedRows.value.filter((r) => !isNvrChannelDevice(r));
  if (!movable.length) {
    createMessage.warning('请选择可移动的摄像头（NVR 挂载通道请通过 NVR 行批量移动）');
    return;
  }
  openMoveDevicesModal(movable);
};

const handleMoveToDirectory = (record: DeviceInfo) => {
  openMoveDevicesModal([record]);
};

const handleMoveDevicesSuccess = () => {
  checkedKeys.value = [];
  checkedRows.value = [];
  invalidateMonitorDirectoryTreeCache();
  loadDirectoryList({ force: true });
  if (selectedDirectoryId.value) {
    reloadDeviceTable();
  }
};

// 获取表格操作按钮
const getTableActions = (record: DeviceInfo & { _isNvrGroup?: boolean; children?: DeviceInfo[] }) => {
  if (record._isNvrGroup) {
    const channels = record.children || [];
    if (!channels.length) return [];
    return [
      {
        icon: 'ant-design:folder-open-outlined',
        tooltip: '移动 NVR 下全部通道到目录',
        onClick: () => openMoveDevicesModal(channels),
      },
      {
        icon: 'ant-design:rollback-outlined',
        tooltip: '移回默认分组',
        popConfirm: {
          title: '确定将 NVR 下全部通道移回默认分组？',
          confirm: () => handleUnbindNvrGroupDirectory(channels),
        },
      },
    ];
  }

  const actions: Array<Record<string, unknown>> = [];

  if (!props.embedded) {
    actions.push({
      icon: 'octicon:play-16',
      tooltip: '播放RTMP流',
      onClick: () => handlePlay(record),
    });
  }

  if (!isNvrChannelDevice(record) && !isGb28181SipListRow(record)) {
    actions.push(
      {
        icon: 'ant-design:folder-open-outlined',
        tooltip: '移动到目录',
        onClick: () => handleMoveToDirectory(record),
      },
      {
        icon: 'ant-design:rollback-outlined',
        tooltip: '移回默认分组',
        popConfirm: {
          title: '确定将此设备移回默认分组？',
          confirm: () => handleUnbindDirectory(record),
        },
      },
    );
  }

  return actions;
};

// 播放
const handlePlay = (record: DeviceInfo) => {
  emit('play', record);
};

// NVR 下全部通道移回默认分组
const handleUnbindNvrGroupDirectory = async (channels: DeviceInfo[]) => {
  if (!channels.length) return;
  try {
    createMessage.loading({ content: '正在移回默认分组...', key: 'unbind-nvr' });
    const results = await Promise.all(
      channels.map((ch) => moveDeviceToDirectory(ch.id, 0)),
    );
    const failed = results.filter((r) => {
      const result = (r as { code?: number }).code !== undefined ? r : { code: 0 };
      return result.code !== 0;
    });
    if (failed.length) {
      createMessage.error({
        content: `${failed.length} 个通道移回失败`,
        key: 'unbind-nvr',
      });
    } else {
      createMessage.success({
        content: `已将 ${channels.length} 个通道移回默认分组`,
        key: 'unbind-nvr',
      });
      invalidateMonitorDirectoryTreeCache();
      loadDirectoryList({ force: true });
    }
  } catch (error) {
    console.error('NVR 通道移回默认分组失败', error);
    createMessage.error({ content: '移回默认分组失败', key: 'unbind-nvr' });
  }
};

// 移回默认分组
const handleUnbindDirectory = async (record: DeviceInfo) => {
  try {
    createMessage.loading({ content: '正在移回默认分组...', key: 'unbind' });
    const response = await moveDeviceToDirectory(record.id, 0);
    const result = response.code !== undefined ? response : { code: 0, msg: '已移回默认分组' };
    if (result.code === 0) {
      createMessage.success({ content: '已移回默认分组', key: 'unbind' });
      invalidateMonitorDirectoryTreeCache();
      await loadDirectoryList({ force: true });
    } else {
      createMessage.error({ content: result.msg || '解除关联失败', key: 'unbind' });
    }
  } catch (error) {
    console.error('解除关联失败', error);
    createMessage.error({ content: '解除关联失败', key: 'unbind' });
  }
};

// 复制功能
async function handleCopy(text: string) {
  if (!text || text === '-') {
    return;
  }
  try {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(text);
    } else {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      document.body.removeChild(textarea);
    }
    createMessage.success('复制成功');
  } catch (error) {
    console.error('复制失败', error);
    createMessage.error('复制失败');
  }
}

/** 同步直连（ONVIF 刷新）与国标（WVP 通道入库）摄像头 */
const handleSyncCameras = async () => {
  const parts: string[] = [];
  try {
    syncCamerasLoading.value = true;
    createMessage.loading({ content: '正在同步摄像头...', key: 'sync-cameras' });

    try {
      await refreshDevices();
      parts.push('直连设备已刷新');
    } catch (error) {
      console.error('刷新直连设备失败', error);
      parts.push('直连设备刷新失败');
    }

    try {
      const { channels, wvpDeviceCount } = await collectWvpGbChannelsForSync();
      const payload = await syncGb28181Devices(channels);
      const created = payload?.created ?? 0;
      const total = payload?.total_gb_devices ?? 0;
      const wvpCount = payload?.wvp_device_count ?? wvpDeviceCount;
      const channelsSeen = payload?.channels_seen ?? channels.length;
      const upsertErrors = payload?.upsert_errors ?? [];
      if (upsertErrors.length) {
        parts.push(`入库失败：${upsertErrors[0]}`);
      } else if (wvpDeviceCount > 0 && channels.length === 0) {
        parts.push(`WVP 有 ${wvpDeviceCount} 个国标设备，但未解析到通道`);
      } else if (wvpCount > 0 && total === 0) {
        parts.push(
          `WVP 有 ${wvpCount} 个国标设备、${channelsSeen} 个通道，但未入库（请检查 VIDEO 服务与数据库）`,
        );
      } else if (wvpCount === 0) {
        parts.push('未从 WVP 拉取到国标设备，请检查 dev-api/gb28181 网关与 WVP 服务');
      } else {
        parts.push(`国标新增 ${created} 个，共 ${total} 个`);
      }
    } catch (error: any) {
      console.error('同步国标设备失败', error);
      const errMsg = error?.message || error?.msg || '';
      parts.push(errMsg ? `国标同步失败：${errMsg}` : '国标同步失败，请检查 WVP 服务与 GATEWAY_URL');
    }

    createMessage.success({ content: parts.join('；'), key: 'sync-cameras' });
    invalidateMonitorDirectoryTreeCache();
    cachedMonitorBundle = null;
    await loadDirectoryList({ force: true });
    if (selectedDirectoryId.value) {
      reloadDeviceTable();
    }
  } finally {
    syncCamerasLoading.value = false;
  }
};

// 添加目录
const handleAddDirectory = () => {
  openDirectoryModal(true, {
    type: 'create',
  });
};

// JSON 编辑设备目录
const handleOpenJsonEditor = () => {
  openJsonModal(true, {});
};

// 目录操作成功回调
const handleDirectorySuccess = () => {
  invalidateMonitorDirectoryTreeCache();
  cachedMonitorBundle = null;
  loadDirectoryList({ force: true });
  if (selectedDirectoryId.value) {
    reloadDeviceTable();
  }
};

// 暴露事件
const emit = defineEmits(['view', 'edit', 'delete', 'play', 'toggleStream']);

// 暴露刷新方法
defineExpose({
  /** 缓存优先刷新（Tab 切回、父级 refresh 调用） */
  refresh: () => loadDirectoryList(),
  /** 强制拉取最新目录树 */
  forceRefreshTree: () => loadDirectoryList({ force: true }),
});

// 组件挂载时加载目录列表
onMounted(() => {
  loadDirectoryList();
});
</script>

<style lang="less" scoped>
.directory-manage-wrapper {
  padding: 16px;
  background: #f0f2f5;
  min-height: calc(100vh - 200px);
  height: 100%;

  &.is-embedded {
    padding: 0;
    background: transparent;
    min-height: calc(100vh - 260px);
  }
}

.directory-layout {
  display: flex;
  gap: 16px;
  height: 100%;
}

.directory-sidebar {
  width: 350px;
  flex-shrink: 0;
  background: #fff;
  border-radius: 4px;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  .sidebar-tree {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    padding: 16px;
    
    .tree-header {
      margin-bottom: 16px;
      overflow: visible;

      .tree-header-button {
        display: flex;
        align-items: center;
        justify-content: space-between;
        width: 100%;
        gap: 8px;
      }
    }
    
    .tree-content {
      flex: 1;
      overflow: hidden;
      min-height: 0;
      display: flex;
      flex-direction: column;

      .tree-dir-actions {
        flex-shrink: 0;
        display: flex;
        gap: 4px;
        margin-bottom: 8px;
        padding-bottom: 8px;
        border-bottom: 1px solid #f0f0f0;
      }

      :deep(.directory-monitor-tree) {
        flex: 1;
        min-height: 0;
        height: 100%;
        overflow: hidden;
        display: flex;
        flex-direction: column;

        .ant-spin-nested-loading,
        .ant-spin-container {
          flex: 1;
          min-height: 0;
          height: 100%;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }

        .scroll-container {
          flex: 1;
          min-height: 0;
        }

        .ant-tree-switcher {
          width: 16px;
          margin-inline-end: 2px;
        }

        .ant-tree-switcher-noop {
          width: 8px;
        }

        .ant-tree-node-content-wrapper {
          padding-inline: 2px 6px;
          min-height: 26px;
          line-height: 26px;
        }

        .ant-tree-title,
        [class*='-tree__title'] {
          padding-left: 0 !important;
          padding-right: 8px;
        }
      }
    }
  }
}

.device-content {
  flex: 1;
  background: #fff;
  border-radius: 4px;
  padding: 16px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.device-button-group {
  margin-bottom: 16px;
  display: flex;
  justify-content: flex-end;

  :deep(.ant-space) {
    flex-wrap: wrap;
    justify-content: flex-end;
  }
}
</style>

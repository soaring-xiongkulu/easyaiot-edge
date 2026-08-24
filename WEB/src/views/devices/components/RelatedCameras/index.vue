<template>
  <div class="ops-page related-cameras">
    <div class="ops-header">
      <div class="ops-header-main">
        <div class="ops-header-meta">
          <span class="ops-meta-item">已关联 <strong>{{ pagination.total }}</strong></span>
          <span class="ops-meta-item">设备 <strong>{{ deviceName || '--' }}</strong></span>
        </div>
      </div>
      <div class="ops-header-actions">
        <Button @click="loadBoundList" :loading="loading" preIcon="ant-design:reload-outlined">
          刷新
        </Button>
        <Button type="primary" @click="openBindModal" preIcon="ant-design:video-camera-add-outlined">
          关联摄像头
        </Button>
        <Popconfirm
          title="确认解绑选中的摄像头？"
          :disabled="!selectedRowKeys.length"
          @confirm="handleUnbind"
        >
          <Button
            danger
            :disabled="!selectedRowKeys.length"
            :loading="unbinding"
            preIcon="ant-design:disconnect-outlined"
          >
            批量解绑
          </Button>
        </Popconfirm>
      </div>
    </div>

    <div class="ops-surface">
      <div class="ops-surface-head">
        <div class="ops-surface-title">
          已关联列表
          <span class="ops-count">({{ pagination.total }})</span>
        </div>
      </div>
      <div class="ops-surface-body">
        <Table
          rowKey="id"
          size="middle"
          :loading="loading"
          :columns="columns"
          :dataSource="boundList"
          :rowSelection="{ selectedRowKeys, onChange: onSelectChange }"
          :pagination="false"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'online'">
              <Tag :color="record.online ? 'green' : 'red'">
                {{ record.online ? '在线' : '离线' }}
              </Tag>
            </template>
            <template v-else-if="column.key === 'action'">
              <Popconfirm title="确认解绑该摄像头？" @confirm="handleUnbindOne(record)">
                <a class="danger-link">解绑</a>
              </Popconfirm>
            </template>
          </template>
        </Table>
        <div v-if="!loading && boundList.length === 0" class="ops-empty">
          <Icon icon="ant-design:video-camera-outlined" class="ops-empty-icon" />
          <p>暂无关联摄像头</p>
          <p class="ops-empty-hint">点击「关联摄像头」，从设备目录中选择摄像头进行绑定</p>
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

    <Modal
      v-model:visible="bindVisible"
      :width="'90vw'"
      :style="{ maxWidth: '1440px' }"
      wrap-class-name="device-bind-modal"
      :body-style="{ padding: 0, flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden' }"
      :confirmLoading="binding"
      destroy-on-close
      @cancel="closeBindModal"
    >
      <template #title>
        <div class="bind-modal-title">
          <span class="bind-modal-title-main">关联摄像头</span>
          <span class="bind-modal-title-sub">从设备目录中选择摄像头，关联到当前 IoT 设备</span>
        </div>
      </template>

      <div class="bind-modal-shell">
        <div class="bind-modal-context">
          <div class="bind-modal-context-left">
            <span class="bind-modal-context-item">
              当前设备<strong>{{ deviceName || '--' }}</strong>
            </span>
            <span v-if="selectedDirectoryName" class="bind-modal-context-badge">
              {{ selectedDirectoryName }}
            </span>
          </div>
          <span class="bind-modal-context-item">
            目录内候选<strong>{{ bindPagination.total }}</strong>
          </span>
        </div>

        <div class="bind-modal-layout">
          <div class="bind-modal-sidebar">
            <div class="bind-modal-sidebar-title">设备目录</div>
            <Spin :spinning="treeLoading">
              <BasicTree
                search
                :showIcon="true"
                :indent="12"
                v-model:selectedKeys="treeSelectedKeys"
                :expanded-keys="treeExpandedKeys"
                :tree-data="directoryTreeItems"
                :field-names="{ key: 'key', title: 'title' }"
                class="bind-modal-sidebar-tree"
                @select="handleDirectorySelect"
                @update:expanded-keys="treeExpandedKeys = $event"
              />
            </Spin>
          </div>

          <div class="bind-modal-content">
            <div class="bind-modal-toolbar">
              <Input
                v-model:value="bindKeyword"
                allowClear
                class="bind-modal-search"
                placeholder="搜索摄像头名称，回车查询"
                @pressEnter="loadDirectoryDevices"
              />
              <Button
                type="primary"
                @click="loadDirectoryDevices"
                :loading="bindLoading"
                preIcon="ant-design:search-outlined"
              >
                查询
              </Button>
            </div>

            <div class="bind-modal-table-wrap">
              <Table
                rowKey="id"
                size="middle"
                :loading="bindLoading"
                :columns="bindColumns"
                :dataSource="candidateList"
                :rowSelection="{ selectedRowKeys: bindSelectedKeys, onChange: onBindSelectChange }"
                :pagination="false"
              >
                <template #bodyCell="{ column, record }">
                  <template v-if="column.key === 'online'">
                    <Tag :color="record.online ? 'green' : 'red'">
                      {{ record.online ? '在线' : '离线' }}
                    </Tag>
                  </template>
                </template>
              </Table>
              <div v-if="!bindLoading && selectedDirectoryId && candidateList.length === 0" class="bind-modal-empty">
                <Icon icon="ant-design:video-camera-outlined" class="bind-modal-empty-icon" />
                <p>当前目录下暂无可关联的摄像头</p>
                <p class="bind-modal-empty-hint">可能已被其他设备关联，或目录下暂无设备</p>
              </div>
              <div v-if="!bindLoading && !selectedDirectoryId" class="bind-modal-empty">
                <Icon icon="ant-design:folder-open-outlined" class="bind-modal-empty-icon" />
                <p>请先在左侧选择设备目录</p>
              </div>
            </div>

            <div v-if="bindPagination.total > 0" class="bind-modal-pagination">
              <Pagination
                v-model:current="bindPagination.current"
                v-model:pageSize="bindPagination.pageSize"
                :total="bindPagination.total"
                :showSizeChanger="true"
                :showTotal="(total) => `共 ${total} 条`"
                @change="handleBindPageChange"
                @showSizeChange="handleBindPageChange"
              />
            </div>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="bind-modal-footer">
          <span class="bind-modal-footer-extra">
            已选择 <strong>{{ bindSelectedKeys.length }}</strong> 个摄像头
          </span>
          <Space :size="12">
            <Button @click="closeBindModal">取消</Button>
            <Button type="primary" :loading="binding" @click="handleBind">确认关联</Button>
          </Space>
        </div>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { Input, Modal, Pagination, Popconfirm, Space, Spin, Table, Tag } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { BasicTree, type TreeItem } from '@/components/Tree';
import { useMessage } from '@/hooks/web/useMessage';
import {
  associateDeviceCameras,
  disassociateDeviceCameras,
  getBoundCameraIds,
  getDeviceCameraLinks,
} from '@/api/device/devices';
import {
  getDeviceInfo,
  getDirectoryDevices,
  getDirectoryList,
  type DeviceDirectory,
  type DeviceInfo,
} from '@/api/device/camera';
import { formatCameraDeviceLabel } from '@/views/camera/utils/deviceLabel';

defineOptions({ name: 'DeviceRelatedCameras' });

const props = defineProps<{
  iotDeviceId: string | number;
  deviceName?: string;
}>();

const { createMessage } = useMessage();

const loading = ref(false);
const unbinding = ref(false);
const binding = ref(false);
const bindLoading = ref(false);
const treeLoading = ref(false);
const bindVisible = ref(false);
const bindKeyword = ref('');

const boundList = ref<any[]>([]);
const candidateList = ref<DeviceInfo[]>([]);
const selectedRowKeys = ref<Array<string | number>>([]);
const bindSelectedKeys = ref<Array<string | number>>([]);
const boundCameraIdSet = ref<Set<string>>(new Set());

const directoryTreeRaw = ref<DeviceDirectory[]>([]);
const directoryTreeItems = ref<TreeItem[]>([]);
const treeSelectedKeys = ref<string[]>([]);
const treeExpandedKeys = ref<string[]>([]);
const selectedDirectoryId = ref<number | null>(null);
const selectedDirectoryName = ref('');

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
});

const bindPagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
});

const iotDeviceId = computed(() => props.iotDeviceId);

const columns = [
  { title: '摄像头名称', dataIndex: 'cameraName', key: 'cameraName', ellipsis: true },
  { title: '摄像头 ID', dataIndex: 'cameraDeviceId', key: 'cameraDeviceId', ellipsis: true },
  { title: 'IP', dataIndex: 'ip', key: 'ip', width: 130 },
  { title: '厂商', dataIndex: 'manufacturer', key: 'manufacturer', ellipsis: true, width: 120 },
  { title: '在线状态', dataIndex: 'online', key: 'online', width: 90 },
  { title: '关联时间', dataIndex: 'createTime', key: 'createTime', width: 170 },
  { title: '操作', key: 'action', width: 80 },
];

const bindColumns = [
  { title: '摄像头名称', dataIndex: 'name', key: 'name', ellipsis: true },
  { title: '摄像头 ID', dataIndex: 'id', key: 'id', ellipsis: true },
  { title: 'IP', dataIndex: 'ip', key: 'ip', width: 120 },
  { title: '在线状态', dataIndex: 'online', key: 'online', width: 80 },
];

function toDirectoryTreeItems(nodes: DeviceDirectory[]): TreeItem[] {
  return nodes.map((node) => ({
    key: String(node.id),
    title: `${node.name}${node.device_count != null ? ` (${node.device_count})` : ''}`,
    children: node.children?.length ? toDirectoryTreeItems(node.children) : undefined,
  }));
}

function collectExpandedKeys(nodes: DeviceDirectory[], depth = 0): string[] {
  const keys: string[] = [];
  for (const node of nodes) {
    if (depth < 2) {
      keys.push(String(node.id));
    }
    if (node.children?.length) {
      keys.push(...collectExpandedKeys(node.children, depth + 1));
    }
  }
  return keys;
}

function findDirectoryName(nodes: DeviceDirectory[], id: number): string {
  for (const node of nodes) {
    if (node.id === id) return node.name;
    if (node.children?.length) {
      const found = findDirectoryName(node.children, id);
      if (found) return found;
    }
  }
  return '';
}

function findDefaultDirectory(nodes: DeviceDirectory[]): DeviceDirectory | null {
  for (const node of nodes) {
    if (node.is_default) return node;
    if (node.children?.length) {
      const found = findDefaultDirectory(node.children);
      if (found) return found;
    }
  }
  return nodes.find((n) => n.name === '默认分组') || nodes[0] || null;
}

async function refreshBoundCameraIds() {
  try {
    const res = await getBoundCameraIds();
    const ids: string[] = Array.isArray(res) ? res : res?.data || [];
    boundCameraIdSet.value = new Set(ids.map(String));
  } catch (e) {
    console.error(e);
  }
}

async function enrichCameraInfo(cameraDeviceId: string) {
  try {
    const info = await getDeviceInfo(cameraDeviceId);
    const device = info?.data || info?.device || info;
    return device || null;
  } catch {
    return null;
  }
}

async function loadBoundList() {
  if (!iotDeviceId.value) {
    boundList.value = [];
    pagination.total = 0;
    return;
  }
  loading.value = true;
  try {
    const res = await getDeviceCameraLinks({
      iotDeviceId: iotDeviceId.value,
      pageNum: pagination.current,
      pageSize: pagination.pageSize,
    });
    const links = res?.data || res?.rows || [];
    pagination.total = res?.total || links.length;

    const enriched = await Promise.all(
      links.map(async (link: any) => {
        const camera = await enrichCameraInfo(link.cameraDeviceId);
        return {
          id: link.id,
          cameraDeviceId: link.cameraDeviceId,
          createTime: link.createTime,
          cameraName: camera ? formatCameraDeviceLabel(camera) : link.cameraDeviceId,
          ip: camera?.ip || '--',
          manufacturer: camera?.manufacturer || '--',
          online: !!camera?.online,
        };
      }),
    );
    boundList.value = enriched;
    selectedRowKeys.value = [];
  } catch (e) {
    console.error(e);
    createMessage.error('加载关联摄像头失败');
  } finally {
    loading.value = false;
  }
}

async function loadDirectoryTree() {
  treeLoading.value = true;
  try {
    const res = await getDirectoryList();
    const list: DeviceDirectory[] = res?.data || res || [];
    directoryTreeRaw.value = list;
    directoryTreeItems.value = toDirectoryTreeItems(list);
    treeExpandedKeys.value = collectExpandedKeys(list);

    const defaultDir = findDefaultDirectory(list);
    if (defaultDir) {
      selectedDirectoryId.value = defaultDir.id;
      selectedDirectoryName.value = defaultDir.name;
      treeSelectedKeys.value = [String(defaultDir.id)];
      bindPagination.current = 1;
      await loadDirectoryDevices();
    }
  } catch (e) {
    console.error(e);
    createMessage.error('加载设备目录失败');
  } finally {
    treeLoading.value = false;
  }
}

async function loadDirectoryDevices() {
  if (!selectedDirectoryId.value) {
    candidateList.value = [];
    bindPagination.total = 0;
    return;
  }
  bindLoading.value = true;
  try {
    const res = await getDirectoryDevices(selectedDirectoryId.value, {
      pageNo: bindPagination.current,
      pageSize: bindPagination.pageSize,
      search: bindKeyword.value || undefined,
    });
    const rows: DeviceInfo[] = Array.isArray(res?.data) ? res.data : [];
    const filtered = rows.filter((item) => !boundCameraIdSet.value.has(String(item.id)));
    candidateList.value = filtered;
    // total 需与过滤后可见条数对齐，避免「共 N 条」与空表矛盾
    const rawTotal = res?.total ?? rows.length;
    const filteredOut = rows.length - filtered.length;
    bindPagination.total = Math.max(0, rawTotal - filteredOut);
    bindSelectedKeys.value = [];
  } catch (e) {
    console.error(e);
    createMessage.error('加载目录摄像头失败');
  } finally {
    bindLoading.value = false;
  }
}

function handleDirectorySelect(keys: string[]) {
  if (!keys.length) return;
  const id = Number(keys[0]);
  if (Number.isNaN(id)) return;
  selectedDirectoryId.value = id;
  selectedDirectoryName.value = findDirectoryName(directoryTreeRaw.value, id);
  bindPagination.current = 1;
  loadDirectoryDevices();
}

const onSelectChange = (keys: Array<string | number>) => {
  selectedRowKeys.value = keys;
};

const onBindSelectChange = (keys: Array<string | number>) => {
  bindSelectedKeys.value = keys;
};

function handlePageChange(page: number, pageSize: number) {
  pagination.current = page;
  pagination.pageSize = pageSize;
  loadBoundList();
}

function handleBindPageChange(page: number, pageSize: number) {
  bindPagination.current = page;
  bindPagination.pageSize = pageSize;
  loadDirectoryDevices();
}

async function openBindModal() {
  bindVisible.value = true;
  bindSelectedKeys.value = [];
  bindKeyword.value = '';
  bindPagination.current = 1;
  await refreshBoundCameraIds();
  await loadDirectoryTree();
}

function closeBindModal() {
  bindVisible.value = false;
  bindSelectedKeys.value = [];
}

async function handleBind() {
  if (!bindSelectedKeys.value.length) {
    createMessage.warning('请选择要关联的摄像头');
    return;
  }
  if (!iotDeviceId.value) {
    createMessage.error('IoT 设备 ID 缺失');
    return;
  }
  binding.value = true;
  try {
    await associateDeviceCameras(
      iotDeviceId.value,
      bindSelectedKeys.value.map(String),
    );
    createMessage.success('关联成功');
    closeBindModal();
    await refreshBoundCameraIds();
    await loadBoundList();
  } catch (e: any) {
    console.error(e);
    createMessage.error(e?.message || '关联失败');
  } finally {
    binding.value = false;
  }
}

async function handleUnbind() {
  if (!selectedRowKeys.value.length) return;
  unbinding.value = true;
  try {
    await disassociateDeviceCameras(selectedRowKeys.value);
    createMessage.success('解绑成功');
    await refreshBoundCameraIds();
    await loadBoundList();
  } catch (e: any) {
    console.error(e);
    createMessage.error(e?.message || '解绑失败');
  } finally {
    unbinding.value = false;
  }
}

async function handleUnbindOne(record: any) {
  try {
    await disassociateDeviceCameras([record.id]);
    createMessage.success('解绑成功');
    await refreshBoundCameraIds();
    await loadBoundList();
  } catch (e: any) {
    console.error(e);
    createMessage.error(e?.message || '解绑失败');
  }
}

watch(
  () => props.iotDeviceId,
  (val) => {
    if (val) {
      pagination.current = 1;
      loadBoundList();
    }
  },
);

onMounted(() => {
  loadBoundList();
});
</script>

<style lang="less" scoped>
@import '../styles/device-ops.less';

.danger-link {
  color: #ff4d4f;
}

.table-pagination {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}
</style>

<style lang="less">
@import '../styles/device-bind-modal.less';
</style>

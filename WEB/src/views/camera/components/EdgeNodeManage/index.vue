<template>
  <div id="edge-node-manage">
    <div class="edge-feature-banner">
      <div class="edge-feature-banner__copy">
        <div class="edge-feature-banner__eyebrow">EasyAIoT 无限联邦边缘集群模式</div>
        <div class="edge-feature-banner__title">内存约 512MB · Ceph 边缘 0 硬盘 · 一行命令智能化 · 汇聚上云</div>
        <div class="edge-feature-banner__desc">
          把普通开发板接入联邦边缘集群：现场跑推理，业务对象写共享 Ceph（边缘 0 硬盘占用），告警与事件自动汇聚上云，节点可无限横向扩容。
        </div>
      </div>
      <Button type="primary" preIcon="ant-design:compass-outlined" @click="openGuide()">
        一行命令接入
      </Button>
    </div>

    <!-- 表格模式 -->
    <BasicTable v-if="viewMode === 'table'" @register="registerTable">
      <template #toolbar>
        <div class="toolbar-buttons">
          <Button type="primary" preIcon="ant-design:compass-outlined" @click="openGuide()">
            接入指引
          </Button>
          <Button preIcon="ant-design:reload-outlined" @click="handleRefresh">刷新</Button>
          <Button @click="handleToggleViewMode" type="default">
            <template #icon>
              <SwapOutlined />
            </template>
            切换视图
          </Button>
        </div>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction :actions="getTableActions(record)" />
        </template>
      </template>
    </BasicTable>

    <!-- 卡片模式 -->
    <div v-else class="edge-node-card-list-wrapper p-2">
      <div class="p-4 bg-white" style="margin-bottom: 10px">
        <BasicForm @register="registerForm" @reset="handleSubmit" />
      </div>
      <div class="p-2 bg-white">
        <Spin :spinning="loading">
          <List
            :grid="{ gutter: 12, xs: 1, sm: 2, md: 3, lg: 4, xl: 4, xxl: 4 }"
            :data-source="nodeList"
            :pagination="paginationProp"
            :locale="{ emptyText: listEmpty }"
          >
            <template #header>
              <div class="card-list-header">
                <div class="card-list-header-left">
                  <span class="card-list-title">边缘节点列表</span>
                  <span class="card-list-subtitle">无限联邦 · 512MB · Ceph 0 硬盘 · 汇聚上云</span>
                </div>
                <div style="display: flex; gap: 8px;">
                  <Button type="primary" preIcon="ant-design:compass-outlined" @click="openGuide()">
                    接入指引
                  </Button>
                  <Button preIcon="ant-design:reload-outlined" @click="handleRefresh">刷新</Button>
                  <Button @click="handleToggleViewMode" type="default">
                    <template #icon>
                      <SwapOutlined />
                    </template>
                    切换视图
                  </Button>
                </div>
              </div>
            </template>
            <template #renderItem="{ item }">
              <ListItem :class="isNodeOnline(item) ? 'task-item normal' : 'task-item error'">
                <div class="task-info">
                  <div class="status">{{ statusText(item.status) }}</div>
                  <div class="title o2" :title="item.name || item.host || String(item.id)">
                    {{ item.name || item.host || item.id }}
                  </div>
                  <div class="props">
                    <div class="flex" style="justify-content: space-between;">
                      <div class="prop">
                        <div class="label">主机</div>
                        <div class="value" :title="item.host">{{ item.host || '--' }}</div>
                      </div>
                      <div class="prop">
                        <div class="label">任务槽</div>
                        <div class="value">
                          {{ item.activeTaskCount ?? 0 }}/{{ item.maxTaskCount ?? '-' }}
                        </div>
                      </div>
                    </div>
                    <div class="flex" style="justify-content: space-between;">
                      <div class="prop">
                        <div class="label">算力负载</div>
                        <div class="value">
                          CPU {{ formatPct(item.cpuPercent) }} / MEM {{ formatPct(item.memPercent) }}
                        </div>
                      </div>
                      <div class="prop">
                        <div class="label">Ceph</div>
                        <div class="value">{{ item.cephMountReady ? '已挂载' : '未就绪' }}</div>
                      </div>
                    </div>
                    <div class="flex" style="justify-content: space-between;">
                      <div class="prop">
                        <div class="label">版本</div>
                        <div class="value">{{ item.agentVersion || '--' }}</div>
                      </div>
                      <div class="prop">
                        <div class="label">最近心跳</div>
                        <div class="value" :title="item.lastHeartbeatAt">
                          {{ item.lastHeartbeatAt || '--' }}
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="btns">
                    <div class="btn" @click="openGuide(item)" title="接入指引">
                      <Icon icon="ant-design:compass-outlined" :size="15" color="#3B82F6" />
                    </div>
                    <div class="btn" @click="openEdit(item)" title="编辑">
                      <Icon icon="ant-design:edit-filled" :size="15" color="#3B82F6" />
                    </div>
                    <div
                      v-if="item.enabled !== false"
                      class="btn"
                      @click="handleToggleEnabled(item, false)"
                      title="停用"
                    >
                      <Icon icon="ant-design:pause-circle-outlined" :size="15" color="#3B82F6" />
                    </div>
                    <div
                      v-else
                      class="btn"
                      @click="handleToggleEnabled(item, true)"
                      title="启用"
                    >
                      <Icon icon="ant-design:play-circle-outlined" :size="15" color="#3B82F6" />
                    </div>
                    <Popconfirm
                      title="确认删除该边缘节点管理记录？"
                      ok-text="是"
                      cancel-text="否"
                      @confirm="handleDelete(item)"
                    >
                      <div class="btn delete-btn" title="删除">
                        <Icon
                          icon="material-symbols:delete-outline-rounded"
                          :size="15"
                          color="#DC2626"
                        />
                      </div>
                    </Popconfirm>
                  </div>
                </div>
                <div class="task-img">
                  <img
                    :src="NODE_IMAGE"
                    alt=""
                    class="img"
                    @click="openGuide(item)"
                  />
                </div>
              </ListItem>
            </template>
          </List>
        </Spin>
      </div>
    </div>

    <EdgeSetupGuideDrawer @register="registerGuideDrawer" @success="handleSuccess" />

    <BasicModal
      v-model:open="editVisible"
      title="编辑边缘节点"
      :confirm-loading="saving"
      @ok="submitEdit"
      @cancel="editVisible = false"
    >
      <a-form layout="vertical" class="edit-form">
        <a-form-item label="名称">
          <a-input v-model:value="editForm.name" placeholder="边缘节点显示名称" />
        </a-form-item>
        <a-form-item label="最大任务数">
          <a-input-number
            v-model:value="editForm.maxTaskCount"
            :min="1"
            :max="64"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea v-model:value="editForm.remark" :rows="3" />
        </a-form-item>
      </a-form>
    </BasicModal>
  </div>
</template>

<script lang="ts" setup>
import { h, reactive, ref, onMounted } from 'vue';
import { SwapOutlined } from '@ant-design/icons-vue';
import {
  Form as AForm,
  FormItem as AFormItem,
  Input as AInput,
  InputNumber as AInputNumber,
  Textarea as ATextarea,
  Empty,
  List,
  Popconfirm,
  Spin,
} from 'ant-design-vue';
import { BasicForm, useForm } from '@/components/Form';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { BasicModal } from '@/components/Modal';
import { useDrawer } from '@/components/Drawer';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import {
  deleteEdgeNode,
  getEdgeNodePage,
  updateEdgeNode,
  type EdgeNodeVO,
} from '@/api/device/edge';
import NODE_COMPUTE_IMAGE from '@/assets/images/node/node-compute.svg';
import { formatPct, getBasicColumns, getFormConfig, statusText } from './Data';
import EdgeSetupGuideDrawer from './EdgeSetupGuideDrawer.vue';

defineOptions({ name: 'EdgeNodeManage' });

const ListItem = List.Item;
const NODE_IMAGE = NODE_COMPUTE_IMAGE;
const listEmpty = h(Empty, {
  image: Empty.PRESENTED_IMAGE_SIMPLE,
  description: '暂无边缘节点，点击「一行命令接入」将开发板加入联邦集群',
});
const { createMessage } = useMessage();

const viewMode = ref<'table' | 'card'>('card');
const nodeList = ref<EdgeNodeVO[]>([]);
const loading = ref(false);
const page = ref(1);
const pageSize = ref(8);
const total = ref(0);
const searchParams = ref<{
  name?: string;
  host?: string;
  status?: string;
}>({});

const editVisible = ref(false);
const saving = ref(false);
const editForm = reactive({
  id: 0,
  name: '',
  maxTaskCount: 1,
  remark: '',
});

const [registerGuideDrawer, { openDrawer: openGuideDrawer }] = useDrawer();

const isNodeOnline = (item: EdgeNodeVO) => item.status === 'online' && item.enabled !== false;

function openGuide(record?: EdgeNodeVO) {
  openGuideDrawer(true, record?.id ? { nodeId: record.id } : {});
}

const [registerTable, { reload }] = useTable({
  canResize: true,
  showIndexColumn: false,
  title: '边缘节点列表（无限联邦集群）',
  api: getEdgeNodePage,
  beforeFetch: (params) => ({
    pageNo: params.page,
    pageSize: params.pageSize,
    name: params.name || undefined,
    host: params.host || undefined,
    status: params.status || undefined,
  }),
  columns: getBasicColumns(),
  useSearchForm: true,
  showTableSetting: false,
  bordered: true,
  pagination: true,
  formConfig: getFormConfig(),
  fetchSetting: {
    listField: 'list',
    totalField: 'total',
  },
  rowKey: 'id',
});

function getTableActions(record: EdgeNodeVO) {
  const enabled = record.enabled !== false;
  return [
    {
      icon: 'ant-design:compass-outlined',
      tooltip: '接入指引',
      onClick: () => openGuide(record),
    },
    {
      icon: 'ant-design:edit-filled',
      tooltip: '编辑',
      onClick: () => openEdit(record),
    },
    {
      icon: enabled ? 'ant-design:pause-circle-outlined' : 'ant-design:play-circle-outlined',
      tooltip: enabled ? '停用' : '启用',
      onClick: () => handleToggleEnabled(record, !enabled),
    },
    {
      icon: 'material-symbols:delete-outline-rounded',
      tooltip: '删除',
      color: 'error' as const,
      popConfirm: {
        title: '确认删除该边缘节点管理记录？',
        confirm: () => handleDelete(record),
      },
    },
  ];
}

const handleToggleViewMode = () => {
  viewMode.value = viewMode.value === 'table' ? 'card' : 'table';
  if (viewMode.value === 'card') {
    loadNodes();
  }
};

const loadNodes = async () => {
  loading.value = true;
  try {
    const response = await getEdgeNodePage({
      pageNo: page.value,
      pageSize: pageSize.value,
      name: searchParams.value.name || undefined,
      host: searchParams.value.host || undefined,
      status: searchParams.value.status || undefined,
    });
    nodeList.value = response?.list || [];
    total.value = response?.total || 0;
  } catch (error) {
    console.error('加载边缘节点列表失败', error);
    createMessage.error('加载边缘节点列表失败');
    nodeList.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
};

const handlePageChange = (p: number, pz: number) => {
  page.value = p;
  pageSize.value = pz;
  loadNodes();
};

const handlePageSizeChange = (_current: number, size: number) => {
  pageSize.value = size;
  page.value = 1;
  loadNodes();
};

const paginationProp = ref({
  showSizeChanger: false,
  showQuickJumper: true,
  pageSize,
  current: page,
  total,
  showTotal: (t: number) => `总 ${t} 条`,
  onChange: handlePageChange,
  onShowSizeChange: handlePageSizeChange,
});

async function handleSubmit() {
  const params = await validate();
  searchParams.value = params || {};
  page.value = 1;
  if (viewMode.value === 'card') {
    await loadNodes();
  } else {
    reload();
  }
}

const [registerForm, { validate }] = useForm({
  schemas: getFormConfig().schemas || [],
  labelWidth: 80,
  baseColProps: { span: 6 },
  actionColOptions: { span: 6, offset: 0, style: { textAlign: 'right' } },
  autoSubmitOnEnter: true,
  submitFunc: handleSubmit,
});

function openEdit(record: EdgeNodeVO) {
  editForm.id = record.id!;
  editForm.name = record.name || '';
  editForm.maxTaskCount = record.maxTaskCount || 1;
  editForm.remark = record.remark || '';
  editVisible.value = true;
}

async function submitEdit() {
  saving.value = true;
  try {
    await updateEdgeNode({
      id: editForm.id,
      name: editForm.name,
      maxTaskCount: editForm.maxTaskCount,
      remark: editForm.remark,
    });
    createMessage.success('已保存');
    editVisible.value = false;
    handleSuccess();
  } catch (e: any) {
    createMessage.error(e?.message || '保存失败');
  } finally {
    saving.value = false;
  }
}

async function handleToggleEnabled(record: EdgeNodeVO, enabled: boolean) {
  try {
    await updateEdgeNode({ id: record.id!, enabled });
    createMessage.success(enabled ? '已启用' : '已停用');
    handleSuccess();
  } catch (e: any) {
    createMessage.error(e?.message || '操作失败');
  }
}

async function handleDelete(record: EdgeNodeVO) {
  try {
    await deleteEdgeNode(record.id!);
    createMessage.success('已删除');
    handleSuccess();
  } catch (e: any) {
    createMessage.error(e?.message || '删除失败');
  }
}

const handleSuccess = () => {
  if (viewMode.value === 'table') {
    reload();
  } else {
    loadNodes();
  }
};

const handleRefresh = () => {
  handleSuccess();
};

const refresh = () => {
  handleSuccess();
};

defineExpose({ refresh });

onMounted(() => {
  if (viewMode.value === 'card') {
    loadNodes();
  }
});
</script>

<style scoped lang="less">
#edge-node-manage {
  .toolbar-buttons {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
  }
}

.edge-feature-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  margin: 8px 8px 10px;
  padding: 16px 20px;
  border-radius: 12px;
  background: linear-gradient(120deg, #f3f7ff 0%, #ffffff 55%, #eef6ff 100%);
  border: 1px solid rgba(38, 108, 251, 0.12);
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.04);
}

.edge-feature-banner__eyebrow {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  color: #266cfb;
}

.edge-feature-banner__title {
  margin-top: 6px;
  font-size: 16px;
  font-weight: 600;
  color: #0f172a;
  line-height: 1.4;
}

.edge-feature-banner__desc {
  margin-top: 6px;
  max-width: 820px;
  font-size: 13px;
  line-height: 1.65;
  color: rgba(15, 23, 42, 0.62);
}

@media (max-width: 900px) {
  .edge-feature-banner {
    flex-direction: column;
    align-items: flex-start;
  }
}

.card-list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-direction: row;
}

.card-list-header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.card-list-title {
  padding-left: 7px;
  font-size: 16px;
  font-weight: 500;
  line-height: 24px;
  flex-shrink: 0;
}

.card-list-subtitle {
  font-size: 12px;
  color: rgba(15, 23, 42, 0.45);
  white-space: nowrap;
}

.edit-form {
  padding-top: 8px;
}

.edge-node-card-list-wrapper {
  :deep(.ant-list-header) {
    border-block-end: 0;
    padding-top: 0;
    padding-bottom: 8px;
  }
  :deep(.ant-list) {
    padding: 6px;
  }
  :deep(.ant-list-item) {
    margin: 6px;
  }
  :deep(.task-item) {
    overflow: hidden;
    box-shadow: 0 0 4px #00000026;
    border-radius: 8px;
    padding: 16px 0;
    position: relative;
    background-color: #fff;
    background-repeat: no-repeat;
    background-position: center center;
    background-size: 104% 104%;
    transition: all 0.5s;
    min-height: 240px;
    height: 100%;

    &.normal {
      background-image: url('@/assets/images/product/blue-bg.719b437a.png');

      .task-info .status {
        background: #d9dffd;
        color: #266cfbff;
      }
    }

    &.error {
      background-image: url('@/assets/images/product/red-bg.101af5ac.png');

      .task-info .status {
        background: #fad7d9;
        color: #d43030;
      }
    }

    .task-info {
      flex-direction: column;
      max-width: calc(100% - 128px);
      padding-left: 16px;

      .status {
        min-width: 90px;
        height: 25px;
        border-radius: 6px 0 0 6px;
        font-size: 12px;
        font-weight: 500;
        line-height: 25px;
        text-align: center;
        position: absolute;
        right: 0;
        top: 16px;
        padding: 0 8px;
        white-space: nowrap;
      }

      .title {
        font-size: 16px;
        font-weight: 600;
        color: #050708;
        line-height: 20px;
        height: 40px;
        padding-right: 90px;
      }

      .props {
        margin-top: 10px;

        .prop {
          flex: 1;
          margin-bottom: 10px;
          min-width: 0;

          .label {
            font-size: 12px;
            font-weight: 400;
            color: #666;
            line-height: 14px;
          }

          .value {
            font-size: 14px;
            font-weight: 600;
            color: #050708;
            line-height: 14px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            margin-top: 6px;
          }
        }
      }

      .btns {
        display: flex;
        position: absolute;
        left: 16px;
        bottom: 16px;
        margin-top: 20px;
        width: 180px;
        height: 28px;
        border-radius: 45px;
        justify-content: space-around;
        padding: 0 10px;
        align-items: center;
        border: 2px solid #266cfbff;

        .btn {
          width: 28px;
          text-align: center;
          position: relative;
          cursor: pointer;

          &:before {
            content: '';
            display: block;
            position: absolute;
            width: 1px;
            height: 7px;
            background-color: #e2e2e2;
            left: 0;
            top: 9px;
          }

          &:first-child:before {
            display: none;
          }

          :deep(.anticon) {
            display: flex;
            align-items: center;
            justify-content: center;
            color: #3b82f6;
            transition: color 0.3s;
          }

          &:hover :deep(.anticon) {
            color: #5ba3f5;
          }

          &.delete-btn {
            :deep(.anticon) {
              color: #dc2626;
            }

            &:hover :deep(.anticon) {
              color: #dc2626;
            }
          }
        }
      }
    }

    .task-img {
      position: absolute;
      right: 20px;
      top: 50px;

      img {
        cursor: pointer;
        width: 100px;
      }
    }
  }
}
</style>

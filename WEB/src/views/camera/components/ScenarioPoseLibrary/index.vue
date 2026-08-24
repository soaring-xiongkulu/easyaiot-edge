<template>
  <div id="scenario-pose-library">
    <BasicTable v-if="viewMode === 'table'" @register="registerTable">
      <template #toolbar>
        <div class="toolbar-buttons">
          <Button type="primary" @click="handleCreate">
            <template #icon><PlusOutlined /></template>
            新建场景姿态库
          </Button>
          <Button @click="handleToggleViewMode"><SwapOutlined /> 切换视图</Button>
        </div>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'business_tags'">
          <a-tag v-for="tag in record.business_tags || []" :key="tag" size="small">{{ tag }}</a-tag>
          <span v-if="!record.business_tags?.length">-</span>
        </template>
        <template v-else-if="column.dataIndex === 'is_enabled'">
          <a-switch :checked="record.is_enabled" @change="handleToggleEnabled(record)" />
        </template>
        <template v-else-if="column.dataIndex === 'action'">
          <TableAction :actions="getTableActions(record)" />
        </template>
      </template>
    </BasicTable>

    <div v-else class="card-list-wrapper p-2">
      <div class="p-4 bg-white" style="margin-bottom: 10px">
        <BasicForm @register="registerForm" @reset="loadLibraryList" />
      </div>
      <div class="p-2 bg-white">
        <Spin :spinning="loading">
          <List
            :grid="{ gutter: 12, xs: 1, sm: 2, md: 3, lg: 4, xl: 4, xxl: 4 }"
            :data-source="libraryList"
            :pagination="paginationProp"
          >
            <template #header>
              <div class="list-header">
                <span class="list-title">场景姿态库列表</span>
                <div class="toolbar-buttons">
                  <Button type="primary" @click="handleCreate"><PlusOutlined /> 新建</Button>
                  <Button @click="handleToggleViewMode"><SwapOutlined /> 切换视图</Button>
                </div>
              </div>
            </template>
            <template #renderItem="{ item }">
              <ListItem :class="item.is_enabled ? 'library-item normal' : 'library-item error'">
                <div class="library-info">
                  <div class="status">{{ item.is_enabled ? '启用' : '停用' }}</div>
                  <div class="title o2">{{ item.name }}</div>
                  <div class="props">
                    <div class="prop"><div class="label">编码</div><div class="value">{{ item.code }}</div></div>
                    <div class="prop"><div class="label">场景</div><div class="value">{{ item.scene_category || 'custom' }}</div></div>
                    <div class="prop"><div class="label">条目</div><div class="value">{{ item.entry_count ?? 0 }}</div></div>
                  </div>
                  <div class="btns">
                    <div class="btn" title="管理条目" @click="handleManage(item)">
                      <Icon icon="ant-design:user-outlined" :size="15" color="#3B82F6" />
                    </div>
                    <div class="btn" title="编辑" @click="handleEdit(item)">
                      <Icon icon="ant-design:edit-filled" :size="15" color="#3B82F6" />
                    </div>
                    <Popconfirm title="确定删除？" @confirm="handleDelete(item)">
                      <div class="btn delete-btn"><Icon icon="material-symbols:delete-outline-rounded" :size="15" color="#DC2626" /></div>
                    </Popconfirm>
                  </div>
                </div>
              </ListItem>
            </template>
          </List>
        </Spin>
      </div>
    </div>

    <ScenarioPoseLibraryModal @register="registerLibraryModal" @success="handleSuccess" />
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { PlusOutlined, SwapOutlined } from '@ant-design/icons-vue';
import { List, Popconfirm, Spin } from 'ant-design-vue';
import { BasicForm, useForm } from '@/components/Form';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { useDrawer } from '@/components/Drawer';
import { useMessage } from '@/hooks/web/useMessage';
import { Icon } from '@/components/Icon';
import { Button } from '@/components/Button';
import {
  deleteScenarioPoseLibrary,
  listScenarioPoseLibraries,
  parseScenarioPoseApiError,
  updateScenarioPoseLibrary,
  type ScenarioPoseLibrary,
} from '@/api/device/scenario_pose_library';
import { getBasicColumns, getFormConfig } from './Data';
import ScenarioPoseLibraryModal from './ScenarioPoseLibraryModal.vue';

const ListItem = List.Item;
defineOptions({ name: 'ScenarioPoseLibrary' });

const { createMessage } = useMessage();
const router = useRouter();
const [registerLibraryModal, { openDrawer: openLibraryDrawer }] = useDrawer();

const viewMode = ref<'table' | 'card'>('card');
const libraryList = ref<ScenarioPoseLibrary[]>([]);
const allLibraries = ref<ScenarioPoseLibrary[]>([]);
const loading = ref(false);
const page = ref(1);
const pageSize = ref(12);
const total = ref(0);

const paginationProp = computed(() => ({
  current: page.value,
  pageSize: pageSize.value,
  total: total.value,
  showSizeChanger: true,
  onChange: (p: number, ps: number) => {
    page.value = p;
    pageSize.value = ps;
    applyPagination();
  },
}));

const [registerForm, { getFieldsValue }] = useForm(getFormConfig());
const [registerTable, { reload }] = useTable({
  api: async () => {
    const values = getFieldsValue();
    const res = await listScenarioPoseLibraries({
      search: values.search,
      is_enabled: values.is_enabled === '' || values.is_enabled == null ? undefined : !!values.is_enabled,
    });
    const rows = Array.isArray(res?.data) ? res.data : [];
    return { items: rows, total: rows.length };
  },
  columns: getBasicColumns(),
  useSearchForm: false,
  showIndexColumn: false,
  actionColumn: { width: 200, title: '操作', dataIndex: 'action' },
});

async function loadLibraryList() {
  loading.value = true;
  try {
    const values = getFieldsValue();
    const res = await listScenarioPoseLibraries({
      search: values.search,
      is_enabled: values.is_enabled === '' || values.is_enabled == null ? undefined : !!values.is_enabled,
    });
    libraryList.value = Array.isArray(res?.data) ? res.data : [];
    allLibraries.value = [...libraryList.value];
    total.value = allLibraries.value.length;
    applyPagination();
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  } finally {
    loading.value = false;
  }
}

function applyPagination() {
  const start = (page.value - 1) * pageSize.value;
  libraryList.value = allLibraries.value.slice(start, start + pageSize.value);
}

function handleToggleViewMode() {
  viewMode.value = viewMode.value === 'table' ? 'card' : 'table';
  if (viewMode.value === 'card') loadLibraryList();
  else reload();
}

function handleCreate() {
  openLibraryDrawer(true, { type: 'create' });
}

function handleEdit(record: ScenarioPoseLibrary) {
  openLibraryDrawer(true, { type: 'edit', record });
}

function handleManage(record: ScenarioPoseLibrary) {
  router.push({ name: 'ScenarioPoseManage', params: { libraryId: String(record.id) } });
}

async function handleDelete(record: ScenarioPoseLibrary) {
  try {
    await deleteScenarioPoseLibrary(record.id);
    createMessage.success('删除成功');
    handleSuccess();
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  }
}

async function handleToggleEnabled(record: ScenarioPoseLibrary) {
  try {
    await updateScenarioPoseLibrary(record.id, { is_enabled: !record.is_enabled });
    handleSuccess();
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  }
}

function getTableActions(record: ScenarioPoseLibrary) {
  return [
    { label: '管理', onClick: () => handleManage(record) },
    { label: '编辑', onClick: () => handleEdit(record) },
    {
      label: '删除',
      color: 'error',
      popConfirm: { title: '确定删除？', confirm: () => handleDelete(record) },
    },
  ];
}

function handleSuccess() {
  loadLibraryList();
  reload();
}

defineExpose({ refresh: handleSuccess });

onMounted(() => loadLibraryList());
</script>

<style scoped lang="less">
.list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-left: 7px;
}
.list-title {
  font-size: 16px;
  font-weight: 500;
}
.library-item {
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 12px;
  min-height: 160px;
}
.library-item.error {
  opacity: 0.75;
}
.title {
  font-weight: 600;
  margin: 8px 0;
}
.props {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  font-size: 12px;
  color: #666;
}
.btns {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}
.btn {
  cursor: pointer;
  padding: 4px;
}
</style>

<template>
  <div class="scenario-pose-manage-page">
    <div class="page-header">
      <Button type="text" @click="goBack"><ArrowLeftOutlined /> 返回场景姿态库</Button>
      <div v-if="library" class="library-info">
        <h1>{{ library.name }}</h1>
        <a-tag>{{ library.code }}</a-tag>
        <span class="meta">{{ entryList.length }} 条姿态模板</span>
      </div>
      <div class="header-actions">
        <Button @click="openImportTemplate">导入内置模板</Button>
        <Button type="primary" @click="openEntryModal()"><PlusOutlined /> 录入参考姿态</Button>
      </div>
    </div>

    <BasicTable @register="registerTable">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'source_type'">
          <a-tag>{{ record.source_type === 'rule' ? '规则' : '图片' }}</a-tag>
        </template>
        <template v-else-if="column.dataIndex === 'is_enabled'">
          <a-tag :color="record.is_enabled ? 'green' : 'default'">{{ record.is_enabled ? '启用' : '停用' }}</a-tag>
        </template>
        <template v-else-if="column.dataIndex === 'action'">
          <TableAction :actions="getActions(record)" />
        </template>
      </template>
    </BasicTable>

    <Modal v-model:open="entryModalVisible" title="录入参考姿态" @ok="submitEntry" :confirmLoading="entryLoading">
      <Form layout="vertical">
        <FormItem label="条目名称" required>
          <Input v-model:value="entryForm.name" placeholder="如：侧躺参考1" />
        </FormItem>
        <FormItem label="参考图片" required>
          <Upload :beforeUpload="beforeUpload" :maxCount="1" accept="image/*" list-type="picture-card">
            <div v-if="!entryForm.file"><PlusOutlined /><div>上传</div></div>
          </Upload>
        </FormItem>
        <FormItem label="备注">
          <Input.TextArea v-model:value="entryForm.remark" :rows="2" />
        </FormItem>
      </Form>
    </Modal>

    <Modal v-model:open="templateModalVisible" title="导入内置场景模板" @ok="submitImportTemplate">
      <Select v-model:value="selectedTemplate" style="width: 100%" placeholder="选择模板">
        <SelectOption v-for="t in templates" :key="t.key" :value="t.key">{{ t.name }} ({{ t.scene_category }})</SelectOption>
      </Select>
    </Modal>
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeftOutlined, PlusOutlined } from '@ant-design/icons-vue';
import { Form, FormItem, Input, Modal, Select, SelectOption, Upload } from 'ant-design-vue';
import type { UploadProps } from 'ant-design-vue';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { useMessage } from '@/hooks/web/useMessage';
import { Button } from '@/components/Button';
import {
  addScenarioPoseEntry,
  deleteScenarioPoseEntry,
  getScenarioPoseLibrary,
  importSceneTemplate,
  listSceneTemplates,
  listScenarioPoseEntries,
  parseScenarioPoseApiError,
  reExtractScenarioPoseEntry,
  type ScenarioPoseEntry,
  type ScenarioPoseLibrary,
  type SceneTemplate,
} from '@/api/device/scenario_pose_library';

defineOptions({ name: 'ScenarioPoseManage' });

const route = useRoute();
const router = useRouter();
const { createMessage } = useMessage();

const libraryId = Number(route.params.libraryId);
const library = ref<ScenarioPoseLibrary | null>(null);
const entryList = ref<ScenarioPoseEntry[]>([]);

const entryModalVisible = ref(false);
const entryLoading = ref(false);
const entryForm = ref({ name: '', remark: '', file: null as File | null });

const templateModalVisible = ref(false);
const selectedTemplate = ref('');
const templates = ref<SceneTemplate[]>([]);

const [registerTable, { reload }] = useTable({
  api: async () => {
    const res = await listScenarioPoseEntries(libraryId);
    const rows = Array.isArray(res?.data) ? res.data : [];
    entryList.value = rows;
    return { items: rows, total: rows.length };
  },
  columns: [
    { title: '名称', dataIndex: 'name', width: 160 },
    { title: '来源', dataIndex: 'source_type', width: 90 },
    { title: '备注', dataIndex: 'remark', width: 200, ellipsis: true },
    { title: '启用', dataIndex: 'is_enabled', width: 80 },
    { title: '创建时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 160 },
  ],
  pagination: false,
  showIndexColumn: false,
});

function goBack() {
  router.push({ path: '/camera/index', query: { tab: '13' } });
}

async function loadLibrary() {
  const res = await getScenarioPoseLibrary(libraryId);
  library.value = res?.data || (res as unknown as ScenarioPoseLibrary);
}

function openEntryModal() {
  entryForm.value = { name: '', remark: '', file: null };
  entryModalVisible.value = true;
}

const beforeUpload: UploadProps['beforeUpload'] = (file) => {
  entryForm.value.file = file as File;
  return false;
};

async function submitEntry() {
  if (!entryForm.value.name?.trim()) {
    createMessage.warning('请输入条目名称');
    return;
  }
  if (!entryForm.value.file) {
    createMessage.warning('请上传参考图片');
    return;
  }
  entryLoading.value = true;
  try {
    const fd = new FormData();
    fd.append('name', entryForm.value.name.trim());
    fd.append('file', entryForm.value.file);
    if (entryForm.value.remark) fd.append('remark', entryForm.value.remark);
    await addScenarioPoseEntry(libraryId, fd);
    createMessage.success('录入成功');
    entryModalVisible.value = false;
    reload();
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  } finally {
    entryLoading.value = false;
  }
}

async function openImportTemplate() {
  const res = await listSceneTemplates();
  templates.value = Array.isArray(res?.data) ? res.data : [];
  selectedTemplate.value = templates.value[0]?.key || '';
  templateModalVisible.value = true;
}

async function submitImportTemplate() {
  if (!selectedTemplate.value) return;
  try {
    await importSceneTemplate(libraryId, selectedTemplate.value);
    createMessage.success('导入成功');
    templateModalVisible.value = false;
    reload();
    loadLibrary();
  } catch (e) {
    createMessage.error(parseScenarioPoseApiError(e));
  }
}

function getActions(record: ScenarioPoseEntry) {
  return [
    {
      label: '重提取',
      ifShow: record.source_type !== 'rule',
      onClick: async () => {
        try {
          await reExtractScenarioPoseEntry(record.id);
          createMessage.success('重新提取成功');
          reload();
        } catch (e) {
          createMessage.error(parseScenarioPoseApiError(e));
        }
      },
    },
    {
      label: '删除',
      color: 'error',
      popConfirm: {
        title: '确定删除？',
        confirm: async () => {
          await deleteScenarioPoseEntry(record.id);
          createMessage.success('删除成功');
          reload();
        },
      },
    },
  ];
}

onMounted(() => {
  loadLibrary();
});
</script>

<style scoped lang="less">
.page-header {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  background: #fff;
  margin-bottom: 12px;
  flex-wrap: wrap;
}
.library-info h1 {
  margin: 0 8px 0 0;
  display: inline;
  font-size: 18px;
}
.meta {
  margin-left: 8px;
  color: #666;
}
.header-actions {
  margin-left: auto;
  display: flex;
  gap: 8px;
}
</style>

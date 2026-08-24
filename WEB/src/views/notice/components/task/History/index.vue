<template>
  <div>
    <BasicTable @register="registerTable">
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:eye-filled',
                tooltip: {
                  title: '详情',
                  placement: 'top',
                },
                onClick: openDetailDrawer.bind(null, true, { record }),
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>
    <HistoryDetailDrawer @register="registerDetailDrawer" />
  </div>
</template>
<script lang="ts" setup name="History">
import { defineProps, watch } from 'vue';
import { BasicTable, TableAction, useTable } from '/@/components/Table';
import { useDrawer } from '/@/components/Drawer';
import { getColumns, getFormConfig } from './Data.tsx';
import { historyQuery } from '/@/api/modules/task';
import HistoryDetailDrawer from './HistoryDetailDrawer.vue';

const props = defineProps({
  msgType: { type: String },
});

const [registerDetailDrawer, { openDrawer: openDetailDrawer }] = useDrawer();

const [registerTable, { getForm, reload }] = useTable({
  canResize: true,
  showIndexColumn: false,
  title: '推送历史',
  api: historyQuery,
  columns: [
    ...getColumns(),
    {
      width: 80,
      title: '操作',
      dataIndex: 'action',
      fixed: 'right',
    },
  ],
  useSearchForm: true,
  formConfig: getFormConfig(),
  rowKey: 'id',
  fetchSetting: {
    listField: 'data',
    totalField: 'total',
  },
  beforeFetch(ext) {
    const form = getForm();
    form.setFieldsValue({ msgType: props.msgType || '1' });
    return {
      ...ext,
      msgType: props.msgType || '1',
    };
  },
});

watch(
  () => props.msgType,
  () => {
    reload();
  },
);
</script>

<style lang="less" scoped></style>

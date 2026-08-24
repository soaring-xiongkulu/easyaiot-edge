<template>
  <div class="user-warpper">
    <BasicTable @register="registerTable">
      <template #toolbar>
        <Button type="primary" preIcon="ant-design:plus-outlined" @click="openUserModal(true, { type: 'add' })">新增用户</Button>
        <Button preIcon="ant-design:import-outlined" @click="openImportModal(true)">导入用户</Button>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                tooltip: {
                  title: '编辑',
                  placement: 'top',
                },
                icon: 'ant-design:edit-filled',
                onClick: openUserModal.bind(null, true, { type: 'edit', record }),
              },
              {
                tooltip: {
                  title: '删除',
                  placement: 'top',
                },
                icon: 'material-symbols:delete-outline-rounded',
                popConfirm: {
                  placement: 'topRight',
                  title: '是否确认删除？',
                  confirm: handleDelete.bind(null, record),
                },
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>
    <UserConfigModal @register="registerUserModal" @success="reload" />
    <UserImportModal @register="registerImportModal" @success="reload" />
  </div>
</template>
<script lang="ts" setup name="planTask">
  import { Button } from '@/components/Button';
  import { BasicTable, useTable, TableAction } from '/@/components/Table';
  import { getColumns, getFormConfig } from './Data.tsx';
  import { useMessage } from '/@/hooks/web/useMessage';
  import UserConfigModal from './component/UserConfigModal.vue';
  import UserImportModal from './component/UserImportModal.vue';
  import { useModal } from '/@/components/Modal';
  import { messagePreviewUserQuery, messagePreviewUserDelete } from '/@/api/modules/user';

  const { createMessage } = useMessage();
  const [registerUserModal, { openModal: openUserModal }] = useModal();
  const [registerImportModal, { openModal: openImportModal }] = useModal();
  const [
    registerTable,
    {
      // setLoading,
      // setColumns,
      // getColumns,
      // getDataSource,
      // getRawDataSource,
      reload,
      // getPaginationRef,
      // setPagination,
      // getSelectRows,
      // getSelectRowKeys,
      // setSelectedRowKeys,
      // clearSelectedRowKeys,
    },
  ] = useTable({
    canResize: true,
    showIndexColumn: false,
    title: '用户管理',
    api: messagePreviewUserQuery,
    columns: getColumns(),
    useSearchForm: true,
    formConfig: getFormConfig(),
    rowKey: 'id',
    fetchSetting: {
      listField: 'data',
      totalField: 'total',
    },
  });

  const handleDelete = async ({ id }) => {
    try {
      await messagePreviewUserDelete({ id });
      createMessage.success('删除成功');
      reload();
    }catch (error) {
    console.error(error)
      createMessage.success('删除失败');
      console.log('handleDelete', error);
    }
  };

</script>

<style lang="less" scoped>
  :deep(.iot-basic-table-action.left) {
    justify-content: center;
  }
  :global(.user-warpper .ant-notification) {
    left: 50% !important;
    transform: translateX(-50%);
  }
</style>

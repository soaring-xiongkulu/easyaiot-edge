<template>
  <div>
    <BasicTable @register="registerTable">
      <template #toolbar>
        <Button type="primary" preIcon="ant-design:plus-outlined" @click="openConfigModal(true, { type: 'add', pushType })"
          >新增模板</Button
        >
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:eye-filled',
                tooltip: { title: '详情', placement: 'top' },
                onClick: openDetailDrawer.bind(null, true, { record }),
              },
              {
                tooltip: { title: '编辑', placement: 'top' },
                icon: 'ant-design:edit-filled',
                onClick: openConfigModal.bind(null, true, { type: 'edit', record, pushType }),
              },
              {
                tooltip: { title: '测试发送', placement: 'top' },
                icon: 'ant-design:experiment-outlined',
                ifShow: () => canTestSend(record),
                onClick: handleTestSend.bind(null, record),
              },
              {
                tooltip: { title: '删除', placement: 'top' },
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
    <ConfigModal @register="registerConfigModal" @success="reload" />
    <DetailDrawer @register="registerDetailDrawer" />
  </div>
</template>
<script lang="ts" setup name="MsgTemplateList">
  import { Button } from '@/components/Button';
  import { BasicTable, useTable, TableAction } from '/@/components/Table';
  import { useMessage } from '/@/hooks/web/useMessage';
  import { useModal } from '/@/components/Modal';
  import { useDrawer } from '@/components/Drawer';
  import ConfigModal from './components/ConfigModal.vue';
  import DetailDrawer from './components/DetailDrawer.vue';
  import { messageTemplateQuery, messageTemplateDelete, messageSendByParam } from '/@/api/modules/notice';

  defineOptions({ name: 'MsgTemplateList' });

  const props = defineProps({
    pushType: { type: String, default: 'email' },
    columns: { type: Array, default: () => [] },
    searchField: { type: Array, default: () => [] },
  });

  const MSG_TYPE_MAP = {
    sms: 1,
    email: 3,
    weixin: 4,
    http: 5,
    ding: 6,
    feishu: 7,
  };

  const [registerConfigModal, { openModal: openConfigModal }] = useModal();
  const [registerDetailDrawer, { openDrawer: openDetailDrawer }] = useDrawer();
  const { createMessage } = useMessage();

  const [registerTable, { reload }] = useTable({
    canResize: true,
    showIndexColumn: false,
    title: '消息模板',
    api: messageTemplateQuery,
    beforeFetch: (data) => ({
      ...data,
      msgType: props.pushType === 'sms' ? data.msgType : MSG_TYPE_MAP[props.pushType],
    }),
    columns: getColumns(),
    useSearchForm: true,
    formConfig: getFormConfig(),
    rowKey: 'id',
    fetchSetting: { listField: 'data', totalField: 'total' },
  });

  function getFormConfig() {
    return {
      labelWidth: 70,
      baseColProps: { span: 6 },
      schemas: [
        ...props.searchField,
        { field: 'msgName', label: '模板名称', component: 'Input' },
      ],
    };
  }

  function getColumns() {
    return [
      {
        title: '模板名称',
        dataIndex: 'msgName',
        ifShow: () => ['sms', 'http'].includes(props.pushType),
      },
      {
        title: '模板标题',
        dataIndex: 'title',
        ifShow: () => !['sms', 'http'].includes(props.pushType),
      },
      ...props.columns,
      { width: 260, title: '操作', dataIndex: 'action', fixed: 'right' },
    ];
  }

  /** 群机器人 / Webhook / 飞书无需用户分组；工作通知需已配置用户分组 */
  function canTestSend(record) {
    if (!record?.id) return false;
    if (['http', 'feishu'].includes(props.pushType)) return true;
    if (['weixin', 'ding'].includes(props.pushType)) {
      const isRobot =
        record.radioType === '群机器人消息' || !!record.webHook;
      if (isRobot) return true;
    }
    return !!record.userGroupId;
  }

  async function handleTestSend(record) {
    const msgType = MSG_TYPE_MAP[props.pushType];
    if (!msgType || !record?.id) {
      createMessage.error('测试发送失败：缺少模板信息');
      return;
    }
    try {
      const ret: any = await messageSendByParam({ msgType, msgId: String(record.id) });
      let sendResult = ret?.data;
      if (sendResult?.data) sendResult = sendResult.data;
      if (sendResult?.success) {
        createMessage.success('测试发送成功');
      } else {
        createMessage.error(sendResult?.info || sendResult?.message || '测试发送失败');
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.info ||
        error?.response?.data?.message ||
        error?.message ||
        '测试发送失败';
      createMessage.error(errorMsg);
    }
  }

  const handleDelete = async ({ id }) => {
    try {
      await messageTemplateDelete({ id, msgType: MSG_TYPE_MAP[props.pushType] });
      createMessage.success('删除成功');
      reload();
    } catch (error) {
      console.error(error);
      createMessage.error('删除失败');
    }
  };
</script>

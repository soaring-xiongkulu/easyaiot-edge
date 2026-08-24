import type { FormProps } from '/@/components/Form';
import { BasicColumn } from '/@/components/Table/src/types/table';
import { formatToDateTime } from '/@/utils/dateUtil';
import { Tooltip, Tag } from 'ant-design-vue';

const msgTypeOptions: Record<number, string> = {
  1: '阿里云短信',
  2: '腾讯云短信',
  3: 'EMail',
  4: '企业微信',
  5: 'Webhook',
  6: '钉钉',
  7: '飞书',
};

export const getMsgTypeLabel = (msgType: number | string) =>
  msgTypeOptions[Number(msgType)] || String(msgType ?? '-');

export const getHistoryDetailSchema = () => [
  {
    field: 'msgName',
    label: '消息名称',
  },
  {
    field: 'msgTypeLabel',
    label: '消息类型',
  },
  {
    field: 'createTimeLabel',
    label: '推送时间',
  },
  {
    field: 'result',
    label: '推送结果',
    render: (val) => {
      const text = val || '-';
      const ok = typeof text === 'string' && text.startsWith('成功');
      return <Tag color={ok ? 'success' : 'error'}>{text}</Tag>;
    },
  },
  {
    field: 'msgId',
    label: '消息ID',
  },
];

export const getColumns = (): BasicColumn[] => {
  return [
    {
      title: '消息名称',
      dataIndex: 'msgName',
      width: 200,
    },
    {
      title: '推送时间',
      dataIndex: 'createTime',
      width: 180,
      format(val) {
        return val ? formatToDateTime(val) : '-';
      },
    },
    {
      title: '推送结果',
      dataIndex: 'result',
      ellipsis: true,
      customRender({ value }) {
        const text = value || '-';
        const ok = typeof text === 'string' && text.startsWith('成功');
        const tag = <Tag color={ok ? 'success' : 'error'}>{ok ? '成功' : '失败'}</Tag>;
        return (
          <Tooltip title={text}>
            {tag}
          </Tooltip>
        );
      },
    },
  ];
};

export const getFormConfig = (): FormProps => {
  return {
    labelWidth: 70,
    baseColProps: { span: 6 },
    schemas: [
      {
        field: `msgName`,
        label: `消息名称`,
        component: 'Input',
      }
    ],
  };
};

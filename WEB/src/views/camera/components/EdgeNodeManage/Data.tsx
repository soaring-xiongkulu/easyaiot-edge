import { Tag } from 'ant-design-vue';
import { BasicColumn, FormProps } from '@/components/Table';
import type { EdgeNodeVO } from '@/api/device/edge';

function statusColor(status?: string) {
  if (status === 'online') return 'success';
  if (status === 'disabled') return 'default';
  return 'error';
}

function statusText(status?: string) {
  if (status === 'online') return '在线';
  if (status === 'disabled') return '停用';
  return '离线';
}

function formatPct(v?: number) {
  if (v == null || Number.isNaN(v)) return '-';
  return `${Number(v).toFixed(0)}%`;
}

export { statusColor, statusText, formatPct };

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: 'ID', dataIndex: 'id', width: 70 },
    { title: '名称', dataIndex: 'name', width: 140 },
    { title: '主机', dataIndex: 'host', width: 140 },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      customRender: ({ text }) => <Tag color={statusColor(text)}>{statusText(text)}</Tag>,
    },
    {
      title: 'Ceph',
      dataIndex: 'cephMountReady',
      width: 90,
      customRender: ({ text }) => (
        <Tag color={text ? 'success' : 'warning'}>{text ? '已挂载' : '未就绪'}</Tag>
      ),
    },
    {
      title: '算力负载',
      dataIndex: 'resource',
      width: 160,
      customRender: ({ record }) => {
        const r = record as EdgeNodeVO;
        return `CPU ${formatPct(r.cpuPercent)} / MEM ${formatPct(r.memPercent)}`;
      },
    },
    {
      title: '任务槽',
      dataIndex: 'maxTaskCount',
      width: 80,
      customRender: ({ record }) => {
        const r = record as EdgeNodeVO;
        return `${r.activeTaskCount ?? 0}/${r.maxTaskCount ?? '-'}`;
      },
    },
    { title: 'MQTT Client', dataIndex: 'mqttClientId', width: 160, ellipsis: true },
    { title: '版本', dataIndex: 'agentVersion', width: 100 },
    { title: '最近心跳', dataIndex: 'lastHeartbeatAt', width: 170 },
    {
      title: '启用',
      dataIndex: 'enabled',
      width: 80,
      customRender: ({ text }) => (
        <Tag color={text !== false ? 'green' : 'default'}>{text !== false ? '启用' : '停用'}</Tag>
      ),
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 180,
      fixed: 'right',
    },
  ];
}

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: { span: 6 },
    actionColOptions: {
      span: 6,
      offset: 0,
      style: { textAlign: 'right' },
    },
    schemas: [
      {
        field: 'name',
        label: '名称',
        component: 'Input',
        componentProps: {
          placeholder: '请输入名称',
          allowClear: true,
        },
      },
      {
        field: 'host',
        label: '主机',
        component: 'Input',
        componentProps: {
          placeholder: '请输入主机',
          allowClear: true,
        },
      },
      {
        field: 'status',
        label: '状态',
        component: 'Select',
        componentProps: {
          allowClear: true,
          placeholder: '请选择状态',
          options: [
            { label: '在线', value: 'online' },
            { label: '离线', value: 'offline' },
            { label: '停用', value: 'disabled' },
          ],
        },
      },
    ],
  };
}

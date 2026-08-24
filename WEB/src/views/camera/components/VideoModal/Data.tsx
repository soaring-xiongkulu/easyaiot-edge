import {BasicColumn, FormProps} from "@/components/Table";
import type { ColumnsType } from 'ant-design-vue/es/table';

export interface OnvifDiscoveryRow {
  ip: string;
  mac?: string | null;
  hardware_name?: string | null;
}

export function getOnvifBasicColumns(): BasicColumn[] {
  return [
    {
      title: 'IP地址',
      dataIndex: 'ip',
      width: 160,
    },
    {
      title: 'MAC地址',
      dataIndex: 'mac',
      width: 200,
    },
    {
      title: '设备型号',
      dataIndex: 'hardware_name',
      width: 200,
      ellipsis: true,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 88,
      fixed: 'right',
    }
  ];
}

/** 添加设备 ONVIF 扫描结果表格列（与 getOnvifBasicColumns 字段一致） */
export function getOnvifDiscoveryTableColumns(): ColumnsType<OnvifDiscoveryRow> {
  return [
    { title: 'IP地址', dataIndex: 'ip', width: 160, ellipsis: true },
    { title: 'MAC地址', dataIndex: 'mac', width: 200, ellipsis: true },
    { title: '设备型号', dataIndex: 'hardware_name', ellipsis: true, minWidth: 160 },
    { title: '操作', dataIndex: 'action', width: 88, fixed: 'right' },
  ];
}

export function formatOnvifMac(mac?: string | null): string {
  if (!mac) return '—';
  const raw = String(mac).trim();
  if (!raw) return '—';
  if (raw.includes(':') || raw.includes('-')) return raw;
  if (/^[0-9a-fA-F]{12}$/.test(raw)) {
    return raw.match(/.{1,2}/g)?.join(':').toUpperCase() ?? raw;
  }
  return raw;
}

export function getOnvifFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: {span: 11},
    schemas: [
      {
        field: `ip`,
        label: `IP地址`,
        component: 'Input',
      },
      {
        field: `mac`,
        label: `MAC地址`,
        component: 'Input',
      },
    ]
  }
}

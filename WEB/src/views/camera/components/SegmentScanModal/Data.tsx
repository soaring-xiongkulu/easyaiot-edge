import { BasicColumn } from '@/components/Table';

export function getCameraScanColumns(): BasicColumn[] {
  return [
    { title: 'IP', dataIndex: 'ip', width: 130 },
    { title: '端口', dataIndex: 'port', width: 70 },
    { title: '品牌', dataIndex: 'vendor_label', width: 90 },
    { title: '角色', dataIndex: 'role_label', width: 90 },
    { title: '认证用户', dataIndex: 'auth_username', width: 100 },
    { title: '型号', dataIndex: 'model', width: 120, ellipsis: true },
    { title: '名称', dataIndex: 'device_name', width: 120, ellipsis: true },
    { title: 'MAC', dataIndex: 'mac', width: 130, ellipsis: true },
    { title: 'RTSP', dataIndex: 'rtsp_url', width: 220, ellipsis: true },
    { title: '状态', dataIndex: 'register_status', width: 90 },
    { title: '操作', dataIndex: 'action', width: 80, fixed: 'right' },
  ];
}

export function getNvrScanColumns(): BasicColumn[] {
  return [
    { title: 'IP', dataIndex: 'ip', width: 130 },
    { title: '端口', dataIndex: 'port', width: 70 },
    { title: '品牌', dataIndex: 'vendor_label', width: 90 },
    { title: '角色', dataIndex: 'role_label', width: 90 },
    { title: '认证用户', dataIndex: 'auth_username', width: 100 },
    { title: '型号', dataIndex: 'model', width: 130, ellipsis: true },
    { title: '名称', dataIndex: 'device_name', width: 130, ellipsis: true },
    { title: 'RTSP', dataIndex: 'rtsp_url', width: 220, ellipsis: true },
    { title: '状态', dataIndex: 'register_status', width: 90 },
    { title: '操作', dataIndex: 'action', width: 130, fixed: 'right' },
  ];
}

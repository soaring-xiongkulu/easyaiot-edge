import type { BasicColumn, FormProps } from '@/components/Table';

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: '库名称', dataIndex: 'name', width: 160 },
    { title: '库编号', dataIndex: 'code', width: 140 },
    { title: '车牌数量', dataIndex: 'plate_count', width: 100 },
    { title: '业务标签', dataIndex: 'business_tags', width: 180 },
    { title: '启用状态', dataIndex: 'is_enabled', width: 100 },
    { title: '描述', dataIndex: 'description', width: 200, ellipsis: true },
    { title: '操作', dataIndex: 'action', width: 200, fixed: 'right' },
  ];
}

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: { span: 6 },
    actionColOptions: { span: 6, offset: 12, style: { textAlign: 'right' } },
    schemas: [
      {
        field: 'search',
        label: '库名称',
        component: 'Input',
        componentProps: { placeholder: '请输入库名称或编号' },
      },
      {
        field: 'is_enabled',
        label: '启用状态',
        component: 'Select',
        componentProps: {
          placeholder: '请选择启用状态',
          options: [
            { value: '', label: '全部' },
            { value: 1, label: '已启用' },
            { value: 0, label: '已禁用' },
          ],
        },
      },
    ],
  };
}

export function getEntryColumns(): BasicColumn[] {
  return [
    { title: '车牌号', dataIndex: 'plate_no', width: 120 },
    { title: '颜色', dataIndex: 'plate_color', width: 80 },
    { title: '车主', dataIndex: 'owner_name', width: 120 },
    { title: '电话', dataIndex: 'owner_phone', width: 130 },
    { title: '图片', dataIndex: 'image_url', width: 80 },
    { title: '备注', dataIndex: 'remark', width: 160, ellipsis: true },
    { title: '启用', dataIndex: 'is_enabled', width: 80 },
    { title: '录入时间', dataIndex: 'created_at', width: 170 },
    { title: '操作', dataIndex: 'action', width: 120, fixed: 'right' },
  ];
}

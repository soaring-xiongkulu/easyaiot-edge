import type { BasicColumn, FormProps } from '@/components/Table';

export function getPlateEntryFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: { span: 6 },
    actionColOptions: {
      span: 6,
      offset: 12,
      style: { textAlign: 'right' },
    },
    schemas: [
      {
        field: 'search',
        label: '搜索',
        component: 'Input',
        componentProps: {
          placeholder: '车牌号 / 车主 / 电话',
        },
      },
    ],
  };
}

export function getPlateManageColumns(): BasicColumn[] {
  return [
    {
      title: '照片',
      dataIndex: 'image_url',
      width: 80,
    },
    {
      title: '车牌号',
      dataIndex: 'plate_no',
      width: 120,
    },
    {
      title: '颜色',
      dataIndex: 'plate_color',
      width: 80,
    },
    {
      title: '车主',
      dataIndex: 'owner_name',
      width: 120,
    },
    {
      title: '电话',
      dataIndex: 'owner_phone',
      width: 130,
    },
    {
      title: '启用',
      dataIndex: 'is_enabled',
      width: 80,
    },
    {
      title: '录入时间',
      dataIndex: 'created_at',
      width: 170,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 140,
      fixed: 'right',
    },
  ];
}

import type { BasicColumn, FormProps } from '@/components/Table';

export function getPersonColumns(): BasicColumn[] {
  return [
    {
      title: '封面',
      dataIndex: 'cover_image_url',
      width: 80,
    },
    {
      title: '姓名',
      dataIndex: 'person_name',
      width: 120,
    },
    {
      title: '编号',
      dataIndex: 'person_code',
      width: 120,
    },
    {
      title: '照片数',
      dataIndex: 'face_count',
      width: 90,
    },
    {
      title: '启用',
      dataIndex: 'is_enabled',
      width: 80,
    },
    {
      title: '更新时间',
      dataIndex: 'updated_at',
      width: 170,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 160,
      fixed: 'right',
    },
  ];
}

export function getPersonFormConfig(): Partial<FormProps> {
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
          placeholder: '姓名 / 编号',
        },
      },
    ],
  };
}

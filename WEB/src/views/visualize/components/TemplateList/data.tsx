import { BasicColumn, FormProps } from '@/components/Table'

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: '模板ID', dataIndex: 'id', width: 90 },
    { title: '模板名称', dataIndex: 'templateName', width: 180 },
    { title: '分类', dataIndex: 'category', width: 120, customRender: ({ text }) => text || '--' },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '备注', dataIndex: 'remarks', width: 180, customRender: ({ text }) => text || '--' },
    {
      title: '创建时间',
      dataIndex: 'createTime',
      width: 170,
      customRender: ({ text }) => formatDateTime(text),
    },
    { width: 140, title: '操作', dataIndex: 'action', fixed: 'right' },
  ]
}

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: { span: 6 },
    schemas: [
      { field: 'templateName', label: '模板名称', component: 'Input' },
      { field: 'category', label: '分类', component: 'Input' },
    ],
  }
}

function formatDateTime(dateString: string): string {
  if (!dateString) return '--'
  const date = new Date(dateString)
  if (Number.isNaN(date.getTime())) return String(dateString)
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString()
}

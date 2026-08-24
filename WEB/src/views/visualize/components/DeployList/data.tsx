import { BasicColumn, FormProps } from '@/components/Table'

const STATUS_MAP: Record<number, string> = {
  0: '草稿',
  1: '已上线',
  2: '已下线',
}

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '部署名称', dataIndex: 'deployName', width: 160 },
    { title: '项目', dataIndex: 'projectName', width: 140, customRender: ({ text }) => text || '--' },
    { title: '投放编码', dataIndex: 'deployCode', width: 150 },
    {
      title: '状态',
      dataIndex: 'status',
      width: 100,
      customRender: ({ text }) => STATUS_MAP[Number(text)] || '--',
    },
    {
      title: '访问路径',
      dataIndex: 'accessPath',
      width: 220,
      customRender: ({ text }) => text || '--',
    },
    {
      title: '创建时间',
      dataIndex: 'createTime',
      width: 170,
      customRender: ({ text }) => formatDateTime(text),
    },
    { width: 180, title: '操作', dataIndex: 'action', fixed: 'right' },
  ]
}

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 80,
    baseColProps: { span: 6 },
    schemas: [
      { field: 'deployName', label: '部署名称', component: 'Input' },
      {
        field: 'status',
        label: '状态',
        component: 'Select',
        componentProps: {
          allowClear: true,
          options: [
            { label: '草稿', value: 0 },
            { label: '已上线', value: 1 },
            { label: '已下线', value: 2 },
          ],
        },
      },
    ],
  }
}

function formatDateTime(dateString: string): string {
  if (!dateString) return '--'
  const date = new Date(dateString)
  if (Number.isNaN(date.getTime())) return String(dateString)
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString()
}

import { BasicColumn, FormProps } from '@/components/Table'

const DS_TYPE_MAP: Record<string, string> = {
  http: 'HTTP',
  sql: 'SQL',
  static: '静态数据',
  device: '设备数据',
}

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: 'ID', dataIndex: 'id', width: 90 },
    { title: '名称', dataIndex: 'dsName', width: 160 },
    {
      title: '类型',
      dataIndex: 'dsType',
      width: 110,
      customRender: ({ text }) => DS_TYPE_MAP[text] || text || '--',
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 90,
      customRender: ({ text }) => (Number(text) === 1 ? '停用' : '启用'),
    },
    {
      title: '请求地址',
      dataIndex: 'requestUrl',
      width: 220,
      customRender: ({ text }) => text || '--',
    },
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
      { field: 'dsName', label: '名称', component: 'Input' },
      {
        field: 'dsType',
        label: '类型',
        component: 'Select',
        componentProps: {
          allowClear: true,
          options: [
            { label: 'HTTP', value: 'http' },
            { label: 'SQL', value: 'sql' },
            { label: '静态数据', value: 'static' },
            { label: '设备数据', value: 'device' },
          ],
        },
      },
      {
        field: 'status',
        label: '状态',
        component: 'Select',
        componentProps: {
          allowClear: true,
          options: [
            { label: '启用', value: 0 },
            { label: '停用', value: 1 },
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

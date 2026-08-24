import { BasicColumn, FormProps } from '@/components/Table'

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: '素材ID', dataIndex: 'id', width: 90 },
    { title: '素材名称', dataIndex: 'assetName', width: 180 },
    { title: '类型', dataIndex: 'assetType', width: 100 },
    {
      title: '文件地址',
      dataIndex: 'fileUrl',
      width: 260,
      customRender: ({ text }) => text || '--',
    },
    {
      title: '大小',
      dataIndex: 'fileSize',
      width: 100,
      customRender: ({ text }) => (text == null ? '--' : `${text}`),
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
      { field: 'assetName', label: '素材名称', component: 'Input' },
      {
        field: 'assetType',
        label: '类型',
        component: 'Select',
        componentProps: {
          allowClear: true,
          options: [
            { label: '图片', value: 'image' },
            { label: '视频', value: 'video' },
            { label: '其他', value: 'other' },
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

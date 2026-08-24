import type { BasicColumn, FormProps } from '@/components/Table';

export function getBasicColumns(): BasicColumn[] {
  return [
    { title: '库名称', dataIndex: 'name', width: 160 },
    { title: '库编号', dataIndex: 'code', width: 140 },
    { title: '场景类别', dataIndex: 'scene_category', width: 120 },
    { title: '条目数', dataIndex: 'entry_count', width: 90 },
    { title: '匹配阈值', dataIndex: 'similarity_threshold', width: 100 },
    { title: '业务标签', dataIndex: 'business_tags', width: 180 },
    { title: '启用', dataIndex: 'is_enabled', width: 90 },
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
          placeholder: '请选择',
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

export const SCENE_CATEGORY_OPTIONS = [
  { label: '自定义', value: 'custom' },
  { label: '跌倒检测', value: 'fall' },
  { label: '攀爬检测', value: 'climb' },
  { label: '蹲伏检测', value: 'squat' },
  { label: '举手求助', value: 'hands_up' },
];

export const MATCH_MODE_OPTIONS = [
  { label: '关节角度', value: 'angle' },
  { label: '骨架比例', value: 'ratio' },
  { label: '组合模式', value: 'combined' },
];

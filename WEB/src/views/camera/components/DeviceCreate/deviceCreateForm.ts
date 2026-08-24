import type { FormProps } from '@/components/Form';

/** 添加设备页统一表单栅格 */
export const DEVICE_CREATE_LABEL_WIDTH = 110;

/** 配置表单区最大宽度 */
export const DEVICE_CREATE_FORM_MAX_WIDTH = 1080;

/** 标准输入框最大宽度（两列栅格内） */
export const DEVICE_CREATE_FIELD_WIDTH = 480;

/** 单行字段输入框最大宽度（略宽于标准列） */
export const DEVICE_CREATE_FIELD_LINE_WIDTH = 560;

/** 标准字段：一行两列 */
export const DEVICE_CREATE_COL = { span: 12 } as const;

/** 长文本 / URL 字段：独占一行且控件撑满 */
export const DEVICE_CREATE_COL_FULL = { span: 24 } as const;

/** 独占一行，控件宽度为 DEVICE_CREATE_FIELD_LINE_WIDTH */
export const DEVICE_CREATE_COL_LINE = { span: 24, class: 'device-create-col-line' } as const;

/** @deprecated 与 DEVICE_CREATE_COL 相同，保留兼容 */
export const DEVICE_CREATE_COL_HALF = DEVICE_CREATE_COL;

/** InputNumber 等需撑满列宽 */
export const DEVICE_CREATE_NUMBER_PROPS = { style: { width: '100%' } } as const;

export const DEVICE_CREATE_FORM_GRID: Partial<FormProps> = {
  labelWidth: DEVICE_CREATE_LABEL_WIDTH,
  baseColProps: DEVICE_CREATE_COL,
  rowProps: { gutter: 16 },
  showActionButtonGroup: false,
  compact: true,
};

/** BasicTable 内嵌搜索表单（字段 + 查询/重置按钮同一行） */
export const DEVICE_CREATE_TABLE_SEARCH_COL = { span: 8 } as const;

export const DEVICE_CREATE_TABLE_FORM: Partial<FormProps> = {
  labelWidth: DEVICE_CREATE_LABEL_WIDTH,
  baseColProps: DEVICE_CREATE_TABLE_SEARCH_COL,
  rowProps: { gutter: 16 },
  compact: true,
  showAdvancedButton: false,
  actionColOptions: { span: 8, style: { textAlign: 'left' } },
};

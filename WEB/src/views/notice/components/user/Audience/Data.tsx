import { FormSchema } from '/@/components/Form';
import { BasicColumn, FormProps } from '/@/components/Table';

/** 导入模板中示例行的目标用户前缀，导入时自动跳过 */
export const IMPORT_EXAMPLE_PREFIX = '（示例）';

export const MSG_TYPE_OPTIONS = [
  { label: '阿里云短信', value: 1 },
  { label: '腾讯云短信', value: 2 },
  { label: 'EMail', value: 3 },
  { label: '企业微信', value: 4 },
  { label: '钉钉', value: 6 },
];

/** Excel 导入时「消息通知类型」列须与下列文案完全一致 */
export const IMPORT_MSG_TYPE_LABELS = [
  '阿里云短信',
  '腾讯云短信',
  '邮件',
  '企业微信',
  'http',
  '钉钉',
];

export const IMPORT_GUIDE_ROWS = [
  {
    msgType: '阿里云短信',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}13900001234`,
    format: '11 位中国大陆手机号',
    hint: '填写可正常接收短信的 11 位手机号码',
  },
  {
    msgType: '腾讯云短信',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}18600001234`,
    format: '11 位中国大陆手机号',
    hint: '填写可正常接收短信的 11 位手机号码',
  },
  {
    msgType: '邮件',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}alert@company.com`,
    format: '有效邮箱地址',
    hint: '填写用于接收告警通知的邮箱地址',
  },
  {
    msgType: '企业微信',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}zhangsan`,
    format: '企业微信成员 UserID',
    hint: '填写企业微信通讯录成员 UserID（非手机号），可在管理后台「通讯录 → 成员详情」中查看',
  },
  {
    msgType: 'http',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}https://api.company.com/message/callback`,
    format: 'HTTP / HTTPS 地址',
    hint: '填写可公网访问的消息回调地址，支持 HTTP 或 HTTPS',
  },
  {
    msgType: '钉钉',
    previewUser: `${IMPORT_EXAMPLE_PREFIX}0123456789`,
    format: '钉钉成员 UserID',
    hint: '填写钉钉通讯录成员 UserID，可在管理后台「通讯录 → 成员详情」中查看',
  },
];

export const getColumns = (): BasicColumn[] => {
  return [
    {
      title: '类型',
      dataIndex: 'msgType',
      customRender: ({ text }) => {
        return {
          1: '阿里云短信',
          2: '腾讯云短信',
          3: 'EMail',
          4: '企业微信',
          5: 'http',
          6: '钉钉',
        }[text];
      },
    },
    {
      title: '用户',
      dataIndex: 'previewUser',
    },
    {
      width: 100,
      title: '操作',
      dataIndex: 'action',
      fixed: 'right',
    },
  ];
};

export const getFormConfig = (): FormProps => {
  return {
    labelWidth: 70,
    baseColProps: { span: 6 },
    schemas: [
      {
        field: `msgType`,
        label: `用户类型`,
        component: 'Select',
        componentProps: {
          options: MSG_TYPE_OPTIONS,
        },
        defaultValue: 3,
      },
    ],
  };
};

export const formSchemas = (msgTypeChange): FormSchema[] => {
  return [
    {
      field: 'id',
      component: 'Input',
      colProps: {
        span: 0,
      },
      label: '',
    },
    {
      field: 'msgType',
      label: '类型',
      required: true,
      component: 'Select',
      componentProps: {
        options: MSG_TYPE_OPTIONS,
        getPopupContainer: () => document.body,
        onChange: (...ext) => msgTypeChange(...ext),
      },
    },
    {
      field: 'previewUser',
      component: 'Input',
      label: '用户',
      rules: [{ required: true, trigger: ['change', 'blur'] }],
    },
  ];
};

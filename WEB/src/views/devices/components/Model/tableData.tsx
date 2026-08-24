import {BasicColumn} from '@/components/Table/src/types/table';
import {FormProps} from '@/components/Table';
import {formatToDateTime} from '@/utils/dateUtil';
import {Tooltip} from 'ant-design-vue';

export function getBasicColumns(): BasicColumn[] {
  return [
    {
      dataIndex: 'propertyName',
      title: '名称',
      width: 160,
      ellipsis: true,
    },
    {
      title: '键',
      dataIndex: 'propertyCode',
      width: 160,
      ellipsis: true,
    },
    {
      title: '值',
      dataIndex: 'dataValue',
      ellipsis: true,
      customRender({value}) {
        const text = value == null || value === '' ? '--' : String(value);
        return (
          <Tooltip title={text}>
            <span class={'ellipsis-span'}>{text}</span>
          </Tooltip>
        );
      },
    },
    {
      title: '最后更新时间',
      dataIndex: 'ts',
      width: 180,
      customRender({value}) {
        let val = value;
        if (!val) return '--';
        val = formatToDateTime(val);
        return (
          <Tooltip title={val}>
            <span class={'ellipsis-span'}>{val}</span>
          </Tooltip>
        );
      },
      ellipsis: true,
    },
  ];
}

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 70,
    baseColProps: {span: 10},
    schemas: [
      {
        field: `name`,
        label: `键/名称`,
        component: 'Input',
      },
    ],
  };
}

export const detailColumns = (): BasicColumn[] => {
  return [
    {
      dataIndex: 'ts',
      title: '时间',
      customRender({value}) {
        let val = value;
        if (!val) return '--';
        val = formatToDateTime(val);
        return (
          <Tooltip title={val}>
            <span class={'ellipsis-span'}>{val}</span>
          </Tooltip>
        );
      },
      ellipsis: true,
    },
  ];
};

export const detailSearchSchema = (): Partial<FormProps> => {
  return {
    fieldMapToTime: [['time', ['lastUpdateTimeFrom', 'lastUpdateTimeTo'], 'x']],
    schemas: [
      {
        field: `currentTime`,
        label: ``,
        component: 'RadioGroup',
        slot: 'custom1',
      },
      {
        field: `deviceProfileId`,
        label: ``,
        component: 'RangePicker',
        slot: 'custom',
      },
    ],
    showResetButton: false,
    showSubmitButton: false,
    showActionButtonGroup: false,
  };
};


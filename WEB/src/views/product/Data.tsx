import {BasicColumn} from '@/components/Table/src/types/table';
import {FormProps} from '@/components/Table';

import {Tag, Tooltip} from 'ant-design-vue';
import {formatToDateTime} from "@/utils/dateUtil";

export function getBasicColumns(): BasicColumn[] {
  return [
    {
      title: '产品ID',
      dataIndex: 'id',
      defaultHidden: true
    },
    {
      title: '应用场景',
      dataIndex: 'appId',
      width: 70,
    },
    {
      title: '产品名称',
      dataIndex: 'productName',
      width: 70,
    },
    {
      title: '产品标识',
      dataIndex: 'productIdentification',
      width: 90,
    },
    {
      title: '产品类型',
      dataIndex: 'productType',
      width: 50,
      customRender: ({ text }) => {
        return <Tag color={text=='COMMON' ? 'blue' : text=='GATEWAY'? 'green' : 'yellow'}>{text=='COMMON' ? '普通产品' : text=='GATEWAY'? '网关产品' : '子设备'}</Tag>;
      },
    },
    {
      title: '产品型号',
      dataIndex: 'model',
      width: 50,
    },
    {
      title: '厂商ID',
      dataIndex: 'manufacturerId',
      width: 50,
    },
    {
      title: '厂商名称',
      dataIndex: 'manufacturerName',
      width: 50,
    },
    {
      title: '数据格式',
      dataIndex: 'dataFormat',
      width: 50,
    },
    {
      title: '设备类型',
      dataIndex: 'deviceType',
      width: 50,
    },
    {
      title: '协议类型',
      dataIndex: 'protocolType',
      width: 50,
    },
    {
      title: '状态',
      dataIndex: 'status',
      width: 50,
      customRender: ({ text }) => {
        const enabled = text === '0' || text === 0;
        return <Tag color={enabled ? 'green' : 'red'}>{enabled ? '启用' : '停用'}</Tag>;
      },
    },
    {
      title: '产品描述',
      dataIndex: 'remark',
      width: 50,
    },
    {
      title: '创建时间',
      dataIndex: 'createTime',
      width: 110,
      customRender({ value }) {
        return (
          <Tooltip title={formatToDateTime(value)}>
            <span class={'ellipsis-span'}>{formatToDateTime(value)}</span>
          </Tooltip>
        );
      },
      ellipsis: true,
    },
    {
      width: 110,
      title: '操作',
      dataIndex: 'action',
    },
    // {
    //   title: '配置图片',
    //   dataIndex: 'imageData',
    //   width: 60,
    //   customRender: ({ text }) => {
    //     return (
    //       <div
    //         class={'product-image'}
    //         onClick={() => {
    //           if (!text) return;
    //           createImgPreview({ imageList: [text] });
    //         }}
    //       >
    //         <img src={text ? text : defaultPic} />
    //       </div>
    //     );
    //   },
    // },
  ];
}

// function filterCategoryTree(list: Array): Array {
//   return list.map((item) => {
//     item.key = item.value = item.id;
//     item.title = item.name;
//     if (item.children && item.children.length > 0) {
//       filterCategoryTree(item.children);
//     }
//     return item;
//   });
// }

export function getFormConfig(): Partial<FormProps> {
  return {
    labelWidth: 70,
    baseColProps: { span: 6 },
    schemas: [
      {
        field: `productName`,
        label: `产品名称`,
        component: 'Input',
      },
      {
        field: `model`,
        label: `产品型号`,
        component: 'Input',
      },
      {
        field: `manufacturerName`,
        label: `厂商名称`,
        component: 'Input',
      },
    ],
  };
}

export const deviceType = [
  {
    label: '网关子设备',
    value: 'childrenDevice',
  },
  {
    label: '直连设备',
    value: 'device',
  },
  {
    label: '网关设备',
    value: 'gateway',
  },
];

export const productTypeList = [
  {
    label: '直连设备',
    value: 'COMMON',
  },
  {
    label: '网关设备',
    value: 'GATEWAY',
  },
  {
    label: '网关子设备',
    value: 'SUBSET',
  },
  {
    label: '视频设备',
    value: 'VIDEO_COMMON',
  },
];

export const statusList = [
  {
    label: '启用',
    value: '0',
  },
  {
    label: '停用',
    value: '1',
  },
];

export const dataTypeList = [
  {
    label: 'JSON',
    value: 'JSON',
  },
  {
    label: '二进制（BINARY）',
    value: 'BINARY',
  },
];

/** 工业轮询协议：物模型以属性为主，点位映射在设备侧配置；无需 JS 协议脚本 */
export const INDUSTRIAL_PROTOCOLS = ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA', 'MODBUS'];

export function isIndustrialProtocol(protocolType?: string) {
  return INDUSTRIAL_PROTOCOLS.includes(String(protocolType || '').toUpperCase());
}


export const protoTypeList = [
  {
    label: 'MQTT',
    value: 'MQTT',
  },
  {
    label: 'HTTP',
    value: 'HTTP',
  },
  {
    label: 'TCP',
    value: 'TCP',
  },
  {
    label: 'WEBSOCKET',
    value: 'WEBSOCKET',
  },
  {
    label: 'Modbus TCP',
    value: 'MODBUS_TCP',
  },
  {
    label: 'Modbus RTU',
    value: 'MODBUS_RTU',
  },
  {
    label: 'OPC UA',
    value: 'OPCUA',
  },
  {
    label: 'GB28181',
    value: 'GB28181',
  },
];

export const encryptMethodList = [
  {
    label: '明文',
    value: '0',
  },
  {
    label: 'SM4',
    value: '1',
  },
  {
    label: 'AES',
    value: '2',
  },
];

export const authModeList = [
  { label: '用户名密码', value: 'USERNAME_PASSWORD' },
  { label: 'Access Token', value: 'ACCESS_TOKEN' },
  { label: '证书认证', value: 'CERTIFICATE' },
];

export function createEmptyProduct() {
  return {
    id: '',
    appId: '',
    productName: '',
    productIdentification: '',
    productType: '',
    manufacturerId: '',
    manufacturerName: '',
    model: '',
    dataFormat: 'JSON',
    deviceType: '',
    protocolType: 'MQTT',
    encryptKey: '',
    encryptVector: '',
    status: '0',
    remark: '',
    authMode: '',
    userName: '',
    password: '',
    connector: '',
    signKey: '',
    encryptMethod: '0',
  };
}

export const productModel = createEmptyProduct();

// 设备接入
export function deviceAccessFormSchemas() {
  return [
    {
      field: 'appId',
      label: '应用场景',
      component: 'Input',
    },
    {
      field: 'deviceName',
      label: '设备名称',
      component: 'Input',
    },
    {
      field: `connectStatus`,
      label: `连接状态`,
      component: 'Select',
      componentProps: {
        options: [
          { value: '', label: '全部' },
          { value: 'ONLINE', label: '在线' },
          { value: 'OFFLINE', label: '离线' },
        ],
      },
      defaultValue: '',
    },
  ];
}

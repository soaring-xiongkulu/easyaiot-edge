import type { AccessGuideProps, AccessNodeType, CredRow, GuideTopicRow } from './types';

const PLACEHOLDER_DEVICE = '<设备标识>';

export function normalizeNodeType(type?: string): AccessNodeType {
  const t = String(type || 'COMMON').toUpperCase();
  if (t === 'GATEWAY' || t === 'SUBSET' || t === 'VIDEO_COMMON' || t === 'COMMON') {
    return t;
  }
  return 'COMMON';
}

export function nodeTypeLabel(type?: string): string {
  switch (normalizeNodeType(type)) {
    case 'GATEWAY':
      return '网关设备';
    case 'SUBSET':
      return '网关子设备';
    case 'VIDEO_COMMON':
      return '视频设备';
    default:
      return '直连设备';
  }
}

export function resolveIds(props: AccessGuideProps) {
  const productId = props.productIdentification?.trim() || '<产品标识>';
  const deviceId =
    props.scope === 'device' && props.deviceIdentification?.trim()
      ? props.deviceIdentification.trim()
      : PLACEHOLDER_DEVICE;
  const tenantId = props.tenantId ?? 1;
  return { productId, deviceId, tenantId };
}

/** MQTT 用户名：deviceIdentification&productIdentification */
export function buildMqttUsername(productId: string, deviceId: string): string {
  return `${deviceId}&${productId}`;
}

function topic(productId: string, deviceId: string, suffix: string): string {
  return `/iot/${productId}/${deviceId}${suffix}`;
}

/** 直连 / 网关自身数据面 Topic */
export function buildDirectTopics(productId: string, deviceId: string): GuideTopicRow[] {
  return [
    {
      group: '属性',
      direction: '上行',
      desc: '属性上报（影子 / 运行状态 / 时序入库）',
      topic: topic(productId, deviceId, '/property/upstream/report'),
    },
    {
      group: '属性',
      direction: '下行',
      desc: '云端设置属性期望值',
      topic: topic(productId, deviceId, '/property/downstream/desired/set'),
    },
    {
      group: '属性',
      direction: '上行',
      desc: '设备回复属性期望设置 ACK',
      topic: topic(productId, deviceId, '/property/upstream/desired/set/ack'),
    },
    {
      group: '服务',
      direction: '下行',
      desc: '云端调用设备服务（{identifier} 为服务标识）',
      topic: topic(productId, deviceId, '/service/downstream/invoke/{identifier}'),
    },
    {
      group: '服务',
      direction: '上行',
      desc: '设备应答服务调用',
      topic: topic(productId, deviceId, '/service/upstream/invoke/{identifier}/response'),
    },
    {
      group: '事件',
      direction: '上行',
      desc: '事件上报',
      topic: topic(productId, deviceId, '/event/upstream/report/{identifier}'),
    },
    {
      group: '日志',
      direction: '上行',
      desc: '设备日志上报',
      topic: topic(productId, deviceId, '/log/upstream/report'),
    },
    {
      group: '影子',
      direction: '上行',
      desc: '设备上报影子状态',
      topic: topic(productId, deviceId, '/shadow/upstream/report'),
    },
    {
      group: '影子',
      direction: '下行',
      desc: '云端推送影子期望值',
      topic: topic(productId, deviceId, '/shadow/downstream/desired'),
    },
  ];
}

/** 网关拓扑 + 子设备代理 Topic（路径永远是网关） */
export function buildGatewayProxyTopics(gwProductId: string, gwDeviceId: string): GuideTopicRow[] {
  return [
    {
      group: '拓扑',
      direction: '上行',
      desc: '添加 / 发现子设备（可自动建档并绑定所属网关）',
      topic: topic(gwProductId, gwDeviceId, '/topo/upstream/add'),
    },
    {
      group: '拓扑',
      direction: '上行',
      desc: '删除子设备拓扑关系（不解绑设备档案）',
      topic: topic(gwProductId, gwDeviceId, '/topo/upstream/delete'),
    },
    {
      group: '拓扑',
      direction: '上行',
      desc: '上报子设备在线 / 离线状态',
      topic: topic(gwProductId, gwDeviceId, '/topo/upstream/status'),
    },
    {
      group: '子设备代理',
      direction: '上行',
      desc: '代报子设备属性（payload 带子设备产品/设备标识）',
      topic: topic(gwProductId, gwDeviceId, '/sub/property/upstream/report'),
    },
    {
      group: '子设备代理',
      direction: '上行',
      desc: '代报子设备事件',
      topic: topic(gwProductId, gwDeviceId, '/sub/event/upstream/report/{identifier}'),
    },
    {
      group: '子设备代理',
      direction: '下行',
      desc: '云端经网关调用子设备服务（网关需订阅）',
      topic: topic(gwProductId, gwDeviceId, '/sub/service/downstream/invoke/{identifier}'),
    },
    {
      group: '子设备代理',
      direction: '上行',
      desc: '网关代回子设备服务响应',
      topic: topic(gwProductId, gwDeviceId, '/sub/service/upstream/invoke/{identifier}/response'),
    },
    {
      group: '子设备代理',
      direction: '下行',
      desc: '云端经网关设置子设备属性期望值',
      topic: topic(gwProductId, gwDeviceId, '/sub/property/downstream/desired/set'),
    },
    {
      group: '子设备代理',
      direction: '上行',
      desc: '网关代回属性期望设置 ACK',
      topic: topic(gwProductId, gwDeviceId, '/sub/property/upstream/desired/set/ack'),
    },
  ];
}

export function buildCredentials(props: AccessGuideProps): CredRow[] {
  const { productId, deviceId } = resolveIds(props);
  const nodeType = normalizeNodeType(props.nodeType);
  const password = props.password && props.password !== '--' ? props.password : '<产品/设备密码>';
  const username =
    props.userName && props.userName !== '--' && props.scope === 'device'
      ? props.userName
      : buildMqttUsername(productId, deviceId);
  const connector =
    props.connector && props.connector !== '--' ? props.connector : '平台 EMQX（默认 TCP 1883）';

  if (nodeType === 'SUBSET') {
    const parent = props.parentIdentification?.trim() || '<所属网关设备标识>';
    return [
      {
        label: '建连主体',
        value: '所属网关（子设备本身通常不直连 MQTT）',
        hint: '子设备数据由网关在 /iot/{网关产品}/{网关设备}/sub/... 上代发代收',
      },
      {
        label: '所属网关',
        value: parent,
        copyable: !!props.parentIdentification?.trim(),
        hint: '对应设备表 parent_identification；可在「基础信息」或网关「子设备」中查看绑定',
      },
      {
        label: '子设备产品标识',
        value: productId,
        copyable: productId !== '<产品标识>',
      },
      {
        label: '子设备设备标识',
        value: deviceId,
        copyable: deviceId !== PLACEHOLDER_DEVICE,
        hint: '写入代理 Topic 的 JSON params，而不是 Topic 路径',
      },
    ];
  }

  if (nodeType === 'VIDEO_COMMON') {
    return [
      {
        label: '接入方式',
        value: '视频类设备通常走摄像头 / 国标接入，而非本文 MQTT 物模型 Topic',
        hint: '请到「摄像头管理」或国标相关页面查看 RTSP / GB28181 接入参数',
      },
      {
        label: '产品标识',
        value: productId,
        copyable: productId !== '<产品标识>',
      },
      {
        label: '设备标识',
        value: deviceId,
        copyable: deviceId !== PLACEHOLDER_DEVICE,
      },
    ];
  }

  return [
    {
      label: 'MQTT Broker',
      value: connector,
      hint: '请使用设备可达的 EMQX 地址；本地联调常见 localhost:1883',
    },
    {
      label: '端口',
      value: '1883（TCP，按部署可能调整）',
    },
    {
      label: 'Username',
      value: username,
      copyable: true,
      hint: '格式固定为：设备标识&产品标识',
    },
    {
      label: 'Password',
      value: password,
      copyable: password !== '<产品/设备密码>',
      hint: '使用产品或设备上配置的密码；EMQX 需开启设备 HTTP 鉴权',
    },
    {
      label: 'ClientId',
      value: `${productId}.${deviceId}`,
      copyable: productId !== '<产品标识>' && deviceId !== PLACEHOLDER_DEVICE,
      hint: '建议唯一；多连接演示可用自定义前缀，鉴权主要看 Username + Password',
    },
    {
      label: '产品标识',
      value: productId,
      copyable: productId !== '<产品标识>',
    },
    {
      label: '设备标识',
      value: deviceId,
      copyable: deviceId !== PLACEHOLDER_DEVICE,
      hint:
        props.scope === 'product'
          ? '产品详情下为占位符；请替换为真实设备标识，或先在「关联设备」中创建设备'
          : undefined,
    },
  ];
}

export function propertyReportPayload(tenantId: number | string): string {
  return JSON.stringify(
    {
      tenantId: Number(tenantId) || 1,
      requestId: 'a1b2c3d4e5f60718',
      method: 'thing.property.post',
      params: {
        temperature: 23.5,
        humidity: 56.2,
      },
    },
    null,
    2,
  );
}

export function gatewayTopoAddPayload(
  tenantId: number | string,
  subProductId: string,
  subDeviceId: string,
  subName?: string,
): string {
  const name = subName || '演示子设备';
  return JSON.stringify(
    {
      tenantId: Number(tenantId) || 1,
      requestId: 'topo-add-0001',
      method: 'thing.topology.add',
      params: {
        deviceInfos: [
          {
            productIdentification: subProductId || '<子设备产品标识>',
            deviceIdentification: subDeviceId || '<子设备标识>',
            deviceName: name,
            name,
          },
        ],
      },
    },
    null,
    2,
  );
}

export function gatewaySubPropertyPayload(
  tenantId: number | string,
  subProductId: string,
  subDeviceId: string,
): string {
  return JSON.stringify(
    {
      tenantId: Number(tenantId) || 1,
      requestId: 'sub-prop-0001',
      method: 'thing.property.post',
      params: {
        productIdentification: subProductId || '<子设备产品标识>',
        deviceIdentification: subDeviceId || '<子设备标识>',
        properties: {
          temperature: 26.1,
          humidity: 48,
        },
      },
    },
    null,
    2,
  );
}

export interface JourneyStep {
  index: string;
  title: string;
  desc: string;
}

export function buildJourney(props: AccessGuideProps): JourneyStep[] {
  const nodeType = normalizeNodeType(props.nodeType);
  if (nodeType === 'GATEWAY') {
    return [
      {
        index: '01',
        title: '填子设备产品',
        desc: '在「快速联调」填写 SUBSET 产品标识与子设备标识',
      },
      {
        index: '02',
        title: '跑 06 代报',
        desc: '复制 06 命令：topo 建档 + 周期代报，子设备影子可见',
      },
      {
        index: '03',
        title: '跑 07 听下行',
        desc: '另开终端跑 07，订阅网关 /sub/#',
      },
      {
        index: '04',
        title: '页面验收',
        desc: '对子设备功能调用，看 07 终端打印并回执成功',
      },
    ];
  }
  if (nodeType === 'SUBSET') {
    return [
      {
        index: '01',
        title: '填所属网关',
        desc: '快速联调填写网关产品/设备标识（设备标识常已预填）',
      },
      {
        index: '02',
        title: '网关跑 06',
        desc: '用网关身份代报本设备，自动建档并刷新影子',
      },
      {
        index: '03',
        title: '网关跑 07',
        desc: '订阅代理下行，准备接收云端对子设备的指令',
      },
      {
        index: '04',
        title: '本页下发',
        desc: '功能调用下发后，在 07 终端看到 /sub/... 下行',
      },
    ];
  }
  if (nodeType === 'VIDEO_COMMON') {
    return [
      {
        index: '01',
        title: '选择视频接入',
        desc: '按摄像头 RTSP / 国标 GB28181 等协议接入',
      },
      {
        index: '02',
        title: '完成媒体链路',
        desc: '在摄像头或国标管理中配置推流 / 拉流参数',
      },
      {
        index: '03',
        title: '（可选）物模型',
        desc: '若需 MQTT 物模型能力，再参考直连 Topic / 快速联调',
      },
    ];
  }
  return [
    {
      index: '01',
      title: '复制 01 命令',
      desc: '快速联调一键生成，填好产品/设备/密码',
    },
    {
      index: '02',
      title: '看影子上线',
      desc: '设备影子 params 刷新，连接状态 ONLINE',
    },
    {
      index: '03',
      title: '再开 02 听下行',
      desc: '功能调用后终端打印下行 Topic 并 ACK',
    },
    {
      index: '04',
      title: '可选 03 闭环',
      desc: '单进程上下行；或写 .env 后 start_mqtt_demo.sh',
    },
  ];
}

export const INDUSTRIAL_PROTOCOLS = ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'] as const;

export function isIndustrialProtocol(protocolType?: string): boolean {
  return INDUSTRIAL_PROTOCOLS.includes(String(protocolType || '').toUpperCase() as any);
}

export function industrialProtocolLabel(protocolType?: string): string {
  const type = String(protocolType || '').toUpperCase();
  if (type === 'MODBUS_TCP') return 'Modbus TCP';
  if (type === 'MODBUS_RTU') return 'Modbus RTU';
  if (type === 'OPCUA') return 'OPC UA';
  return protocolType || '工业协议';
}

/** 工业协议接入指引步骤（参考 Modbus 设备测试） */
export function buildIndustrialGuideSteps(protocolType?: string): Array<{
  index: string;
  title: string;
  desc: string;
}> {
  const type = String(protocolType || '').toUpperCase();
  if (type === 'MODBUS_RTU') {
    return [
      { index: '01', title: '配置串口参数', desc: '填写 Sink 主机可见串口（如 /dev/ttyUSB0），波特率/校验与从站一致' },
      { index: '02', title: '配置采集点位', desc: '绑定物模型属性，并填写功能区、地址、数据类型' },
      { index: '03', title: '测试连接', desc: '仅验证串口可打开，不校验站号与寄存器' },
      { index: '04', title: '验收采集', desc: 'Sink 周期轮询后运行状态有值，设备变为 ONLINE' },
      { index: '05', title: '可写点位下发', desc: '在「寄存器操作」写入保持寄存器/线圈并核对设备侧值' },
    ];
  }
  if (type === 'OPCUA') {
    return [
      { index: '01', title: '填写 Endpoint', desc: '如 opc.tcp://192.168.1.100:4840；匿名可留空用户名密码' },
      { index: '02', title: '配置 NodeId 点位', desc: 'NodeId 与现场一致，并绑定产品物模型属性' },
      { index: '03', title: '启用 Sink OPC UA', desc: 'basiclab.iot.sink.protocol.opcua.enabled=true' },
      { index: '04', title: '验收采集', desc: '运行状态/点位影子刷新，设备 ONLINE' },
      { index: '05', title: '可写节点下发', desc: '在「寄存器操作」向可写 NodeId 写入并核对' },
    ];
  }
  return [
    { index: '01', title: '配置主机端口', desc: '填写设备或串口服务器 IP，端口通常 502，站号通常 1' },
    { index: '02', title: '配置采集点位', desc: '绑定物模型属性，并填写功能区、地址、数据类型' },
    { index: '03', title: '测试连接', desc: '验证 TCP 端口可达，不校验具体寄存器地址' },
    { index: '04', title: '验收采集', desc: 'Sink 周期轮询后运行状态有值，设备变为 ONLINE' },
    { index: '05', title: '可写点位下发', desc: '在「寄存器操作」写入并在属性历史查看寄存器值/PDU' },
  ];
}

export function buildIndustrialVerifySteps(protocolType?: string): string[] {
  const label = industrialProtocolLabel(protocolType);
  return [
    `产品协议类型为 ${label}，设备连接参数与点位已保存并可回显`,
    '「测试连接」结果符合预期（TCP 可达 / 串口可开；OPC UA 以采集为准）',
    'Sink 对应协议开关已启用，设备 ONLINE 且运行状态有最新值',
    '可写点位经「寄存器操作」写入成功；采集事件/通信日志有记录',
    '属性历史可展示解析值；Modbus 可额外看到寄存器值与原始 PDU',
  ];
}

export function buildIndustrialNotes(protocolType?: string): string[] {
  const type = String(protocolType || '').toUpperCase();
  if (type === 'MODBUS_RTU') {
    return [
      'Sink 进程必须能访问串口；容器部署需映射设备节点',
      '同一 RS-485 总线上站号必须唯一（常用 1-247）',
      '详细步骤见仓库 .scripts/industrial-README.md 与 modbus-rtu-demo',
    ];
  }
  if (type === 'OPCUA') {
    return [
      'Endpoint 需从 Sink 所在网络可达',
      '点位需绑定物模型属性（propertyCode）；旧配置仅有 identifier 时仍兼容',
      '匿名访问可留空用户名密码；需鉴权时填写服务器账号',
    ];
  }
  return [
    '容器内勿用 127.0.0.1 指向宿主机设备，应使用宿主机 IP 或 host 网络',
    '点位需绑定物模型属性（propertyCode）；旧配置仅有 identifier 时仍兼容',
    '详细步骤见仓库 .scripts/industrial-README.md 与各协议 demo',
  ];
}

export function overviewAlert(props: AccessGuideProps): { type: 'info' | 'warning' | 'success'; message: string } {
  const nodeType = normalizeNodeType(props.nodeType);
  const name = props.scope === 'device' ? props.deviceName || '当前设备' : props.productName || '当前产品';
  if (isIndustrialProtocol(props.protocolType)) {
    const label = industrialProtocolLabel(props.protocolType);
    return {
      type: 'info',
      message: `${name} 使用 ${label} 工业协议：由 Sink 主动轮询采集，无需设备侧 MQTT 连接。请在设备编辑中配置连接参数与点位，并确保 Sink 协议开关已启用。`,
    };
  }
  if (nodeType === 'GATEWAY') {
    return {
      type: 'info',
      message: `${name} 为网关：仅网关持有 MQTT 连接；子设备通过拓扑与 /sub 代理 Topic 接入。路径上的产品/设备永远是网关自身。`,
    };
  }
  if (nodeType === 'SUBSET') {
    const parent = props.parentIdentification?.trim();
    return {
      type: 'warning',
      message: parent
        ? `${name} 为网关子设备，通常不直连 MQTT。所属网关：${parent}。请确保该网关在线并已订阅 /sub/... 下行。`
        : `${name} 为网关子设备，通常不直连 MQTT。请先绑定所属网关，或由网关通过 topo/add、代报属性自动建档绑定。`,
    };
  }
  if (nodeType === 'VIDEO_COMMON') {
    return {
      type: 'info',
      message: `${name} 为视频设备，主接入路径一般是摄像头 / 国标，而非标准 MQTT 物模型 Topic。下方仅作对照说明。`,
    };
  }
  return {
    type: 'success',
    message: `${name} 为直连设备：设备自行连接 EMQX，Topic 路径使用本产品/本设备标识 /iot/{产品标识}/{设备标识}/...`,
  };
}

export function buildVerifySteps(props: AccessGuideProps): string[] {
  const nodeType = normalizeNodeType(props.nodeType);
  if (nodeType === 'GATEWAY') {
    return [
      '快速联调已填写 SUBSET 子设备产品，并复制运行 06',
      '网关在线；「子设备」Tab 出现 --sub-device',
      '打开子设备影子 / 运行状态随 06 刷新',
      '另开终端跑 07 后，对子设备「功能调用」能在 07 终端看到 /sub/... 下行',
    ];
  }
  if (nodeType === 'SUBSET') {
    return [
      '快速联调已填写所属网关产品/设备，并复制运行 06',
      '本设备影子 / 运行状态有代报数据',
      '07 保持运行时，本页「功能调用」下行出现在网关终端',
      '指令日志状态可到 SUCCESS（依赖 07 自动 ACK）',
    ];
  }
  if (nodeType === 'VIDEO_COMMON') {
    return [
      '在摄像头 / 国标管理中完成媒体接入',
      '预览或录像链路可通',
      '若同时启用物模型，再按直连 Topic / 快速联调验证 MQTT',
    ];
  }
  return [
    '复制运行 01 后，影子 params 刷新且设备 ONLINE',
    '另开终端跑 02（或直接用 03），功能调用能打印下行',
    '（可选）写 .env 后 bash start_mqtt_demo.sh 常驻演示',
    '（可选）私有协议：产品启用协议脚本后再跑 04/05',
  ];
}

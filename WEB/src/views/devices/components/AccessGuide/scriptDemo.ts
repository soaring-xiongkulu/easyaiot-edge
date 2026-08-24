import type { AccessGuideProps } from './types';
import { normalizeNodeType, resolveIds } from './guideContent';

export interface ScriptDemoOptions {
  host: string;
  port: number | string;
  authMode: 'device' | 'broker';
  tenantId: number | string;
  /** 网关脚本：子设备产品/设备；直连不需要 */
  subProduct?: string;
  subDevice?: string;
  subName?: string;
  /** 子设备视角：所属网关产品/设备 */
  gatewayProduct?: string;
  gatewayDevice?: string;
  /** 设备数字主键（07 --invoke-api 可选） */
  deviceNumericId?: string;
}

export interface DemoCommandCard {
  id: string;
  step: string;
  title: string;
  goal: string;
  script: string;
  command: string;
  accept: string;
  recommended?: boolean;
  optional?: boolean;
}

const DEMO_DIR = '.scripts/mqtt-demo';

function shellQuote(value: string): string {
  if (!value) return "''";
  if (/^[A-Za-z0-9_./:@%=+-]+$/.test(value)) return value;
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

function baseFlags(opts: ScriptDemoOptions, product: string, device: string): string {
  const parts = [
    `--host ${shellQuote(String(opts.host || 'localhost'))}`,
    `--port ${shellQuote(String(opts.port || 1883))}`,
    `--product ${shellQuote(product)}`,
    `--device ${shellQuote(device)}`,
    `--tenant-id ${shellQuote(String(opts.tenantId || 1))}`,
  ];
  if (opts.authMode === 'broker') {
    parts.push('--auth-mode broker');
    parts.push('--password 123456');
  } else {
    // password 由调用方追加
  }
  return parts.join(' \\\n  ');
}

function withPassword(flags: string, password: string, authMode: 'device' | 'broker'): string {
  if (authMode === 'broker') return flags;
  const pwd = password && password !== '--' ? password : '<密码>';
  return `${flags} \\\n  --password ${shellQuote(pwd)}`;
}

export function buildPrepCommands(): { title: string; command: string; hint: string }[] {
  return [
    {
      title: '进入脚本目录',
      command: `cd ${DEMO_DIR}`,
      hint: '相对仓库根目录；也可写绝对路径',
    },
    {
      title: '安装依赖（仅首次）',
      command: 'pip install paho-mqtt',
      hint: '或：python3 -m pip install paho-mqtt',
    },
  ];
}

export function resolveDemoIdentities(props: AccessGuideProps, opts: ScriptDemoOptions) {
  const nodeType = normalizeNodeType(props.nodeType);
  const { productId, deviceId, tenantId } = resolveIds(props);
  const password =
    props.password && props.password !== '--' ? String(props.password) : '<密码>';

  if (nodeType === 'SUBSET') {
    const gwProduct = opts.gatewayProduct?.trim() || '<网关产品标识>';
    const gwDevice =
      opts.gatewayDevice?.trim() ||
      props.parentIdentification?.trim() ||
      '<网关设备标识>';
    return {
      nodeType,
      connectProduct: gwProduct,
      connectDevice: gwDevice,
      subProduct: productId,
      subDevice: deviceId === '<设备标识>' ? opts.subDevice || 'demo-sub-001' : deviceId,
      subName: props.deviceName || opts.subName || '演示子设备',
      password,
      tenantId: opts.tenantId || tenantId,
    };
  }

  if (nodeType === 'GATEWAY') {
    return {
      nodeType,
      connectProduct: productId,
      connectDevice: deviceId,
      subProduct: opts.subProduct?.trim() || '<子设备产品标识>',
      subDevice: opts.subDevice?.trim() || 'demo-sub-001',
      subName: opts.subName?.trim() || '演示子设备-001',
      password,
      tenantId: opts.tenantId || tenantId,
    };
  }

  return {
    nodeType,
    connectProduct: productId,
    connectDevice: deviceId,
    subProduct: '',
    subDevice: '',
    subName: '',
    password,
    tenantId: opts.tenantId || tenantId,
  };
}

export function buildDemoCommandCards(
  props: AccessGuideProps,
  opts: ScriptDemoOptions,
): DemoCommandCard[] {
  const nodeType = normalizeNodeType(props.nodeType);
  if (nodeType === 'VIDEO_COMMON') return [];

  const id = resolveDemoIdentities(props, opts);
  const flags = withPassword(
    baseFlags(opts, id.connectProduct, id.connectDevice),
    id.password,
    opts.authMode,
  );

  if (nodeType === 'GATEWAY' || nodeType === 'SUBSET') {
    const subFlags = [
      flags,
      `--sub-product ${shellQuote(id.subProduct)}`,
      `--sub-device ${shellQuote(id.subDevice)}`,
      `--sub-name ${shellQuote(id.subName)}`,
    ].join(' \\\n  ');

    const cards: DemoCommandCard[] = [
      {
        id: 'gw-up',
        step: '01',
        title: '网关代报子设备（推荐先跑）',
        goal: '网关建连 → topo 添加子设备 → 周期代报属性，子设备影子可见',
        script: '06_gateway_uplink_subdevice.py',
        command: `python3 06_gateway_uplink_subdevice.py \\\n  ${subFlags}`,
        accept: '网关「子设备」Tab 出现设备；打开子设备看影子 / 运行状态刷新；网关在线',
        recommended: true,
      },
      {
        id: 'gw-down',
        step: '02',
        title: '网关代收下发并自动 ACK',
        goal: '订阅 /sub/#，Web 对子设备「功能调用」时网关终端打印下行并回执',
        script: '07_gateway_downlink_subdevice.py',
        command: `python3 07_gateway_downlink_subdevice.py \\\n  ${subFlags}`,
        accept: '另开终端保持运行 → 子设备详情「功能调用」下发 → 本终端出现 /sub/... 下行',
        recommended: true,
      },
    ];

    // 网关自身也可先用直连脚本验证连通
    if (nodeType === 'GATEWAY' && id.connectDevice !== '<设备标识>') {
      cards.push({
        id: 'gw-self-up',
        step: '可选',
        title: '仅验证网关自身上行',
        goal: '不涉及子设备，确认网关 MQTT 鉴权与 Topic 通路',
        script: '01_uplink_property.py',
        command: `python3 01_uplink_property.py \\\n  ${flags}`,
        accept: '网关详情「设备影子」params 刷新，连接状态 ONLINE',
        optional: true,
      });
    }
    return cards;
  }

  // COMMON / 产品直连
  return [
    {
      id: 'up',
      step: '01',
      title: '属性上行（最快上线）',
      goal: '模拟设备周期上报，让影子 / 运行状态 / 在线状态立刻有数',
      script: '01_uplink_property.py',
      command: `python3 01_uplink_property.py \\\n  ${flags}`,
      accept: '设备详情 → 影子 / 运行状态有数据；列表显示在线',
      recommended: true,
    },
    {
      id: 'down',
      step: '02',
      title: '下行监听 + 自动回执',
      goal: '订阅下行 Topic；页面「功能调用」后终端打印并 ACK',
      script: '02_downlink_listen.py',
      command: `python3 02_downlink_listen.py \\\n  ${flags}`,
      accept: '另开终端运行 → 功能调用下发服务 → 终端打印下行 Topic',
      recommended: true,
    },
    {
      id: 'full',
      step: '03',
      title: '上下行同进程（一键闭环）',
      goal: '单进程同时上报并监听下行，适合快速演示',
      script: '03_full_loop.py',
      command: `python3 03_full_loop.py \\\n  ${flags}`,
      accept: '影子持续刷新；功能调用能在同一终端看到下行',
      optional: true,
    },
    {
      id: 'codec-up',
      step: '进阶',
      title: '私有协议上行（需协议脚本）',
      goal: '发送 EA|… 紧凑文本；产品需先启用「紧凑文本」协议脚本',
      script: '04_codec_uplink.py',
      command: `python3 04_codec_uplink.py \\\n  ${flags}`,
      accept: '产品「协议脚本」已启用；影子出现属性；sink 日志含 JS 上行解码',
      optional: true,
    },
    {
      id: 'codec-down',
      step: '进阶',
      title: '私有协议下行',
      goal: '接收 EA|DN|… 非 JSON 下行并自动 ACK',
      script: '05_codec_downlink.py',
      command: `python3 05_codec_downlink.py \\\n  ${flags}`,
      accept: '功能调用后终端打印 EA|DN|...（不是 JSON）',
      optional: true,
    },
  ];
}

export function buildEnvFileContent(
  props: AccessGuideProps,
  opts: ScriptDemoOptions,
): string {
  const id = resolveDemoIdentities(props, opts);
  const nodeType = normalizeNodeType(props.nodeType);
  const lines = [
    `# 由接入指引根据当前${props.scope === 'product' ? '产品' : '设备'}生成`,
    `# 保存为 .scripts/mqtt-demo/.env 后执行: bash start_mqtt_demo.sh`,
    `MQTT_HOST=${opts.host || 'localhost'}`,
    `MQTT_PORT=${opts.port || 1883}`,
    `PRODUCT=${id.connectProduct}`,
    `DEVICE=${id.connectDevice}`,
    `TENANT_ID=${id.tenantId || 1}`,
    `PASSWORD=${id.password === '<密码>' ? '' : id.password}`,
    `AUTH_MODE=${opts.authMode}`,
  ];

  if (nodeType === 'GATEWAY' || nodeType === 'SUBSET') {
    lines.push(`MQTT_DEMO_SCRIPTS=gw-up,gw-down`);
    lines.push(`SUB_PRODUCT=${id.subProduct}`);
    lines.push(`SUB_DEVICE=${id.subDevice}`);
    lines.push(`SUB_NAME=${id.subName}`);
    lines.push(`GATEWAY_PRODUCT=${id.connectProduct}`);
    lines.push(`GATEWAY_DEVICE=${id.connectDevice}`);
  } else {
    lines.push(`MQTT_DEMO_SCRIPTS=up,down,full`);
  }

  if (opts.deviceNumericId) {
    lines.push(`DEVICE_ID=${opts.deviceNumericId}`);
  }
  lines.push(`MQTT_DEMO_INTERVAL=3`);
  return lines.join('\n') + '\n';
}

export function buildStartAllCommand(): string {
  return 'bash start_mqtt_demo.sh';
}

export function quickPathSummary(nodeType: string): string {
  const t = normalizeNodeType(nodeType);
  if (t === 'GATEWAY') {
    return '推荐：先跑 06 代报建档 → 再跑 07 听下行 → Web 对子设备功能调用验收。';
  }
  if (t === 'SUBSET') {
    return '子设备不直连：用所属网关身份跑 06/07，--sub-* 填本设备标识。';
  }
  if (t === 'VIDEO_COMMON') {
    return '视频设备请走摄像头 / 国标接入；mqtt-demo 不覆盖媒体链路。';
  }
  return '推荐：先 01 看影子上线 → 再 02 听下行 → 需要时用 03 一键闭环。';
}

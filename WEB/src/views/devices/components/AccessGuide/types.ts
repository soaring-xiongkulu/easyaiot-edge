/** 产品 / 设备节点类型（与库字段 product_type / device_type 一致） */
export type AccessNodeType = 'COMMON' | 'GATEWAY' | 'SUBSET' | 'VIDEO_COMMON' | string;

export interface AccessGuideProps {
  /** product：产品详情；device：设备详情 */
  scope: 'product' | 'device';
  nodeType: AccessNodeType;
  productIdentification?: string;
  /** 设备标识；产品详情可为空，界面用占位符 */
  deviceIdentification?: string;
  deviceName?: string;
  productName?: string;
  password?: string;
  userName?: string;
  connector?: string;
  /** 子设备所属网关 deviceIdentification */
  parentIdentification?: string;
  protocolType?: string;
  tenantId?: number | string;
  /** 设备数字主键（设备详情路由 id，供脚本 DEVICE_ID / invoke-api） */
  deviceNumericId?: string;
}

export interface GuideTopicRow {
  topic: string;
  direction: '上行' | '下行';
  desc: string;
  group: string;
}

export interface CredRow {
  label: string;
  value: string;
  hint?: string;
  copyable?: boolean;
}

/** EasyAIoT 内置 Node-RED 演示规则链（与 .scripts/node-red 种子一致，只读） */

export const NODERED_DEMO_FLOW_IDS = new Set<string>([
  'easyaiot_demo_telemetry',
  'easyaiot_demo_alert',
  'easyaiot_demo_bridge',
  'easyaiot_demo_vision',
])

export const NODERED_DEMO_FLOW_LABELS = new Set<string>([
  '设备遥测采集链路',
  '告警分级推送链路',
  '工控协议桥接链路',
  '视觉质检联动链路',
])

export interface NodeRedDemoFlowLike {
  id?: string | number | null
  label?: string | null
  name?: string | null
}

/** 是否为内置演示规则链（禁止编辑/删除） */
export function isNodeRedDemoFlow(flow?: NodeRedDemoFlowLike | null): boolean {
  if (!flow) return false
  const id = String(flow.id ?? '').trim()
  if (id && NODERED_DEMO_FLOW_IDS.has(id)) {
    return true
  }
  const label = String(flow.label || flow.name || '').trim()
  return !!label && NODERED_DEMO_FLOW_LABELS.has(label)
}

/** 物模型 IoT 能力已移除；保留与表格/卡片相同的返回结构，避免改动上层组件。 */
export function getDevicethingModels(_params?: Record<string, unknown>) {
  return Promise.resolve({ data: [], total: 0 });
}

export function getDevicethingmodelsHistory(_params?: Record<string, unknown>) {
  return Promise.resolve({ data: [], total: 0 });
}

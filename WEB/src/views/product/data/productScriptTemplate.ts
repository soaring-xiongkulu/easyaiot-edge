/**
 * 产品协议脚本默认骨架（与 iot-sink ProductScriptTemplates.SKELETON 保持一致）
 */
export const DEFAULT_SCRIPT_SKELETON = `/**
 * 产品私有协议编解码脚本
 *
 * rawDataToProtocol(topic, bytes)
 *   上行解码：设备原始字节 → 平台标准 JSON（返回 byte[]）
 *
 * protocolToRawData(topic, message)
 *   下行编码：平台标准消息 → 设备原始字节（返回 byte[] 或 UTF-8 字符串）
 *
 * 平台标准消息字段：tenantId, requestId, method, params, data, code, msg
 * 常用辅助：jsUtil.toStandardMessage / toJsonString / utf8Bytes / bytesToUtf8
 * 非本协议可 return bytes 透传，兼容设备已发标准 JSON 的场景
 */

/** 上行：设备 → 平台 */
function rawDataToProtocol(topic, bytes) {
  // TODO: 解析设备上行原始数据
  // var text = jsUtil.bytesToUtf8(bytes);
  // var params = jsUtil.newMap();
  // params.put('key', 'value');
  // return jsUtil.toStandardMessage(1, 'req001', 'thing.property.post', params);
  return bytes;
}

/** 下行：平台 → 设备 */
function protocolToRawData(topic, message) {
  // TODO: 将平台下行消息编码为设备协议
  // var params = message.params || message.get('params');
  // var payload = jsUtil.toJsonString(params);
  // return jsUtil.utf8Bytes(payload);
  return jsUtil.utf8Bytes(jsUtil.toJsonString(message));
}
`;

export function resolveScriptContent(content?: string | null): string {
  return content?.trim() ? content : DEFAULT_SCRIPT_SKELETON;
}

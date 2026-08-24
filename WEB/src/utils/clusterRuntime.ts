/**
 * 集群工作负载运行节点展示（7 大能力统一格式）
 */
export interface ClusterRuntimeRecord {
  schedule_policy?: string | null;
  node_id?: number | string | null;
  target_node_id?: number | string | null;
  service_server_ip?: string | null;
  server_ip?: string | null;
  assigned_node_host?: string | null;
  assigned_node_id?: number | string | null;
  service_process_id?: number | string | null;
  process_id?: number | string | null;
}

export function resolveRuntimeHost(record: ClusterRuntimeRecord | null | undefined): string {
  if (!record) return '';
  const raw =
    record.service_server_ip
    || record.server_ip
    || record.assigned_node_host
    || '';
  return String(raw).split(',')[0]?.trim() || '';
}

export function resolveRuntimeNodeId(record: ClusterRuntimeRecord | null | undefined): string {
  if (!record) return '';
  const id = record.node_id ?? record.assigned_node_id;
  return id != null && id !== '' ? String(id) : '';
}

export function resolveRuntimePid(record: ClusterRuntimeRecord | null | undefined): string {
  if (!record) return '';
  const pid = record.service_process_id ?? record.process_id;
  return pid != null && pid !== '' ? String(pid) : '';
}

/** 列表/卡片用：192.168.1.10 / PID 12345 / #3 */
export function formatClusterRuntime(record: ClusterRuntimeRecord | null | undefined): string {
  if (!record) return '--';
  const policy = (record.schedule_policy || 'local').toLowerCase();
  if (policy === 'local' && !resolveRuntimeHost(record) && !resolveRuntimeNodeId(record)) {
    return '本机';
  }
  const parts: string[] = [];
  const host = resolveRuntimeHost(record);
  const pid = resolveRuntimePid(record);
  const nodeId = resolveRuntimeNodeId(record);
  if (host) parts.push(host);
  if (pid) parts.push(`PID ${pid}`);
  if (nodeId) parts.push(`#${nodeId}`);
  return parts.length ? parts.join(' / ') : '--';
}

export const schedulePolicyLabels: Record<string, string> = {
  local: '本机',
  auto: '自动调度',
  node: '指定节点',
};

export function formatSchedulePolicy(
  policy?: string | null,
  record?: ClusterRuntimeRecord | null,
): string {
  const key = (policy || 'local').toLowerCase();
  const label = schedulePolicyLabels[key] || key;
  const nodeId = resolveRuntimeNodeId(record || undefined);
  if (key === 'local' || !nodeId) {
    return label;
  }
  return `${label} (#${nodeId})`;
}

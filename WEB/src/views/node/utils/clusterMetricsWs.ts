import type { ComputeNodeVO } from '@/api/device/node';

export type ClusterWsMessageType = 'snapshot' | 'node_update';

export interface ClusterWsNodePayload {
  id: number;
  name: string;
  host: string;
  status?: string;
  nodeRole: string;
  cpuPercent?: number;
  memPercent?: number;
  memUsedBytes?: number;
  memTotalBytes?: number;
  diskPercent?: number;
  diskUsedBytes?: number;
  diskTotalBytes?: number;
  activeTasks?: number;
  gpuInfo?: string;
  lastHeartbeatAt?: string;
  isPlatform?: boolean;
}

export interface ClusterWsMessage {
  type: ClusterWsMessageType;
  nodes?: ClusterWsNodePayload[];
  node?: ClusterWsNodePayload;
  timestamp?: number;
}

export type ClusterWsStatus = 'connecting' | 'open' | 'closed';

export function buildClusterMetricsWsUrl(): string {
  const token = localStorage.getItem('jwt_token') ?? '';
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const apiPrefix = (import.meta.env.VITE_GLOB_API_URL?.trim() || '/admin-api').replace(/\/$/, '');
  const prefix = apiPrefix.startsWith('/') ? apiPrefix : `/${apiPrefix}`;
  return `${protocol}//${window.location.host}${prefix}/node/ws/cluster-metrics?token=${encodeURIComponent(token)}`;
}

export function wsPayloadToComputeNode(payload: ClusterWsNodePayload): ComputeNodeVO {
  return {
    id: payload.id,
    name: payload.name,
    host: payload.host,
    status: payload.status,
    nodeRole: payload.nodeRole,
    cpuPercent: payload.cpuPercent,
    memPercent: payload.memPercent,
    memUsedBytes: payload.memUsedBytes,
    memTotalBytes: payload.memTotalBytes,
    diskPercent: payload.diskPercent,
    diskUsedBytes: payload.diskUsedBytes,
    diskTotalBytes: payload.diskTotalBytes,
    activeTasks: payload.activeTasks,
    gpuInfo: payload.gpuInfo,
    lastHeartbeatAt: payload.lastHeartbeatAt,
    isPlatform: payload.isPlatform,
  };
}

type MessageHandler = (message: ClusterWsMessage) => void;
type StatusHandler = (status: ClusterWsStatus) => void;

let socket: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let consumers = 0;
let shouldReconnect = false;
let messageHandler: MessageHandler | null = null;
let statusHandler: StatusHandler | null = null;

function setStatus(status: ClusterWsStatus) {
  statusHandler?.(status);
}

function clearReconnectTimer() {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
}

function scheduleReconnect() {
  if (!shouldReconnect || consumers <= 0) return;
  clearReconnectTimer();
  reconnectTimer = setTimeout(() => {
    if (shouldReconnect && consumers > 0) {
      openSocket();
    }
  }, 3000);
}

function handleMessage(event: MessageEvent) {
  try {
    const message = JSON.parse(String(event.data)) as ClusterWsMessage;
    messageHandler?.(message);
  } catch {
    // ignore malformed payload
  }
}

function openSocket() {
  if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
    return;
  }
  setStatus('connecting');
  socket = new WebSocket(buildClusterMetricsWsUrl());
  socket.addEventListener('open', () => setStatus('open'));
  socket.addEventListener('message', handleMessage);
  socket.addEventListener('close', () => {
    setStatus('closed');
    socket = null;
    scheduleReconnect();
  });
  socket.addEventListener('error', () => {
    setStatus('closed');
  });
}

export function connectClusterMetricsWebSocket(
  onMessage: MessageHandler,
  onStatusChange?: StatusHandler,
) {
  consumers += 1;
  messageHandler = onMessage;
  statusHandler = onStatusChange ?? null;
  shouldReconnect = true;
  openSocket();
  onStatusChange?.(socket?.readyState === WebSocket.OPEN ? 'open' : 'connecting');
}

export function disconnectClusterMetricsWebSocket(onMessage?: MessageHandler) {
  consumers = Math.max(0, consumers - 1);
  if (onMessage && messageHandler === onMessage) {
    messageHandler = null;
  }
  if (consumers > 0) return;
  shouldReconnect = false;
  clearReconnectTimer();
  statusHandler = null;
  if (socket) {
    socket.close();
    socket = null;
  }
}

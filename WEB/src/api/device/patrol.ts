/**
 * 摄像头巡检会话 API
 */
import { defHttp } from '@/utils/http/axios';

const PATROL_PREFIX = '/video/patrol';

const commonApi = <T = any>(
  method: 'get' | 'post',
  url: string,
  options: { params?: any; data?: any; timeout?: number } = {},
) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp[method](
    {
      url,
      headers: { ignoreCancelToken: true } as any,
      ...(options.timeout ? { timeout: options.timeout } : {}),
      ...(method === 'get' ? { params: options.params } : { data: options.data ?? options.params }),
    },
    { isTransformResponse: true },
  ) as Promise<T>;
};

/** 巡检固定使用连接池模式（并发拉流 + 共享推理，适合多路低频巡检） */
export const DEFAULT_PATROL_MODE = 'pool' as const;

export type PatrolMode = typeof DEFAULT_PATROL_MODE;

export interface PatrolSession {
  id: number;
  session_name: string;
  patrol_mode: PatrolMode;
  interval_sec: number;
  pool_size: number;
  device_ids: string[];
  device_names?: string[];
  model_ids: number[];
  focus_device_id?: string;
  status: 'running' | 'stopped' | 'error';
  progress?: Record<string, PatrolDeviceProgress>;
  total_patrols?: number;
  total_detections?: number;
  completed_devices?: number;
  total_devices?: number;
  completion_ratio?: number;
}

export interface PatrolDeviceProgress {
  last_patrol_at?: string;
  last_result?: string;
  detection_count?: number;
  error?: string;
}

export interface CreatePatrolSessionParams {
  session_name?: string;
  device_ids: string[];
  model_ids: number[];
  patrol_mode?: PatrolMode;
  interval_sec?: number;
  pool_size?: number;
  focus_device_id?: string;
  algorithm_task_id?: number;
  alert_event_enabled?: boolean;
}

export function createPatrolSession(data: CreatePatrolSessionParams) {
  return commonApi<{ data: PatrolSession }>('post', `${PATROL_PREFIX}/session`, { data });
}

export function startPatrolSession(sessionId: number) {
  return commonApi<{ data: PatrolSession; msg: string }>('post', `${PATROL_PREFIX}/session/${sessionId}/start`, {
    timeout: 60000,
  });
}

export function stopPatrolSession(sessionId: number) {
  return commonApi<{ data: PatrolSession; msg: string }>('post', `${PATROL_PREFIX}/session/${sessionId}/stop`, {
    timeout: 60000,
  });
}

export function getPatrolSessionStats(sessionId: number) {
  return commonApi<{ data: PatrolSession }>('get', `${PATROL_PREFIX}/session/${sessionId}/stats`);
}

export interface PatrolDirectoryDevices {
  directory_id: number;
  directory_name: string;
  device_ids: string[];
  total: number;
}

export function getPatrolDirectoryDevices(directoryId: number, includeChildren = true) {
  return commonApi<{ data: PatrolDirectoryDevices }>(
    'get',
    `${PATROL_PREFIX}/directory/${directoryId}/devices`,
    { params: { include_children: includeChildren ? 1 : 0 } },
  );
}

/** SSE 订阅巡检进度（网关需支持 token 查询参数鉴权） */
export function createPatrolProgressEventSource(sessionId: number): EventSource {
  const token = localStorage.getItem('jwt_token') || '';
  const base = import.meta.env.VITE_GLOB_API_URL || '';
  const url = `${base}/video/patrol/session/${sessionId}/events?token=${encodeURIComponent(token)}`;
  return new EventSource(url);
}

export function patchPatrolSession(sessionId: number, data: Partial<CreatePatrolSessionParams>) {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp.patch(
    {
      url: `${PATROL_PREFIX}/session/${sessionId}`,
      data,
      headers: { ignoreCancelToken: true } as any,
    },
    { isTransformResponse: true },
  ) as Promise<{ data: PatrolSession }>;
}

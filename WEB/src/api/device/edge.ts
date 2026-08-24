import { defHttp } from '@/utils/http/axios';

enum Api {
  Edge = '/node/edge',
}

type EdgeRequestOptions = {
  errorMessageMode?: 'none' | 'message' | 'modal';
  isTransformResponse?: boolean;
};

const commonApi = (
  method: 'get' | 'post' | 'delete' | 'put',
  url: string,
  params = {},
  options: EdgeRequestOptions = {},
) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  const { isTransformResponse = true, errorMessageMode } = options;
  return defHttp[method](
    {
      url,
      headers: { ignoreCancelToken: true },
      ...params,
    },
    { isTransformResponse, errorMessageMode },
  );
};

export interface EdgeNodeVO {
  id?: number;
  computeNodeId?: number;
  name?: string;
  host?: string;
  status?: string;
  fingerprint?: string;
  mqttClientId?: string;
  mqttUsername?: string;
  agentVersion?: string;
  nodeRole?: string;
  maxTaskCount?: number;
  activeTaskCount?: number;
  cephMountReady?: boolean;
  lastHeartbeatAt?: string;
  enabled?: boolean;
  remark?: string;
  tags?: Record<string, string>;
  cpuPercent?: number;
  memPercent?: number;
  agentPort?: number;
  createTime?: string;
  updateTime?: string;
}

export interface EdgeNodePageReq {
  pageNo?: number;
  pageSize?: number;
  name?: string;
  host?: string;
  status?: string;
  enabled?: boolean;
}

function normalizePage(res: any) {
  const data = res?.data ?? res;
  if (data?.list) return data;
  if (Array.isArray(data)) return { list: data, total: data.length };
  return { list: [], total: 0 };
}

export const getEdgeNodePage = (params: EdgeNodePageReq) => {
  return commonApi('get', Api.Edge + '/page', { params }).then(normalizePage);
};

export const getEdgeNode = (id: number) => {
  return commonApi('get', Api.Edge + '/get', { params: { id } });
};

export const updateEdgeNode = (data: Partial<EdgeNodeVO> & { id: number }) => {
  return commonApi('put', Api.Edge + '/update', { data });
};

export const deleteEdgeNode = (id: number) => {
  return commonApi('delete', Api.Edge + '/delete', { params: { id } });
};

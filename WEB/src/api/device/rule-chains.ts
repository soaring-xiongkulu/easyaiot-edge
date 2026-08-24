import {defHttp} from '@/utils/http/axios';

enum Api {
  NodeRed = '/nodeRed',
}

/** isTransformResponse:false 时返回 AxiosResponse，取其 data；否则视为已解包 body */
function getResponseBody(res: any) {
  if (res && typeof res === 'object' && 'data' in res && 'status' in res && 'config' in res) {
    return res.data;
  }
  return res;
}

/**
 * Node-RED 原生成功体无平台 code/msg；网关/演示拦截会返回 { code, msg }（HTTP 仍可能为 200）。
 * 写操作必须识别并抛错，避免前端误报「成功」。
 */
function assertNodeRedWriteOk(res: any) {
  const body = getResponseBody(res);
  if (body && typeof body === 'object' && !Array.isArray(body)) {
    const code = (body as any).code;
    const msg = (body as any).msg || (body as any).message;
    if (code === 'DEMO_DENY' || code === 901) {
      throw new Error(msg || '演示环境禁止写操作');
    }
    // 平台错误封套（非 Node-RED flow 对象）
    if (
      Reflect.has(body, 'code') &&
      Reflect.has(body, 'msg') &&
      !Reflect.has(body, 'id') &&
      !Reflect.has(body, 'nodes') &&
      code !== 0 &&
      code !== 200
    ) {
      throw new Error(msg || '操作失败');
    }
  }
  return res;
}

/**
 * @description: 规则查询
 */
export const flowsList = () => {
  return defHttp.get({url: Api.NodeRed + '/flows'}, {isTransformResponse: false});
}

/**
 * @description: 新增规则
 */
export const addFlows = async (params) => {
  const res = await defHttp.post(
    {
      url: Api.NodeRed + '/flow',
      params,
    },
    {isTransformResponse: false},
  );
  return assertNodeRedWriteOk(res);
};
/**
 * @description: 获取规则链详细信息
 */
export const getFlows = (key: string) => {
  if (!key || key === 'undefined') {
    return Promise.reject(new Error('规则链ID不能为空'));
  }
  return defHttp.get(
    {
      url: Api.NodeRed + '/flow/' + key,
    },
    {isTransformResponse: false},
  );
};
/**
 * @description: 更新规则
 */
export const updateflows = async (key, params) => {
  if (!key || key === 'undefined') {
    return Promise.reject(new Error('规则链ID不能为空'));
  }
  const res = await defHttp.put(
    {
      url: Api.NodeRed + '/flow/' + key,
      params,
    },
    {isTransformResponse: false},
  );
  return assertNodeRedWriteOk(res);
};
/**
 * @description: 删除规则
 */
export const deleteflows = async (key) => {
  if (!key || key === 'undefined') {
    return Promise.reject(new Error('规则链ID不能为空'));
  }
  const res = await defHttp.delete(
    {
      url: Api.NodeRed + '/flow/' + key,
    },
    {isTransformResponse: false},
  );
  return assertNodeRedWriteOk(res);
};

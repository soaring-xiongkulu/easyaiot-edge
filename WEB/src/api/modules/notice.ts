import { defHttp } from '/@/utils/http/axios';

enum Api {
  // 消息配置
  message_config_add = '/message/config/add',
  message_config_update = '/message/config/update',
  message_config_delete = '/message/config/delete',
  message_config_query = '/message/config/query',
  message_config_mailSendTest = '/message/config/mailSendTest',

  // 消息准备
  message_prepare_add = '/message/prepare/add',
  message_prepare_update = '/message/prepare/update',
  message_prepare_delete = '/message/prepare/delete',
  message_prepare_query = '/message/prepare/query',
  message_file_upload = '/message/file/upload',
  message_preview_user_queryByMsgType = '/message/preview/user/queryByMsgType',
  // 消息推送
  message_send = '/message/send',
  message_send_body = '/message/messageSend',

  // 消息模板（与推送分离）
  message_template_add = '/message/template/add',
  message_template_update = '/message/template/update',
  message_template_delete = '/message/template/delete',
  message_template_query = '/message/template/query',
  message_template_queryByType = '/message/template/queryByType',
  message_template_get = '/message/template/get',
}

const commonApi = (method: 'get' | 'post' | 'delete' | 'put', url, params, headers = {}, isTransformResponse = true) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });

  return defHttp[method](
    {
      url,
      headers: {
        // @ts-ignore
        ignoreCancelToken: true,
        ...headers,
      },
      ...params,
    },
    {
      isTransformResponse: isTransformResponse,
    },
  );
};

// 添加
export const messageConfigAdd = (data) => {
  return commonApi('post', Api.message_config_add, { data });
};
// 更新
export const messageConfigUpdate = (data) => {
  return commonApi('post', Api.message_config_update, { data });
};

// 删除
export const messageConfigDelete = (params) => {
  return commonApi('get', Api.message_config_delete, { params });
};

// 查询（GET 须走 params，否则 msgType 等筛选条件不会拼到 URL）
export const messageConfigQuery = (params = {}) => {
  const clean = { ...params };
  Object.keys(clean).forEach((key) => {
    const value = clean[key];
    if (value === undefined || value === null || value === '') {
      delete clean[key];
    }
  });
  if ('msgType' in clean && !Number.isFinite(Number(clean.msgType))) {
    delete clean.msgType;
  }
  return commonApi('get', Api.message_config_query, { params: clean });
};

// 根据邮件调试
export const messageConfigMailSendTest = (tos) => {
  return commonApi('get', `${Api.message_config_mailSendTest}?tos=${tos}`, {});
};

// 添加
export const messagePrepareAdd = (data) => {
  return commonApi('post', Api.message_prepare_add, { data });
};

// 更新
export const messagePrepareUpdate = (data) => {
  return commonApi('post', Api.message_prepare_update, { data });
};

// 删除
export const messagePrepareDelete = (params) => {
  return commonApi('get', Api.message_prepare_delete, { params });
};

// 查询
export const messagePrepareQuery = (data) => {
  const { pageNo, pageSize, ...res } = data;
  // 将所有参数（包括分页参数和其他查询参数）作为 params 传递
  return commonApi('get', Api.message_prepare_query, { 
    params: {
      page: pageNo,
      pageSize: pageSize,
      ...res
    }
  });
};
// 邮件上传
export const messageFileUpload = (data) => {
  return commonApi(
    'post',
    Api.message_file_upload,
    { data },
    { 'Content-Type': 'multipart/form-data' },
  );
};

// 根据消息类型查询目标用户列表
export const messagePreviewUserQueryByMsgType = (params) => {
  return commonApi(
    'get',
    `${Api.message_preview_user_queryByMsgType}?msgType=${params?.msgType}`,
    {},
  );
};

// 消息推送 - Body方式（优先使用）
export const messageSendByBody = (data, headers = {}, cookies = {}) => {
  // 使用 @RequestBody，传递完整的 DTO 对象
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  
  // 构建请求头，合并传入的 headers
  const requestHeaders = {
    'Content-Type': 'application/json',
    // @ts-ignore
    ignoreCancelToken: true,
    ...headers,
  };
  
  // 如果有 cookies，将其添加到请求头中
  if (cookies && Object.keys(cookies).length > 0) {
    const cookieString = Object.entries(cookies)
      .map(([key, value]) => `${key}=${value}`)
      .join('; ');
    requestHeaders['Cookie'] = cookieString;
  }
  
  return defHttp.post(
    {
      url: Api.message_send_body,
      data: data,
      headers: requestHeaders,
    },
    {
      isTransformResponse: false,
    },
  );
};

// 消息推送 - Param方式（备用）
export const messageSendByParam = ({ msgId, msgType }, headers = {}, cookies = {}) => {
  // 后端接口使用 @RequestParam，期望从表单数据中获取参数
  // 使用 data 对象，设置 Content-Type 为 application/x-www-form-urlencoded
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  
  // 构建请求头，合并传入的 headers
  const requestHeaders = {
    'Content-Type': 'application/x-www-form-urlencoded',
    // @ts-ignore
    ignoreCancelToken: true,
    ...headers,
  };
  
  // 如果有 cookies，将其添加到请求头中
  if (cookies && Object.keys(cookies).length > 0) {
    const cookieString = Object.entries(cookies)
      .map(([key, value]) => `${key}=${value}`)
      .join('; ');
    requestHeaders['Cookie'] = cookieString;
  }
  
  return defHttp.post(
    {
      url: Api.message_send,
      data: {
        msgId: String(msgId),
        msgType: String(msgType),
      },
      headers: requestHeaders,
    },
    {
      isTransformResponse: false,
    },
  );
};

// 消息推送 - 兼容旧接口（保持向后兼容）
export const messageSend = ({ msgId, msgType }) => {
  return messageSendByParam({ msgId, msgType });
};

// 消息模板
export const messageTemplateAdd = (data) => {
  return commonApi('post', Api.message_template_add, { data });
};

export const messageTemplateUpdate = (data) => {
  return commonApi('post', Api.message_template_update, { data });
};

export const messageTemplateDelete = (params) => {
  return commonApi('get', Api.message_template_delete, { params });
};

export const messageTemplateQuery = (data) => {
  const { pageNo, pageSize, ...res } = data;
  return commonApi('get', Api.message_template_query, {
    params: {
      page: pageNo,
      pageSize: pageSize,
      ...res,
    },
  });
};

export const messageTemplateQueryByType = (params) => {
  return commonApi('get', Api.message_template_queryByType, { params });
};

export const messageTemplateGet = (params) => {
  return commonApi('get', Api.message_template_get, { params });
};

// import {messageFileUpload} from '/@/api/modules/notice';

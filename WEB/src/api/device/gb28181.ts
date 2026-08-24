import {defHttp} from '@/utils/http/axios';
import { normalizeWvpChannelItem } from '@/views/camera/utils/gb28181Channel';
import { isGb28181Enabled } from '@/utils/deployProfile';

// GB28181 通过网关转发到 WVP：Path=/admin-api/gb28181/** -> RewritePath -> /api/${segment}
// 前端请求路径为 gb28181/xxx（无 /api 前缀），网关会重写为 /api/xxx 转发到 iot-gb28181
// 注意：需要添加前导斜杠 /，否则与 /dev-api 拼接时会变成 /dev-apigb28181
const GB28181_PREFIX = '/gb28181/device/query';
const CHANNEL_PREFIX = '/gb28181/common/channel';
const SERVER_PREFIX = '/gb28181/server';
const PROXY_PREFIX = '/gb28181/proxy';
const PLAYBACK_PREFIX = '/gb28181/playback';
const GB_RECORD_PREFIX = '/gb28181/gb_record';
const CLOUD_RECORD_PREFIX = '/gb28181/cloud/record';

/**
 * 通用请求封装
 * delete 使用 query 传参以匹配 WVP 的 @RequestParam
 */
const GB28181_DISABLED_PAGE_BODY = { data: { list: [], total: 0 } };

const commonApi = (method: 'get' | 'post' | 'delete' | 'put', url: string, params: any = {}, isTransformResponse = true) => {
  if (!isGb28181Enabled()) {
    if (isTransformResponse) {
      return Promise.resolve(null);
    }
    return Promise.resolve(GB28181_DISABLED_PAGE_BODY);
  }
  const isGet = method === 'get';
  const isDelete = method === 'delete';
  return defHttp[method](
    {
      url,
      ...(isGet || isDelete ? { params } : { data: params }),
      ...(isGet && url.includes('/devices') ? { timeout: 60 * 1000 } : {}),
    },
    {
      isTransformResponse,
    },
  );
};

/** WVP 列表接口返回 PageInfo：{ list, total, pageNum, pageSize, ... }，统一为前端期望的 { data, total } */
/** 兼容：1) axios 原始 res，body 在 res.data；2) body 为 { code, msg, data: PageInfo } 时取 data.list/data.total */
const normalizePageResponse = (res: any) => {
  const body = res?.data ?? res;
  const page = body?.data ?? body;
  const list =
    page?.list
    ?? page?.records
    ?? page?.rows
    ?? (Array.isArray(page) ? page : []);
  const total = page?.total ?? body?.total ?? res?.total ?? 0;
  return { data: list, total };
};

/** 设备列表项：后端字段 deviceId -> 前端使用的 deviceIdentification */
const normalizeDeviceList = (list: any[]) => (list || []).map((item) => ({
  ...item,
  deviceIdentification: item.deviceIdentification ?? item.deviceId,
}));

/** 设备列表：统一返回 { data, list, total }，并补齐页面依赖字段 */
const normalizeGbDeviceList = (res: any) => {
  const { data, total } = normalizePageResponse(res);
  const list = normalizeDeviceList(data).map((item) => ({
    ...item,
    localIp: item.localIp ?? item.ip,
    updatedTime: item.updatedTime ?? item.updateTime,
  }));
  return { data: list, list, total };
};

/** 通道列表：统一返回 { data, list, total }，并补齐页面依赖字段 */
const normalizeGbChannelList = (res: any) => {
  const { data, total } = normalizePageResponse(res);
  const list = (data || []).map((item: any) => ({
    ...item,
    deviceIdentification: item.deviceIdentification ?? item.deviceId ?? item.parentId,
    manufacturer: item.manufacturer ?? item.manufacture ?? '',
    manufacture: item.manufacture ?? item.manufacturer ?? '',
    createdTime: item.createdTime ?? item.createTime,
    updatedTime: item.updatedTime ?? item.updateTime,
  }));
  return { data: list, list, total };
};

// ====================== 设备管理接口 ======================

/**
 * 分页查询国标设备列表
 * @param params 查询参数
 */
export const queryVideoList = async (params: {
  page?: number;
  pageNum?: number;
  count?: number;
  pageSize?: number;
  query?: string;
  status?: boolean;
}) => {
  const requestParams: any = {};
  if (params.pageNum !== undefined) {
    requestParams.page = params.pageNum;
  } else if (params.page !== undefined) {
    requestParams.page = params.page;
  }
  if (params.pageSize !== undefined) {
    requestParams.count = params.pageSize;
  } else if (params.count !== undefined) {
    requestParams.count = params.count;
  }
  if (params.query !== undefined) {
    requestParams.query = params.query;
  }
  if (params.status !== undefined) {
    requestParams.status = params.status;
  }
  const res = await commonApi('get', `${GB28181_PREFIX}/devices`, requestParams, false);
  const { data, total } = normalizePageResponse(res);
  return { data: normalizeDeviceList(data), total };
};

/** 拉取全部国标 SIP 设备（自动分页，避免单页遗漏） */
export const queryAllVideoList = async (
  params: Omit<Parameters<typeof queryVideoList>[0], 'page' | 'count' | 'pageNum' | 'pageSize'> = {},
) => {
  const pageSize = 500;
  let page = 1;
  let all: Record<string, any>[] = [];
  let total = 0;
  const maxPages = 200;
  do {
    const res = await queryVideoList({ ...params, page, count: pageSize });
    const batch = res.data ?? [];
    if (!batch.length) break;
    total = res.total ?? all.length + batch.length;
    all = all.concat(batch);
    if (batch.length < pageSize || all.length >= total) break;
    page += 1;
  } while (page <= maxPages);
  return { data: all, total: all.length };
};

/**
 * 查询单个设备
 * @param deviceId 设备国标编号
 */
export const getDevice = (deviceId: string) => {
  return commonApi('get', `${GB28181_PREFIX}/devices/${deviceId}`);
};

/**
 * 国标云台控制
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param payload 控制参数
 */
export const controlGbPtz = (
  deviceId: string,
  channelId: string,
  payload: {
    command: string;
    horizonSpeed?: number;
    verticalSpeed?: number;
    zoomSpeed?: number;
  },
) => {
  return commonApi('get', `/gb28181/front-end/ptz/${deviceId}/${channelId}`, payload);
};

/** 国标预置位查询 */
export const queryGbPreset = (deviceId: string, channelId: string) =>
  commonApi('get', `/gb28181/front-end/preset/query/${deviceId}/${channelId}`, {}, false);

/** 国标预置位设置 */
export const addGbPreset = (deviceId: string, channelId: string, presetId: number) =>
  commonApi('get', `/gb28181/front-end/preset/add/${deviceId}/${channelId}`, { presetId });

/** 国标预置位调用 */
export const callGbPreset = (deviceId: string, channelId: string, presetId: number) =>
  commonApi('get', `/gb28181/front-end/preset/call/${deviceId}/${channelId}`, { presetId });

/** 国标预置位删除 */
export const deleteGbPreset = (deviceId: string, channelId: string, presetId: number) =>
  commonApi('get', `/gb28181/front-end/preset/delete/${deviceId}/${channelId}`, { presetId });

/** 国标聚焦 */
export const controlGbFocus = (
  deviceId: string,
  channelId: string,
  command: 'near' | 'far' | 'stop',
  speed = 100,
) =>
  commonApi('get', `/gb28181/front-end/fi/focus/${deviceId}/${channelId}`, { command, speed });

/** 国标光圈 */
export const controlGbIris = (
  deviceId: string,
  channelId: string,
  command: 'in' | 'out' | 'stop',
  speed = 100,
) =>
  commonApi('get', `/gb28181/front-end/fi/iris/${deviceId}/${channelId}`, { command, speed });

/** 启动国标语音广播/对讲 */
export const startGbAudioBroadcast = (
  deviceId: string,
  channelId: string,
  broadcastMode = true,
) =>
  commonApi(
    'get',
    `/gb28181/play/broadcast/${deviceId}/${channelId}`,
    { broadcastMode },
    false,
  );

/** 停止国标语音广播 */
export const stopGbAudioBroadcast = (deviceId: string, channelId: string) =>
  commonApi('get', `/gb28181/play/broadcast/stop/${deviceId}/${channelId}`);

/**
 * 添加设备
 * @param device 设备信息
 */
export const addDevice = (device: any) => {
  return commonApi('post', `${GB28181_PREFIX}/device/add`, device);
};

/**
 * 更新设备
 * @param device 设备信息
 */
export const updateDevice = (device: any) => {
  return commonApi('post', `${GB28181_PREFIX}/device/update`, device);
};

/**
 * 删除设备
 * @param deviceId 设备国标编号
 */
export const deleteDevice = (deviceId: string) => {
  return commonApi('delete', `${GB28181_PREFIX}/devices/${deviceId}/delete`);
};

/**
 * 同步设备通道
 * @param deviceId 设备国标编号
 */
export const refreshChannelList = (deviceId: string) => {
  return commonApi('get', `${GB28181_PREFIX}/devices/${deviceId}/sync`);
};

/**
 * 获取通道同步状态
 * @param deviceId 设备国标编号
 */
export const getSyncStatus = (deviceId: string) => {
  return commonApi('get', `${GB28181_PREFIX}/sync_status`, { deviceId });
};

// ====================== 通道管理接口 ======================

/**
 * 分页查询通道列表
 * @param params 查询参数
 */
export const queryChannelList = async (params: {
  page?: number;
  pageNo?: number;
  count?: number;
  pageSize?: number;
  query?: string;
  online?: boolean;
  channelType?: number;
  deviceId?: string;
  deviceIdentification?: string;
  sortOrder?: string;
}) => {
  const requestParams: any = {};
  if (params.pageNo !== undefined) {
    requestParams.page = params.pageNo;
  } else if (params.page !== undefined) {
    requestParams.page = params.page;
  }
  if (params.pageSize !== undefined) {
    requestParams.count = params.pageSize;
  } else if (params.count !== undefined) {
    requestParams.count = params.count;
  }
  if (params.query !== undefined) {
    requestParams.query = params.query;
  }
  if (params.online !== undefined) {
    requestParams.online = params.online;
  }
  if (params.channelType !== undefined) {
    requestParams.channelType = params.channelType;
  }

  const sipDeviceId = params.deviceId || params.deviceIdentification;
  const url = sipDeviceId
    ? `${GB28181_PREFIX}/devices/${sipDeviceId}/channels`
    : `${CHANNEL_PREFIX}/list`;
  const res = await commonApi('get', url, requestParams, false);
  const { data, total } = normalizePageResponse(res);
  const list = (data || []).map((item: any) =>
    normalizeWvpChannelItem(item, sipDeviceId ? String(sipDeviceId) : undefined),
  );
  return { data: list, total };
};

/**
 * 获取单个通道详情
 * @param channelId 通道数据库ID
 */
export const getChannel = (channelId: number) => {
  return commonApi('get', `${CHANNEL_PREFIX}/one`, { id: channelId });
};

/**
 * 更新通道
 * @param channel 通道信息
 */
export const updateChannel = (channel: any) => {
  return commonApi('post', `${CHANNEL_PREFIX}/update`, channel);
};

/**
 * 删除通道（WVP 通道表自增 id，与列表项 id / gbId 一致）
 */
export const deleteGbChannel = (id: number) => {
  return commonApi('delete', `${CHANNEL_PREFIX}/delete`, { id });
};

/**
 * 批量删除通道
 */
export const batchDeleteGbChannels = (ids: number[]) => {
  return commonApi('post', `${CHANNEL_PREFIX}/batch/delete`, ids);
};

/**
 * 添加通道
 * @param channel 通道信息
 */
export const addChannel = (channel: any) => {
  return commonApi('post', `${CHANNEL_PREFIX}/add`, channel);
};

/**
 * 请求截图
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param mark 标识（可选）
 */
export const snapshot = (deviceId: string, channelId: string, mark?: string) => {
  if (!isGb28181Enabled()) {
    return Promise.resolve({ data: '' });
  }
  let url = `${GB28181_PREFIX}/snap/${deviceId}/${channelId}`;
  if (mark) {
    url += `?mark=${mark}`;
  }
  return defHttp.get({
    url,
    responseType: 'blob',
  }, {
    isTransformResponse: false,
  }).then((response: any) => {
    // 将blob转换为URL
    const blob = new Blob([response.data]);
    const url = window.URL.createObjectURL(blob);
    return { data: url };
  });
};

/**
 * 播放通道（通过通道数据库ID）
 * @param channelId 通道数据库ID
 */
export const play = (channelId: number) => {
  return commonApi('get', `${CHANNEL_PREFIX}/play`, { channelId }, false);
};

/**
 * 播放通道（通过设备国标编号和通道国标编号）
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 */
export const playByDeviceAndChannel = (deviceId: string, channelId: string) => {
  return commonApi('get', `/gb28181/play/start/${deviceId}/${channelId}`, {}, false);
};

/**
 * 停止播放（通过通道数据库ID）
 * @param channelId 通道数据库ID
 */
export const stopPlay = (channelId: number) => {
  return commonApi('get', `${CHANNEL_PREFIX}/play/stop`, { channelId });
};

/**
 * 停止播放（通过设备国标编号和通道国标编号）
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 */
export const stopPlayByDeviceAndChannel = (deviceId: string, channelId: string) => {
  return commonApi('get', `/gb28181/play/stop/${deviceId}/${channelId}`);
};

// ====================== 媒体服务器管理接口 ======================

/**
 * 获取媒体服务器列表（WVP 返回数组，网关可能包装为 { code, msg, data }；统一返回 { data, total } 以兼容列表组件）
 */
export const getMediaServerList = async (params?: Record<string, any>) => {
  const res = await commonApi('get', `${SERVER_PREFIX}/media_server/list`, params ?? {}, false);
  // isTransformResponse=false 时 res 为 axios 响应，body 在 res.data；网关包装后为 { code, msg, data: [...] }
  const body = res?.data;
  const list = Array.isArray(body) ? body : (body?.data ?? body?.list ?? []);
  const arr = Array.isArray(list) ? list : [];
  return { data: arr, total: arr.length };
};

/**
 * 获取在线媒体服务器列表
 */
export const getOnlineMediaServerList = () => {
  return commonApi('get', `${SERVER_PREFIX}/media_server/online/list`);
};

/**
 * 获取单个媒体服务器
 * @param id 媒体服务器ID
 */
export const getMediaServer = (id: string) => {
  return commonApi('get', `${SERVER_PREFIX}/media_server/one/${id}`);
};

/**
 * 测试媒体服务器（WVP 接口使用 query 参数 port，对应 ZLM 的 HTTP 端口）
 * @param params 测试参数，支持 port 或 httpPort
 */
export const checkMediaServer = (params: {
  ip: string;
  port?: number | string;
  httpPort?: number | string;
  secret: string;
  type?: string;
}) => {
  const port = params.port ?? params.httpPort;
  return commonApi('get', `${SERVER_PREFIX}/media_server/check`, {
    ip: params.ip,
    port: Number(port),
    secret: params.secret,
    type: params.type ?? 'zlm',
  });
};

/**
 * 保存或更新媒体服务器
 * @param mediaServer 媒体服务器信息
 */
export const saveOrUpdateMediaServer = (mediaServer: any) => {
  return commonApi('post', `${SERVER_PREFIX}/media_server/save`, mediaServer);
};

/**
 * 删除媒体服务器
 * @param id 媒体服务器ID
 */
export const deleteMediaServer = (id: string) => {
  return commonApi('delete', `${SERVER_PREFIX}/media_server/delete`, { id });
};

// ====================== 拉流代理接口 ======================

/**
 * 分页查询拉流代理列表
 * @param params 查询参数
 */
export const getPullProxyList = async (params: {
  page?: number;
  count?: number;
  query?: string;
  pulling?: boolean;
  mediaServerId?: string;
}) => {
  const res = await commonApi('get', `${PROXY_PREFIX}/list`, params, false);
  return normalizePageResponse(res);
};

/**
 * 查询单个拉流代理
 * @param app 应用名
 * @param stream 流ID
 */
export const getPullProxy = (app: string, stream: string) => {
  return commonApi('get', `${PROXY_PREFIX}/one`, { app, stream });
};

/**
 * 添加拉流代理
 * @param proxy 代理信息
 */
export const addPullProxy = (proxy: any) => {
  return commonApi('post', `${PROXY_PREFIX}/add`, proxy);
};

/**
 * 更新拉流代理
 * @param proxy 代理信息
 */
export const updatePullProxy = (proxy: any) => {
  return commonApi('post', `${PROXY_PREFIX}/update`, proxy);
};

/**
 * 保存拉流代理（新增或更新）
 * @param proxy 代理信息
 */
export const savePullProxy = (proxy: any) => {
  if (proxy.id && proxy.id > 0) {
    return updatePullProxy(proxy);
  } else {
    return addPullProxy(proxy);
  }
};

/**
 * 删除拉流代理
 * @param app 应用名
 * @param stream 流ID
 */
export const deletePullProxy = (app: string, stream: string) => {
  return commonApi('delete', `${PROXY_PREFIX}/del`, { app, stream });
};

/**
 * 启动拉流代理
 * @param idOrApp 代理ID或应用名
 * @param stream 流ID（当第一个参数是app时必填）
 */
export const startPullProxy = async (idOrApp: number | string, stream?: string) => {
  if (typeof idOrApp === 'number') {
    // 通过ID启动
    return commonApi('get', `${PROXY_PREFIX}/start`, { id: idOrApp }, false);
  } else {
    // 通过app和stream启动
    const proxy = await getPullProxy(idOrApp, stream!);
    if (proxy && proxy.id) {
      return commonApi('get', `${PROXY_PREFIX}/start`, { id: proxy.id }, false);
    }
    throw new Error('拉流代理不存在');
  }
};

/**
 * 停止拉流代理
 * @param idOrApp 代理ID或应用名
 * @param stream 流ID（当第一个参数是app时必填）
 */
export const stopPullProxy = async (idOrApp: number | string, stream?: string) => {
  if (typeof idOrApp === 'number') {
    // 通过ID停止
    return commonApi('get', `${PROXY_PREFIX}/stop`, { id: idOrApp });
  } else {
    // 通过app和stream停止
    const proxy = await getPullProxy(idOrApp, stream!);
    if (proxy && proxy.id) {
      return commonApi('get', `${PROXY_PREFIX}/stop`, { id: proxy.id });
    }
    throw new Error('拉流代理不存在');
  }
};

// ====================== 录像回放接口 ======================

/**
 * 查询设备录像列表
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param startTime 开始时间
 * @param endTime 结束时间
 */
export const getDeviceRecordList = (deviceId: string, channelId: string, startTime: string, endTime: string) => {
  return commonApi('get', `${GB_RECORD_PREFIX}/query/${deviceId}/${channelId}`, {
    startTime,
    endTime,
  }, false);
};

/**
 * 设备录像回放
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param startTime 开始时间
 * @param endTime 结束时间
 */
export const playBack = (deviceId: string, channelId: string, startTime: string, endTime: string) => {
  return commonApi('get', `${PLAYBACK_PREFIX}/start/${deviceId}/${channelId}`, {
    startTime,
    endTime,
  }, false);
};

/**
 * 停止设备录像回放
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param stream 回放流ID（由 playBack 返回的 data 中获取）
 */
export const stopPlayBack = (deviceId: string, channelId: string, stream: string) => {
  return commonApi('get', `${PLAYBACK_PREFIX}/stop/${deviceId}/${channelId}/${stream}`);
};

/**
 * 查询云端录像日期列表
 * @param app 应用名
 * @param stream 流ID
 * @param year 年（可选）
 * @param month 月（可选）
 * @param mediaServerId 流媒体ID（可选）
 */
export const getCloudRecordDateList = (params: {
  app: string;
  stream: string;
  year?: number;
  month?: number;
  mediaServerId?: string;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/date/list`, params);
};

/**
 * 查询云端录像列表
 * @param params 查询参数
 */
export const getCloudRecordList = async (params: {
  app?: string;
  stream?: string;
  page?: number;
  count?: number;
  startTime?: string;
  endTime?: string;
  mediaServerId?: string;
  callId?: string;
  query?: string;
  ascOrder?: boolean;
}) => {
  const res = await commonApi('get', `${CLOUD_RECORD_PREFIX}/list`, params, false);
  return normalizePageResponse(res);
};

/**
 * 云端录像回放（按 app/stream/时间 参数）
 * @param params 回放参数
 */
export const cloudplayBack = (params: {
  app: string;
  stream: string;
  startTime: number;
  endTime: number;
  mediaServerId?: string;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/play`, params, false);
};

/**
 * 获取云端录像播放地址（按录像记录 ID，返回 DownloadFileInfo 含 httpPath）
 * @param recordId 录像记录 ID
 */
export const getCloudRecordPlayPath = (recordId: number) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/play/path`, { recordId }, false);
};

/**
 * 停止云端录像回放
 * @param params 停止参数
 */
export const stopCloudPlayBack = (params: {
  app: string;
  stream: string;
  mediaServerId?: string;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/play/stop`, params);
};

/**
 * 加载云端录像文件形成播放地址
 * @param params 加载参数
 */
export const loadCloudRecord = (params: {
  app: string;
  stream: string;
  cloudRecordId: number;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/loadRecord`, params, false);
};

/**
 * 定位云端录像播放到指定位置
 * @param params 定位参数
 */
export const seekCloudRecord = (params: {
  mediaServerId: string;
  app: string;
  stream: string;
  seek: number;
  schema?: string;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/seek`, params);
};

/**
 * 设置云端录像播放速度
 * @param params 速度参数
 */
export const setCloudRecordSpeed = (params: {
  mediaServerId: string;
  app: string;
  stream: string;
  speed: number;
  schema?: string;
}) => {
  return commonApi('get', `${CLOUD_RECORD_PREFIX}/speed`, params);
};

// ====================== 通道回放接口（通用通道） ======================

/**
 * 查询通道录像
 * @param channelId 通道数据库ID
 * @param startTime 开始时间
 * @param endTime 结束时间
 */
export const queryChannelRecord = (channelId: number, startTime: string, endTime: string) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/query`, {
    channelId,
    startTime,
    endTime,
  }, false);
};

/**
 * 通道录像回放
 * @param channelId 通道数据库ID
 * @param startTime 开始时间
 * @param endTime 结束时间
 */
export const channelPlayback = (channelId: number, startTime: string, endTime: string) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback`, {
    channelId,
    startTime,
    endTime,
  }, false);
};

/**
 * 停止通道录像回放
 * @param channelId 通道数据库ID
 * @param stream 流ID
 */
export const stopChannelPlayback = (channelId: number, stream: string) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/stop`, {
    channelId,
    stream,
  });
};

/**
 * 暂停通道录像回放
 * @param channelId 通道数据库ID
 * @param stream 流ID
 */
export const pauseChannelPlayback = (channelId: number, stream: string) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/pause`, {
    channelId,
    stream,
  });
};

/**
 * 恢复通道录像回放
 * @param channelId 通道数据库ID
 * @param stream 流ID
 */
export const resumeChannelPlayback = (channelId: number, stream: string) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/resume`, {
    channelId,
    stream,
  });
};

/**
 * 拖动通道录像回放
 * @param channelId 通道数据库ID
 * @param stream 流ID
 * @param seekTime 目标时间戳
 */
export const seekChannelPlayback = (channelId: number, stream: string, seekTime: number) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/seek`, {
    channelId,
    stream,
    seekTime,
  });
};

/**
 * 设置通道录像回放倍速
 * @param channelId 通道数据库ID
 * @param stream 流ID
 * @param speed 倍速
 */
export const speedChannelPlayback = (channelId: number, stream: string, speed: number) => {
  return commonApi('get', `${CHANNEL_PREFIX}/playback/speed`, {
    channelId,
    stream,
    speed,
  });
};

// ====================== 设备控制接口 ======================

/**
 * 远程启动设备
 * @param deviceId 设备国标编号
 */
export const teleBoot = (deviceId: string) => {
  return commonApi('get', `gb28181/device/control/teleboot/${deviceId}`);
};

/**
 * 录像控制
 * @param deviceId 设备国标编号
 * @param channelId 通道国标编号
 * @param recordCmdStr 命令：Record（手动录像），StopRecord（停止手动录像）
 */
export const recordControl = (deviceId: string, channelId: string, recordCmdStr: string) => {
  return commonApi('get', `gb28181/device/control/record`, {
    deviceId,
    channelId,
    recordCmdStr,
  }, false);
};

/**
 * 设备状态查询
 * @param deviceId 设备国标编号
 */
export const queryDeviceStatus = (deviceId: string) => {
  return commonApi('get', `${GB28181_PREFIX}/devices/${deviceId}/status`, {}, false);
};

/**
 * 设备信息查询
 * @param deviceId 设备国标编号
 */
export const queryDeviceInfo = (deviceId: string) => {
  return commonApi('get', `${GB28181_PREFIX}/info`, { deviceId }, false);
};

/**
 * 设备报警查询
 * @param params 查询参数
 */
export const queryDeviceAlarm = (params: {
  deviceId: string;
  startPriority?: string;
  endPriority?: string;
  alarmMethod?: string;
  alarmType?: string;
  startTime?: string;
  endTime?: string;
}) => {
  return commonApi('get', `${GB28181_PREFIX}/alarm`, params, false);
};

// ====================== 树形结构接口 ======================

/**
 * 获取通道树形结构（用于地图等）
 * @param params 查询参数
 */
export const getTree = (params?: {
  query?: string;
  online?: boolean;
  hasRecordPlan?: boolean;
  channelType?: number;
}) => {
  return commonApi('get', `${CHANNEL_PREFIX}/map/list`, params || {});
};

/**
 * 获取设备的通道列表（用于树形结构）
 * @param deviceId 设备国标编号
 */
const queryDeviceChannelsPage = async (deviceId: string, page: number, count: number) => {
  const res = await commonApi('get', `${GB28181_PREFIX}/devices/${deviceId}/channels`, {
    page,
    count,
  }, false);
  const body = res?.data ?? res;
  const payload = body?.data ?? body;
  if (payload?.code != null && Number(payload.code) !== 0) {
    throw new Error(payload.msg || '查询国标设备通道失败');
  }
  const { data, total } = normalizePageResponse(res);
  const list = (data || []).map((item: any) => normalizeWvpChannelItem(item, deviceId));
  return { data: list, list, total };
};

export const getDeviceChannels = async (deviceId: string) => {
  return queryDeviceChannelsPage(deviceId, 1, 10000);
};

/** 拉取指定国标设备的全部通道（自动分页，供通道选择等完整列表场景使用） */
export const queryAllDeviceChannels = async (deviceId: string) => {
  const pageSize = 500;
  const maxPages = 200;
  let page = 1;
  let all: Record<string, any>[] = [];
  let total = 0;
  do {
    const res = await queryDeviceChannelsPage(deviceId, page, pageSize);
    const batch = res.data ?? [];
    if (!batch.length) break;
    total = res.total ?? all.length + batch.length;
    all = all.concat(batch);
    if (batch.length < pageSize || all.length >= total) break;
    page += 1;
  } while (page <= maxPages);
  return { data: all, list: all, total: all.length };
};

// ====================== 其他工具接口 ======================

/**
 * 获取FFmpeg命令模板
 * @param mediaServerId 流媒体服务器ID
 */
export const getFFmpegCMDs = (mediaServerId: string) => {
  return commonApi('get', `${PROXY_PREFIX}/ffmpeg_cmd/list`, { mediaServerId });
};

/**
 * 修改通道音频开关
 * @param channelId 通道数据库ID
 * @param audio 是否开启音频
 */
export const changeChannelAudio = (channelId: number, audio: boolean) => {
  return commonApi('post', `${GB28181_PREFIX}/channel/audio`, {
    channelId,
    audio,
  });
};

/**
 * 修改数据流传输模式
 * @param deviceId 设备国标编号
 * @param streamMode 传输模式：UDP/TCP-ACTIVE/TCP-PASSIVE
 */
export const updateTransport = (deviceId: string, streamMode: string) => {
  return commonApi('post', `${GB28181_PREFIX}/transport/${deviceId}/${streamMode}`);
};

/**
 * 开启/关闭目录订阅
 * @param id 设备数据库ID
 * @param cycle 订阅周期（0表示关闭）
 */
export const subscribeCatalog = (id: number, cycle: number) => {
  return commonApi('get', `${GB28181_PREFIX}/subscribe/catalog`, { id, cycle });
};

/**
 * 开启/关闭移动位置订阅
 * @param id 设备数据库ID
 * @param cycle 订阅周期（0表示关闭）
 * @param interval 报送间隔
 */
export const subscribeMobilePosition = (id: number, cycle: number, interval: number) => {
  return commonApi('get', `${GB28181_PREFIX}/subscribe/mobile-position`, {
    id,
    cycle,
    interval,
  });
};

/**
 * 生成国标设备接入信息（调用后端脚本，返回文本）
 * @param count 生成组数，1～100，默认 10
 */
export const generateDeviceAccessInfo = (count?: number) => {
  const params = count != null && count >= 1 && count <= 100 ? { count } : {};
  return commonApi('get', `${GB28181_PREFIX}/device-access-info/generate`, params, false);
};


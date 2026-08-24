import {defHttp} from '@/utils/http/axios';
import { dedupeRequest } from '@/utils/requestDedupe';
import { getDeviceList } from '@/api/device/camera';
import { getJwtToken } from '@/utils/auth';

enum Api {
  Alarm = '/video/alert',
}

/** 大屏轮询：放宽超时、关闭 GET 重试（默认 10s×5 次会长时间挂起） */
const DASHBOARD_POLL_REQUEST_OPTIONS = {
  errorMessageMode: 'none' as const,
  timeout: 30 * 1000,
  retryRequest: { isOpenRetry: false, count: 0, waitTime: 0 },
};

const commonApi = (
  method: 'get' | 'post' | 'delete' | 'put',
  url,
  params = {},
  headers = {},
  isTransformResponse = true,
  responseType = 'json',
  requestOptions: {
    errorMessageMode?: 'none' | 'message' | 'modal';
    timeout?: number;
    retryRequest?: { isOpenRetry: boolean; count: number; waitTime: number };
  } = {},
) => {
  defHttp.setHeader({'X-Authorization': 'Bearer ' + getJwtToken()});

  return defHttp[method](
    {
      url,
      headers: {
        // @ts-ignore
        ignoreCancelToken: true,
        ...headers,
      },
      ...params,
      responseType: responseType,
    },
    {
      isTransformResponse: isTransformResponse,
      errorMessageMode: requestOptions.errorMessageMode ?? 'message',
      ...(requestOptions.timeout ? { timeout: requestOptions.timeout } : {}),
      ...(requestOptions.retryRequest ? { retryRequest: requestOptions.retryRequest } : {}),
    },
  );
};

// 告警事件（带请求去重）
export const queryAlarmList = async (
  params,
  options?: { polling?: boolean },
) => {
  const url = Api.Alarm + '/page';
  const polling = options?.polling === true;
  const requestParams = polling ? { ...params, skip_backfill: 1 } : params;
  const reqOptions = polling
    ? DASHBOARD_POLL_REQUEST_OPTIONS
    : { errorMessageMode: 'none' as const };
  return dedupeRequest(
    async () => {
      const res = await commonApi('get', url, {params: requestParams}, {}, false, 'json', reqOptions);
      // 后端返回格式: { code: 0, msg/message: "success", data: { alert_list: [], total: 100 } }
      // 当 isTransformResponse: false 时，返回的是整个 Axios 响应对象，需要访问 res.data 获取实际响应
      // 然后访问 res.data.data 获取实际数据
      if (res && res.data && res.data.data) {
        return res.data.data;
      }
      // 兼容处理：如果结构不同，尝试直接返回 res.data
      if (res && res.data) {
        return res.data;
      }
      return res;
    },
    url,
    requestParams,
    polling ? 4500 : 1000,
  );
};

// 获取告警筛选摄像头列表
export const queryAlertCameras = async () => {
  const res = await getDeviceList({ pageNo: 1, pageSize: 1000 });
  const deviceList = (res && res.data) ? res.data : [];
  const cameraOptions = deviceList.map((item) => {
    const deviceId = item.id;
    const deviceName = item.name || item.id;
    return {
      value: deviceId,
      label: deviceName && deviceName !== deviceId ? `${deviceName} (${deviceId})` : deviceId,
      device_id: deviceId,
      device_name: deviceName,
    };
  });

  cameraOptions.sort((a, b) => String(a.label).localeCompare(String(b.label)));
  return {
    data: [
      { value: '', label: '全部摄像头' },
      ...cameraOptions,
    ],
  };
};

export const deleteAlarm = (id) => {
  return commonApi('delete', `${Api.Alarm}/delete/${id}`);
};

export const getAlertCount = (params) => {
  return commonApi('get', Api.Alarm + '/count', {device_id: params['id']});
};

/** 按日期分组统计告警数量 */
export const queryAlertCountByDate = async (params: {
  device_id?: string;
  begin_datetime?: string;
  end_datetime?: string;
}) => {
  const res = await commonApi('get', Api.Alarm + '/count', { ...params, group: 'date' }, {}, false);
  if (res?.data?.data) return res.data.data;
  if (res?.data) return res.data;
  return res;
};

export const getAlertImage = (path) => {
  return commonApi('get', Api.Alarm + '/image?path=' + path, {}, {}, false, 'blob');
};

export const getAlertRecord = (path) => {
  return commonApi('get', Api.Alarm + '/record?path=' + path, {}, {}, false, 'blob');
};

// 根据告警时间和设备ID查询对应的录像
export const queryAlertRecord = async (params: {
  device_id: string;
  alert_time: string;
  time_range?: number;
  alert_id?: number | string;
}) => {
  const res = await commonApi('get', Api.Alarm + '/record/query', {params}, {}, false);
  // 处理响应数据
  if (res && res.data) {
    const responseData = res.data;
    // 如果code是400（业务错误），抛出错误让前端处理
    if (responseData.code === 400) {
      const error: any = new Error(responseData.message || '未找到匹配的录像');
      error.response = { data: responseData };
      error.data = responseData;
      throw error;
    }
    // 成功情况，返回数据
    if (responseData.data) {
      return responseData.data;
    }
    return responseData;
  }
  return res;
};

export const generatePlayback = (params) => {
  return commonApi('post', Api.Alarm + '/generatePlayback', {params});
};

// 清空任务的所有告警记录（通过task_name）
export const clearAlertsByTaskName = (task_name: string) => {
  return commonApi('delete', Api.Alarm + '/clear', { params: { task_name } });
};

// 清空所有告警记录
export const clearAllAlerts = () => {
  return commonApi('delete', Api.Alarm + '/clear/all');
};

// 获取仪表板统计信息（统一接口，带请求去重）
export const getDashboardStatistics = async () => {
  const url = Api.Alarm + '/statistics';
  return dedupeRequest(
    async () => {
      const res = await commonApi('get', url, {}, {}, false, 'json', DASHBOARD_POLL_REQUEST_OPTIONS);
      // 后端返回格式: { code: 0, data: { alarm_count, today_alarm_count, ... } }
      if (res && res.data && res.data.data) {
        return res.data.data;
      }
      // 兼容处理：如果结构不同，尝试直接返回 res.data
      if (res && res.data) {
        return res.data;
      }
      return res;
    },
    url,
    undefined, // 统计接口无参数
    4500, // 与大屏 5s 轮询对齐，Sidebar/index 错峰请求可复用
  );
};

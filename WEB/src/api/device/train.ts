import {defHttp} from '@/utils/http/axios';

const Api = {
  TrainTask: '/model/train_task',
};

const buildAuthHeader = () => ({
  'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token'),
});

const commonApi = (
  method: 'get' | 'post' | 'delete' | 'put',
  url: string,
  params: Record<string, unknown> = {},
  headers: Record<string, string> = {},
  isTransformResponse = true,
) => {
  const authHeader = buildAuthHeader();

  return defHttp[method](
    {
      url,
      headers: {
        ...authHeader,
        ...headers,
      },
      ...params,
    },
    {
      isTransformResponse,
    },
  );
};

export const getTrainTaskPage = (params: Record<string, unknown>) => {
  return commonApi('get', `${Api.TrainTask}/list`, {params});
};

export const getTrainTaskDetail = (recordId: number) => {
  return commonApi('get', `${Api.TrainTask}/${recordId}`);
};

export const deleteTrainTask = (recordId: number) => {
  return commonApi('delete', `${Api.TrainTask}/delete/${recordId}`);
};

export const startTrain = (config: TrainStartConfig | Record<string, unknown>) => {
  return commonApi('post', `${Api.TrainTask}/start`, {data: config});
};

export const stopTrain = (taskId: number) => {
  return commonApi('post', `${Api.TrainTask}/${taskId}/stop`);
};

export const getTrainStatus = (taskId: number) => {
  return commonApi('get', `${Api.TrainTask}/${taskId}/status`);
};

export const getTrainLogs = (taskId: number) => {
  return commonApi('get', `${Api.TrainTask}/${taskId}/logs`);
};

export const getTrainGpuStatus = () => {
  return commonApi('get', `${Api.TrainTask}/gpu/status`);
};

export type TrainSchedulePolicy = 'local' | 'auto' | 'node';

export interface TrainStartConfig {
  epochs: number;
  batch_size: number;
  imgsz: number;
  taskName?: string;
  modelPath: string;
  datasetSource?: 'local' | 'cloud';
  datasetPath: string;
  datasetName?: string;
  datasetVersion?: string;
  use_gpu?: boolean;
  gpu_ids?: number[];
  gpu_selection_manual?: boolean;
  taskId?: number;
  resume?: boolean;
  schedulePolicy?: TrainSchedulePolicy;
  schedule_policy?: TrainSchedulePolicy;
  targetNodeId?: number | null;
  target_node_id?: number | null;
}

/** 上传本地 YOLO 数据集 zip，返回服务端路径供训练使用 */
export const uploadTrainDataset = (formData: FormData) => {
  return defHttp.post(
    {
      url: `${Api.TrainTask}/dataset/upload`,
      data: formData,
      timeout: 60 * 60 * 1000,
      headers: buildAuthHeader(),
    },
    {
      isTransformResponse: true,
      successMessageMode: 'none',
    },
  );
};

/** 将已完成训练任务的权重发布到模型管理 */
export const publishTrainTask = (
  taskId: number,
  params?: { name?: string; version?: string; description?: string; auto_increment?: boolean },
) => {
  return commonApi('post', `${Api.TrainTask}/${taskId}/publish`, {data: params || {}});
};

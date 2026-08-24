import { defHttp } from '@/utils/http/axios';

enum Api {
  Sam = '/model/sam',
}

const SAM_API_SUCCESS_CODES = new Set([0, 200]);

async function samMutationApi<T = unknown>(
  method: 'post',
  url: string,
): Promise<{ code: number; msg: string; data?: T }> {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  try {
    const res = await defHttp[method](
      {
        url,
        headers: {
          // @ts-ignore
          ignoreCancelToken: true,
        },
      },
      { isTransformResponse: false, errorMessageMode: 'none' },
    );
    const body = ((res as { data?: { code: number; msg: string; data?: T } })?.data ?? res) as {
      code: number;
      msg: string;
      data?: T;
    };
    if (!SAM_API_SUCCESS_CODES.has(body?.code)) {
      throw new Error(body?.msg || '请求失败');
    }
    return body;
  } catch (error) {
    throw new Error(parseSamApiError(error, '请求失败'));
  }
}

export function parseSamApiError(error: unknown, fallback = '操作失败，请稍后重试'): string {
  if (error == null) return fallback;
  if (typeof error === 'string') {
    return /^Request failed with status code \d+$/i.test(error) ? fallback : error;
  }
  const e = error as { message?: string; response?: { data?: { msg?: string } } };
  const bodyMsg = e.response?.data?.msg;
  if (typeof bodyMsg === 'string' && bodyMsg.trim()) return bodyMsg.trim();
  const msg = e.message;
  if (typeof msg === 'string' && msg && !/^Request failed with status code \d+$/i.test(msg)) {
    return msg;
  }
  return fallback;
}

/** SAM3 模型权重状态 */
export interface SamModelStatus {
  exists: boolean;
  filename: string;
  path?: string;
  size_bytes: number;
  downloading: boolean;
  /** 存在未完成的 .downloading 文件，可断点续传 */
  resumable?: boolean;
  /** idle | downloading | installing | done | error */
  stage?: string;
  progress: number;
  downloaded_bytes?: number;
  total_bytes?: number;
  error?: string | null;
  /** modelscope | http */
  source?: string;
  modelscope_id?: string | null;
}

const commonApi = (
  method: 'get' | 'post',
  url: string,
  params: Record<string, unknown> = {},
) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp[method](
    {
      url,
      headers: { ignoreCancelToken: true },
      ...params,
    },
    { isTransformResponse: true },
  );
};

export interface SamPredictParams {
  image_base64?: string;
  image_url?: string;
  text?: string[];
  bboxes?: number[][];
  return_masks?: boolean;
  conf?: number;
  save_result?: boolean;
}

export interface SamPredictResult {
  predictions: Array<{
    class: number;
    class_name: string;
    confidence: number;
    bbox: number[];
  }>;
  masks?: Array<{
    class_name: string;
    confidence: number;
    xy: number[][][];
    xyn: number[][][];
    contour_count: number;
  }>;
  orig_shape?: number[];
  inference_ms?: number;
  prompt_type?: string;
  engine?: string;
  /** 服务端绘制的标注结果图（JPEG base64，无前缀） */
  result_image_base64?: string;
}

export const getSamHealth = () =>
  defHttp
    .get(
      { url: `${Api.Sam}/health`, headers: { ignoreCancelToken: true } },
      // health 返回裸 JSON {status,enabled,engine,device,model_loaded}，HTTP 200/503，无 {code} 信封，不应走业务 transform
      { isTransformResponse: false, errorMessageMode: 'none' },
    )
    .then((res) => ((res as { data?: unknown })?.data ?? res));

export const samPredict = (data: SamPredictParams) => {
  // SAM 模型推理（含模型冷加载）耗时较长，超时设为 5 分钟
  // 不使用 commonApi 以避免 cloneDeep 可能丢失 timeout 配置
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp.post(
    {
      url: `${Api.Sam}/predict`,
      data,
      timeout: 300000,
      headers: { ignoreCancelToken: true },
    },
    { isTransformResponse: true, errorMessageMode: 'none' },
  );
};

export const samPredictFile = (file: File, params: Omit<SamPredictParams, 'image_base64'>) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  const formData = new FormData();
  formData.append('file', file);
  if (params.text) formData.append('text', JSON.stringify(params.text));
  if (params.bboxes) formData.append('bboxes', JSON.stringify(params.bboxes));
  formData.append('return_masks', String(params.return_masks ?? true));
  if (params.conf != null) formData.append('conf', String(params.conf));
  return defHttp.post(
    { url: `${Api.Sam}/predict`, data: formData, timeout: 300000 },
    { isTransformResponse: true, errorMessageMode: 'none' },
  );
};

export const getSamHistory = (params: { page?: number; page_size?: number; prompt_type?: string } = {}) =>
  commonApi('get', `${Api.Sam}/history`, { params });

/** 查询 SAM 模型是否已下载 */
export const getSamModelStatus = () => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp
    .get(
      {
        url: `${Api.Sam}/model/status`,
        headers: {
          // @ts-ignore
          ignoreCancelToken: true,
        },
      },
      { isTransformResponse: false, errorMessageMode: 'none' },
    )
    .then((res) => {
      const body = ((res as { data?: { code: number; msg: string; data: SamModelStatus } })?.data ??
        res) as { code: number; msg: string; data: SamModelStatus };
      if (!SAM_API_SUCCESS_CODES.has(body?.code)) {
        throw new Error(body?.msg || '查询失败');
      }
      return body;
    });
};

/** 触发服务端下载 SAM 模型权重 */
export const downloadSamModel = () => {
  return samMutationApi<SamModelStatus & { started?: boolean; message?: string }>(
    'post',
    `${Api.Sam}/model/download`,
  );
};

export function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

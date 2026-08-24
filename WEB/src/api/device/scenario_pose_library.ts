/**
 * 场景姿态库管理接口
 */
import { defHttp } from '@/utils/http/axios';

const POSE_PREFIX = '/video/scenario-pose';

const API_SUCCESS_CODES = new Set([0, 200]);

export function isScenarioPoseApiOk(response: unknown): boolean {
  if (response == null || typeof response !== 'object') return false;
  const r = response as Record<string, unknown>;
  if (typeof r.code === 'number') return API_SUCCESS_CODES.has(r.code);
  if (typeof r.id === 'number') return true;
  if (Array.isArray(r.entries)) return true;
  return false;
}

export function parseScenarioPoseApiError(error: unknown, fallback = '操作失败，请稍后重试'): string {
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

async function poseMutationApi<T = unknown>(
  method: 'post' | 'put' | 'delete',
  url: string,
  data?: unknown,
): Promise<{ code: number; msg: string; data?: T }> {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  const res = await defHttp[method](
    {
      url,
      ...(method === 'delete' ? {} : { data }),
      headers: { ignoreCancelToken: true },
    },
    { isTransformResponse: false, errorMessageMode: 'none' },
  );
  return res as { code: number; msg: string; data?: T };
}

async function commonApi<T>(method: 'get', url: string, options: { params?: Record<string, unknown> } = {}) {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp[method](
    {
      url,
      params: options.params,
      headers: { ignoreCancelToken: true },
    },
    { isTransformResponse: true, errorMessageMode: 'none' },
  ) as Promise<T>;
}

export interface ScenarioPoseLibrary {
  id: number;
  name: string;
  code: string;
  scene_category?: string;
  business_tags?: string[];
  description?: string;
  similarity_threshold?: number;
  match_mode?: string;
  intent_event?: string;
  intent_object?: string;
  alert_level?: string;
  is_enabled: boolean;
  entry_count?: number;
  created_at?: string;
  updated_at?: string;
  entries?: ScenarioPoseEntry[];
}

export interface ScenarioPoseEntry {
  id: number;
  library_id: number;
  name: string;
  source_type?: string;
  image_path?: string;
  image_url?: string;
  keypoints?: number[][][];
  feature_vector?: number[];
  extra_rules?: Record<string, unknown>;
  remark?: string;
  is_enabled: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface SceneTemplate {
  key: string;
  name: string;
  scene_category: string;
  intent_event: string;
  intent_object: string;
}

export const listScenarioPoseLibraries = (params?: { search?: string; is_enabled?: boolean }) =>
  commonApi<{ code: number; msg: string; data: ScenarioPoseLibrary[]; total: number }>(
    'get',
    `${POSE_PREFIX}/libraries`,
    { params },
  );

export const getScenarioPoseLibrary = (libraryId: number, includeEntries = false) =>
  commonApi<{ code: number; msg: string; data: ScenarioPoseLibrary }>(
    'get',
    `${POSE_PREFIX}/libraries/${libraryId}`,
    { params: { include_entries: includeEntries } },
  );

export const createScenarioPoseLibrary = (data: Partial<ScenarioPoseLibrary>) =>
  poseMutationApi<ScenarioPoseLibrary>('post', `${POSE_PREFIX}/libraries`, data);

export const updateScenarioPoseLibrary = (libraryId: number, data: Partial<ScenarioPoseLibrary>) =>
  poseMutationApi<ScenarioPoseLibrary>('put', `${POSE_PREFIX}/libraries/${libraryId}`, data);

export const deleteScenarioPoseLibrary = (libraryId: number) =>
  poseMutationApi('delete', `${POSE_PREFIX}/libraries/${libraryId}`);

export const listScenarioPoseEntries = (libraryId: number, params?: { search?: string }) =>
  commonApi<{ code: number; msg: string; data: ScenarioPoseEntry[]; total: number }>(
    'get',
    `${POSE_PREFIX}/libraries/${libraryId}/entries`,
    { params },
  );

export const addScenarioPoseEntry = (libraryId: number, formData: FormData) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp.post(
    {
      url: `${POSE_PREFIX}/libraries/${libraryId}/entries`,
      data: formData,
      headers: { 'Content-Type': 'multipart/form-data', ignoreCancelToken: true },
    },
    { isTransformResponse: false, errorMessageMode: 'none' },
  );
};

export const updateScenarioPoseEntry = (entryId: number, data: Partial<ScenarioPoseEntry>) =>
  poseMutationApi<ScenarioPoseEntry>('put', `${POSE_PREFIX}/entries/${entryId}`, data);

export const deleteScenarioPoseEntry = (entryId: number) =>
  poseMutationApi('delete', `${POSE_PREFIX}/entries/${entryId}`);

export const reExtractScenarioPoseEntry = (entryId: number, conf = 0.25) =>
  poseMutationApi<ScenarioPoseEntry>('post', `${POSE_PREFIX}/entries/${entryId}/re-extract`, { conf });

export const extractPosePreview = (formData: FormData) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp.post(
    {
      url: `${POSE_PREFIX}/entries/extract`,
      data: formData,
      headers: { 'Content-Type': 'multipart/form-data', ignoreCancelToken: true },
    },
    { isTransformResponse: false, errorMessageMode: 'none' },
  );
};

export const matchTestScenarioPose = (libraryId: number, formData: FormData) => {
  defHttp.setHeader({ 'X-Authorization': 'Bearer ' + localStorage.getItem('jwt_token') });
  return defHttp.post(
    {
      url: `${POSE_PREFIX}/libraries/${libraryId}/match-test`,
      data: formData,
      headers: { 'Content-Type': 'multipart/form-data', ignoreCancelToken: true },
    },
    { isTransformResponse: false, errorMessageMode: 'none' },
  );
};

export const listSceneTemplates = () =>
  commonApi<{ code: number; msg: string; data: SceneTemplate[] }>('get', `${POSE_PREFIX}/scene-templates`);

export const importSceneTemplate = (libraryId: number, templateKey: string) =>
  poseMutationApi<ScenarioPoseEntry>('post', `${POSE_PREFIX}/libraries/${libraryId}/import-template`, {
    template_key: templateKey,
  });

export function resolveScenarioPoseImageUrl(imageUrl?: string | null): string {
  if (!imageUrl) return '';
  if (imageUrl.startsWith('http')) return imageUrl;
  return imageUrl.startsWith('/') ? imageUrl : `/${imageUrl}`;
}

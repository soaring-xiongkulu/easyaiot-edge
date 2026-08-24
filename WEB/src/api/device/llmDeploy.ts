import { defHttp } from '@/utils/http/axios';

enum Api {
  CATALOG = '/model/llm_deploy/catalog',
  LIST = '/model/llm_deploy/list',
  CHECK_VRAM = '/model/llm_deploy/check-vram',
  DEPLOY = '/model/llm_deploy/deploy',
  STOP = '/model/llm_deploy/stop',
  DELETE = '/model/llm_deploy/delete',
}

export interface QwenModelPreset {
  key: string;
  label: string;
  hf_model_id: string;
  model_type: string;
  min_vram_gb: number;
  recommended_gpu_count: number;
  max_model_len_default: number;
  description?: string;
}

export interface LLMDeployService {
  id?: number;
  service_name: string;
  qwen_model_key: string;
  hf_model_id: string;
  node_id?: number;
  server_ip?: string;
  port?: number;
  api_endpoint?: string;
  tensor_parallel_size?: number;
  max_model_len?: number;
  status?: string;
  llm_config_id?: number;
  process_id?: number;
  log_path?: string;
  error_message?: string;
  deploy_time?: string;
  last_heartbeat?: string;
  created_at?: string;
  updated_at?: string;
}

export interface LLMDeployParams {
  qwen_model_key: string;
  target_node_id?: number;
  auto_schedule?: boolean;
  start_port?: number;
  tensor_parallel_size?: number;
  max_model_len?: number;
  service_name?: string;
}

export function getLlmDeployCatalog() {
  return defHttp.get<{ data: QwenModelPreset[] }>({ url: Api.CATALOG });
}

export function getLlmDeployList(params?: { page?: number; pageSize?: number }) {
  return defHttp.get<{ data: { list: LLMDeployService[]; total: number } }>({
    url: Api.LIST,
    params,
  });
}

export interface LLMVramCheckResult {
  ok: boolean;
  model_key?: string;
  model_label?: string;
  node_id?: number;
  node_name?: string;
  node_host?: string;
  tensor_parallel_size?: number;
  required_vram_gb?: number;
  required_gpu_count?: number;
  free_vram_gb?: number;
  selected_free_vram_gb?: number;
  total_vram_gb?: number;
  gpu_count?: number;
  gpus?: Array<{
    id?: number;
    name?: string;
    mem_total_gb?: number;
    mem_free_gb?: number;
    util?: number;
  }>;
  selected_gpus?: Array<{
    id?: number;
    name?: string;
    mem_free_gb?: number;
    mem_total_gb?: number;
  }>;
}

export function checkLlmDeployVram(params: {
  qwen_model_key: string;
  target_node_id: number;
  tensor_parallel_size?: number;
}) {
  return defHttp.get<{ msg: string; data: LLMVramCheckResult }>({
    url: Api.CHECK_VRAM,
    params,
  });
}

export function deployLlmModel(data: LLMDeployParams) {
  return defHttp.post<{ data: LLMDeployService; msg: string }>({ url: Api.DEPLOY, data });
}

export function stopLlmDeploy(serviceId: number) {
  return defHttp.post({ url: Api.STOP, data: { service_id: serviceId } });
}

export function deleteLlmDeploy(id: number) {
  return defHttp.delete({ url: Api.DELETE, params: { id } });
}

/** 模型来源分类 — 数据集无人值守 / 选模型时使用 */

export type ModelOrigin = 'upload' | 'auto_label' | 'smart_label' | 'train' | 'import' | 'unknown';

export interface ModelListItem {
  id: number;
  name?: string;
  version?: string;
  description?: string;
  model_origin?: string;
  origin_ref?: string;
  model_path?: string;
  onnx_model_path?: string;
  torchscript_model_path?: string;
  tensorrt_model_path?: string;
  openvino_model_path?: string;
  class_names?: string | string[];
}

export const MODEL_ORIGIN_LABELS: Record<ModelOrigin, string> = {
  upload: '用户上传',
  auto_label: '自动标注产出',
  smart_label: '智能标注训练',
  train: '训练任务导出',
  import: '外部导入',
  unknown: '其他',
};

export const MODEL_ORIGIN_COLORS: Record<ModelOrigin, string> = {
  upload: 'blue',
  auto_label: 'cyan',
  smart_label: 'purple',
  train: 'green',
  import: 'default',
  unknown: 'default',
};

/** 推断模型来源（后端 model_origin 字段优先） */
export function resolveModelOrigin(model: ModelListItem): ModelOrigin {
  const raw = (model.model_origin || '').toLowerCase().trim();
  if (raw && raw in MODEL_ORIGIN_LABELS) {
    return raw as ModelOrigin;
  }
  const desc = `${model.description || ''} ${model.name || ''}`.toLowerCase();
  if (desc.includes('auto_label') || desc.includes('自动标注')) return 'auto_label';
  if (desc.includes('smart_label') || desc.includes('sam_pipeline') || desc.includes('智能标注')) {
    return 'smart_label';
  }
  if (desc.includes('train_') || desc.includes('训练')) return 'train';
  if (model.onnx_model_path || model.model_path) return 'upload';
  return 'unknown';
}

export function modelHasWeights(model: ModelListItem): boolean {
  return Boolean(
    model.model_path ||
      model.onnx_model_path ||
      model.torchscript_model_path ||
      model.tensorrt_model_path ||
      model.openvino_model_path,
  );
}

export function formatModelOptionLabel(model: ModelListItem): string {
  const origin = resolveModelOrigin(model);
  const originLabel = MODEL_ORIGIN_LABELS[origin];
  const ver = model.version ? ` v${model.version}` : '';
  return `${model.name || '模型'}${ver} (#${model.id}) · ${originLabel}`;
}

export function filterModelsByOrigin(
  models: ModelListItem[],
  origin: ModelOrigin | 'all',
): ModelListItem[] {
  const withWeights = models.filter(modelHasWeights);
  if (origin === 'all') return withWeights;
  return withWeights.filter((m) => resolveModelOrigin(m) === origin);
}

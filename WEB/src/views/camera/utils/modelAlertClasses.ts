import { getModelClasses, parseModelClassPayload } from '@/api/device/model';

/** 内置 YOLO 预训练模型使用的 COCO 80 类 */
export const COCO_CLASS_NAMES: string[] = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck',
  'boat', 'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench',
  'bird', 'cat', 'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear',
  'zebra', 'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase',
  'frisbee', 'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat',
  'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
  'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
  'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut',
  'cake', 'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet',
  'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave',
  'oven', 'toaster', 'sink', 'refrigerator', 'book', 'clock', 'vase',
  'scissors', 'teddy bear', 'hair drier', 'toothbrush',
];

const DEFAULT_MODEL_CLASS_MAP: Record<number, string[]> = {
  [-1]: COCO_CLASS_NAMES,
  [-2]: COCO_CLASS_NAMES,
  [-3]: COCO_CLASS_NAMES,
};

function mergeUniqueClassNames(existing: string[], incoming: string[]): string[] {
  const seen = new Set(existing.map((name) => name.toLowerCase()));
  const merged = [...existing];
  for (const name of incoming) {
    const label = String(name || '').trim();
    if (!label) continue;
    const key = label.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(label);
  }
  return merged;
}

export async function loadAlertClassNamesForModels(modelIds: number[]): Promise<string[]> {
  const ids = Array.isArray(modelIds)
    ? modelIds.map((id) => Number(id)).filter((id) => !Number.isNaN(id))
    : [];
  if (ids.length === 0) {
    return [];
  }

  let classNames: string[] = [];
  for (const modelId of ids) {
    if (modelId < 0) {
      classNames = mergeUniqueClassNames(classNames, DEFAULT_MODEL_CLASS_MAP[modelId] || COCO_CLASS_NAMES);
      continue;
    }
    try {
      const resp = await getModelClasses(modelId);
      const { classNames: names } = parseModelClassPayload(resp);
      classNames = mergeUniqueClassNames(classNames, names);
    } catch (error) {
      console.warn(`加载模型 ${modelId} 检测标签失败`, error);
    }
  }
  return classNames;
}

export function buildAlertClassOptions(classNames: string[]) {
  return classNames.map((name) => ({ label: name, value: name }));
}

export function pruneAlertClassNames(selected: string[] | undefined, available: string[]): string[] {
  if (!Array.isArray(selected) || selected.length === 0) {
    return [];
  }
  const availableSet = new Set(available.map((name) => name.toLowerCase()));
  return selected.filter((name) => availableSet.has(String(name).toLowerCase()));
}

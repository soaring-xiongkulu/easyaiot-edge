/** COCO-17 骨架连接（与 VIDEO pose_analysis.py 一致） */
export const COCO_SKELETON: [number, number][] = [
  [0, 1], [0, 2], [1, 3], [2, 4],
  [5, 6], [5, 7], [7, 9], [6, 8], [8, 10],
  [5, 11], [6, 12], [11, 12],
  [11, 13], [13, 15], [12, 14], [14, 16],
];

export type PoseKeypoint = [number, number, number];

export interface PosePerson {
  keypoints: PoseKeypoint[];
  person_index?: number;
}

export interface PoseIntentMatchInfo {
  library_name?: string;
  entry_name?: string;
  similarity?: number;
  scene_category?: string;
  person_index?: number;
  intent_event?: string;
}

export interface ParsedAlertPoseInfo {
  persons: PosePerson[];
  matches: PoseIntentMatchInfo[];
  matchType?: string;
}

function tryParseJson<T>(raw: unknown): T | null {
  if (raw == null) return null;
  if (typeof raw === 'object') return raw as T;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }
  return null;
}

/** 从告警 information 解析姿态结果与意图匹配信息 */
export function parseAlertPoseInfo(information: unknown): ParsedAlertPoseInfo | null {
  const info = tryParseJson<Record<string, unknown>>(information);
  if (!info) return null;

  const poseResult = tryParseJson<{ persons?: PosePerson[]; count?: number }>(info.pose_result);
  const persons = (poseResult?.persons || []).filter((p) => Array.isArray(p?.keypoints) && p.keypoints.length > 0);
  if (!persons.length) return null;

  const rawMatches = info.pose_intent_matches;
  let matches: PoseIntentMatchInfo[] = [];
  if (Array.isArray(rawMatches)) {
    matches = rawMatches as PoseIntentMatchInfo[];
  } else if (info.match_type === 'pose_intent') {
    matches = [{
      library_name: info.library_name as string | undefined,
      entry_name: info.entry_name as string | undefined,
      similarity: info.similarity as number | undefined,
      scene_category: info.scene_category as string | undefined,
      person_index: info.person_index as number | undefined,
    }];
  }

  return {
    persons,
    matches,
    matchType: (info.match_type as string) || undefined,
  };
}

export function isPoseIntentAlertEvent(event?: string | null): boolean {
  if (!event) return false;
  return event === 'pose_intent_match' || event.startsWith('pose_');
}

/** 在 canvas 上绘制 COCO-17 骨架 */
export function drawPoseSkeletonOnCanvas(
  ctx: CanvasRenderingContext2D,
  persons: PosePerson[],
  options?: {
    highlightPersonIndex?: number;
    keypointThreshold?: number;
    lineWidth?: number;
  },
) {
  const threshold = options?.keypointThreshold ?? 0.25;
  const lineWidth = options?.lineWidth ?? 2;
  const highlightIdx = options?.highlightPersonIndex;

  persons.forEach((person, pi) => {
    const keypoints = person.keypoints || [];
    const isHighlight = highlightIdx != null && (person.person_index ?? pi) === highlightIdx;
    const boneColor = isHighlight ? '#ff4d4f' : '#52c41a';
    const jointColor = isHighlight ? '#ff7875' : '#ff4d4f';

    for (const [i, j] of COCO_SKELETON) {
      if (i >= keypoints.length || j >= keypoints.length) continue;
      const [x1, y1, c1] = keypoints[i];
      const [x2, y2, c2] = keypoints[j];
      if (c1 < threshold || c2 < threshold) continue;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.strokeStyle = boneColor;
      ctx.lineWidth = lineWidth;
      ctx.stroke();
    }

    keypoints.forEach(([x, y, c]) => {
      if (c < threshold) return;
      ctx.beginPath();
      ctx.arc(x, y, isHighlight ? 4 : 3, 0, Math.PI * 2);
      ctx.fillStyle = jointColor;
      ctx.fill();
    });
  });
}

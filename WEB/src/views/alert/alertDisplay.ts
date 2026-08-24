/** 告警列表展示与筛选共用常量 */

export const ALERT_EVENT_OPTIONS = [
  { value: null, label: '全部' },
  { value: '行人检测', label: '行人检测' },
  { value: 'face_library_match', label: '人脸库匹配' },
  { value: 'plate_library_match', label: '车牌库匹配' },
  { value: 'pose_intent_match', label: '姿态意图' },
  { value: 'pose_fall_detected', label: '跌倒检测' },
  { value: 'pose_climb_detected', label: '攀爬检测' },
  { value: 'pose_squat_detected', label: '蹲伏检测' },
  { value: 'pose_hands_up_detected', label: '举手求助' },
] as const;

const ALERT_EVENT_LABEL_MAP: Record<string, string> = {
  face_library_match: '人脸库匹配',
  plate_library_match: '车牌库匹配',
  pose_intent_match: '姿态意图',
  pose_fall_detected: '跌倒检测',
  pose_climb_detected: '攀爬检测',
  pose_squat_detected: '蹲伏检测',
  pose_hands_up_detected: '举手求助',
  行人检测: '行人检测',
};

export function formatAlertEvent(event?: string | null): string {
  if (!event) return '-';
  if (event.startsWith('pose_') && !ALERT_EVENT_LABEL_MAP[event]) {
    return event.replace(/^pose_/, '').replace(/_/g, ' ');
  }
  return ALERT_EVENT_LABEL_MAP[event] || event;
}

export function getAlertEventTagColor(event?: string | null): string {
  if (event === 'face_library_match') return 'purple';
  if (event === 'plate_library_match') return 'cyan';
  if (event === '行人检测') return 'orange';
  if (event?.startsWith('pose_')) return 'volcano';
  return 'default';
}

/** 解析告警 information（对象或 JSON 字符串） */
export function parseAlertInformation(information: unknown): Record<string, unknown> | null {
  if (information == null) return null;
  if (typeof information === 'object') return information as Record<string, unknown>;
  if (typeof information === 'string') {
    try {
      const parsed = JSON.parse(information);
      return typeof parsed === 'object' && parsed ? parsed : null;
    } catch {
      return null;
    }
  }
  return null;
}

/** 姿态意图告警摘要 */
export function formatPoseIntentAlertSummary(information: unknown): string | undefined {
  const info = parseAlertInformation(information);
  if (!info || info.match_type !== 'pose_intent') return undefined;
  const lib = info.library_name ? String(info.library_name) : '';
  const entry = info.entry_name ? String(info.entry_name) : '';
  const sim = info.similarity != null ? `${(Number(info.similarity) * 100).toFixed(1)}%` : '';
  const parts = [lib, entry, sim].filter(Boolean);
  return parts.length ? parts.join(' · ') : undefined;
}

type AlertPersonRecord = {
  event?: string | null;
  matched_person_name?: string | null;
  source_event?: string | null;
};

/** 人脸库匹配告警：读取已录入人员姓名 */
export function getAlertMatchedPersonName(record: AlertPersonRecord): string | undefined {
  if (record.matched_person_name) {
    return String(record.matched_person_name);
  }
  return undefined;
}

/** 人脸库匹配告警：读取触发的算法告警事件 */
export function getAlertSourceEvent(record: AlertPersonRecord): string | undefined {
  if (record.source_event) {
    return String(record.source_event);
  }
  return undefined;
}

/** 列表/大屏标题：人员姓名 + 触发告警 */
export function formatAlertListTitle(record: AlertPersonRecord & { event?: string | null; information?: unknown }): string {
  const poseSummary = formatPoseIntentAlertSummary(record.information);
  if (poseSummary) {
    return `${formatAlertEvent(record.event)} · ${poseSummary}`;
  }
  const personName = getAlertMatchedPersonName(record);
  const sourceEvent = getAlertSourceEvent(record);
  if (personName && sourceEvent) {
    return `${personName} · ${formatAlertEvent(sourceEvent)}`;
  }
  if (personName) {
    return `${formatAlertEvent(record.event)} · ${personName}`;
  }
  return formatAlertEvent(record.event);
}

/** 是否为抓拍类任务（无关联告警录像） */
export function isSnapAlertTask(record: {
  task_type?: string | null;
  information?: unknown;
}): boolean {
  let taskType = record.task_type;
  if (!taskType && record.information) {
    if (typeof record.information === 'object' && record.information !== null) {
      taskType = (record.information as { task_type?: string }).task_type;
    } else if (typeof record.information === 'string') {
      try {
        const info = JSON.parse(record.information);
        taskType = info?.task_type;
      } catch {
        // ignore
      }
    }
  }
  return taskType === 'snap' || taskType === 'snapshot';
}

export function normalizeAlertBusinessTagsParam(tags: unknown): string | undefined {
  if (Array.isArray(tags)) {
    const normalized = tags.map((t) => String(t).trim()).filter(Boolean);
    return normalized.length ? normalized.join(',') : undefined;
  }
  if (typeof tags === 'string' && tags.trim()) {
    return tags.trim();
  }
  return undefined;
}

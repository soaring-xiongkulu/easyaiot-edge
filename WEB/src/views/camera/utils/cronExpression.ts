import CronParser from 'cron-parser';

/** 抓拍任务最短执行间隔（秒） */
export const MIN_SNAP_CRON_INTERVAL_SECONDS = 30;

/** 抓拍任务标准 6 段 cron：秒 分 时 日 月 周（勿使用 ?） */
export const DEFAULT_SNAP_CRON = '0 */5 * * * *';

export const CRON_FORMAT_HINT =
  `格式：秒 分 时 日 月 周（6 段）。最短间隔 ${MIN_SNAP_CRON_INTERVAL_SECONDS} 秒；秒级仅支持每 30 秒；分钟级示例 0 */5 * * * * 表示每 5 分钟；请勿使用 ?。`;

export interface CronTemplateOption {
  label: string;
  value: string;
  description?: string;
  group?: 'second' | 'minute';
}

/** 常用抓拍 cron 模板（与后端 croniter 兼容） */
export const SNAP_CRON_TEMPLATES: CronTemplateOption[] = [
  { label: '每 30 秒', value: '*/30 * * * * *', group: 'second' },
  { label: '每 1 分钟', value: '0 */1 * * * *', group: 'minute' },
  { label: '每 5 分钟', value: '0 */5 * * * *', group: 'minute' },
  { label: '每 10 分钟', value: '0 */10 * * * *', group: 'minute' },
  { label: '每 15 分钟', value: '0 */15 * * * *', group: 'minute' },
  { label: '每 30 分钟', value: '0 */30 * * * *', group: 'minute' },
  { label: '每小时整点', value: '0 0 * * * *', group: 'minute' },
  { label: '每天 00:00', value: '0 0 0 * * *', group: 'minute' },
  { label: '每天 08:00', value: '0 0 8 * * *', group: 'minute' },
  { label: '每天 12:00', value: '0 0 12 * * *', group: 'minute' },
  { label: '每天 18:00', value: '0 0 18 * * *', group: 'minute' },
  { label: '工作日 09:00', value: '0 0 9 * * 1-5', group: 'minute' },
];

/** 标签旁 BasicHelp 提示（格式说明 + 常用模板，可选中复制） */
export function getSnapCronHelpLines(): string[] {
  return [
    CRON_FORMAT_HINT,
    '常用模板（可选中复制表达式）：',
    '【秒级（最短30秒）】',
    ...SNAP_CRON_TEMPLATES.filter((t) => t.group === 'second').map(
      (t) => `${t.label}: ${t.value}`,
    ),
    '【分钟级及以上】',
    ...SNAP_CRON_TEMPLATES.filter((t) => t.group !== 'second').map(
      (t) => `${t.label}: ${t.value}`,
    ),
  ];
}

function toSelectOption(item: CronTemplateOption) {
  return {
    label: `${item.label} — ${item.value}`,
    value: item.value,
  };
}

export function getSnapCronTemplateSelectOptions() {
  const secondItems = SNAP_CRON_TEMPLATES.filter((item) => item.group === 'second');
  const minuteItems = SNAP_CRON_TEMPLATES.filter((item) => item.group !== 'second');
  return [
    { label: '秒级（最短30秒）', options: secondItems.map(toSelectOption) },
    { label: '分钟级及以上', options: minuteItems.map(toSelectOption) },
  ];
}

/** 将 Quartz 风格 cron 规范为 cron-parser 可解析格式 */
export function normalizeSnapCronExpression(expression: string): string {
  const parts = expression.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 6 && parts[0].startsWith('*/') && parts[5] === '?') {
    return parts.slice(0, 5).join(' ');
  }
  return parts.map((p) => (p === '?' ? '*' : p)).join(' ');
}

/**
 * 校验抓拍 cron 最短执行间隔
 */
export function validateSnapCronMinInterval(
  expression: string,
  minSeconds: number = MIN_SNAP_CRON_INTERVAL_SECONDS,
): { valid: boolean; message?: string; normalized?: string } {
  const raw = expression?.trim();
  if (!raw) {
    return { valid: false, message: '请填写 Cron 表达式' };
  }

  try {
    const parts = raw.split(/\s+/).filter(Boolean);
    let val = normalizeSnapCronExpression(raw);
    if (parts.length === 7) {
      val = normalizeSnapCronExpression(parts.slice(0, 6).join(' '));
    }

    const iter = CronParser.parseExpression(val);
    const times: Date[] = [];
    for (let i = 0; i < 5; i++) {
      times.push(iter.next().toDate());
    }
    const deltas = times.slice(1).map((t, i) => (t.getTime() - times[i].getTime()) / 1000);
    const minDelta = Math.min(...deltas);
    if (minDelta < minSeconds) {
      return {
        valid: false,
        message: `抓拍执行间隔不能小于 ${minSeconds} 秒，请使用模板或增大间隔（当前约 ${Math.round(minDelta)} 秒）`,
      };
    }
    return { valid: true, normalized: val };
  } catch (e: any) {
    return { valid: false, message: `Cron 表达式错误：${e?.message || e}` };
  }
}

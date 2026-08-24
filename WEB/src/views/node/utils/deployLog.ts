import type { MediaDeployStepVO } from '@/api/device/node';

export interface DeployResultState {
  success: boolean;
  message: string;
  steps: MediaDeployStepVO[];
}

const STATUS_LABEL: Record<string, string> = {
  success: '成功',
  failed: '失败',
  skipped: '跳过',
  running: '进行中',
  pending: '等待',
};

export function stepStatusLabel(status?: string): string {
  return STATUS_LABEL[status || ''] || '等待';
}

export function resolveDeployMessage(data: {
  success?: boolean;
  message?: string;
  steps?: MediaDeployStepVO[];
}): string {
  if (data.message?.trim()) return data.message;
  if (data.success) return '部署完成';
  const failedStep = data.steps?.find((s) => s.status === 'failed');
  if (failedStep?.name) return `${failedStep.name}失败`;
  return '部署失败';
}

/** 格式化为可读部署日志，避免 Steps 描述与日志区重复 */
export function formatDeployLog(steps: MediaDeployStepVO[]): string {
  if (!steps?.length) return '';
  return steps
    .map((step) => {
      const header = `--- ${step.name} [${stepStatusLabel(step.status)}] ---`;
      const body = step.output?.trim();
      if (!body) return header;
      return `${header}\n${body}`;
    })
    .join('\n\n');
}

import type { ComputeNodeVO, MediaDeployStepVO, WorkloadBundleNodeResult } from '@/api/device/node';
import { resolveDeployMessage } from './deployLog';

export type NodeOpResult = {
  success?: boolean;
  message?: string;
  steps?: MediaDeployStepVO[];
};

/** 按节点顺序执行远程操作，汇总各节点结果 */
export async function runSequentialNodeOps(
  nodes: ComputeNodeVO[],
  op: (nodeId: number) => Promise<NodeOpResult>,
): Promise<WorkloadBundleNodeResult[]> {
  const results: WorkloadBundleNodeResult[] = [];
  for (const node of nodes) {
    if (!node.id) continue;
    try {
      const data = await op(node.id);
      results.push({
        nodeId: node.id,
        nodeName: node.name,
        host: node.host,
        success: !!data.success,
        message: resolveDeployMessage(data),
        steps: data.steps,
      });
    } catch (e: unknown) {
      results.push({
        nodeId: node.id,
        nodeName: node.name,
        host: node.host,
        success: false,
        message: e instanceof Error ? e.message : '请求失败',
      });
    }
  }
  return results;
}

export function summarizeBatchResults(results: WorkloadBundleNodeResult[]): {
  success: boolean;
  message: string;
} {
  const ok = results.filter((r) => r.success).length;
  const total = results.length;
  if (!total) return { success: false, message: '未选择目标节点' };
  if (ok === total) return { success: true, message: `全部 ${total} 个节点执行成功` };
  if (ok === 0) return { success: false, message: `全部 ${total} 个节点执行失败` };
  return { success: false, message: `${ok}/${total} 个节点成功，${total - ok} 个失败` };
}

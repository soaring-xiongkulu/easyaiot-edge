import type { ComputeNodeVO } from '@/api/device/node';

type PlatformNodeLike = Pick<ComputeNodeVO, 'isPlatform' | 'capabilities'> | null | undefined;

export function isPlatformNode(node: PlatformNodeLike): boolean {
  return node?.isPlatform === true || node?.capabilities?.platform === true;
}

export function sortNodesWithPlatformFirst<T extends PlatformNodeLike>(nodes: T[]): T[] {
  return [...nodes].sort((a, b) => {
    const aPlatform = isPlatformNode(a) ? 0 : 1;
    const bPlatform = isPlatformNode(b) ? 0 : 1;
    return aPlatform - bPlatform;
  });
}

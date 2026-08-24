export interface TrainGpuMemoryInfo {
  totalMemoryGb?: number;
  freeMemoryGb?: number;
}

export interface TrainBatchSizeRecommendation {
  batchSize: number;
  perGpuBatchSize: number;
  gpuCount: number;
  limitingMemoryGb?: number;
}

interface RecommendTrainBatchSizeOptions {
  gpuCount: number;
  devices: TrainGpuMemoryInfo[];
  imageSize: number;
  maxBatchSize?: number;
}

export type TrainTaskLaunchMode = 'new' | 'resume' | 'retrain';

export function defaultAutoBatchSize(mode: TrainTaskLaunchMode): boolean {
  return mode !== 'resume';
}

const PER_GPU_BATCH_STEPS = [1, 2, 4, 8, 16, 32];

function positiveNumber(value: unknown): number | undefined {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : undefined;
}

function usableMemoryGb(device: TrainGpuMemoryInfo): number | undefined {
  const total = positiveNumber(device.totalMemoryGb);
  const free = positiveNumber(device.freeMemoryGb);
  if (total && free) return Math.min(free, total * 0.8);
  if (total) return total * 0.8;
  if (free) return free;
  return undefined;
}

function baseBatchAt640(memoryGb?: number): number {
  if (memoryGb == null) return 4;
  if (memoryGb >= 24) return 16;
  if (memoryGb >= 12) return 8;
  if (memoryGb >= 8) return 4;
  if (memoryGb >= 5) return 2;
  return 1;
}

function floorBatchStep(target: number): number {
  return PER_GPU_BATCH_STEPS.reduce(
    (result, step) => step <= target ? step : result,
    1,
  );
}

export function recommendTrainBatchSize(
  options: RecommendTrainBatchSizeOptions,
): TrainBatchSizeRecommendation {
  const gpuCount = Math.max(0, Math.floor(Number(options.gpuCount) || 0));
  if (!gpuCount) {
    return { batchSize: 4, perGpuBatchSize: 4, gpuCount: 0 };
  }

  const memoryValues = options.devices
    .map(usableMemoryGb)
    .filter((value): value is number => value != null);
  const limitingMemory = memoryValues.length ? Math.min(...memoryValues) : undefined;
  const imageSize = Math.max(320, Number(options.imageSize) || 640);
  const imageScale = (640 / imageSize) ** 2;
  const maxBatchSize = Math.max(gpuCount, Math.floor(options.maxBatchSize ?? 64));
  const maxPerGpu = Math.max(1, Math.floor(maxBatchSize / gpuCount));
  const targetPerGpu = Math.min(baseBatchAt640(limitingMemory) * imageScale, maxPerGpu);
  const perGpuBatchSize = floorBatchStep(targetPerGpu);

  return {
    batchSize: perGpuBatchSize * gpuCount,
    perGpuBatchSize,
    gpuCount,
    ...(limitingMemory == null
      ? {}
      : { limitingMemoryGb: Math.round(limitingMemory * 100) / 100 }),
  };
}

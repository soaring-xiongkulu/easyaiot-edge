import {
  abortDatasetChunkUpload,
  completeDatasetChunkUpload,
  initDatasetChunkUpload,
  uploadDatasetChunk,
  uploadDatasetImage,
  waitForDatasetImportTask,
  type DatasetImageUploadResult,
} from '@/api/device/dataset';
import JSZip from 'jszip';

/** 单分片大小 10MB */
export const DATASET_CHUNK_SIZE = 10 * 1024 * 1024;

/** 数据集单文件最大 200GB */
export const DATASET_MAX_FILE_SIZE = 200 * 1024 * 1024 * 1024;

export const UPLOAD_CONFIG = {
  /** 从环境变量读取，未配置时默认为 5 */
  MAX_CONCURRENCY: Number(import.meta.env.VITE_UPLOAD_MAX_CONCURRENCY) || 5,
};

/** 小于该阈值走直传（仍兼容旧接口） */
const DIRECT_UPLOAD_THRESHOLD = 5 * 1024 * 1024;

/** 前端打包压缩占用进度的比例 */
const ZIP_PROGRESS_WEIGHT = 0.15;

const STORAGE_PREFIX = 'dataset-chunk-upload:';

export interface ResumableUploadOptions {
  datasetId: number;
  file: File;
  isZip: boolean;
  /** 0-100 */
  onProgress?: (percent: number) => void;
  signal?: AbortSignal;
}

export interface ResumableUploadResult extends DatasetImageUploadResult {
  uploadId?: string;
}

function buildFileKey(file: File): string {
  return `${file.name}|${file.size}|${file.lastModified}`;
}

function storageKey(datasetId: number, fileKey: string): string {
  return `${STORAGE_PREFIX}${datasetId}:${fileKey}`;
}

function saveLocalUploadId(datasetId: number, fileKey: string, uploadId: string) {
  try {
    localStorage.setItem(storageKey(datasetId, fileKey), uploadId);
  } catch {
    /* ignore quota */
  }
}

function clearLocalUploadId(datasetId: number, fileKey: string) {
  try {
    localStorage.removeItem(storageKey(datasetId, fileKey));
  } catch {
    /* ignore */
  }
}

async function cleanupAbortedChunkUpload(
  uploadId: string,
  datasetId: number,
  fileKey: string,
): Promise<void> {
  try {
    await abortDatasetChunkUpload(uploadId);
  } catch {
    /* 取消清理失败时不阻塞关闭弹窗 */
  }
  clearLocalUploadId(datasetId, fileKey);
}

function isUploadAborted(signal?: AbortSignal, error?: unknown): boolean {
  if (signal?.aborted) {
    return true;
  }
  return error instanceof Error && error.message === '上传已取消';
}

function calcTotalChunks(fileSize: number): number {
  return Math.max(1, Math.ceil(fileSize / DATASET_CHUNK_SIZE));
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForImportTask(
  taskId: string,
  onProgress?: (percent: number) => void,
  signal?: AbortSignal,
): Promise<DatasetImageUploadResult> {
  const task = await waitForDatasetImportTask(taskId, {
    signal,
    onProgress: (processed, total) => {
      if (total != null && total > 0) {
        onProgress?.(Math.min(99, Math.floor((processed / total) * 100)));
      } else if (processed > 0) {
        onProgress?.(99);
      }
    },
  });
  if (!task.result) {
    throw new Error('导入结果为空');
  }
  onProgress?.(100);
  return task.result;
}

async function finalizeUploadResult(
  result: DatasetImageUploadResult,
  onProgress?: (percent: number) => void,
  signal?: AbortSignal,
): Promise<DatasetImageUploadResult> {
  if (result.importStatus === 'processing' && result.importTaskId) {
    return waitForImportTask(result.importTaskId, onProgress, signal);
  }
  return result;
}

async function uploadDirect(file: File, datasetId: number, isZip: boolean): Promise<DatasetImageUploadResult> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('datasetId', String(datasetId));
  formData.append('isZip', String(isZip));
  formData.append('unzip', 'true');
  return uploadDatasetImage(formData);
}

async function uploadChunkWithRetry(
  uploadId: string,
  chunkIndex: number,
  chunkBlob: Blob,
  retries = 3,
): Promise<void> {
  let lastError: unknown;
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      await uploadDatasetChunk(uploadId, chunkIndex, chunkBlob);
      return;
    } catch (e) {
      lastError = e;
      if (attempt < retries - 1) {
        await sleep(1000 * (attempt + 1));
      }
    }
  }
  throw lastError;
}

/**
 * 断点续传上传数据集图片或 ZIP（最大 200GB）
 */
export async function resumableUploadDatasetFile(
  options: ResumableUploadOptions,
): Promise<ResumableUploadResult> {
  const { datasetId, file, isZip, onProgress, signal } = options;
  const fileKey = buildFileKey(file);
  let uploadId: string | null = null;
  let cleanupTriggered = false;

  const cleanupOnAbort = () => {
    if (!uploadId || cleanupTriggered) {
      return;
    }
    cleanupTriggered = true;
    void cleanupAbortedChunkUpload(uploadId, datasetId, fileKey);
  };

  signal?.addEventListener('abort', cleanupOnAbort, { once: true });

  try {
    if (file.size > DATASET_MAX_FILE_SIZE) {
      throw new Error('文件大小不能超过 200GB');
    }

    if (signal?.aborted) {
      throw new Error('上传已取消');
    }

    if (file.size <= DIRECT_UPLOAD_THRESHOLD) {
      onProgress?.(0);
      const result = await finalizeUploadResult(
        await uploadDirect(file, datasetId, isZip),
        onProgress,
        signal,
      );
      onProgress?.(100);
      return result;
    }

    const totalChunks = calcTotalChunks(file.size);
    const initResp = await initDatasetChunkUpload({
      datasetId,
      fileName: file.name,
      fileSize: file.size,
      isZip,
      totalChunks,
      chunkSize: DATASET_CHUNK_SIZE,
      fileKey,
    });

    uploadId = initResp.uploadId;
    const uploadedSet = new Set<number>(initResp.uploadedChunks ?? []);
    saveLocalUploadId(datasetId, fileKey, uploadId);

    const reportProgress = () => {
      const percent = Math.min(99, Math.round((uploadedSet.size / totalChunks) * 100));
      onProgress?.(percent);
    };

    reportProgress();

    for (let i = 0; i < totalChunks; i++) {
      if (signal?.aborted) {
        throw new Error('上传已取消');
      }
      if (uploadedSet.has(i)) {
        continue;
      }

      const start = i * DATASET_CHUNK_SIZE;
      const end = Math.min(file.size, start + DATASET_CHUNK_SIZE);
      const chunkBlob = file.slice(start, end);

      await uploadChunkWithRetry(uploadId, i, chunkBlob);
      uploadedSet.add(i);
      reportProgress();
    }

    onProgress?.(99);
    const result = await finalizeUploadResult(
      await completeDatasetChunkUpload(uploadId),
      (p) => onProgress?.(Math.max(99, p)),
      signal,
    );
    clearLocalUploadId(datasetId, fileKey);
    uploadId = null;
    onProgress?.(100);
    return { ...result, uploadId: initResp.uploadId };
  } catch (error) {
    if (isUploadAborted(signal, error)) {
      cleanupOnAbort();
      throw new Error('上传已取消');
    }
    throw error;
  } finally {
    signal?.removeEventListener('abort', cleanupOnAbort);
  }
}

/** 格式化文件大小显示 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

/** 将多张图片打包为 ZIP（同名文件后者覆盖） */
export async function zipDatasetImageFiles(
  files: File[],
  onProgress?: (percent: number) => void,
): Promise<File> {
  const zip = new JSZip();
  const usedNames = new Set<string>();
  for (const file of files) {
    const name = file.name;
    if (usedNames.has(name)) {
      zip.remove(name);
    }
    zip.file(name, file);
    usedNames.add(name);
  }
  const blob = await zip.generateAsync(
    {
      type: 'blob',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 },
    },
    (metadata) => {
      const percent = Math.round(metadata.percent * ZIP_PROGRESS_WEIGHT);
      onProgress?.(percent);
    },
  );
  onProgress?.(Math.round(ZIP_PROGRESS_WEIGHT * 100));
  return new File([blob], `dataset-upload-${Date.now()}.zip`, { type: 'application/zip' });
}

/** 批量上传数据集文件：并发控制（最大并发数见 UPLOAD_CONFIG），支持断点续传 */
export async function resumableUploadDatasetFiles(
  datasetId: number,
  files: File[],
  onProgress?: (percent: number, current: number, total: number) => void,
  signal?: AbortSignal,
): Promise<{ successCount: number; failedCount: number; failedFiles: string[]; overwrittenCount?: number }> {
  if (signal?.aborted) {
    throw new Error('上传已取消');
  }
  if (files.length === 0) {
    return { successCount: 0, failedCount: 0, failedFiles: [] };
  }

  const MAX_CONCURRENCY = UPLOAD_CONFIG.MAX_CONCURRENCY;
  const totalFiles = files.length;

  let successCount = 0;
  let failedCount = 0;
  let finishedCount = 0;
  const failedFiles: string[] = [];
  let overwrittenCount = 0;

  const fileProgressMap = new Map<number, number>();

  const updateOverallProgress = () => {
    let currentInternalProgress = 0;
    for (const p of fileProgressMap.values()) {
      currentInternalProgress += p;
    }
    const overallPercent = Math.round(((finishedCount + currentInternalProgress / 100) / totalFiles) * 100);
    onProgress?.(Math.min(99, overallPercent), finishedCount, totalFiles);
  };

  const executeNext = async (index: number): Promise<void> => {
    if (signal?.aborted) return;

    const file = files[index];
    try {
      fileProgressMap.set(index, 0);

      const result = await resumableUploadDatasetFile({
        datasetId,
        file,
        isZip: false,
        onProgress: (filePercent) => {
          fileProgressMap.set(index, filePercent);
          updateOverallProgress();
        },
        signal,
      });

      successCount++;
      if (result.overwrittenCount) {
        overwrittenCount += result.overwrittenCount;
      }
    } catch (error) {
      if (error instanceof Error && error.message === '上传已取消') {
        throw error;
      }
      console.error(`文件 ${file.name} 上传失败:`, error);
      failedCount++;
      failedFiles.push(file.name);
    } finally {
      fileProgressMap.delete(index);
      finishedCount++;
      updateOverallProgress();
    }
  };

  const initialTasks: Promise<void>[] = [];
  for (let i = 0; i < Math.min(MAX_CONCURRENCY, totalFiles); i++) {
    initialTasks.push(executeNext(i));
  }

  let nextIndex = MAX_CONCURRENCY;

  const runWithRefill = async (taskPromise: Promise<void>) => {
    await taskPromise;
    if (nextIndex < totalFiles && !signal?.aborted) {
      const currentIndex = nextIndex++;
      await runWithRefill(executeNext(currentIndex));
    }
  };

  await Promise.all(initialTasks.map((task) => runWithRefill(task)));

  onProgress?.(100, totalFiles, totalFiles);

  return {
    successCount,
    failedCount,
    failedFiles,
    overwrittenCount: overwrittenCount || undefined,
  };
}

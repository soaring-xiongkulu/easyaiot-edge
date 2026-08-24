import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useMessage } from '@/hooks/web/useMessage';
import {
  downloadSamModel,
  getSamModelStatus,
  parseSamApiError,
  type SamModelStatus,
} from '@/api/device/sam';

const MODEL_POLL_INTERVAL_MS = 800;

export function useSamModelSetup(onReady?: () => void) {
  const { createMessage } = useMessage();

  const modelStatusChecked = ref(false);
  const modelStatus = ref<SamModelStatus | null>(null);
  const modelPollTimer = ref<ReturnType<typeof setInterval> | null>(null);
  const smoothProgress = ref(0);
  const modelDownloadJustFinished = ref(false);
  const downloadStarted = ref(false);
  const downloadStarting = ref(false);
  const finishTimer = ref<ReturnType<typeof setTimeout> | null>(null);

  const modelReady = computed(() => !!modelStatus.value?.exists);
  const modelDownloading = computed(() => !!modelStatus.value?.downloading);
  const showProgressPanel = computed(
    () => downloadStarted.value || modelDownloading.value || modelDownloadJustFinished.value,
  );

  const downloadStepCurrent = computed(() => {
    const stage = modelStatus.value?.stage;
    if (modelDownloadJustFinished.value || stage === 'done') return 2;
    if (stage === 'installing') return 1;
    if (stage === 'downloading') return 0;
    return 0;
  });

  const displayProgress = computed(() => {
    if (modelDownloadJustFinished.value) return 100;
    return smoothProgress.value;
  });

  watch(
    () => modelStatus.value?.progress,
    (progress) => {
      if (progress != null && progress > smoothProgress.value) {
        smoothProgress.value = progress;
      }
    },
  );

  function clearFinishTimer() {
    if (finishTimer.value) {
      clearTimeout(finishTimer.value);
      finishTimer.value = null;
    }
  }

  function showDownloadSuccess() {
    modelDownloadJustFinished.value = true;
    smoothProgress.value = 100;
    clearFinishTimer();
    finishTimer.value = setTimeout(() => {
      modelDownloadJustFinished.value = false;
    }, 1200);
  }

  function stopModelPolling() {
    if (modelPollTimer.value) {
      clearInterval(modelPollTimer.value);
      modelPollTimer.value = null;
    }
  }

  function startModelPolling() {
    stopModelPolling();
    modelPollTimer.value = setInterval(() => {
      refreshModelStatus();
    }, MODEL_POLL_INTERVAL_MS);
  }

  async function refreshModelStatus() {
    const wasReady = modelReady.value;
    try {
      const res = await getSamModelStatus();
      if (res?.data) {
        modelStatus.value = res.data;
        if (res.data.progress != null && res.data.progress > smoothProgress.value) {
          smoothProgress.value = res.data.progress;
        } else if (res.data.resumable && res.data.downloaded_bytes && res.data.total_bytes) {
          smoothProgress.value = Math.min(
            95,
            Math.round((res.data.downloaded_bytes / res.data.total_bytes) * 95),
          );
        }
        if (res.data.exists) {
          stopModelPolling();
          downloadStarted.value = false;
          if (!wasReady) {
            showDownloadSuccess();
            createMessage.success('SAM 模型已安装完成');
            onReady?.();
          }
        } else if (res.data.stage === 'error') {
          downloadStarted.value = false;
        }
      }
    } catch (error: unknown) {
      console.warn('查询 SAM 模型状态失败', error);
    } finally {
      modelStatusChecked.value = true;
    }
    return modelReady.value;
  }

  async function handleDownloadModel() {
    downloadStarting.value = true;
    try {
      smoothProgress.value = modelStatus.value?.progress ?? 0;
      modelDownloadJustFinished.value = false;
      downloadStarted.value = true;
      const res = await downloadSamModel();
      if (res?.data) {
        modelStatus.value = {
          exists: !!res.data.exists,
          filename: res.data.filename || 'sam3.1_multiplex.pt',
          path: res.data.path,
          size_bytes: res.data.size_bytes ?? 0,
          downloading: !!res.data.downloading,
          resumable: !!res.data.resumable,
          stage: res.data.stage,
          progress: res.data.progress ?? 0,
          downloaded_bytes: res.data.downloaded_bytes,
          total_bytes: res.data.total_bytes,
          error: res.data.error,
        };
        if (res.data.progress != null) {
          smoothProgress.value = res.data.progress;
        }
      }
      startModelPolling();
      await refreshModelStatus();
    } catch (error: unknown) {
      downloadStarted.value = false;
      createMessage.error(parseSamApiError(error, '触发 SAM 模型下载失败'));
    } finally {
      downloadStarting.value = false;
    }
  }

  onBeforeUnmount(() => {
    stopModelPolling();
    clearFinishTimer();
  });

  return {
    modelStatusChecked,
    modelStatus,
    modelReady,
    modelDownloading,
    showProgressPanel,
    displayProgress,
    downloadStepCurrent,
    modelDownloadJustFinished,
    downloadStarting,
    refreshModelStatus,
    handleDownloadModel,
  };
}

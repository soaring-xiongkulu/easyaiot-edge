import { defHttp } from '@/utils/http/axios';

const AUDIO_TALK_PREFIX = '/video/camera/audio/talk';

/** 对讲能力探测会连摄像机 RTSP，需放宽超时并关闭 GET 重试/弹窗 */
const AUDIO_TALK_REQUEST_OPTIONS = {
  errorMessageMode: 'none' as const,
  timeout: 20 * 1000,
  retryRequest: { isOpenRetry: false, count: 0, waitTime: 0 },
};

const commonApi = (
  method: 'get' | 'post',
  url: string,
  params: Record<string, unknown> = {},
  isTransformResponse = true,
  requestOptions: {
    errorMessageMode?: 'none' | 'message' | 'modal';
    timeout?: number;
    retryRequest?: { isOpenRetry: boolean; count: number; waitTime: number };
  } = {},
) =>
  defHttp[method](
    {
      url,
      ...(method === 'get' ? { params } : { data: params }),
    },
    {
      isTransformResponse,
      errorMessageMode: requestOptions.errorMessageMode ?? 'message',
      ...(requestOptions.timeout ? { timeout: requestOptions.timeout } : {}),
      ...(requestOptions.retryRequest ? { retryRequest: requestOptions.retryRequest } : {}),
    },
  );

export interface AudioTalkCapabilities {
  supported?: boolean;
  audio_backchannel_supported?: boolean;
  codecs?: string[];
  sample_rate?: number;
  channels?: number;
  onvif_supported?: boolean;
}

export const getAudioTalkCapabilities = (deviceId: string) =>
  commonApi(
    'get',
    `${AUDIO_TALK_PREFIX}/capabilities`,
    { device_id: deviceId },
    true,
    AUDIO_TALK_REQUEST_OPTIONS,
  );

export const startOnvifAudioTalk = (payload: {
  device_id: string;
  audio_codec?: string;
  sample_rate?: number;
  volume_gain?: number;
  noise_suppression?: boolean;
  echo_cancellation?: boolean;
}) =>
  commonApi('post', `${AUDIO_TALK_PREFIX}/start`, payload, false, {
    ...AUDIO_TALK_REQUEST_OPTIONS,
    timeout: 30 * 1000,
  });

export const stopOnvifAudioTalk = (sessionId: string) =>
  commonApi('post', `${AUDIO_TALK_PREFIX}/stop`, { session_id: sessionId }, false, {
    errorMessageMode: 'none',
  });

export const sendOnvifAudioData = (sessionId: string, audioDataBase64: string) =>
  commonApi(
    'post',
    `${AUDIO_TALK_PREFIX}/send`,
    { session_id: sessionId, audio_data: audioDataBase64 },
    false,
    { errorMessageMode: 'none', timeout: 15 * 1000 },
  );

import { ref, onUnmounted } from 'vue';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getAudioTalkCapabilities,
  startOnvifAudioTalk,
  stopOnvifAudioTalk,
  sendOnvifAudioData,
} from '@/api/device/audioTalk';

export type AudioTalkStatus = 'idle' | 'connecting' | 'active' | 'error';

export function useOnvifAudioTalk(deviceId: () => string | undefined) {
  const { createMessage } = useMessage();
  const status = ref<AudioTalkStatus>('idle');
  const infoText = ref('点击「开始对讲」建立连接');
  const volume = ref(100);
  const noiseSuppression = ref(true);
  const echoCancellation = ref(true);
  const level = ref(0);
  const supported = ref<boolean | null>(null);

  let sessionId: string | null = null;
  let localStream: MediaStream | null = null;
  let audioContext: AudioContext | null = null;
  let scriptProcessor: ScriptProcessorNode | null = null;
  let gainNode: GainNode | null = null;
  let sendTimer: ReturnType<typeof setInterval> | null = null;
  const pendingChunks: Int16Array[] = [];

  async function checkCapabilities() {
    const id = deviceId();
    if (!id) return;
    try {
      const res: any = await getAudioTalkCapabilities(id);
      const body = res?.data ?? res;
      const caps = body?.capabilities ?? body?.data?.capabilities;
      supported.value = !!caps?.audio_backchannel_supported;
      infoText.value = supported.value
        ? '设备支持 ONVIF Audio Back Channel'
        : '设备不支持 Audio Back Channel';
    } catch {
      supported.value = false;
      infoText.value = '检测语音对讲能力失败';
    }
  }

  async function start() {
    const id = deviceId();
    if (!id) return;
    status.value = 'connecting';
    infoText.value = '请求麦克风权限...';

    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: echoCancellation.value,
          noiseSuppression: noiseSuppression.value,
          autoGainControl: true,
          sampleRate: 8000,
          channelCount: 1,
        },
        video: false,
      });
    } catch (e: any) {
      status.value = 'error';
      infoText.value = '无法获取麦克风权限';
      createMessage.error(infoText.value);
      return;
    }

    infoText.value = '建立 Audio Back Channel...';
    try {
      const res: any = await startOnvifAudioTalk({
        device_id: id,
        audio_codec: 'PCMU',
        sample_rate: 8000,
        volume_gain: volume.value / 100,
        noise_suppression: noiseSuppression.value,
        echo_cancellation: echoCancellation.value,
      });
      const body = res?.data ?? res;
      if (!body?.success && body?.code !== 0) {
        throw new Error(body?.msg || '启动失败');
      }
      sessionId = body?.session_id ?? body?.data?.session_id;
      if (!sessionId) throw new Error('未返回 session_id');
    } catch (e: any) {
      stopTracks();
      status.value = 'error';
      infoText.value = e?.message || '启动 ONVIF 对讲失败';
      createMessage.error(infoText.value);
      return;
    }

    audioContext = new AudioContext({ sampleRate: 8000 });
    const source = audioContext.createMediaStreamSource(localStream);
    gainNode = audioContext.createGain();
    gainNode.gain.value = volume.value / 100;
    scriptProcessor = audioContext.createScriptProcessor(2048, 1, 1);
    scriptProcessor.onaudioprocess = (event) => {
      const input = event.inputBuffer.getChannelData(0);
      let sum = 0;
      for (let i = 0; i < input.length; i++) sum += input[i] * input[i];
      const rms = Math.sqrt(sum / input.length);
      level.value = Math.min(5, Math.floor(Math.sqrt(rms * (volume.value / 100)) * 80));
      if (status.value !== 'active') return;
      const pcm = new Int16Array(input.length);
      for (let i = 0; i < input.length; i++) {
        const s = Math.max(-1, Math.min(1, input[i]));
        pcm[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
      }
      pendingChunks.push(pcm);
      if (pendingChunks.length > 8) pendingChunks.shift();
    };
    source.connect(gainNode);
    gainNode.connect(scriptProcessor);
    scriptProcessor.connect(audioContext.destination);

    sendTimer = setInterval(flushAudio, 40);
    status.value = 'active';
    infoText.value = '语音对讲进行中（ONVIF）';
  }

  async function flushAudio() {
    if (!sessionId || !pendingChunks.length) return;
    const chunk = pendingChunks.shift();
    if (!chunk) return;
    const bytes = new Uint8Array(chunk.buffer);
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    try {
      await sendOnvifAudioData(sessionId, btoa(binary));
    } catch {
      /* 静默丢包，避免刷屏 */
    }
  }

  function stopTracks() {
    localStream?.getTracks().forEach((t) => t.stop());
    localStream = null;
  }

  async function stop() {
    if (sendTimer) {
      clearInterval(sendTimer);
      sendTimer = null;
    }
    pendingChunks.length = 0;
    scriptProcessor?.disconnect();
    gainNode?.disconnect();
    scriptProcessor = null;
    gainNode = null;
    if (audioContext) {
      await audioContext.close().catch(() => {});
      audioContext = null;
    }
    stopTracks();
    if (sessionId) {
      try {
        await stopOnvifAudioTalk(sessionId);
      } catch {
        /* ignore */
      }
      sessionId = null;
    }
    status.value = 'idle';
    level.value = 0;
    infoText.value = '对讲已结束';
  }

  function updateVolume(v: number) {
    volume.value = v;
    if (gainNode) gainNode.gain.value = v / 100;
  }

  onUnmounted(() => {
    stop();
  });

  return {
    status,
    infoText,
    volume,
    noiseSuppression,
    echoCancellation,
    level,
    supported,
    checkCapabilities,
    start,
    stop,
    updateVolume,
  };
}

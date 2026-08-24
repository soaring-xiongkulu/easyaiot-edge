/** GPUStack 控制台地址与默认登录信息（与 .scripts/docker 部署配置一致，可通过环境变量覆盖） */

const trimEnv = (value: string | undefined) => (value ?? '').trim()

const GPUSTACK_MONITOR_TIP_DISMISSED_KEY = 'easyaiot_gpustack_monitor_tip_dismissed'

/** 用户是否已关闭算力监控提示条（摄像头/模型管理共用，持久化到 localStorage） */
export function isGpuStackMonitorTipDismissed(): boolean {
  if (typeof window === 'undefined') {
    return false
  }
  try {
    return localStorage.getItem(GPUSTACK_MONITOR_TIP_DISMISSED_KEY) === '1'
  } catch {
    return false
  }
}

export function setGpuStackMonitorTipDismissed(): void {
  if (typeof window === 'undefined') {
    return
  }
  try {
    localStorage.setItem(GPUSTACK_MONITOR_TIP_DISMISSED_KEY, '1')
  } catch {
    /* 存储不可用时忽略 */
  }
}

export function getGpuStackConsoleUrl(): string {
  const configured = trimEnv(import.meta.env.VITE_GPUSTACK_URL)
  if (configured) {
    return configured.replace(/\/$/, '')
  }
  if (typeof window !== 'undefined') {
    const { protocol, hostname } = window.location
    return `${protocol}//${hostname}:10180`
  }
  return 'http://localhost:10180'
}

export const GPUSTACK_DEFAULT_USERNAME =
  trimEnv(import.meta.env.VITE_GPUSTACK_USERNAME) || 'admin'

export const GPUSTACK_DEFAULT_PASSWORD =
  trimEnv(import.meta.env.VITE_GPUSTACK_PASSWORD) || 'basiclab@iotp4JWmQSvzdh0z4mF'

import type { GlobConfig } from '@/types/config'

import { warn } from '@/utils/log'
import { getAppEnvConfig } from '@/utils/env'

/** 生产构建若仍指向本机 Gateway(48080)，改为与 API 同源前缀（mini 容器无 48080） */
function resolveUploadUrl(apiUrl: string, configured?: string): string {
  const raw = (configured || apiUrl || '/dev-api').trim()
  if (!import.meta.env.PROD) {
    return raw
  }
  if (/^https?:\/\/(127\.0\.0\.1|localhost):48080\b/i.test(raw)) {
    return (apiUrl || '/dev-api').replace(/\/$/, '')
  }
  return raw
}

export function useGlobSetting(): Readonly<GlobConfig> {
  const {
    VITE_GLOB_APP_TITLE,
    VITE_GLOB_API_URL,
    VITE_GLOB_APP_SHORT_NAME,
    VITE_GLOB_API_URL_PREFIX,
    VITE_GLOB_UPLOAD_URL,
    VITE_GLOB_APP_TENANT_ENABLE,
    VITE_GLOB_APP_CAPTCHA_ENABLE,
  } = getAppEnvConfig()

  if (!/[a-zA-Z\_]*/.test(VITE_GLOB_APP_SHORT_NAME)) {
    warn(
      'VITE_GLOB_APP_SHORT_NAME Variables can only be characters/underscores, please modify in the environment variables and re-running.',
    )
  }

  // Take global configuration
  const glob: Readonly<GlobConfig> = {
    title: VITE_GLOB_APP_TITLE,
    apiUrl: VITE_GLOB_API_URL,
    shortName: VITE_GLOB_APP_SHORT_NAME,
    urlPrefix: VITE_GLOB_API_URL_PREFIX,
    uploadUrl: resolveUploadUrl(VITE_GLOB_API_URL, VITE_GLOB_UPLOAD_URL),
    tenantEnable: VITE_GLOB_APP_TENANT_ENABLE,
    captchaEnable: VITE_GLOB_APP_CAPTCHA_ENABLE,
  }
  return glob
}

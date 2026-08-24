import pkg from '../../package.json'
import type { GlobEnvConfig } from '@/types/config'

import { warn } from '@/utils/log'

export function getCommonStoragePrefix() {
  const { VITE_GLOB_APP_SHORT_NAME } = getAppEnvConfig()
  return `${VITE_GLOB_APP_SHORT_NAME}__${getEnv()}`.toUpperCase()
}

// Generate cache key according to version
export function getStorageShortName() {
  return `${getCommonStoragePrefix()}${`__${pkg.version}`}__`.toUpperCase()
}

export function getAppEnvConfig() {
  const ENV = { ...import.meta.env } as unknown as GlobEnvConfig

  // 生产环境：部署时可挂载运行时 _app.config.js（window.__PRODUCTION__<SHORT_NAME>__CONF__）
  // 覆盖构建期 VITE_GLOB_* 值，共用镜像按部署形态切换租户/验证码/形态裁剪，无需重建
  if (isProdMode()) {
    const confName = `__PRODUCTION__${ENV.VITE_GLOB_APP_SHORT_NAME || '__APP'}__CONF__`.toUpperCase().replace(/\s/g, '')
    const runtimeConf = (window as unknown as Record<string, Partial<GlobEnvConfig>>)[confName]
    if (runtimeConf) {
      Object.keys(runtimeConf).forEach((key) => {
        const val = runtimeConf[key as keyof GlobEnvConfig]
        if (val !== undefined && val !== null && val !== '') {
          (ENV as Record<string, unknown>)[key] = val
        }
      })
    }
  }

  const {
    VITE_GLOB_APP_TITLE,
    VITE_GLOB_BASE_URL,
    VITE_GLOB_API_URL,
    VITE_GLOB_APP_SHORT_NAME,
    VITE_GLOB_API_URL_PREFIX,
    VITE_GLOB_UPLOAD_URL,
    VITE_GLOB_APP_TENANT_ENABLE,
    VITE_GLOB_APP_CAPTCHA_ENABLE,
    VITE_GLOB_DEPLOY_PROFILE,
    VITE_GLOB_EDGE_STANDALONE,
  } = ENV

  if (!/^[a-zA-Z\_]*$/.test(VITE_GLOB_APP_SHORT_NAME)) {
    warn(
      'VITE_GLOB_APP_SHORT_NAME Variables can only be characters/underscores, please modify the environment variables and re-running.',
    )
  }

  return {
    VITE_GLOB_APP_TITLE,
    VITE_GLOB_BASE_URL,
    VITE_GLOB_API_URL,
    VITE_GLOB_APP_SHORT_NAME,
    VITE_GLOB_API_URL_PREFIX,
    VITE_GLOB_UPLOAD_URL,
    VITE_GLOB_APP_TENANT_ENABLE,
    VITE_GLOB_APP_CAPTCHA_ENABLE,
    VITE_GLOB_DEPLOY_PROFILE,
    VITE_GLOB_EDGE_STANDALONE,
  }
}

/**
 * @description: Development mode
 */
export const devMode = 'development'

/**
 * @description: Production mode
 */
export const prodMode = 'production'

/**
 * @description: Get environment variables
 * @returns:
 * @example:
 */
export function getEnv(): string {
  return import.meta.env.MODE
}

/**
 * @description: Is it a development mode
 * @returns:
 * @example:
 */
export function isDevMode(): boolean {
  return import.meta.env.DEV
}

/**
 * @description: Is it a production mode
 * @returns:
 * @example:
 */
export function isProdMode(): boolean {
  return import.meta.env.PROD
}

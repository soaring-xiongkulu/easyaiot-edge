import type {
  AxiosError,
  AxiosInstance,
  AxiosRequestConfig,
  AxiosResponse,
  InternalAxiosRequestConfig,
} from 'axios'
import axios from 'axios'
import qs from 'qs'
import { cloneDeep } from 'lodash-es'
import type { CreateAxiosOptions } from './axiosTransform'
import { AxiosCanceler } from './axiosCancel'
import { isFunction } from '@/utils/is'
import type { RequestOptions, Result, UploadFileParams } from '@/types/axios'
import { ContentTypeEnum, RequestEnum } from '@/enums/httpEnum'
import { downloadByData } from '@/utils/file/download'
import { useGlobSetting } from '@/hooks/setting'
import { getRefreshToken, getTenantId, setAccessToken } from '@/utils/auth'
import { useUserStoreWithOut } from '@/store/modules/user'

export * from './axiosTransform'

const globSetting = useGlobSetting()
// 请求队列
let requestList: any[] = []
// 是否正在刷新中
let isRefreshToken = false

/**
 * @description:  axios 模块
 */
export class VAxios {
  private axiosInstance: AxiosInstance
  private readonly options: CreateAxiosOptions

  constructor(options: CreateAxiosOptions) {
    this.options = options
    this.axiosInstance = axios.create(options)
    this.setupInterceptors()
  }

  /**
   * @description:  创建 axios 实例
   */
  private createAxios(config: CreateAxiosOptions): void {
    this.axiosInstance = axios.create(config)
  }

  private getTransform() {
    const { transform } = this.options
    return transform
  }

  getAxios(): AxiosInstance {
    return this.axiosInstance
  }

  refreshToken() {
    axios.defaults.headers.common['tenant-id'] = getTenantId() as number
    const refreshToken = getRefreshToken()
    return axios.post(`${globSetting.apiUrl}/system/auth/refresh-token?refreshToken=${refreshToken}`)
  }

  /**
   * @description: 重新配置 axios
   */
  configAxios(config: CreateAxiosOptions) {
    if (!this.axiosInstance)
      return

    this.createAxios(config)
  }

  /**
   * @description: 设置通用标题
   */
  setHeader(headers: any): void {
    if (!this.axiosInstance)
      return

    Object.assign(this.axiosInstance.defaults.headers, headers)
  }

  /**
   * @description: Interceptor configuration 拦截器配置
   */
  private setupInterceptors() {
    // const transform = this.getTransform();
    const {
      axiosInstance,
      options: { transform },
    } = this
    if (!transform)
      return

    const {
      requestInterceptors,
      requestInterceptorsCatch,
      responseInterceptors,
      responseInterceptorsCatch,
    } = transform

    const axiosCanceler = new AxiosCanceler()

    // 请求拦截器配置处理（支持同步或异步拦截器，便于会话预检）
    this.axiosInstance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
      // If cancel repeat request is turned on, then cancel repeat request is prohibited
      const requestOptions
        = (config as unknown as any).requestOptions ?? this.options.requestOptions
      const ignoreCancelToken = requestOptions?.ignoreCancelToken ?? true

      !ignoreCancelToken && axiosCanceler.addPending(config)

      if (requestInterceptors && isFunction(requestInterceptors))
        return Promise.resolve(requestInterceptors(config, this.options))

      return config
    }, undefined)

    // 请求拦截器错误捕获
    requestInterceptorsCatch
      && isFunction(requestInterceptorsCatch)
      && this.axiosInstance.interceptors.request.use(undefined, requestInterceptorsCatch)

    // 响应结果拦截器处理
    this.axiosInstance.interceptors.response.use(async (res: AxiosResponse<any>) => {
      const config = res.config
      if (res.data.code === 401) {
        // 如果未认证，并且未进行刷新令牌，说明可能是访问令牌过期了
        if (!isRefreshToken) {
          isRefreshToken = true
          const rt = getRefreshToken()
          if (rt) {
            try {
              const refreshTokenRes = await this.refreshToken()
              const newAccess = refreshTokenRes?.data?.data?.accessToken
              if (!newAccess)
                throw new Error('refresh token response missing accessToken')
              setAccessToken(newAccess)
              ;(config as Recordable).headers.Authorization = `Bearer ${newAccess}`
              isRefreshToken = false
              const queued = requestList
              requestList = []
              queued.forEach((cb: any) => {
                cb()
              })
              return this.axiosInstance(config)
            }
            catch (e) {
              isRefreshToken = false
              requestList = []
              useUserStoreWithOut().logout(true)
              return Promise.reject(e)
            }
          }
          else {
            isRefreshToken = false
            useUserStoreWithOut().logout(true)
            return Promise.reject(new Error('Unauthorized'))
          }
        }
        else {
          // 添加到队列，等待刷新获取到新的令牌
          return new Promise((resolve) => {
            requestList.push(() => {
              const access = useUserStoreWithOut().getAccessToken
              ;(config as Recordable).headers.Authorization = access
                ? `Bearer ${access}`
                : (config as Recordable).headers.Authorization
              resolve(this.axiosInstance(config))
            })
          })
        }
      }
      res && axiosCanceler.removePending(res.config)
      if (responseInterceptors && isFunction(responseInterceptors))
        res = responseInterceptors(res)

      return res
    }, undefined)

    // 响应结果拦截器错误捕获
    responseInterceptorsCatch
      && isFunction(responseInterceptorsCatch)
      && this.axiosInstance.interceptors.response.use(undefined, (error) => {
        return responseInterceptorsCatch(axiosInstance, error)
      })
  }

  /**
   * @description:  文件上传
   */
  uploadFile<T = any>(config: AxiosRequestConfig, params: UploadFileParams) {
    const formData = new window.FormData()
    const customFilename = params.name || 'file'

    if (params.filename)
      formData.append(customFilename, params.file, params.filename)

    else
      formData.append(customFilename, params.file)

    if (params.data) {
      Object.keys(params.data).forEach((key) => {
        const value = params.data![key]
        if (Array.isArray(value)) {
          value.forEach((item) => {
            formData.append(`${key}[]`, item)
          })
          return
        }

        formData.append(key, params.data![key])
      })
    }

    return this.axiosInstance.request<T>({
      ...config,
      method: 'POST',
      data: formData,
      headers: {
        'Content-type': ContentTypeEnum.FORM_DATA,
        'ignoreCancelToken': true,
      },
    })
  }

  // 支持表单数据
  supportFormData(config: AxiosRequestConfig) {
    const headers = config.headers || this.options.headers
    const contentType = headers?.['Content-Type'] || headers?.['content-type']

    if (
      contentType !== ContentTypeEnum.FORM_URLENCODED
      || !Reflect.has(config, 'data')
      || config.method?.toUpperCase() === RequestEnum.GET
    )
      return config

    return {
      ...config,
      data: qs.stringify(config.data, { arrayFormat: 'brackets' }),
    }
  }

  get<T = any>(config: AxiosRequestConfig, options?: RequestOptions): Promise<T> {
    return this.request({ ...config, method: 'GET' }, options)
  }

  post<T = any>(config: AxiosRequestConfig, options?: RequestOptions): Promise<T> {
    return this.request({ ...config, method: 'POST' }, options)
  }

  put<T = any>(config: AxiosRequestConfig, options?: RequestOptions): Promise<T> {
    return this.request({ ...config, method: 'PUT' }, options)
  }

  delete<T = any>(config: AxiosRequestConfig, options?: RequestOptions): Promise<T> {
    return this.request({ ...config, method: 'DELETE' }, options)
  }

  download<T = any>(config: AxiosRequestConfig, title?: string, options?: RequestOptions): Promise<T> {
    let conf: CreateAxiosOptions = cloneDeep({
      ...config,
      method: 'GET',
      responseType: 'blob',
    })
    const transform = this.getTransform()

    const { requestOptions } = this.options

    const opt: RequestOptions = Object.assign({}, requestOptions, options)

    const { beforeRequestHook, requestCatchHook } = transform || {}

    if (beforeRequestHook && isFunction(beforeRequestHook))
      conf = beforeRequestHook(conf, opt)

    conf.requestOptions = opt

    conf = this.supportFormData(conf)

    return new Promise((resolve, reject) => {
      this.axiosInstance
        .request<any, AxiosResponse<Result>>(conf)
        .then((res: AxiosResponse<Result>) => {
          resolve(res as unknown as Promise<T>)
          // download file
          if (typeof res != 'undefined')
            downloadByData(res?.data as unknown as BlobPart, title || 'export')
        })
        .catch((e: Error | AxiosError) => {
          if (requestCatchHook && isFunction(requestCatchHook)) {
            reject(requestCatchHook(e, opt))
            return
          }
          if (axios.isAxiosError(e)) {
            // rewrite error message from axios in here
          }
          reject(e)
        })
    })
  }

  export<T = any>(config: AxiosRequestConfig, title: string, options?: RequestOptions): Promise<T> {
    let conf: CreateAxiosOptions = cloneDeep({
      ...config,
      method: 'POST',
      responseType: 'blob',
    })
    const transform = this.getTransform()

    const { requestOptions } = this.options

    const opt: RequestOptions = Object.assign({}, requestOptions, options)

    const { beforeRequestHook, requestCatchHook } = transform || {}

    if (beforeRequestHook && isFunction(beforeRequestHook))
      conf = beforeRequestHook(conf, opt)

    conf.requestOptions = opt

    conf = this.supportFormData(conf)

    return new Promise((resolve, reject) => {
      this.axiosInstance
        .request<any, AxiosResponse<Result>>(conf)
        .then((res: AxiosResponse<Result>) => {
          resolve(res as unknown as Promise<T>)
          // download file
          if (typeof res != 'undefined')
            downloadByData(res?.data as unknown as BlobPart, title)
        })
        .catch((e: Error | AxiosError) => {
          if (requestCatchHook && isFunction(requestCatchHook)) {
            reject(requestCatchHook(e, opt))
            return
          }
          if (axios.isAxiosError(e)) {
            // rewrite error message from axios in here
          }
          reject(e)
        })
    })
  }

  request<T = any>(config: AxiosRequestConfig, options?: RequestOptions): Promise<T> {
    let conf: CreateAxiosOptions = cloneDeep(config)
    // cancelToken 如果被深拷贝，会导致最外层无法使用cancel方法来取消请求
    if (config.cancelToken)
      conf.cancelToken = config.cancelToken

    if (config.signal)
      conf.signal = config.signal

    const transform = this.getTransform()

    const { requestOptions } = this.options

    const opt: RequestOptions = Object.assign({}, requestOptions, options)

    const { beforeRequestHook, requestCatchHook, transformResponseHook } = transform || {}
    if (beforeRequestHook && isFunction(beforeRequestHook))
      conf = beforeRequestHook(conf, opt)

    conf.requestOptions = opt

    conf = this.supportFormData(conf)

    return new Promise((resolve, reject) => {
      this.axiosInstance
        .request<any, AxiosResponse<Result>>(conf)
        .then((res: AxiosResponse<Result>) => {
          if (transformResponseHook && isFunction(transformResponseHook)) {
            try {
              const ret = transformResponseHook(res, opt)
              resolve(ret)
            }
            catch (err) {
              reject(err || new Error('request error!'))
            }
            return
          }
          resolve(res as unknown as Promise<T>)
        })
        .catch((e: Error | AxiosError) => {
          if (requestCatchHook && isFunction(requestCatchHook)) {
            reject(requestCatchHook(e, opt))
            return
          }
          if (axios.isAxiosError(e)) {
            // 在此处重写来自 axios 的错误消息
          }
          reject(e)
        })
    })
  }
}

import { defHttp } from '@/utils/http/axios'

enum Api {
  Project = '/visualize/project',
  Template = '/visualize/template',
  Asset = '/visualize/asset',
  Datasource = '/visualize/datasource',
  Deploy = '/visualize/deploy',
}

/** 可视化项目分页（含大屏 / 组态） */
export const getVisualizeProjectPage = (params: Recordable) => {
  return defHttp.get({ url: `${Api.Project}/page`, params })
}

/** 可视化项目详情 */
export const getVisualizeProject = (id: number | string) => {
  return defHttp.get({ url: `${Api.Project}/get`, params: { id } })
}

/** 创建可视化项目（projectType: dashboard | scada） */
export const createVisualizeProject = (data: Recordable) => {
  return defHttp.post({ url: `${Api.Project}/create`, data })
}

/** 更新可视化项目元数据 */
export const updateVisualizeProject = (data: Recordable) => {
  return defHttp.put({ url: `${Api.Project}/update`, data })
}

/** 保存画布内容 */
export const saveVisualizeProjectContent = (data: { id: number | string; content: string }) => {
  return defHttp.put({ url: `${Api.Project}/save-content`, data })
}

/** 发布 / 取消发布：state = 1 发布，-1 未发布 */
export const publishVisualizeProject = (data: { id: number | string; state: number }) => {
  return defHttp.put({ url: `${Api.Project}/publish`, data })
}

/** 删除可视化项目 */
export const deleteVisualizeProject = (id: number | string) => {
  return defHttp.delete({ url: `${Api.Project}/delete`, params: { id } })
}

/** 获取 FUXA 免登打开地址（后端代登录 → SSO 桥接页） */
export const getFuxaOpenUrl = (params: {
  id?: number | string | null
  mode?: 'edit' | 'preview'
  editorRef?: string
}) => {
  return defHttp.get({ url: `${Api.Project}/fuxa-open`, params })
}

/** 模板分页 */
export const getVisualizeTemplatePage = (params: Recordable) => {
  return defHttp.get({ url: `${Api.Template}/page`, params })
}

export const getVisualizeTemplate = (id: number | string) => {
  return defHttp.get({ url: `${Api.Template}/get`, params: { id } })
}

export const createVisualizeTemplate = (data: Recordable) => {
  return defHttp.post({ url: `${Api.Template}/create`, data })
}

export const updateVisualizeTemplate = (data: Recordable) => {
  return defHttp.put({ url: `${Api.Template}/update`, data })
}

export const deleteVisualizeTemplate = (id: number | string) => {
  return defHttp.delete({ url: `${Api.Template}/delete`, params: { id } })
}

/** 素材分页 */
export const getVisualizeAssetPage = (params: Recordable) => {
  return defHttp.get({ url: `${Api.Asset}/page`, params })
}

export const getVisualizeAsset = (id: number | string) => {
  return defHttp.get({ url: `${Api.Asset}/get`, params: { id } })
}

export const createVisualizeAsset = (data: Recordable) => {
  return defHttp.post({ url: `${Api.Asset}/create`, data })
}

export const updateVisualizeAsset = (data: Recordable) => {
  return defHttp.put({ url: `${Api.Asset}/update`, data })
}

export const deleteVisualizeAsset = (id: number | string) => {
  return defHttp.delete({ url: `${Api.Asset}/delete`, params: { id } })
}

/** 数据源 */
export const getVisualizeDatasourcePage = (params: Recordable) => {
  return defHttp.get({ url: `${Api.Datasource}/page`, params })
}

export const getVisualizeDatasource = (id: number | string) => {
  return defHttp.get({ url: `${Api.Datasource}/get`, params: { id } })
}

export const createVisualizeDatasource = (data: Recordable) => {
  return defHttp.post({ url: `${Api.Datasource}/create`, data })
}

export const updateVisualizeDatasource = (data: Recordable) => {
  return defHttp.put({ url: `${Api.Datasource}/update`, data })
}

export const deleteVisualizeDatasource = (id: number | string) => {
  return defHttp.delete({ url: `${Api.Datasource}/delete`, params: { id } })
}

/** 服务部署 */
export const getVisualizeDeployPage = (params: Recordable) => {
  return defHttp.get({ url: `${Api.Deploy}/page`, params })
}

export const getVisualizeDeploy = (id: number | string) => {
  return defHttp.get({ url: `${Api.Deploy}/get`, params: { id } })
}

export const createVisualizeDeploy = (data: Recordable) => {
  return defHttp.post({ url: `${Api.Deploy}/create`, data })
}

export const updateVisualizeDeploy = (data: Recordable) => {
  return defHttp.put({ url: `${Api.Deploy}/update`, data })
}

export const deleteVisualizeDeploy = (id: number | string) => {
  return defHttp.delete({ url: `${Api.Deploy}/delete`, params: { id } })
}

export const onlineVisualizeDeploy = (id: number | string) => {
  return defHttp.put({ url: `${Api.Deploy}/online`, params: { id } })
}

export const offlineVisualizeDeploy = (id: number | string) => {
  return defHttp.put({ url: `${Api.Deploy}/offline`, params: { id } })
}

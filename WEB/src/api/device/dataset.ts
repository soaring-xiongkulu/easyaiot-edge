/**
 * 边缘端无独立「设备数据集」后端；训练相关组件若引用 getDatasetPage，此处返回空列表，
 * 避免缺失模块导致开发服务器对 /src/api/device/dataset 返回 404。
 */
export const getDatasetPage = async (_params?: Record<string, unknown>) => ({
  data: { list: [] as unknown[] },
  total: 0,
});

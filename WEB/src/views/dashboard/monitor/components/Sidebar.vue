<template>
  <div class="monitor-sidebar">
    <!-- 全局总览 -->
    <div class="sidebar-section overview-section">
      <div class="section-header">
        <Icon icon="ant-design:dashboard-outlined" :size="16" class="header-icon" />
        <span class="section-title">全局总览</span>
      </div>
      <div class="statistics-cards">
        <div class="stat-card">
          <div class="stat-icon alarm">
            <Icon icon="ant-design:warning-outlined" :size="24" />
          </div>
          <div class="stat-content">
            <div class="stat-label">告警数量</div>
            <div class="stat-value">{{ statistics.alarmCount }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon camera">
            <Icon icon="ant-design:video-camera-outlined" :size="24" />
          </div>
          <div class="stat-content">
            <div class="stat-label">摄像头数量</div>
            <div class="stat-value">{{ statistics.cameraCount }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon algorithm">
            <Icon icon="ant-design:code-outlined" :size="24" />
          </div>
          <div class="stat-content">
            <div class="stat-label">算法数量</div>
            <div class="stat-value">{{ statistics.algorithmCount }}</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon model">
            <Icon icon="ant-design:database-outlined" :size="24" />
          </div>
          <div class="stat-content">
            <div class="stat-label">模型数量</div>
            <div class="stat-value">{{ statistics.modelCount }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- 设备目录 -->
    <div class="sidebar-section directory-section">
      <div class="section-header">
        <Icon icon="ant-design:folder-outlined" :size="16" class="header-icon" />
        <span class="section-title">设备目录</span>
        <div class="header-actions">
          <span class="device-count" v-if="!loading && treeData.length > 0">
            {{ playableLeafCount }} 个通道
          </span>
        </div>
      </div>
      <!-- 设备树（与分屏监控一致：搜索框固定，树列表区域滚动） -->
      <div class="sidebar-tree">
        <div class="sidebar-tree-scroll">
          <BasicTree
            class="sidebar-device-tree"
            :tree-data="treeData"
            :expanded-keys="expandedKeys"
            :selected-keys="selectedKeys"
            :loading="loading"
            search
            :showIcon="true"
            :indent="12"
            :click-row-to-expand="false"
            :load-data="onLoadGbDeviceChannels"
            @update:expanded-keys="handleExpandedKeysChange"
            @select="handleTreeSelect"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { Icon } from '@/components/Icon'
import { BasicTree } from '@/components/Tree'
import type { TreeItem } from '@/components/Tree'
import type { MonitorTreeDeviceNode } from '@/api/device/camera'
import { formatCameraDeviceLabel, isGb28181Device } from '@/views/camera/utils/deviceLabel'
import {
  collectMonitorTreeExpandedKeys,
  countMonitorTreePlayableLeaves,
  findMonitorGbDeviceByChannel,
  findMonitorTreeNodeByKey,
} from '@/views/camera/utils/monitorDeviceTree'
import { buildWvpChannelTreeNodes, parseGbChannelKey, type GbChannelRef } from '@/views/camera/utils/gb28181Tree'
import { getDeviceChannels } from '@/api/device/gb28181'
import { getCachedMonitorDirectoryTreeBundle, invalidateMonitorDirectoryTreeCache } from '@/views/camera/utils/monitorDirectoryTreeCache'
import { loadMonitorDirectoryTreeWithCache } from '@/views/camera/utils/monitorDirectoryTreeLoad'
import { syncGb28181DevicesInBackground } from '@/views/camera/utils/wvpGbSync'
import { isGb28181Enabled } from '@/utils/deployProfile'
import {
  enrichWvpChannelTreeNodes,
  resolveMonitorGbChannelDisplayName,
} from '@/views/camera/utils/monitorGbDisplay'
import { getDashboardStatistics } from '@/api/device/calculate'
import { useMessage } from '@/hooks/web/useMessage'
import type { TreeProps } from 'ant-design-vue'

defineOptions({
  name: 'MonitorSidebar'
})

const props = defineProps<{
  selectedDevice?: any
}>()

const emit = defineEmits<{
  (e: 'device-change', device: any): void
  (e: 'device-play', device: any): void
}>()

const {createMessage} = useMessage()

const expandedKeys = ref<string[]>([])
const selectedKeys = ref<string[]>([])
const treeData = ref<TreeItem[]>([])
const loading = ref(false)

// 统计数据
const statistics = ref({
  alarmCount: 0,
  cameraCount: 0,
  algorithmCount: 0,
  modelCount: 0
})

const playableLeafCount = computed(() => countMonitorTreePlayableLeaves(treeData.value))

const onLoadGbDeviceChannels: TreeProps['loadData'] = (treeNode) => {
  return new Promise<void>((resolve) => {
    const key = String(treeNode?.key ?? treeNode?.eventKey ?? '')
    if (!key.startsWith('gb_dev_')) {
      resolve()
      return
    }
    const sipDeviceId = key.slice('gb_dev_'.length)
    const dataRef = (treeNode.dataRef ?? treeNode) as TreeItem
    if (dataRef?.children?.length) {
      resolve()
      return
    }

    getDeviceChannels(sipDeviceId)
      .then((res) => {
        const list = res.data || res.list || []
        dataRef.children = enrichWvpChannelTreeNodes(
          buildWvpChannelTreeNodes(list, sipDeviceId),
          treeData.value,
        )
        dataRef.isLeaf = !dataRef.children?.length
        treeData.value = [...treeData.value]
        if (!expandedKeys.value.includes(key)) {
          expandedKeys.value = [...expandedKeys.value, key]
        }
        resolve()
      })
      .catch(() => resolve())
  })
}

const applyMonitorTreeBundle = (bundle: { treeItems: TreeItem[] }) => {
  treeData.value = bundle.treeItems
  expandedKeys.value = collectMonitorTreeExpandedKeys(treeData.value)
}

const loadTreeData = async (options?: { force?: boolean }) => {
  const hasCache = !!getCachedMonitorDirectoryTreeBundle()?.treeItems?.length
  if (!hasCache) loading.value = true

  await loadMonitorDirectoryTreeWithCache({
    force: options?.force,
    skipSync: true,
    onBundle: (bundle) => {
      applyMonitorTreeBundle(bundle)
    },
    onError: (error) => {
      console.error('加载设备目录失败', error)
      if (!treeData.value.length) {
        createMessage.error('加载设备目录失败: ' + (error as Error)?.message)
        treeData.value = []
      }
    },
    onRefreshingChange: (v) => {
      if (!treeData.value.length) loading.value = v
    },
  })
  loading.value = false
}

/** 首页进入时后台同步 WVP 国标设备，避免必须先打开分屏监控点「刷新」 */
const syncGbDevicesInBackground = async () => {
  if (!isGb28181Enabled()) return
  const { created } = await syncGb28181DevicesInBackground()
  if (created > 0) {
    invalidateMonitorDirectoryTreeCache()
    await loadTreeData({ force: true })
  }
}

// 加载统计数据
const loadStatistics = async () => {
  try {
    // 调用统一的统计接口
    const statsResponse = await getDashboardStatistics()
    if (statsResponse) {
      statistics.value.alarmCount = statsResponse.alarm_count || 0
      statistics.value.cameraCount = statsResponse.camera_count || 0
      statistics.value.algorithmCount = statsResponse.algorithm_count || 0
      statistics.value.modelCount = statsResponse.model_count || 0
    }
  } catch (error) {
    console.error('加载统计数据失败', error)
    // 发生错误时使用默认值
    statistics.value.alarmCount = 0
    statistics.value.cameraCount = 0
    statistics.value.algorithmCount = 0
    statistics.value.modelCount = 0
  }
}

// 处理展开/收起变化
const handleExpandedKeysChange = (keys: string[]) => {
  expandedKeys.value = keys
}

function buildGbChannelPlayPayload(gb: GbChannelRef, node: TreeItem | null) {
  const playId = `gb_ch_${gb.sipDeviceId},${gb.channelId}`
  const synced =
    findMonitorGbDeviceByChannel(treeData.value, gb.sipDeviceId, gb.channelId) ??
    ((node as TreeItem & { device?: MonitorTreeDeviceNode })?.device ?? null)
  const displayName = resolveMonitorGbChannelDisplayName(
    gb.sipDeviceId,
    gb.channelId,
    treeData.value,
    gb.name,
  )
  const monitorDevice: MonitorTreeDeviceNode = synced ?? {
    type: 'device',
    id: playId,
    name: displayName.replace(/^\[GB28181\]\s*/, '').trim() || gb.name,
    source: `gb28181://${gb.sipDeviceId}/${gb.channelId}`,
    device_kind: 'gb28181',
  }
  return {
    id: playId,
    name: displayName,
    location: node ? getFullPath(node, treeData.value) : '',
    device: monitorDevice,
  }
}

// 处理树节点选择（与分屏监控一致：国标设备下展开通道后点播）
const handleTreeSelect = (keys: string[], _info?: unknown) => {
  if (!keys.length) return

  const selectedKey = String(keys[0])

  if (selectedKey.startsWith('gb_dev_')) {
    createMessage.info('请展开国标设备并选择具体通道')
    return
  }
  if (selectedKey.startsWith('nvr_')) {
    createMessage.info('请展开 NVR 并选择具体通道')
    return
  }
  if (selectedKey.startsWith('gb_dir_') || selectedKey.startsWith('dir_')) {
    createMessage.info('请选择摄像头或国标通道')
    return
  }

  const node = findMonitorTreeNodeByKey(treeData.value, selectedKey)
  if (!node) return

  if (selectedKey.startsWith('gb_ch_')) {
    let gb = parseGbChannelKey(selectedKey)
    if ((node as any).gbChannel) {
      gb = (node as any).gbChannel as GbChannelRef
    }
    if (!gb) {
      createMessage.warning('无效国标通道')
      return
    }
    selectedKeys.value = [selectedKey]
    const payload = buildGbChannelPlayPayload(gb, node)
    emit('device-change', payload)
    emit('device-play', payload)
    return
  }

  if (!selectedKey.startsWith('device_')) {
    createMessage.info('请选择摄像头或国标通道')
    return
  }

  const device = (node as any).device as MonitorTreeDeviceNode | undefined
  if (!device) {
    createMessage.warning('无效设备')
    return
  }
  if (isGb28181Device(device.source, device.device_kind)) {
    createMessage.info('请展开上级国标设备并选择通道')
    return
  }

  selectedKeys.value = [selectedKey]
  const payload = {
    id: device.id,
    name: formatCameraDeviceLabel(device),
    location: getFullPath(node, treeData.value),
    device,
  }
  emit('device-change', payload)
  emit('device-play', {
    ...payload,
    http_stream: device.http_stream,
    rtmp_stream: device.rtmp_stream,
    ai_http_stream: device.ai_http_stream,
    ai_rtmp_stream: device.ai_rtmp_stream,
    source: device.source,
  })
}

// 获取完整路径
const getFullPath = (node: TreeItem, treeNodes: TreeItem[]): string => {
  const path: string[] = [node.title as string]

  // 递归查找父节点路径
  const findPath = (nodes: TreeItem[], targetKey: string, currentPath: string[] = []): string[] | null => {
    for (const n of nodes) {
      const newPath = [...currentPath, n.title as string]
      if (n.key === targetKey) {
        return newPath
      }
      if (n.children && n.children.length > 0) {
        const found = findPath(n.children as TreeItem[], targetKey, newPath)
        if (found) {
          return found
        }
      }
    }
    return null
  }

  const fullPath = findPath(treeNodes, node.key as string)
  return fullPath ? fullPath.join(' / ') : (node.title as string)
}

// 刷新定时器
let statisticsTimer: any = null
let delayTimer: any = null
let isMounted = false

// 组件挂载时加载数据
onMounted(() => {
  isMounted = true
  
  loadTreeData()
  syncGbDevicesInBackground()
  // 初始加载统计数据
  loadStatistics()
  
  // 错峰刷新：延迟1秒开始，每5秒刷新一次统计数据（1秒、6秒、11秒...）
  delayTimer = setTimeout(() => {
    // 检查组件是否仍然挂载
    if (!isMounted) return
    
    loadStatistics()
    
    // 再次检查组件是否仍然挂载
    if (!isMounted) return
    
    statisticsTimer = setInterval(() => {
      // 每次执行前检查组件是否仍然挂载
      if (!isMounted) {
        if (statisticsTimer) {
          clearInterval(statisticsTimer)
          statisticsTimer = null
        }
        return
      }
      
      loadStatistics()
    }, 5000)
  }, 1000)
})

// 组件卸载时清理定时器
onUnmounted(() => {
  isMounted = false
  
  // 清理延迟定时器
  if (delayTimer) {
    clearTimeout(delayTimer)
    delayTimer = null
  }
  
  // 清理定时器
  if (statisticsTimer) {
    clearInterval(statisticsTimer)
    statisticsTimer = null
  }
})
</script>

<style lang="less" scoped>
.monitor-sidebar {
  width: 350px;
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 16px;
  overflow: hidden;
}

.sidebar-section {
  background: linear-gradient(135deg, rgba(15, 34, 73, 0.8), rgba(24, 46, 90, 0.6));
  border-radius: 8px;
  border: 1px solid rgba(52, 134, 218, 0.3);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3), inset 0 0 30px rgba(52, 134, 218, 0.1);
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;

  &::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: 
      linear-gradient(90deg, transparent 0%, rgba(52, 134, 218, 0.05) 50%, transparent 100%),
      radial-gradient(circle at top left, rgba(52, 134, 218, 0.1), transparent 50%);
    pointer-events: none;
    border-radius: 8px;
  }
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 12px 16px;
  border-bottom: 1px solid rgba(52, 134, 218, 0.3);
  background: rgba(52, 134, 218, 0.08);
  position: relative;
  z-index: 1;

  .header-icon {
    color: #3486da;
    filter: drop-shadow(0 0 4px rgba(52, 134, 218, 0.6));
  }

  .section-title {
    font-size: 15px;
    font-weight: 600;
    color: #ffffff;
    text-shadow: 0 0 8px rgba(52, 134, 218, 0.5);
    letter-spacing: 0.5px;
    flex: 1;
  }

  .header-actions {
    display: flex;
    align-items: center;
    gap: 8px;

    .device-count {
      font-size: 12px;
      color: rgba(200, 220, 255, 0.7);
      padding: 2px 8px;
      background: rgba(52, 134, 218, 0.15);
      border-radius: 4px;
      border: 1px solid rgba(52, 134, 218, 0.3);
    }
  }
}

.overview-section {
  flex-shrink: 0;
}

.directory-section {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.statistics-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-rows: repeat(2, 1fr);
  gap: 8px;
  padding: 12px;
  position: relative;
  z-index: 1;
}

.stat-card {
  background: linear-gradient(135deg, rgba(52, 134, 218, 0.15), rgba(48, 82, 174, 0.1));
  border: 1px solid rgba(52, 134, 218, 0.3);
  border-radius: 8px;
  padding: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.3s;
  position: relative;
  overflow: hidden;
  cursor: pointer;

  &::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg, rgba(52, 134, 218, 0.1), transparent);
    opacity: 0;
    transition: opacity 0.3s;
  }

  &:hover {
    border-color: rgba(52, 134, 218, 0.6);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(52, 134, 218, 0.2);

    &::before {
      opacity: 1;
    }

    .stat-icon {
      transform: scale(1.1);
    }
  }

  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.3s;
    position: relative;
    z-index: 1;

    &.alarm {
      background: linear-gradient(135deg, rgba(255, 77, 79, 0.2), rgba(255, 77, 79, 0.1));
      color: #ff4d4f;
      border: 1px solid rgba(255, 77, 79, 0.3);
    }

    &.camera {
      background: linear-gradient(135deg, rgba(52, 134, 218, 0.2), rgba(52, 134, 218, 0.1));
      color: #3486da;
      border: 1px solid rgba(52, 134, 218, 0.3);
    }

    &.algorithm {
      background: linear-gradient(135deg, rgba(82, 196, 26, 0.2), rgba(82, 196, 26, 0.1));
      color: #52c41a;
      border: 1px solid rgba(82, 196, 26, 0.3);
    }

    &.model {
      background: linear-gradient(135deg, rgba(250, 173, 20, 0.2), rgba(250, 173, 20, 0.1));
      color: #faad14;
      border: 1px solid rgba(250, 173, 20, 0.3);
    }
  }

  .stat-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    position: relative;
    z-index: 1;

    .stat-label {
      font-size: 11px;
      color: rgba(255, 255, 255, 0.6);
      white-space: nowrap;
    }

    .stat-value {
      font-size: 20px;
      font-weight: 700;
      color: #ffffff;
      line-height: 1;
      text-shadow: 0 0 8px rgba(52, 134, 218, 0.5);
    }
  }
}

.sidebar-tree {
  flex: 1;
  min-height: 0;
  padding: 8px;
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: linear-gradient(to bottom, rgba(15, 34, 73, 0.4), rgba(24, 46, 90, 0.3));
}

.sidebar-tree-scroll {
  flex: 1;
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;

  :deep(.sidebar-device-tree) {
    flex: 1;
    min-height: 0;
    height: 100%;
    overflow: hidden;
    display: flex;
    flex-direction: column;

    .ant-spin-nested-loading,
    .ant-spin-container {
      flex: 1;
      min-height: 0;
      height: 100%;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background: transparent !important;
    }

    .scroll-container {
      flex: 1;
      min-height: 0;
      background: transparent !important;
    }

    .scrollbar {
      height: 100%;
    }
  }

  // 覆盖 BasicTree 的所有背景色
  :deep(.tree) {
    background: transparent !important;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  // 覆盖 xingyuv-tree 类的背景色
  :deep(.xingyuv-tree) {
    background: transparent !important;
  }

  // 隐藏 BasicTree 的标题栏，只保留搜索框
  :deep(.tree-header) {
    padding: 8px 0;
    border-bottom: none !important;
    background: rgba(15, 34, 73, 0.3) !important;
    margin-bottom: 8px;

    .tree-header-title {
      display: none; // 隐藏标题
    }
  }

  // 去掉搜索框下方的所有边框
  :deep(.tree-header-search) {
    border-bottom: none !important;
  }

  // 增大 xingyuv-tree-header 下方的间距
  :deep(.xingyuv-tree-header) {
    margin-bottom: 12px !important;
    border-bottom: none !important;
  }

  :deep(.ant-tree) {
    background: transparent !important;
    color: rgba(200, 220, 255, 0.9);
  }

  /* 与分屏监控一致：叶子前占位更窄、行高更紧凑 */
  :deep(.sidebar-device-tree) {
    .ant-tree-switcher {
      width: 16px;
      margin-inline-end: 2px;
    }

    .ant-tree-switcher-noop {
      width: 8px;
    }

    .ant-tree-node-content-wrapper {
      padding-inline: 2px 6px;
      min-height: 26px;
      line-height: 26px;
    }

    .ant-tree-title,
    [class*='-tree__title'] {
      padding-left: 0 !important;
    }

    [class*='-tree__title'] .mr-1,
    [class*='-tree__title'] .app-iconify {
      margin-right: 4px !important;
      font-size: 13px !important;
    }
  }

  // 覆盖树节点的背景
  :deep(.ant-tree-list) {
    background: transparent !important;
  }

  :deep(.ant-tree-list-holder) {
    background: transparent !important;
  }

  :deep(.ant-tree-list-holder-inner) {
    background: transparent !important;
  }

  :deep(.ant-tree-treenode) {
    background: transparent !important;
  }

  :deep(.ant-tree-node-content-wrapper) {
    background: transparent !important;
    color: rgba(200, 220, 255, 0.9);
    transition: all 0.25s;

    &:hover {
      background: rgba(52, 134, 218, 0.12) !important;
      color: #ffffff;
    }
  }

  :deep(.ant-tree-node-selected) {
    .ant-tree-node-content-wrapper {
      background: linear-gradient(90deg, rgba(52, 134, 218, 0.3), rgba(52, 134, 218, 0.15)) !important;
      color: #6bb3ff !important;
    }
  }

  :deep(.ant-tree-switcher) {
    color: rgba(52, 134, 218, 0.8);
    background: transparent !important;
  }

  :deep(.ant-tree-title) {
    color: inherit;
  }

  // 覆盖 Empty 组件的背景
  :deep(.ant-empty) {
    background: transparent !important;
  }

  // 搜索框样式
  :deep(.tree-header-search) {
    .ant-input {
      background: rgba(52, 134, 218, 0.15) !important;
      border: 1px solid rgba(52, 134, 218, 0.4);
      border-radius: 6px;
      color: rgba(200, 220, 255, 0.95);

      &::placeholder {
        color: rgba(200, 220, 255, 0.5);
      }

      &:hover {
        border-color: rgba(52, 134, 218, 0.6);
        background: rgba(52, 134, 218, 0.2) !important;
      }

      &:focus {
        border-color: #3486da;
        box-shadow: 0 0 12px rgba(52, 134, 218, 0.5);
        background: rgba(52, 134, 218, 0.25) !important;
      }
    }
  }

  /* 大屏主题：滚动条悬停可见（与分屏监控 ScrollContainer 行为一致） */
  :deep(.scrollbar__bar) {
    opacity: 0.35;
  }

  :deep(.scrollbar:hover .scrollbar__bar) {
    opacity: 1;
  }

  :deep(.scrollbar__thumb) {
    background-color: rgba(52, 134, 218, 0.45);
  }

  :deep(.scrollbar__thumb:hover) {
    background-color: rgba(52, 134, 218, 0.7);
  }
}
</style>

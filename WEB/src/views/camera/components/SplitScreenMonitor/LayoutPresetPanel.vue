<template>
  <Transition name="preset-panel-slide">
    <div v-if="open" class="layout-preset-panel">
      <div class="panel-header">
        <div class="panel-title">
          <Icon icon="ant-design:appstore-outlined" :size="18" />
          <span>布局方案</span>
          <span class="panel-subtitle">最多保存 {{ MAX_CAMERA_MONITOR_LAYOUT_PRESETS }} 套，再次打开分屏监控自动恢复激活方案</span>
        </div>
        <div class="panel-header-actions">
          <button type="button" class="panel-close-btn" @click="emit('close')">
            <Icon icon="ant-design:close-outlined" :size="16" />
          </button>
        </div>
      </div>

      <div class="preset-grid">
        <div
          v-for="item in presetItems"
          :key="item.id"
          :class="[
            'preset-card',
            {
              active: activePresetId === item.id,
              empty: !item.preset,
            },
          ]"
          @click="handleCardClick(item)"
        >
          <div v-if="activePresetId === item.id" class="active-tag">使用中</div>

          <div class="card-main">
            <div class="card-preview" :class="`preview-${item.preset?.layout || currentLayout}`">
              <span v-for="(cell, idx) in getPreviewCells(item.preset?.layout || currentLayout)" :key="idx" :style="cell" />
            </div>
            <div class="card-body">
              <div class="card-name">{{ item.displayName }}</div>
              <div v-if="item.preset" class="card-meta">
                {{ item.layoutLabel }} · {{ item.cameraCount }} 路
              </div>
              <div v-else class="card-meta empty-meta">点击保存当前画面</div>
            </div>
          </div>

          <div v-if="item.preset" class="card-actions" @click.stop>
            <button type="button" class="card-btn" title="切换到此方案" @click.stop="emit('apply', item.id)">
              切换
            </button>
            <button type="button" class="card-btn" title="用当前画面覆盖" @click.stop="emit('save', item.id)">
              覆盖
            </button>
            <button type="button" class="card-btn danger" title="删除方案" @click.stop="emit('delete', item.id)">
              删除
            </button>
          </div>
        </div>
      </div>

      <div class="panel-footer">
        <span>点击已有方案立即切换</span>
        <span class="dot">·</span>
        <span>点击空方案保存当前分屏与摄像头</span>
        <span v-if="activePresetId" class="footer-active">
          当前激活：{{ activePresetLabel }}
        </span>
      </div>
    </div>
  </Transition>
</template>

<script lang="ts" setup>
import { computed } from 'vue'
import { Icon } from '@/components/Icon'
import { useMessage } from '@/hooks/web/useMessage'
import {
  MAX_CAMERA_MONITOR_LAYOUT_PRESETS,
  type CameraMonitorLayoutPreset,
} from '@/views/camera/utils/monitorLayoutStorage'

defineOptions({ name: 'CameraLayoutPresetPanel' })

const { createMessage } = useMessage()

const props = defineProps<{
  open: boolean
  presets: Record<number, CameraMonitorLayoutPreset>
  activePresetId: number | null
  currentLayout: string
  currentCameraCount: number
  canSaveCurrent: boolean
}>()

const emit = defineEmits<{
  close: []
  apply: [presetId: number]
  save: [presetId: number]
  delete: [presetId: number]
}>()

const SPLIT_LABELS: Record<string, string> = {
  '1': '1 分屏',
  '4': '4 分屏',
  '9': '9 分屏',
  '16': '16 分屏',
}

function getLayoutLabel(layout: string) {
  return SPLIT_LABELS[layout] || `${layout} 分屏`
}

function getPresetDisplayName(preset: CameraMonitorLayoutPreset | undefined, id: number) {
  if (!preset) return `方案 ${id}`
  return preset.name?.trim() || `方案 ${id}`
}

const presetItems = computed(() => {
  return Array.from({ length: MAX_CAMERA_MONITOR_LAYOUT_PRESETS }, (_, i) => {
    const id = i + 1
    const preset = props.presets[id]
    return {
      id,
      preset,
      displayName: getPresetDisplayName(preset, id),
      layoutLabel: preset ? getLayoutLabel(preset.layout) : getLayoutLabel(props.currentLayout),
      cameraCount: preset ? preset.slots.filter((s) => s.deviceId).length : 0,
    }
  })
})

const activePresetLabel = computed(() => {
  if (!props.activePresetId) return ''
  const preset = props.presets[props.activePresetId]
  if (!preset) return `方案 ${props.activePresetId}`
  const count = preset.slots.filter((s) => s.deviceId).length
  return `${getPresetDisplayName(preset, props.activePresetId)}（${getLayoutLabel(preset.layout)} · ${count} 路）`
})

function handleCardClick(item: (typeof presetItems.value)[number]) {
  if (item.preset) {
    emit('apply', item.id)
    return
  }
  if (!props.canSaveCurrent) {
    createMessage.warning('请先在画面中添加摄像头')
    return
  }
  emit('save', item.id)
}

function getPreviewCells(layout: string): Array<Record<string, string>> {
  const base = { background: 'rgba(59, 130, 246, 0.55)', borderRadius: '1px' }
  if (layout === '1') return [{ ...base, gridColumn: '1 / 3', gridRow: '1 / 3' }]
  if (layout === '4') {
    return [
      { ...base, gridColumn: '1', gridRow: '1' },
      { ...base, gridColumn: '2', gridRow: '1' },
      { ...base, gridColumn: '1', gridRow: '2' },
      { ...base, gridColumn: '2', gridRow: '2' },
    ]
  }
  if (layout === '9') {
    return Array.from({ length: 9 }, (_, i) => ({
      ...base,
      gridColumn: `${(i % 3) + 1}`,
      gridRow: `${Math.floor(i / 3) + 1}`,
    }))
  }
  return Array.from({ length: 16 }, (_, i) => ({
    ...base,
    gridColumn: `${(i % 4) + 1}`,
    gridRow: `${Math.floor(i / 4) + 1}`,
  }))
}
</script>

<style lang="less" scoped>
.layout-preset-panel {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 220;
  pointer-events: auto;
  padding: 14px 16px 12px;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-top: none;
  border-radius: 0 0 10px 10px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.12);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 14px;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 600;
  color: #111827;

  .panel-subtitle {
    font-size: 12px;
    font-weight: 400;
    color: #6b7280;
    margin-left: 4px;
  }
}

.panel-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.panel-close-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
  background: #f9fafb;
  color: #6b7280;
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    color: #111827;
    border-color: #d1d5db;
    background: #f3f4f6;
  }
}

.preset-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 10px;
}

.preset-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 132px;
  padding: 10px;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  cursor: pointer;
  transition: all 0.2s;
  overflow: hidden;

  &:hover {
    border-color: #93c5fd;
    background: #eff6ff;
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
  }

  &.active {
    border-color: #3b82f6;
    background: #eff6ff;
    box-shadow: inset 0 0 0 1px rgba(59, 130, 246, 0.25);
  }

  &.empty {
    border-style: dashed;
    border-color: #d1d5db;

    .card-preview span {
      opacity: 0.25;
    }
  }
}

.active-tag {
  position: absolute;
  top: 8px;
  right: 8px;
  padding: 1px 6px;
  border-radius: 10px;
  font-size: 10px;
  line-height: 16px;
  color: #1e40af;
  background: #dbeafe;
  border: 1px solid #93c5fd;
}

.card-main {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  flex: 1;
  min-width: 0;
}

.card-preview {
  display: grid;
  gap: 2px;
  width: 44px;
  height: 32px;
  flex-shrink: 0;

  &.preview-1,
  &.preview-4 {
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: repeat(2, 1fr);
  }

  &.preview-9 {
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: repeat(3, 1fr);
  }

  &.preview-16 {
    grid-template-columns: repeat(4, 1fr);
    grid-template-rows: repeat(4, 1fr);
  }
}

.card-body {
  flex: 1;
  min-width: 0;
}

.card-name {
  font-size: 13px;
  font-weight: 600;
  color: #111827;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-meta {
  margin-top: 2px;
  font-size: 11px;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;

  &.empty-meta {
    color: #3b82f6;
  }
}

.card-actions {
  display: flex;
  gap: 4px;
  margin-top: auto;
  flex-shrink: 0;
}

.card-btn {
  flex: 1;
  min-width: 0;
  height: 26px;
  padding: 0 2px;
  border-radius: 4px;
  border: 1px solid #dbeafe;
  background: #eff6ff;
  color: #1d4ed8;
  font-size: 11px;
  line-height: 1;
  cursor: pointer;
  transition: all 0.15s;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  white-space: nowrap;
  overflow: hidden;

  &:hover {
    background: #dbeafe;
    border-color: #93c5fd;
    color: #1e40af;
  }

  &.danger {
    border-color: #e5e7eb;
    background: #f9fafb;
    color: #6b7280;

    &:hover {
      background: #fef2f2;
      border-color: #fca5a5;
      color: #dc2626;
    }
  }
}

.panel-footer {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid #e5e7eb;
  font-size: 12px;
  color: #9ca3af;

  .dot {
    opacity: 0.5;
  }

  .footer-active {
    margin-left: auto;
    color: #1e40af;
  }
}

.preset-panel-slide-enter-active,
.preset-panel-slide-leave-active {
  transition: all 0.22s ease;
}

.preset-panel-slide-enter-from,
.preset-panel-slide-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

@media (max-width: 1400px) {
  .preset-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>

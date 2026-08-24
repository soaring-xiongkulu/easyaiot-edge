<template>
  <Transition name="preset-panel-slide">
    <div v-if="open" class="layout-preset-panel">
      <div class="panel-header">
        <div class="panel-title">
          <Icon icon="ant-design:appstore-outlined" :size="18" />
          <span>布局方案</span>
          <span class="panel-subtitle">最多保存 {{ MAX_MONITOR_LAYOUT_PRESETS }} 套，再次打开大屏自动恢复激活方案</span>
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
        <span>点击空方案或右上角按钮保存当前分屏与摄像头</span>
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
  MAX_MONITOR_LAYOUT_PRESETS,
  type MonitorLayoutPreset,
} from '../utils/monitorLayoutStorage'

defineOptions({ name: 'LayoutPresetPanel' })

const { createMessage } = useMessage()

const props = defineProps<{
  open: boolean
  presets: Record<number, MonitorLayoutPreset>
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
  '6': '6 分屏',
  '8': '8 分屏',
  '9': '9 分屏',
  '16': '16 分屏',
}

function getLayoutLabel(layout: string) {
  return SPLIT_LABELS[layout] || `${layout} 分屏`
}

function getPresetDisplayName(preset: MonitorLayoutPreset | undefined, id: number) {
  if (!preset) return `方案 ${id}`
  return preset.name?.trim() || `方案 ${id}`
}

const presetItems = computed(() => {
  return Array.from({ length: MAX_MONITOR_LAYOUT_PRESETS }, (_, i) => {
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

function findFirstEmptySlot(): number | null {
  for (let i = 1; i <= MAX_MONITOR_LAYOUT_PRESETS; i++) {
    if (!props.presets[i]) return i
  }
  return null
}

function emitSaveToNewSlot() {
  if (!props.canSaveCurrent) {
    createMessage.warning('请先在画面中添加摄像头')
    return
  }
  const empty = findFirstEmptySlot()
  if (empty) {
    emit('save', empty)
    return
  }
  createMessage.warning('15 个方案已满，请点击某个方案的「覆盖」按钮保存')
}

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

/** 迷你分屏预览格 */
function getPreviewCells(layout: string): Array<Record<string, string>> {
  const base = { background: 'rgba(52, 134, 218, 0.55)', borderRadius: '1px' }
  if (layout === '1') return [{ ...base, gridColumn: '1 / 3', gridRow: '1 / 3' }]
  if (layout === '4') {
    return [
      { ...base, gridColumn: '1', gridRow: '1' },
      { ...base, gridColumn: '2', gridRow: '1' },
      { ...base, gridColumn: '1', gridRow: '2' },
      { ...base, gridColumn: '2', gridRow: '2' },
    ]
  }
  if (layout === '6') {
    return [
      { ...base, gridColumn: '1 / 3', gridRow: '1 / 3' },
      { ...base, gridColumn: '3', gridRow: '1' },
      { ...base, gridColumn: '3', gridRow: '2' },
      { ...base, gridColumn: '1', gridRow: '3' },
      { ...base, gridColumn: '2', gridRow: '3' },
      { ...base, gridColumn: '3', gridRow: '3' },
    ]
  }
  if (layout === '9') {
    return Array.from({ length: 9 }, (_, i) => ({
      ...base,
      gridColumn: `${(i % 3) + 1}`,
      gridRow: `${Math.floor(i / 3) + 1}`,
    }))
  }
  if (layout === '16') {
    return Array.from({ length: 16 }, (_, i) => ({
      ...base,
      gridColumn: `${(i % 4) + 1}`,
      gridRow: `${Math.floor(i / 4) + 1}`,
    }))
  }
  // 8 分屏简化为 4x3 示意
  return Array.from({ length: 8 }, (_, i) => ({
    ...base,
    gridColumn: `${(i % 4) + 1}`,
    gridRow: `${Math.floor(i / 4) + 1}`,
  }))
}
</script>

<style lang="less" scoped>
.layout-preset-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  z-index: 220;
  pointer-events: auto;
  padding: 16px 20px 14px;
  background: linear-gradient(180deg, rgba(8, 20, 45, 0.98), rgba(12, 28, 58, 0.96));
  border: 1px solid rgba(52, 134, 218, 0.35);
  border-radius: 0 0 10px 10px;
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
  backdrop-filter: blur(12px);
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
  color: #fff;

  .panel-subtitle {
    font-size: 12px;
    font-weight: 400;
    color: rgba(200, 220, 255, 0.55);
    margin-left: 4px;
  }
}

.panel-header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.panel-action-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 32px;
  padding: 0 14px;
  border-radius: 6px;
  border: 1px solid rgba(52, 134, 218, 0.45);
  background: rgba(52, 134, 218, 0.2);
  color: #d6ebff;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;

  &:hover:not(:disabled) {
    background: rgba(52, 134, 218, 0.35);
    border-color: #3486da;
    color: #fff;
  }

  &.primary {
    background: linear-gradient(135deg, rgba(52, 134, 218, 0.45), rgba(48, 82, 174, 0.35));
    border-color: rgba(52, 134, 218, 0.6);
  }

  &:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }
}

.panel-close-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.04);
  color: rgba(255, 255, 255, 0.65);
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    color: #fff;
    border-color: rgba(255, 255, 255, 0.25);
    background: rgba(255, 255, 255, 0.08);
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
  min-height: 118px;
  padding: 10px;
  border-radius: 8px;
  border: 1px solid rgba(52, 134, 218, 0.22);
  background: rgba(15, 34, 73, 0.55);
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    border-color: rgba(52, 134, 218, 0.55);
    background: rgba(20, 42, 82, 0.75);
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(0, 0, 0, 0.25);
  }

  &.active {
    border-color: rgba(82, 196, 26, 0.65);
    background: rgba(82, 196, 26, 0.08);
    box-shadow: inset 0 0 0 1px rgba(82, 196, 26, 0.2);
  }

  &.empty {
    border-style: dashed;
    border-color: rgba(52, 134, 218, 0.18);

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
  color: #b7eb8f;
  background: rgba(82, 196, 26, 0.18);
  border: 1px solid rgba(82, 196, 26, 0.35);
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

  &.preview-6,
  &.preview-9 {
    grid-template-columns: repeat(3, 1fr);
    grid-template-rows: repeat(3, 1fr);
  }

  &.preview-8,
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
  color: #fff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-meta {
  margin-top: 2px;
  font-size: 11px;
  color: rgba(200, 220, 255, 0.55);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;

  &.empty-meta {
    color: rgba(52, 134, 218, 0.85);
  }
}

.card-actions {
  display: flex;
  gap: 4px;
  margin-top: auto;
}

.card-btn {
  flex: 1;
  height: 24px;
  padding: 0 4px;
  border-radius: 4px;
  border: 1px solid rgba(52, 134, 218, 0.3);
  background: rgba(52, 134, 218, 0.12);
  color: rgba(214, 235, 255, 0.9);
  font-size: 11px;
  cursor: pointer;
  transition: all 0.15s;

  &:hover {
    background: rgba(52, 134, 218, 0.28);
    border-color: rgba(52, 134, 218, 0.55);
    color: #fff;
  }

  &.danger:hover {
    background: rgba(255, 77, 79, 0.18);
    border-color: rgba(255, 77, 79, 0.45);
    color: #ffccc7;
  }
}

.panel-footer {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px solid rgba(52, 134, 218, 0.15);
  font-size: 12px;
  color: rgba(200, 220, 255, 0.45);

  .dot {
    opacity: 0.5;
  }

  .footer-active {
    margin-left: auto;
    color: rgba(183, 235, 143, 0.85);
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

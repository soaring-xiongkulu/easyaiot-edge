<template>
  <div class="space-folder-grid">
    <Spin :spinning="loading">
      <div v-if="!loading && !nodes.length" class="space-empty">
        <div class="space-empty__visual">
          <div class="space-folder-icon space-folder-icon--lg space-folder-icon--camera">
            <Icon icon="mdi:folder" :size="50" class="space-folder-icon__body" />
            <Icon icon="ant-design:video-camera-outlined" :size="16" class="space-folder-icon__type-mark" />
          </div>
        </div>
        <p class="space-empty__title">暂无{{ kindLabel }}空间</p>
        <p class="space-empty__desc">设备接入后会自动创建，双击文件夹即可进入管理</p>
      </div>

      <div v-else class="folder-grid">
        <div
          v-for="node in nodes"
          :key="node.node_key"
          class="folder-item"
          :class="[
            nodeVisualClass(node),
            { 'folder-item--active': selectedKey === node.node_key },
          ]"
          @click="handleSelect(node)"
          @dblclick="handleOpen(node)"
          @contextmenu.prevent="handleContextMenu($event, node)"
        >
          <div class="folder-item__icon">
            <div class="space-folder-icon" :class="iconTypeClass(node)">
              <Icon icon="mdi:folder" :size="54" class="space-folder-icon__body" />
              <Icon
                :icon="typeMarkIcon(node)"
                :size="isFolderNode(node) ? 20 : 17"
                class="space-folder-icon__type-mark"
              />
              <Icon
                v-if="!isFolderNode(node)"
                :icon="storageMarkIcon"
                :size="13"
                class="space-folder-icon__storage-mark"
              />
            </div>
          </div>

          <div class="folder-item__label">
            <span class="folder-item__name" :title="displayName(node)">{{ displayName(node) }}</span>
            <span class="folder-item__meta" :title="metaTitle(node)">{{ metaText(node) }}</span>
          </div>

          <div class="folder-item__actions" @click.stop>
            <template v-if="isFolderNode(node)">
              <button type="button" class="folder-item__action" title="打开文件夹" @click="handleOpen(node)">
                <Icon icon="ant-design:folder-open-outlined" :size="15" />
              </button>
              <button type="button" class="folder-item__action" title="分组存储策略" @click="emit('group-policy', node)">
                <Icon icon="ant-design:setting-outlined" :size="15" />
              </button>
            </template>
            <template v-else>
              <button type="button" class="folder-item__action" :title="openLabel" @click="handleOpen(node)">
                <Icon :icon="openIcon" :size="15" />
              </button>
              <button type="button" class="folder-item__action" title="存储策略" @click="emit('policy', node)">
                <Icon icon="ant-design:setting-outlined" :size="15" />
              </button>
            </template>
          </div>
        </div>
      </div>
    </Spin>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { Spin } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useContextMenu } from '@/hooks/web/useContextMenu';
import {
  DEFAULT_SAVE_TIME,
  formatSaveTimeLabel,
  getSpaceKindLabel,
  isSpaceFolderNode,
  isSpaceLeafNode,
  resolveSpaceNodeDeviceKind,
  type SpaceDeviceKind,
  type SpaceFolderNode,
  type SpaceInfo,
  type SpaceKind,
} from '@/views/camera/utils/spaceSaveTime';
import { SPACE_FOLDER_COLS } from './useSpaceDirectoryManage';

defineOptions({ name: 'SpaceFolderGrid' });

const props = defineProps<{
  nodes: SpaceFolderNode[];
  spaceKind: SpaceKind;
  loading?: boolean;
}>();

const emit = defineEmits<{
  open: [node: SpaceFolderNode];
  enter: [node: SpaceFolderNode];
  policy: [space: SpaceInfo];
  'group-policy': [node: SpaceFolderNode];
}>();

const [createContextMenu] = useContextMenu();
const selectedKey = ref<string | null>(null);

const kindLabel = computed(() => getSpaceKindLabel(props.spaceKind));
const storageMarkIcon = computed(() =>
  props.spaceKind === 'snap' ? 'mdi:image-outline' : 'mdi:video-outline',
);
const openLabel = computed(() => '打开空间');
const openIcon = computed(() => 'ant-design:folder-open-outlined');

const gridColumns = SPACE_FOLDER_COLS;

function isFolderNode(node: SpaceFolderNode) {
  return isSpaceFolderNode(node);
}

function nodeDeviceKind(node: SpaceFolderNode): SpaceDeviceKind {
  return resolveSpaceNodeDeviceKind(node);
}

function iconTypeClass(node: SpaceFolderNode) {
  const kind = nodeDeviceKind(node);
  if (kind === 'nvr_channel') return 'space-folder-icon--nvr';
  if (kind === 'gb28181') return 'space-folder-icon--gb28181';
  return 'space-folder-icon--camera';
}

function nodeVisualClass(node: SpaceFolderNode) {
  const kind = nodeDeviceKind(node);
  const base = isFolderNode(node) ? 'folder-item--group' : 'folder-item--leaf';
  if (kind === 'nvr_channel') return `${base} folder-item--nvr`;
  if (kind === 'gb28181') return `${base} folder-item--gb28181`;
  return `${base} folder-item--camera`;
}

function typeMarkIcon(node: SpaceFolderNode) {
  const kind = nodeDeviceKind(node);
  if (kind === 'nvr_channel') return 'ant-design:hdd-outlined';
  if (kind === 'gb28181') return 'ant-design:cluster-outlined';
  return 'ant-design:video-camera-outlined';
}

function displayName(node: SpaceFolderNode) {
  return node.name || node.space_name || '';
}

function metaText(node: SpaceFolderNode) {
  if (isFolderNode(node)) {
    const count = node.child_count ?? 0;
    const days = node.group_save_time ?? DEFAULT_SAVE_TIME;
    const typeLabel = nodeDeviceKind(node) === 'gb28181' ? 'GB28181' : 'NVR';
    return `${typeLabel} · ${formatSaveTimeLabel(days)} · ${count} 个空间`;
  }
  const days = node.effective_save_time ?? node.save_time;
  const kind = nodeDeviceKind(node);
  const typeLabel = kind === 'nvr_channel'
    ? `NVR${node.nvr_channel ? ` CH${node.nvr_channel}` : ''}`
    : kind === 'gb28181'
      ? 'GB28181'
      : '直连';
  return `${typeLabel} · ${formatSaveTimeLabel(days)} · ${node.save_mode === 1 ? '归档' : '标准'}`;
}

function metaTitle(node: SpaceFolderNode) {
  if (isFolderNode(node)) {
    if (node.folder_type === 'nvr' && node.ip) {
      return `NVR ${node.ip}${node.port ? `:${node.port}` : ''}`;
    }
    if (node.folder_type === 'gb28181' && node.sip_device_id) {
      return `国标设备 ${node.sip_device_id}`;
    }
    return displayName(node);
  }
  const parts = [node.device_id ? `设备 ${node.device_id}` : ''];
  if (node.save_time_custom) parts.push('自定义保存策略');
  return parts.filter(Boolean).join(' · ') || displayName(node);
}

function handleSelect(node: SpaceFolderNode) {
  selectedKey.value = node.node_key;
}

function handleOpen(node: SpaceFolderNode) {
  selectedKey.value = node.node_key;
  if (isFolderNode(node)) {
    emit('enter', node);
    return;
  }
  emit('open', node);
}

function handleContextMenu(event: MouseEvent, node: SpaceFolderNode) {
  selectedKey.value = node.node_key;
  if (isFolderNode(node)) {
    createContextMenu({
      event,
      items: [
        {
          label: '打开文件夹',
          icon: 'ant-design:folder-open-outlined',
          handler: () => emit('enter', node),
        },
        {
          label: '分组存储策略',
          icon: 'ant-design:setting-outlined',
          handler: () => emit('group-policy', node),
        },
      ],
    });
    return;
  }
  if (!isSpaceLeafNode(node)) return;
  createContextMenu({
    event,
    items: [
      {
        label: openLabel.value,
        icon: openIcon.value,
        handler: () => emit('open', node),
      },
      {
        label: '空间存储策略',
        icon: 'ant-design:setting-outlined',
        handler: () => emit('policy', node),
      },
    ],
  });
}
</script>

<style lang="less" scoped>
// 暖色浅底 + 柔和类型色：可辨、有温度，避免冷灰与高饱和「彩虹」
@space-tile-active-shadow: rgba(15, 23, 42, 0.08);

@space-camera-tile-start: #f6f9ff;
@space-camera-tile-end: #e9f1fb;
@space-camera-folder: #6ba4e8;
@space-camera-badge: #4d8fd8;
@space-camera-ring: rgba(77, 143, 216, 0.26);

@space-nvr-tile-start: #fffbf5;
@space-nvr-tile-end: #fdf3e3;
@space-nvr-folder: #e5a84a;
@space-nvr-badge: #d4922f;
@space-nvr-ring: rgba(212, 146, 47, 0.26);

@space-gb-tile-start: #f4fbf8;
@space-gb-tile-end: #e6f4ef;
@space-gb-folder: #5bb99a;
@space-gb-badge: #3fa882;
@space-gb-ring: rgba(63, 168, 130, 0.26);

.space-folder-grid {
  flex: 1;
  min-height: 0;
  overflow: auto;

  :deep(.ant-spin-nested-loading),
  :deep(.ant-spin-container) {
    min-height: 440px;
  }
}

.space-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 440px;
  padding: 40px 24px;
  text-align: center;

  &__visual {
    width: 88px;
    height: 88px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 20px;
    border-radius: 8px;
    background: linear-gradient(180deg, @space-camera-tile-start 0%, @space-camera-tile-end 100%);
    box-shadow: 0 4px 16px rgba(77, 143, 216, 0.08);
  }

  &__title {
    margin: 0 0 8px;
    font-size: 16px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.88);
  }

  &__desc {
    margin: 0;
    max-width: 360px;
    font-size: 13px;
    line-height: 1.6;
    color: rgba(0, 0, 0, 0.45);
  }
}

.space-folder-icon {
  position: relative;
  width: 64px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;

  &--lg {
    width: 56px;
    height: 48px;
  }

  &__body {
    color: @space-camera-folder;
    filter: drop-shadow(0 2px 4px rgba(77, 143, 216, 0.16));
  }

  &__type-mark {
    position: absolute;
    right: -2px;
    bottom: -1px;
    color: #fff;
    padding: 2px;
    border-radius: 4px;
    box-shadow: 0 1px 4px rgba(15, 23, 42, 0.18);
  }

  &__storage-mark {
    position: absolute;
    left: -2px;
    top: -1px;
    color: #fff;
    padding: 1px 2px;
    border-radius: 3px;
    box-shadow: 0 1px 3px rgba(15, 23, 42, 0.12);
  }

  &--camera {
    .space-folder-icon__body {
      color: @space-camera-folder;
      filter: drop-shadow(0 2px 4px rgba(77, 143, 216, 0.16));
    }

    .space-folder-icon__type-mark,
    .space-folder-icon__storage-mark {
      background: @space-camera-badge;
    }
  }

  &--nvr {
    .space-folder-icon__body {
      color: @space-nvr-folder;
      filter: drop-shadow(0 2px 4px rgba(212, 146, 47, 0.16));
    }

    .space-folder-icon__type-mark,
    .space-folder-icon__storage-mark {
      background: @space-nvr-badge;
    }
  }

  &--gb28181 {
    .space-folder-icon__body {
      color: @space-gb-folder;
      filter: drop-shadow(0 2px 4px rgba(63, 168, 130, 0.16));
    }

    .space-folder-icon__type-mark,
    .space-folder-icon__storage-mark {
      background: @space-gb-badge;
    }
  }
}

.folder-grid {
  display: grid;
  grid-template-columns: repeat(v-bind(gridColumns), minmax(0, 1fr));
  gap: 12px 8px;
  padding: 16px 20px 20px;
  min-height: 440px;
  align-content: start;
}

.folder-item {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 4px 2px 8px;
  border-radius: 6px;
  cursor: default;
  user-select: none;
  transition: transform 0.18s ease;

  &:hover {
    transform: translateY(-2px);

    .folder-item__icon {
      box-shadow: 0 8px 22px rgba(15, 23, 42, 0.1);
    }

    .folder-item__actions {
      opacity: 1;
      transform: translateY(0);
    }
  }

  &--camera .folder-item__icon {
    background: linear-gradient(180deg, @space-camera-tile-start 0%, @space-camera-tile-end 100%);
  }

  &--nvr .folder-item__icon {
    background: linear-gradient(180deg, @space-nvr-tile-start 0%, @space-nvr-tile-end 100%);
  }

  &--gb28181 .folder-item__icon {
    background: linear-gradient(180deg, @space-gb-tile-start 0%, @space-gb-tile-end 100%);
  }

  &--active.folder-item--camera .folder-item__icon {
    box-shadow:
      0 0 0 2px @space-camera-ring,
      0 8px 22px @space-tile-active-shadow;
  }

  &--active.folder-item--nvr .folder-item__icon {
    box-shadow:
      0 0 0 2px @space-nvr-ring,
      0 8px 22px @space-tile-active-shadow;
  }

  &--active.folder-item--gb28181 .folder-item__icon {
    box-shadow:
      0 0 0 2px @space-gb-ring,
      0 8px 22px @space-tile-active-shadow;
  }

  &__icon {
    width: 92px;
    height: 92px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    transition: box-shadow 0.18s ease;
  }

  &__label {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 3px;
    width: 100%;
    max-width: 100%;
  }

  &__name {
    width: 100%;
    text-align: center;
    font-size: 15px;
    font-weight: 500;
    line-height: 1.45;
    color: rgba(0, 0, 0, 0.88);
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    word-break: break-all;
  }

  &__meta {
    width: 100%;
    text-align: center;
    font-size: 12px;
    line-height: 1.3;
    color: rgba(0, 0, 0, 0.4);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__actions {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%) translateY(-4px);
    display: inline-flex;
    gap: 2px;
    padding: 3px;
    border-radius: 6px;
    background: rgba(255, 255, 255, 0.98);
    box-shadow: 0 2px 10px rgba(15, 23, 42, 0.1);
    opacity: 0;
    transition:
      opacity 0.16s ease,
      transform 0.16s ease;
  }

  &__action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    padding: 0;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: rgba(0, 0, 0, 0.55);
    cursor: pointer;
    transition:
      color 0.15s ease,
      background-color 0.15s ease;

    &:hover {
      color: @space-camera-badge;
      background: fade(@space-camera-badge, 10%);
    }
  }
}
</style>

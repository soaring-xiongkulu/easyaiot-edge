<template>
  <div class="annotation-label-panel">
    <div class="panel-toolbar">
      <span class="toolbar-title">标注类别</span>
      <div class="toolbar-actions">
        <button
          type="button"
          class="icon-btn"
          :class="{ active: showAdd }"
          title="添加类别"
          @click="toggleAdd"
        >
          <Icon icon="ant-design:plus-outlined"/>
        </button>
        <button type="button" class="icon-btn" title="管理标签" @click="emit('manage')">
          <Icon icon="ant-design:setting-outlined"/>
        </button>
      </div>
    </div>

    <div v-if="showAdd" ref="addBlockRef" class="add-block">
      <Input
        ref="nameInputRef"
        v-model:value="quickName"
        size="small"
        placeholder="类别名称"
        allow-clear
        @press-enter="handleQuickAdd"
      />
      <div class="add-actions">
        <input v-model="quickColor" type="color" class="color-input" title="颜色"/>
        <Button
          type="primary"
          size="small"
          :loading="adding"
          :disabled="!quickName.trim()"
          @click="handleQuickAdd"
        >
          添加
        </Button>
      </div>
    </div>

    <div class="label-list">
      <div v-if="labels.length === 0" class="label-empty">
        <p>暂无类别</p>
        <button type="button" class="empty-btn" @click="toggleAdd(true)">添加第一个类别</button>
      </div>
      <button
        v-for="(label, index) in labels"
        :key="label.id"
        type="button"
        class="label-chip"
        :class="{ active: currentIndex === index }"
        @click="emit('select', index)"
      >
        <span class="chip-color" :style="{ backgroundColor: label.color }"/>
        <span class="chip-name">{{ label.name }}</span>
        <span class="chip-key">{{ label.shortcut }}</span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import {ref, watch} from 'vue';
import { Input } from 'ant-design-vue';
import {Icon} from '@/components/Icon';
import {useMessage} from '@/hooks/web/useMessage';
import {createDatasetTag} from '@/api/device/dataset';
import {TAG_COLOR_PALETTE} from '@/views/dataset/components/AnnotationTool/datasetTagUtils';
import { Button } from '@/components/Button'
defineOptions({name: 'AnnotationLabelPanel'});

export interface AnnotationLabel {
  id: number;
  name: string;
  color: string;
  shortcut: string;
}

const props = defineProps<{
  labels: AnnotationLabel[];
  currentIndex: number;
  datasetId: string | number;
}>();

const emit = defineEmits<{
  (e: 'select', index: number): void;
  (e: 'changed', addedName?: string): void;
  (e: 'manage'): void;
}>();

const {createMessage} = useMessage();
const adding = ref(false);
const showAdd = ref(false);
const quickName = ref('');
const quickColor = ref(TAG_COLOR_PALETTE[0]);
const addBlockRef = ref<HTMLElement | null>(null);
const nameInputRef = ref<{ focus?: () => void } | null>(null);

function nextShortcut(): number | null {
  const used = new Set(props.labels.map((l) => Number(l.shortcut)));
  for (let i = 1; i <= 9; i++) {
    if (!used.has(i)) return i;
  }
  return null;
}

watch(
  () => props.labels.length,
  (len) => {
    quickColor.value = TAG_COLOR_PALETTE[len % TAG_COLOR_PALETTE.length];
  },
  {immediate: true},
);

function toggleAdd(open?: boolean) {
  showAdd.value = open ?? !showAdd.value;
  if (showAdd.value) {
    requestAnimationFrame(() => nameInputRef.value?.focus?.());
  }
}

function focusAddInput() {
  toggleAdd(true);
}

async function handleQuickAdd() {
  const name = quickName.value.trim();
  if (!name) return;
  const shortcut = nextShortcut();
  if (shortcut == null) {
    createMessage.warning('快捷键 1-9 已满，请在管理中调整');
    return;
  }
  adding.value = true;
  try {
    await createDatasetTag({
      datasetId: Number(props.datasetId),
      name,
      shortcut,
      color: quickColor.value,
      description: '',
    });
    createMessage.success(`已添加「${name}」`);
    quickName.value = '';
    showAdd.value = false;
    emit('changed', name);
  } catch {
    createMessage.error('添加失败');
  } finally {
    adding.value = false;
  }
}

defineExpose({focusAddInput});
</script>

<style lang="less" scoped>
@primary: #4361ee;
@border: #e8e8e8;

.annotation-label-panel {
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-height: 0;
}

.panel-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.toolbar-title {
  font-size: 14px;
  font-weight: 600;
  color: #333;
}

.toolbar-actions {
  display: flex;
  gap: 4px;
}

.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: 1px solid @border;
  border-radius: 6px;
  background: #fff;
  color: #666;
  cursor: pointer;
  font-size: 14px;
  transition: border-color 0.15s, color 0.15s, background 0.15s;

  &:hover,
  &.active {
    border-color: @primary;
    color: @primary;
    background: fade(@primary, 6%);
  }
}

.add-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 10px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
}

.add-actions {
  display: flex;
  align-items: center;
  gap: 8px;

  .color-input {
    width: 32px;
    height: 28px;
    padding: 0;
    border: 1px solid @border;
    border-radius: 4px;
    cursor: pointer;
    flex-shrink: 0;
  }
}

.label-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  overflow-y: auto;
  flex: 1;
  min-height: 80px;
  max-height: 280px;
  padding-right: 2px;

  &::-webkit-scrollbar {
    width: 4px;
  }

  &::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.1);
    border-radius: 2px;
  }
}

.label-empty {
  padding: 20px 8px;
  text-align: center;
  color: #999;
  font-size: 13px;

  p {
    margin: 0 0 10px;
  }

  .empty-btn {
    padding: 5px 14px;
    border: 1px dashed @primary;
    border-radius: 6px;
    background: fade(@primary, 5%);
    color: @primary;
    font-size: 12px;
    cursor: pointer;

    &:hover {
      background: fade(@primary, 10%);
    }
  }
}

.label-chip {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 8px 10px;
  border: 1px solid @border;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  text-align: left;
  transition: border-color 0.15s, background 0.15s;

  &:hover {
    border-color: fade(@primary, 40%);
    background: #fafbff;
  }

  &.active {
    border-color: @primary;
    background: fade(@primary, 8%);
    box-shadow: inset 3px 0 0 @primary;
  }

  .chip-color {
    width: 14px;
    height: 14px;
    border-radius: 3px;
    flex-shrink: 0;
  }

  .chip-name {
    flex: 1;
    min-width: 0;
    font-size: 13px;
    font-weight: 500;
    color: #333;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .chip-key {
    flex-shrink: 0;
    min-width: 20px;
    height: 20px;
    padding: 0 5px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
    background: #f0f0f0;
    font-size: 11px;
    font-weight: 600;
    color: #888;
  }

  &.active .chip-key {
    background: fade(@primary, 15%);
    color: @primary;
  }
}
</style>

<template>
  <div class="tag-panel">
    <div class="tag-panel-intro">
      <Icon icon="ant-design:tags-outlined"/>
      <div>
        <p class="intro-title">标注类别</p>
        <p class="intro-desc">快捷键 <kbd>1</kbd>–<kbd>9</kbd> 在画布上快速切换；导入 YOLO/COCO/LabelMe 时会自动创建标签。</p>
      </div>
    </div>

    <div class="quick-add-card">
      <div class="quick-add-title">快速添加</div>
      <div class="quick-add-form">
        <Input
          v-model:value="quickName"
          placeholder="标签名称，如：行人、车辆"
          allow-clear
          @press-enter="handleQuickAdd"
        />
        <input v-model="quickColor" type="color" class="color-input" title="标签颜色"/>
        <span class="shortcut-preview">键 {{ nextShortcutPreview }}</span>
        <Button type="primary" :loading="adding" :disabled="!quickName.trim()" @click="handleQuickAdd">
          添加
        </Button>
      </div>
    </div>

    <Spin :spinning="loading">
      <div v-if="tags.length === 0" class="tag-empty">
        <Icon icon="ant-design:inbox-outlined"/>
        <p>暂无标签</p>
        <p class="tag-empty-hint">导入带标注的数据将自动创建；或上方手动添加</p>
      </div>
      <ul v-else class="tag-list">
        <li v-for="tag in tags" :key="tag.id" class="tag-row">
          <span class="tag-color" :style="{ backgroundColor: tag.color }"/>
          <div class="tag-info">
            <span class="tag-name">{{ tag.name }}</span>
            <span v-if="tag.description" class="tag-desc">{{ tag.description }}</span>
          </div>
          <span class="tag-shortcut">{{ tag.shortcut }}</span>
          <div class="tag-actions">
            <button type="button" class="icon-btn" title="编辑" @click="openEdit(tag)">
              <Icon icon="ant-design:edit-outlined"/>
            </button>
            <Popconfirm title="删除后无法恢复，确认删除？" @confirm="handleDelete(tag)">
              <button type="button" class="icon-btn danger" title="删除">
                <Icon icon="ant-design:delete-outlined"/>
              </button>
            </Popconfirm>
          </div>
        </li>
      </ul>
    </Spin>

    <DatasetTagModal @register="registerTagModal" @success="reload"/>
  </div>
</template>

<script setup lang="ts">
import {computed, onMounted, ref, watch} from 'vue';
import { Input, Popconfirm, Spin } from 'ant-design-vue';
import {Icon} from '@/components/Icon';
import {useMessage} from '@/hooks/web/useMessage';
import {useModal} from '@/components/Modal';
import {createDatasetTag, deleteDatasetTag} from '@/api/device/dataset';
import DatasetTagModal from '@/views/dataset/components/DatasetTagModal/index.vue';
import { Button } from '@/components/Button'
import {
fetchDatasetTags,
  TAG_COLOR_PALETTE,
  type DatasetTagItem,
} from '@/views/dataset/components/AnnotationTool/datasetTagUtils';

defineOptions({name: 'DatasetTagPanel'});

const props = defineProps<{
  datasetId: string | number;
}>();

const emit = defineEmits<{
  (e: 'changed'): void;
}>();

const {createMessage} = useMessage();
const [registerTagModal, {openModal: openTagModal}] = useModal();

const loading = ref(false);
const adding = ref(false);
const tags = ref<DatasetTagItem[]>([]);
const quickName = ref('');
const quickColor = ref(TAG_COLOR_PALETTE[0]);

const nextShortcutPreview = computed(() => {
  const used = new Set(tags.value.map((t) => Number(t.shortcut)));
  for (let i = 1; i <= 9; i++) {
    if (!used.has(i)) return i;
  }
  return '—';
});

async function reload() {
  loading.value = true;
  try {
    tags.value = await fetchDatasetTags(props.datasetId);
    emit('changed');
  } finally {
    loading.value = false;
  }
}

async function handleQuickAdd() {
  const name = quickName.value.trim();
  if (!name) return;
  const used = new Set(tags.value.map((t) => Number(t.shortcut)));
  let shortcut: number | null = null;
  for (let i = 1; i <= 9; i++) {
    if (!used.has(i)) {
      shortcut = i;
      break;
    }
  }
  if (shortcut == null) {
    createMessage.warning('快捷键 1-9 已全部占用');
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
    createMessage.success('标签已添加');
    quickName.value = '';
    quickColor.value = TAG_COLOR_PALETTE[tags.value.length % TAG_COLOR_PALETTE.length];
    await reload();
  } catch {
    createMessage.error('添加失败');
  } finally {
    adding.value = false;
  }
}

function openEdit(tag: DatasetTagItem) {
  openTagModal(true, {
    datasetId: Number(props.datasetId),
    isEdit: true,
    isView: false,
    record: {
      ...tag,
      datasetId: Number(props.datasetId || tag.datasetId),
      shortcut: Number(tag.shortcut),
    },
  });
}

async function handleDelete(tag: DatasetTagItem) {
  try {
    await deleteDatasetTag(tag.id);
    createMessage.success('已删除');
    await reload();
  } catch {
    createMessage.error('删除失败');
  }
}

onMounted(reload);
watch(() => props.datasetId, reload);

defineExpose({reload});
</script>

<style lang="less" scoped>
@primary: #4361ee;

.tag-panel {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.tag-panel-intro {
  display: flex;
  gap: 12px;
  padding: 12px 14px;
  background: linear-gradient(135deg, fade(@primary, 8%), fade(@primary, 2%));
  border: 1px solid fade(@primary, 15%);
  border-radius: 8px;
  font-size: 20px;
  color: @primary;

  .intro-title {
    margin: 0 0 4px;
    font-size: 14px;
    font-weight: 600;
    color: #262626;
  }

  .intro-desc {
    margin: 0;
    font-size: 12px;
    color: #8c8c8c;
    line-height: 1.5;

    kbd {
      padding: 0 4px;
      border: 1px solid #d9d9d9;
      border-radius: 3px;
      background: #fafafa;
      font-size: 11px;
    }
  }
}

.quick-add-card {
  padding: 12px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  background: #fafafa;

  .quick-add-title {
    font-size: 12px;
    font-weight: 600;
    color: #595959;
    margin-bottom: 8px;
  }

  .quick-add-form {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px;

    :deep(.ant-input) {
      flex: 1;
      min-width: 140px;
    }
  }

  .color-input {
    width: 36px;
    height: 32px;
    padding: 2px;
    border: 1px solid #d9d9d9;
    border-radius: 6px;
    cursor: pointer;
  }

  .shortcut-preview {
    font-size: 12px;
    color: #8c8c8c;
    white-space: nowrap;
  }
}

.tag-empty {
  text-align: center;
  padding: 32px 16px;
  color: #bfbfbf;
  font-size: 32px;

  p {
    margin: 8px 0 0;
    font-size: 14px;
    color: #8c8c8c;
  }

  .tag-empty-hint {
    font-size: 12px;
  }
}

.tag-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.tag-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  background: #fff;
  transition: box-shadow 0.2s;

  &:hover {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  }

  .tag-color {
    width: 28px;
    height: 28px;
    border-radius: 6px;
    flex-shrink: 0;
  }

  .tag-info {
    flex: 1;
    min-width: 0;
  }

  .tag-name {
    font-weight: 500;
    color: #262626;
  }

  .tag-desc {
    display: block;
    font-size: 12px;
    color: #8c8c8c;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tag-shortcut {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f5f5f5;
    border-radius: 6px;
    font-size: 12px;
    font-weight: 600;
    color: #595959;
    flex-shrink: 0;
  }

  .tag-actions {
    display: flex;
    gap: 4px;
  }

  .icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 6px;
    background: transparent;
    color: #8c8c8c;
    cursor: pointer;

    &:hover {
      background: #f5f5f5;
      color: @primary;
    }

    &.danger:hover {
      color: #ff4d4f;
      background: #fff1f0;
    }
  }
}
</style>

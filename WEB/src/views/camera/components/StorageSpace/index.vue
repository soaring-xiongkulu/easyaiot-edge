<template>
  <div class="storage-space">
    <div class="mode-toolbar">
      <RadioGroup
        v-model:value="activeKind"
        button-style="solid"
        size="middle"
        class="mode-radio-group"
      >
        <RadioButton value="snap">
          <span class="mode-radio-item">
            <Icon icon="ant-design:camera-outlined" />
            抓拍空间
          </span>
        </RadioButton>
        <RadioButton value="record">
          <span class="mode-radio-item">
            <Icon icon="ant-design:video-camera-outlined" />
            录像空间
          </span>
        </RadioButton>
      </RadioGroup>
      <span v-if="activeKind === 'snap'" class="mode-hint">
        管理设备抓拍存储空间，支持图库浏览与算法告警查看
      </span>
      <span v-else class="mode-hint">管理设备录像存储空间，支持回放与存储策略配置</span>
    </div>

    <SnapSpace
      v-if="snapMounted"
      v-show="activeKind === 'snap'"
      ref="snapRef"
      embedded
      :active="activeKind === 'snap'"
    />
    <RecordSpace
      v-if="recordMounted"
      v-show="activeKind === 'record'"
      ref="recordRef"
      embedded
      :active="activeKind === 'record'"
    />
  </div>
</template>

<script lang="ts" setup>
import { onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { RadioButton, RadioGroup } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import SnapSpace from '../SnapSpace/index.vue';
import RecordSpace from '../RecordSpace/index.vue';
import type { SpaceKind } from '@/views/camera/utils/spaceSaveTime';

defineOptions({ name: 'StorageSpace' });

const route = useRoute();
const router = useRouter();

const snapRef = ref<InstanceType<typeof SnapSpace> | null>(null);
const recordRef = ref<InstanceType<typeof RecordSpace> | null>(null);
const activeKind = ref<SpaceKind>('snap');
const snapMounted = ref(activeKind.value === 'snap');
const recordMounted = ref(activeKind.value === 'record');

function normalizeStorageKind(value: unknown): SpaceKind {
  if (value === 'record') return 'record';
  return 'snap';
}

function applyStorageKind(kind: SpaceKind) {
  activeKind.value = kind;
  if (kind === 'snap') snapMounted.value = true;
  else recordMounted.value = true;
}

function syncKindFromRoute() {
  if (route.query.storage === 'task') {
    const nextQuery: Record<string, unknown> = { ...route.query, storage: 'snap' };
    delete nextQuery.space_id;
    delete nextQuery.device_id;
    router.replace({ path: route.path, query: nextQuery });
    applyStorageKind('snap');
    return;
  }
  applyStorageKind(normalizeStorageKind(route.query.storage));
}

function refreshCurrent() {
  if (activeKind.value === 'record') {
    recordRef.value?.refresh();
  } else {
    snapRef.value?.refresh();
  }
}

function refreshAll() {
  snapRef.value?.refresh();
  recordRef.value?.refresh();
}

defineExpose({
  refresh: refreshCurrent,
  refreshAll,
});

watch(activeKind, (kind) => {
  if (kind === 'snap') snapMounted.value = true;
  else recordMounted.value = true;
  // 与分屏监控一致：v-show 切换时不重复拉取（子组件首次挂载时已 load）
});

watch(
  () => route.query.storage,
  () => syncKindFromRoute(),
);

onMounted(() => {
  syncKindFromRoute();
});
</script>

<style lang="less" scoped>
.storage-space {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 192px);
  max-height: calc(100vh - 192px);
  padding-bottom: 4px;
  box-sizing: border-box;
  overflow: hidden;
  background: #f0f2f5;

  > :not(.mode-toolbar) {
    flex: 1;
    min-height: 0;
  }
}

.mode-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  padding: 12px 16px;
  margin-bottom: 8px;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;

  .mode-radio-group {
    :deep(.ant-radio-button-wrapper) {
      height: auto;
      line-height: 1;
      padding: 6px 14px;
    }
  }

  .mode-radio-item {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .mode-hint {
    color: #6b7280;
    font-size: 13px;
  }
}
</style>

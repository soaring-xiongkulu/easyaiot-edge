<template>
  <Drawer
    v-model:open="visible"
    :title="drawerTitle"
    placement="right"
    :width="560"
    :get-container="getContainer"
    destroy-on-close
    class="dataset-manage-drawer"
  >
    <div class="drawer-nav">
      <button
        v-for="item in navItems"
        :key="item.key"
        type="button"
        class="nav-pill"
        :class="{ active: activeTab === item.key }"
        @click="activeTab = item.key"
      >
        <Icon :icon="item.icon"/>
        {{ item.label }}
      </button>
    </div>

    <div class="drawer-body">
      <DatasetTagPanel
        v-show="activeTab === 'tags'"
        ref="tagPanelRef"
        :dataset-id="datasetId"
        @changed="emit('tags-changed')"
      />
      <DatasetSourcePanel
        v-show="activeTab === 'source'"
        @open-unattended="emit('open-unattended')"
        @frame-tasks-changed="emit('frame-tasks-changed')"
      />
    </div>
  </Drawer>
</template>

<script setup lang="ts">
import {computed, ref, watch} from 'vue';
import {Drawer} from 'ant-design-vue';
import {Icon} from '@/components/Icon';
import {useRoute} from 'vue-router';
import DatasetTagPanel from '@/views/dataset/components/AnnotationTool/DatasetTagPanel.vue';
import DatasetSourcePanel from '@/views/dataset/components/AnnotationTool/DatasetSourcePanel.vue';

defineOptions({name: 'DatasetManageDrawer'});

/** @deprecated 保留兼容：frame/video 合并为 source */
export type ManageDrawerTab = 'tags' | 'source' | 'frame' | 'video';

const props = defineProps<{
  open: boolean;
  initialTab?: ManageDrawerTab;
  getContainer?: () => HTMLElement;
}>();

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void;
  (e: 'tags-changed'): void;
  (e: 'open-unattended'): void;
  (e: 'frame-tasks-changed'): void;
}>();

const route = useRoute();
const datasetId = computed(() => route.params['id']);
const tagPanelRef = ref<InstanceType<typeof DatasetTagPanel> | null>(null);

const visible = ref(false);
const activeTab = ref<'tags' | 'source'>('tags');

const navItems = [
  {key: 'tags' as const, label: '标签', icon: 'ant-design:tags-outlined'},
  {key: 'source' as const, label: '数据源', icon: 'ant-design:database-outlined'},
];

const drawerTitle = computed(() =>
  activeTab.value === 'tags' ? '标签管理' : '数据来源',
);

function normalizeTab(tab?: ManageDrawerTab): 'tags' | 'source' {
  if (tab === 'frame' || tab === 'video') return 'source';
  return tab === 'source' ? 'source' : 'tags';
}

watch(
  () => props.open,
  (v) => {
    visible.value = v;
    if (v && props.initialTab) {
      activeTab.value = normalizeTab(props.initialTab);
    }
  },
  {immediate: true},
);

watch(
  () => props.initialTab,
  (tab) => {
    if (tab && visible.value) activeTab.value = normalizeTab(tab);
  },
);

watch(visible, (v) => {
  emit('update:open', v);
  if (v) tagPanelRef.value?.reload();
});

defineExpose({reloadTags: () => tagPanelRef.value?.reload()});
</script>

<style lang="less">
.dataset-manage-drawer {
  .ant-drawer-body {
    padding: 12px 16px 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .drawer-nav {
    display: flex;
    gap: 8px;
    flex-shrink: 0;
  }

  .nav-pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 14px;
    border: 1px solid #e8e8e8;
    border-radius: 20px;
    background: #fff;
    font-size: 13px;
    color: #595959;
    cursor: pointer;
    transition: all 0.2s;

    &:hover {
      border-color: #4361ee;
      color: #4361ee;
    }

    &.active {
      background: fade(#4361ee, 10%);
      border-color: #4361ee;
      color: #4361ee;
      font-weight: 500;
    }
  }

  .drawer-body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }

  .subDevice-wrapper,
  .device-drawer-warpper {
    margin: 0;
  }

  .device-tabs .ant-card,
  .device-drawer-warpper .device-tabs {
    margin: 0 !important;
  }

  .source-collapse .subDevice-wrapper {
    :deep(.iot-basic-table-header) {
      padding: 0;
    }
  }
}
</style>

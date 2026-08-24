<template>
  <div class="monitor-preset">
    <Tabs v-model:activeKey="activeTab" size="small">
      <TabPane key="preset" tab="预置点">
        <div v-if="loading" class="monitor-preset__loading">
          <Spin size="small" /> 加载中...
        </div>
        <div v-else class="monitor-preset__list">
          <div v-if="!presets.length" class="monitor-preset__empty">暂无预置点</div>
          <div v-for="item in presets" :key="item.id" class="monitor-preset__item">
            <span class="monitor-preset__name">{{ item.name }}</span>
            <div class="monitor-preset__actions">
              <Tooltip title="调用">
                <button type="button" @click="emit('call', item.id)">
                  <Icon icon="ant-design:play-circle-outlined" :size="16" />
                </button>
              </Tooltip>
              <Tooltip title="设置">
                <button type="button" @click="emit('set', item.id)">
                  <Icon icon="ant-design:setting-outlined" :size="16" />
                </button>
              </Tooltip>
              <Tooltip title="删除">
                <button type="button" class="danger" @click="emit('delete', item.id)">
                  <Icon icon="ant-design:delete-outlined" :size="16" />
                </button>
              </Tooltip>
            </div>
          </div>
        </div>
        <Button type="dashed" block class="monitor-preset__add" @click="emit('add')">
          <Icon icon="ant-design:plus-outlined" :size="14" />
          添加预置点
        </Button>
      </TabPane>
      <TabPane key="patrol" tab="巡航">
        <div class="monitor-preset__empty">巡航路径管理即将开放</div>
      </TabPane>
    </Tabs>
  </div>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { Tabs, TabPane, Button, Spin, Tooltip } from 'ant-design-vue';
import { Icon } from '@/components/Icon';

export interface PresetItem {
  id: string | number;
  name: string;
}

defineProps<{
  presets: PresetItem[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  call: [id: string | number];
  set: [id: string | number];
  delete: [id: string | number];
  add: [];
}>();

const activeTab = ref('preset');
</script>

<style scoped lang="less">
.monitor-preset {
  margin-top: 8px;
}

.monitor-preset__list {
  max-height: 180px;
  overflow-y: auto;
  margin-bottom: 10px;
}

.monitor-preset__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 10px;
  border-radius: 8px;
  background: #f8fafc;
  margin-bottom: 6px;
}

.monitor-preset__name {
  font-size: 13px;
  color: #334155;
}

.monitor-preset__actions {
  display: flex;
  gap: 4px;

  button {
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 6px;
    background: transparent;
    color: #64748b;
    cursor: pointer;

    &:hover {
      background: #e2e8f0;
      color: #0f766e;
    }

    &.danger:hover {
      color: #dc2626;
    }
  }
}

.monitor-preset__empty,
.monitor-preset__loading {
  padding: 24px 0;
  text-align: center;
  color: #94a3b8;
  font-size: 13px;
}

.monitor-preset__add {
  margin-top: 4px;
}
</style>

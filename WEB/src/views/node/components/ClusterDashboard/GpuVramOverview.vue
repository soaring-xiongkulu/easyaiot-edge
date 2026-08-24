<script lang="ts" setup>
import { useRender } from '@/components/Table';
import NodeGpuMiniBars from '../NodeGpuMiniBars/index.vue';
import type { NodeGpuGroup } from '../../utils/clusterMetrics';
import { NODE_DASHBOARD, NODE_STATUS_MAP } from '../../utils/constants';

defineOptions({ name: 'GpuVramOverview' });

defineProps<{
  groups: NodeGpuGroup[];
}>();

function statusTag(status?: string) {
  return NODE_STATUS_MAP[status || ''] || { text: status || '-', color: 'default' };
}

function renderStatusTag(status?: string) {
  const item = statusTag(status);
  return useRender.renderTag(item.text, item.color);
}
</script>

<template>
  <div v-if="!groups.length" class="gpu-vram-empty">
    {{ NODE_DASHBOARD.noVramData }}
  </div>
  <div v-else class="gpu-vram-list">
    <div class="gpu-vram-head">
      <span>{{ NODE_DASHBOARD.colName }}</span>
      <span>{{ NODE_DASHBOARD.vramColUsed }}</span>
    </div>
    <div v-for="group in groups" :key="group.nodeId" class="gpu-vram-node">
      <div class="gpu-vram-node__info">
        <div class="gpu-vram-node__title">
          <span class="gpu-vram-node__name">{{ group.nodeName }}</span>
          <component :is="renderStatusTag(group.status)" class="gpu-vram-node__tag" />
        </div>
        <div class="gpu-vram-node__meta">
          <span>{{ group.host }}</span>
          <span>{{ group.gpus.length }} 张 GPU</span>
          <span v-if="group.avgVram >= 85" class="gpu-vram-node__warn">{{ NODE_DASHBOARD.vramTight }}</span>
        </div>
      </div>
      <div class="gpu-vram-node__bars">
        <NodeGpuMiniBars
          :gpu-info="group.gpus.map((g) => ({
            id: g.gpuId,
            name: g.name,
            util: g.util,
            mem_used_mb: g.memUsedMb,
            mem_total_mb: g.memTotalMb,
          }))"
          metric="vram"
        />
      </div>
    </div>
  </div>
</template>

<style lang="less" scoped>
.gpu-vram-empty {
  padding: 32px 16px;
  text-align: center;
  font-size: 13px;
  color: #8c8c8c;
  background: #fafafa;
  border: 1px dashed #e8e8e8;
  border-radius: 4px;
}

.gpu-vram-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.gpu-vram-head,
.gpu-vram-node {
  display: grid;
  grid-template-columns: 220px 1fr;
  gap: 20px;
  align-items: center;
  padding: 0 16px;
}

.gpu-vram-head {
  font-size: 12px;
  color: #8c8c8c;
  padding-bottom: 4px;

  span:last-child {
    text-align: right;
  }
}

.gpu-vram-node {
  padding: 14px 16px;
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 4px;

  &:hover {
    background: #f5f5f5;
  }
}

.gpu-vram-node__info {
  min-width: 0;
}

.gpu-vram-node__title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.gpu-vram-node__name {
  font-size: 14px;
  font-weight: 600;
  color: #262626;
}

.gpu-vram-node__tag {
  margin: 0;
}

.gpu-vram-node__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  font-size: 12px;
  color: #8c8c8c;

  span:first-child {
    font-family: Consolas, monospace;
  }
}

.gpu-vram-node__warn {
  color: #ff4d4f;
  font-weight: 500;
}

.gpu-vram-node__bars {
  min-width: 0;
}

@media (max-width: 900px) {
  .gpu-vram-head {
    display: none;
  }

  .gpu-vram-node {
    grid-template-columns: 1fr;
    gap: 10px;
  }
}
</style>

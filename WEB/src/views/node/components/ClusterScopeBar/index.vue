<template>
  <div class="cluster-scope-bar">
    <div class="node-select-row">
      <label class="control-item">
        <span>{{ NODE_DASHBOARD.overviewCentralNode }}</span>
        <ApiSelect
          v-model:value="centralLaneSelectValue"
          show-search
          class="cluster-scope-bar__select"
          :options="centralLaneOptions"
          :filter-option="filterLane"
          :loading="loading"
          :immediate="false"
        />
      </label>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, onMounted, ref } from 'vue';
import { ApiSelect } from '@/components/Form';
import { NODE_DASHBOARD } from '../../utils/constants';
import { useClusterNodeScope } from '../../utils/useClusterNodeScope';

defineOptions({ name: 'ClusterScopeBar' });

const emit = defineEmits<{
  laneChange: [laneKey: string];
}>();

const loading = ref(false);
const { activeLaneKey, centralLaneOptions, loadLanes, setActiveLaneKey } = useClusterNodeScope();

const centralLaneSelectValue = computed({
  get: () => activeLaneKey.value,
  set: (laneKey: string) => handleLaneChange(laneKey),
});

function filterLane(input: string, option: { label?: string }) {
  return (option.label || '').toLowerCase().includes(input.toLowerCase());
}

function handleLaneChange(laneKey: string) {
  setActiveLaneKey(laneKey);
  emit('laneChange', laneKey);
}

onMounted(async () => {
  loading.value = true;
  try {
    await loadLanes();
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped lang="less">
@import '../../utils/theme.less';

.cluster-scope-bar {
  margin-bottom: 16px;
}

.node-select-row {
  display: flex;
  align-items: center;
  gap: 12px 20px;
  flex-wrap: wrap;
}

.cluster-scope-bar__select {
  min-width: 220px;
}

.control-item {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  font-size: @node-font-caption;
  color: @node-text-secondary;
}
</style>

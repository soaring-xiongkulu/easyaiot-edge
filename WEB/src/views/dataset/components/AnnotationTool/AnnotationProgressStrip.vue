<template>
  <div v-if="visible" class="progress-strip">
    <div class="progress-track">
      <div
        class="progress-fill"
        :class="progressLevel"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <div class="progress-meta">
      <span class="progress-text">
        标注进度 <strong>{{ completed }}</strong>/{{ total }}
        <span class="percent">({{ percent }}%)</span>
      </span>
      <span v-if="tip" class="progress-tip">
        {{ tip.text }}
        <button
          v-if="tip.action"
          type="button"
          class="tip-action"
          @click="emit('tip-action', tip.action)"
        >
          {{ tip.actionLabel }}
        </button>
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import {computed} from 'vue';

export type TipAction = 'import' | 'nextPending' | 'split' | 'sync' | 'filterPending' | 'aiLabel';

export interface WorkflowTip {
  text: string;
  action?: TipAction;
  actionLabel?: string;
}

const props = defineProps<{
  total: number;
  completed: number;
  tip: WorkflowTip | null;
}>();

const emit = defineEmits<{
  (e: 'tip-action', action: TipAction): void;
}>();

const visible = computed(() => props.total > 0 || !!props.tip?.text);

const percent = computed(() => {
  if (props.total <= 0) return 0;
  return Math.min(100, Math.round((props.completed / props.total) * 100));
});

const progressLevel = computed(() => {
  if (percent.value >= 100) return 'is-complete';
  if (percent.value >= 70) return 'is-good';
  if (percent.value >= 30) return 'is-mid';
  return 'is-low';
});
</script>

<style lang="less" scoped>
@primary: #4361ee;

.progress-strip {
  flex-shrink: 0;
  padding: 6px 12px 8px;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
}

.progress-track {
  height: 4px;
  background: #e8e8e8;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 6px;
}

.progress-fill {
  height: 100%;
  border-radius: 2px;
  transition: width 0.35s ease;

  &.is-low {
    background: #ff7875;
  }

  &.is-mid {
    background: #ffc53d;
  }

  &.is-good {
    background: #69b1ff;
  }

  &.is-complete {
    background: #52c41a;
  }
}

.progress-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 12px;
  color: #8c8c8c;
}

.progress-text {
  white-space: nowrap;

  strong {
    color: #262626;
  }

  .percent {
    color: #bfbfbf;
    margin-left: 2px;
  }
}

.progress-tip {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #595959;
  min-width: 0;
}

.tip-action {
  border: none;
  background: none;
  padding: 0;
  color: @primary;
  cursor: pointer;
  font-size: 12px;
  white-space: nowrap;

  &:hover {
    text-decoration: underline;
  }
}
</style>

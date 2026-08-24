<script setup lang="ts">
import { computed } from 'vue';
import { Tag } from 'ant-design-vue';
import { formatAlertEvent, getAlertEventTagColor } from '@/views/alert/alertDisplay';
import type { AlertMapItem } from '../../types';

defineOptions({ name: 'CameraAlertCard' });

const props = withDefaults(defineProps<{
  name?: string;
  online?: boolean;
  alerts?: AlertMapItem[];
}>(), {
  alerts: () => [],
});

const total = computed(() => props.alerts.length);

interface AlertGroup {
  event: string;
  label: string;
  color: string;
  count: number;
  latestTime?: string;
}

// 按告警类型(event)分组：数量 + 最近时间（alerts 传入时已按时间倒序）
const groups = computed<AlertGroup[]>(() => {
  const map = new Map<string, AlertGroup>();
  for (const a of props.alerts) {
    const key = a.event || '';
    let g = map.get(key);
    if (!g) {
      g = { event: key, label: formatAlertEvent(a.event), color: getAlertEventTagColor(a.event), count: 0, latestTime: a.time };
      map.set(key, g);
    }
    g.count += 1;
    if (a.time && (!g.latestTime || a.time > g.latestTime)) g.latestTime = a.time;
  }
  return Array.from(map.values()).sort((x, y) => y.count - x.count);
});
</script>

<template>
  <div class="camera-alert-card">
    <header class="camera-alert-card__head">
      <span class="camera-alert-card__dot" :class="online === false ? 'is-offline' : 'is-online'" />
      <span class="camera-alert-card__name" :title="name">{{ name || '未命名摄像头' }}</span>
      <span v-if="total" class="camera-alert-card__total">告警 {{ total }}</span>
    </header>

    <p v-if="!total" class="camera-alert-card__empty">暂无告警</p>

    <div v-else class="camera-alert-card__table">
      <!-- 列头：让"日期=最近告警时间"一眼可懂 -->
      <span class="camera-alert-card__th">告警类型</span>
      <span class="camera-alert-card__th camera-alert-card__th--c">数量</span>
      <span class="camera-alert-card__th camera-alert-card__th--t">最近告警时间</span>

      <template v-for="g in groups" :key="g.event">
        <Tag :color="g.color" class="camera-alert-card__tag">{{ g.label }}</Tag>
        <span class="camera-alert-card__count">×{{ g.count }}</span>
        <span class="camera-alert-card__time">{{ g.latestTime || '—' }}</span>
      </template>
    </div>
  </div>
</template>

<style scoped lang="less">
.camera-alert-card {
  /* 自适应内容宽度：随告警名/数量/时间撑开，限定上下界，避免过窄出滚动条、过宽超屏 */
  width: max-content;
  min-width: 248px;
  max-width: min(400px, 80vw);
  padding: 10px 12px;
  background: #fff;
  border-radius: 10px;
  border: 1px solid #e8ecf4;
  box-shadow: 0 8px 28px rgb(15 23 42 / 16%);
  pointer-events: auto;
  font-size: 13px;
  color: rgba(0, 0, 0, 0.82);

  &__head {
    display: flex;
    align-items: center;
    gap: 7px;
  }

  &__dot {
    flex-shrink: 0;
    width: 8px;
    height: 8px;
    border-radius: 50%;

    &.is-online { background: #52c41a; box-shadow: 0 0 0 3px rgb(82 196 26 / 14%); }
    &.is-offline { background: #bfbfbf; box-shadow: 0 0 0 3px rgb(0 0 0 / 8%); }
  }

  &__name {
    flex: 1;
    min-width: 0;
    font-weight: 600;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  &__total {
    flex-shrink: 0;
    padding: 1px 7px;
    font-size: 11px;
    font-weight: 600;
    color: #ff4d4f;
    background: rgb(255 77 79 / 10%);
    border-radius: 9px;
  }

  &__empty {
    margin: 8px 0 2px;
    font-size: 12px;
    color: rgba(0, 0, 0, 0.4);
  }

  /* 三列表格：类型 / 数量 / 最近告警时间，列对齐、列头解释语义 */
  &__table {
    display: grid;
    grid-template-columns: 1fr auto auto;
    align-items: center;
    column-gap: 12px;
    row-gap: 7px;
    margin-top: 8px;
    max-height: 222px;
    overflow-y: auto;

    &::-webkit-scrollbar { width: 5px; }
    &::-webkit-scrollbar-thumb { background: #d3d9e3; border-radius: 3px; }
  }

  &__th {
    position: sticky;
    top: 0;
    z-index: 1;
    padding-bottom: 4px;
    font-size: 11px;
    color: rgba(0, 0, 0, 0.4);
    background: #fff;
    border-bottom: 1px solid #f0f2f7;

    &--c { text-align: center; }
    &--t { text-align: right; }
  }

  &__tag {
    margin: 0;
    justify-self: start;
  }

  &__count {
    text-align: center;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    color: rgba(0, 0, 0, 0.7);
  }

  &__time {
    text-align: right;
    font-size: 11px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    color: rgba(0, 0, 0, 0.55);
    white-space: nowrap;
  }
}
</style>

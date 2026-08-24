<script setup lang="ts">
import { computed } from 'vue';

export type MapToolbarStatVariant = 'camera' | 'alert' | 'marker' | 'track' | 'error' | 'info';

const props = withDefaults(
  defineProps<{
    label?: string;
    count?: number | string | null;
    value?: string;
    variant?: MapToolbarStatVariant;
  }>(),
  {
    variant: 'info',
  },
);

const displayText = computed(() => props.value || null);

const isCountStat = computed(() => !displayText.value && props.label != null && props.count != null && props.count !== '');

const isZero = computed(() => {
  if (!isCountStat.value) return false;
  const n = Number(props.count);
  return !Number.isNaN(n) && n === 0;
});
</script>

<template>
  <span
    class="map-toolbar-stat"
    :class="[
      `map-toolbar-stat--${variant}`,
      { 'map-toolbar-stat--count': isCountStat, 'is-zero': isZero },
    ]"
    :title="displayText || undefined"
  >
    <span v-if="displayText" class="map-toolbar-stat__text">{{ displayText }}</span>
    <span v-else-if="isCountStat" class="map-toolbar-stat__badge">
      <span class="map-toolbar-stat__label">{{ label }}</span>
      <span class="map-toolbar-stat__colon">：</span>
      <span class="map-toolbar-stat__count">{{ count }}</span>
    </span>
    <template v-else>
      <span v-if="label" class="map-toolbar-stat__label">{{ label }}</span>
      <span v-if="count != null && count !== ''" class="map-toolbar-stat__count">{{ count }}</span>
    </template>
  </span>
</template>

<style scoped lang="less">
.map-toolbar-stat {
  display: inline-flex;
  align-items: center;
  font-size: 13px;
  line-height: 1;
  white-space: nowrap;
  max-width: 100%;

  &__badge {
    display: inline-flex;
    align-items: center;
    padding: 4px 10px;
    border-radius: 6px;
    border: 1px solid #e8e8e8;
    background: transparent;
  }

  &__label {
    color: rgba(0, 0, 0, 0.65);
    font-weight: 500;
  }

  &__colon {
    color: rgba(0, 0, 0, 0.25);
    margin: 0 1px;
    font-weight: 400;
  }

  &__count {
    min-width: 1.2em;
    font-size: 16px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  &__text {
    color: rgba(0, 0, 0, 0.75);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  &--count.is-zero .map-toolbar-stat__count {
    opacity: 0.45;
  }

  &--camera.map-toolbar-stat--count {
    .map-toolbar-stat__badge {
      border-color: #91caff;
    }

    .map-toolbar-stat__count {
      color: #1677ff;
    }
  }

  &--alert.map-toolbar-stat--count {
    .map-toolbar-stat__badge {
      border-color: #ffccc7;
    }

    .map-toolbar-stat__count {
      color: #ff4d4f;
    }
  }

  &--marker.map-toolbar-stat--count {
    .map-toolbar-stat__badge {
      border-color: #d3adf7;
    }

    .map-toolbar-stat__count {
      color: #531dab;
    }
  }

  &--track.map-toolbar-stat--count {
    .map-toolbar-stat__badge {
      border-color: #b7eb8f;
    }

    .map-toolbar-stat__count {
      color: #389e0d;
    }
  }

  &--error .map-toolbar-stat__text {
    color: #ff4d4f;
  }

  &--info .map-toolbar-stat__text {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 12px;
    color: rgba(0, 0, 0, 0.7);
    max-width: min(360px, 50vw);
  }
}
</style>

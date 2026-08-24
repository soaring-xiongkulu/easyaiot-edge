<template>
  <div class="node-server-icon" :class="[visual.iconClass, sizeClass]">
    <Icon :icon="visual.bodyIcon" :size="bodySize" class="node-server-icon__body" />
    <span class="node-server-icon__rack" aria-hidden="true" />
    <Icon :icon="visual.roleMarkIcon" :size="markSize" class="node-server-icon__role-mark" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Icon } from '@/components/Icon';
import { getNodeRoleVisual } from '../../utils/nodeAssets';

defineOptions({ name: 'NodeRoleIcon' });

const props = withDefaults(
  defineProps<{
    role?: string;
    size?: 'md' | 'ml' | 'lg';
  }>(),
  { size: 'lg' },
);

const visual = computed(() => getNodeRoleVisual(props.role));
const sizeClass = computed(() => `node-server-icon--${props.size}`);

const SIZE_MAP = {
  md: { body: 54, mark: 16 },
  ml: { body: 72, mark: 18 },
  lg: { body: 88, mark: 20 },
} as const;

const bodySize = computed(() => SIZE_MAP[props.size].body);
const markSize = computed(() => SIZE_MAP[props.size].mark);
</script>

<style lang="less" scoped>
@import '../../utils/nodeRoleTheme.less';

.node-server-icon {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;

  &--md {
    width: 64px;
    height: 56px;
  }

  &--ml {
    width: 84px;
    height: 74px;
  }

  &--lg {
    width: 100px;
    height: 88px;
  }

  &__body {
    filter: drop-shadow(0 4px 8px rgba(15, 23, 42, 0.14));
  }

  &__rack {
    position: absolute;
    left: 50%;
    bottom: 2px;
    transform: translateX(-50%);
    width: 72%;
    height: 3px;
    border-radius: 2px;
    background: currentColor;
    opacity: 0.12;
    pointer-events: none;
  }

  &__role-mark {
    position: absolute;
    right: -4px;
    bottom: -2px;
    color: #fff;
    padding: 3px;
    border-radius: 5px;
    box-shadow: 0 2px 6px rgba(15, 23, 42, 0.18);
  }

  &--compute {
    color: @node-compute-server;

    .node-server-icon__body {
      color: @node-compute-server;
      filter: drop-shadow(0 4px 8px @node-compute-shadow);
    }

    .node-server-icon__role-mark {
      background: @node-compute-badge;
    }
  }

  &--media {
    color: @node-media-server;

    .node-server-icon__body {
      color: @node-media-server;
      filter: drop-shadow(0 4px 8px @node-media-shadow);
    }

    .node-server-icon__role-mark {
      background: @node-media-badge;
    }
  }

  &--mqtt {
    color: @node-mqtt-server;

    .node-server-icon__body {
      color: @node-mqtt-server;
      filter: drop-shadow(0 4px 8px @node-mqtt-shadow);
    }

    .node-server-icon__role-mark {
      background: @node-mqtt-badge;
    }
  }

  &--hybrid {
    color: @node-hybrid-server;

    .node-server-icon__body {
      color: @node-hybrid-server;
      filter: drop-shadow(0 4px 8px @node-hybrid-shadow);
    }

    .node-server-icon__role-mark {
      background: @node-hybrid-badge;
    }
  }

  &--storage {
    color: @node-storage-server;

    .node-server-icon__body {
      color: @node-storage-server;
      filter: drop-shadow(0 4px 8px @node-storage-shadow);
    }

    .node-server-icon__role-mark {
      background: @node-storage-badge;
    }
  }
}
</style>

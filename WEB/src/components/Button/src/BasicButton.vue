<script lang="ts" setup>
import { Button, theme } from 'ant-design-vue'
import type { ComponentOptionsMixin } from 'vue'
import { computed, unref, useSlots } from 'vue'
import { buttonProps } from './props'
import { useAttrs } from '@/hooks/core/useAttrs'
import { Icon } from '@/components/Icon'

defineOptions({
  name: 'AButton',
  extends: Button as ComponentOptionsMixin,
  inheritAttrs: false,
  indeterminate: false,
})
const props = defineProps(buttonProps)
const slots = useSlots()
const { useToken } = theme
const { token } = useToken()
const attrs = useAttrs({ excludeDefaultKeys: false })

const getButtonClass = computed(() => ({
  'is-disabled': props.disabled,
}))

const hasIconSlot = computed(() => Boolean(props.preIcon || slots.icon))

const getBindValue = computed(() => {
  const bind = { ...unref(attrs), ...props } as Record<string, unknown>
  const {
    preIcon: _preIcon,
    postIcon: _postIcon,
    iconSize: _iconSize,
    color: _color,
    onClick: _onClick,
    ...rest
  } = bind
  return rest
})
</script>

<template>
  <Button
    v-bind="getBindValue"
    :style="{
      backgroundColor: color
        ? (
          color === 'primary'
            ? token.colorPrimary
            : (
              color === 'error'
                ? token.colorError
                : (
                  color === 'warning'
                    ? token.colorWarning
                    : (color === 'success' ? token.colorSuccess : '')
                )
            )
        )
        : '',
    }"
    :class="getButtonClass"
    @click="onClick"
  >
    <template v-if="hasIconSlot" #icon>
      <slot name="icon">
        <Icon v-if="preIcon" :icon="preIcon" :size="iconSize" />
      </slot>
    </template>
    <template #default="data">
      <slot v-bind="data || {}" />
      <Icon v-if="postIcon" :icon="postIcon" :size="iconSize" />
    </template>
  </Button>
</template>

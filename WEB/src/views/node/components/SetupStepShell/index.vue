<script lang="ts" setup>
defineOptions({ name: 'SetupStepShell' });
</script>

<template>
  <div class="setup-step-shell">
    <div v-if="$slots.intro" class="setup-step-intro">
      <slot name="intro" />
    </div>

    <div class="setup-step-sections">
      <slot />
    </div>
  </div>
</template>

<style lang="less" scoped>
@import '../../utils/setup-panel.less';

.setup-step-shell {
  display: flex;
  flex-direction: column;
  gap: @setup-section-gap;
}

.setup-step-intro {
  :deep(.ant-alert) {
    border-radius: @setup-panel-radius;
    padding: 6px 12px;

    .ant-alert-message {
      font-size: 13px;
      line-height: 1.5;
    }
  }
}

.setup-step-sections {
  display: flex;
  flex-direction: column;
  gap: @setup-section-gap;

  :deep(.xingyuv-collapse-container) {
    .setup-section-card();
    padding: 0;
    overflow: hidden;

    .p-2 {
      padding: @setup-section-body-padding !important;
    }

    &__header {
      height: auto;
      min-height: 48px;
      padding: @setup-section-header-padding !important;
      border-bottom: 1px solid #f0f0f0;
    }

    &__body {
      > :first-child {
        margin-top: 0;
      }

      > :last-child {
        margin-bottom: 0;
      }
    }
  }
}
</style>

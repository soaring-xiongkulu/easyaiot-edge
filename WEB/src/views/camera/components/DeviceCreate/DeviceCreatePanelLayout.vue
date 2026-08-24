<template>
  <div class="device-create-panel">
    <div v-if="$slots.form || $slots.actions" class="panel-block panel-config">
      <div class="panel-form-wrap">
        <slot name="form" />
        <div v-if="$slots.actions" class="panel-form-footer" :class="{ 'is-only': !$slots.form }">
          <slot name="actions" />
        </div>
      </div>
    </div>

    <div
      v-if="$slots.result || $slots.default"
      class="panel-block panel-result"
      :class="{ 'is-fill': fillResult }"
    >
      <div v-if="resultTitle || $slots.resultExtra" class="panel-result-head">
        <span v-if="resultTitle" class="panel-result-title">{{ resultTitle }}</span>
        <div v-if="$slots.resultExtra" class="panel-result-extra">
          <slot name="resultExtra" />
        </div>
      </div>
      <div class="panel-result-body" :class="{ 'no-padding': resultNoPadding }">
        <slot name="result" />
        <slot />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import {
  DEVICE_CREATE_FIELD_LINE_WIDTH,
  DEVICE_CREATE_FIELD_WIDTH,
  DEVICE_CREATE_FORM_MAX_WIDTH,
  DEVICE_CREATE_LABEL_WIDTH,
} from './deviceCreateForm';

const formMaxWidth = `${DEVICE_CREATE_FORM_MAX_WIDTH}px`;
const formLabelWidth = `${DEVICE_CREATE_LABEL_WIDTH}px`;
const fieldWidth = `${DEVICE_CREATE_FIELD_WIDTH}px`;
const fieldLineWidth = `${DEVICE_CREATE_FIELD_LINE_WIDTH}px`;

defineProps({
  resultTitle: { type: String, default: '' },
  fillResult: { type: Boolean, default: true },
  resultNoPadding: { type: Boolean, default: false },
});
</script>

<style lang="less" scoped>
.device-create-panel {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.panel-block {
  flex-shrink: 0;
}

.panel-form-wrap {
  max-width: v-bind(formMaxWidth);

  :deep(.ant-form-item) {
    margin-bottom: 16px;
  }

  :deep(.ant-form-item:last-child) {
    margin-bottom: 0;
  }

  :deep(.ant-form-item-control-input-content) {
    max-width: v-bind(fieldWidth);
  }

  :deep(.device-create-col-line .ant-form-item-control-input-content) {
    max-width: v-bind(fieldLineWidth);
  }

  :deep(.ant-input),
  :deep(.ant-input-number),
  :deep(.ant-input-affix-wrapper),
  :deep(.ant-select),
  :deep(.ant-picker) {
    width: 100%;
  }
}

.panel-form-footer {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 20px;
  padding-left: v-bind(formLabelWidth);

  :deep(.ant-btn + .ant-btn) {
    margin-inline-start: 0;
  }

  :deep(.dc-action-tip) {
    margin-left: 4px;
    color: rgb(0 0 0 / 45%);
    font-size: 13px;
    line-height: 32px;
  }

  &.is-only {
    margin-top: 0;
    padding-left: 0;
  }
}

.panel-result {
  display: flex;
  flex-direction: column;
  border: 1px solid #f0f0f0;
  border-radius: 6px;
  overflow: hidden;
  background: #fff;

  &.is-fill {
    flex: 1;
    min-height: 0;
  }
}

.panel-result-head {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 12px;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
}

.panel-result-title {
  font-size: 14px;
  font-weight: 500;
  color: rgb(0 0 0 / 85%);
}

.panel-result-extra {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;

  :deep(.ant-btn + .ant-btn) {
    margin-inline-start: 0;
  }

  :deep(.dc-action-tip) {
    color: rgb(0 0 0 / 45%);
    font-size: 13px;
  }
}

.panel-result-body {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: auto;
  padding: 12px;

  &.no-padding {
    padding: 0;

    :deep(.vben-basic-table) {
      height: 100%;
      min-height: 0;
    }

    :deep(.ant-form) {
      max-width: v-bind(formMaxWidth);
      margin-bottom: 8px;
      padding: 12px 12px 0;
    }

    :deep(.ant-form-item-control-input-content) {
      max-width: v-bind(fieldWidth);
    }

    :deep(.ant-input),
    :deep(.ant-input-number),
    :deep(.ant-input-affix-wrapper),
    :deep(.ant-select) {
      width: 100%;
    }
  }

  /* 让 ant-design Table 在 flex 容器中自适应：表头固定、表体滚动、分页始终可见 */
  :deep(.ant-table-wrapper) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-spin-nested-loading) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-spin-container) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-table) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  :deep(.ant-table-container) {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  /* scroll.y 模式下 .ant-table-body 有固定高度，用 flex:1 覆盖使其自适应容器 */
  :deep(.ant-table-body) {
    flex: 1;
    min-height: 0;
    max-height: none !important;
    overflow: auto !important;
  }

  /* 分页控件始终固定在底部，不被表格内容推出可视区域 */
  :deep(.ant-table-pagination) {
    flex-shrink: 0;
    margin: 8px 0 0;
    padding: 0;
  }

  :deep(.ant-table-content + .ant-table-pagination) {
    flex-shrink: 0;
  }
}
</style>

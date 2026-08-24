<template>
  <div v-if="visible" class="gpustack-monitor-tip">
    <Alert type="info" show-icon closable @close="handleClose">
      <template #message>
        <span class="tip-line">
          <span class="tip-text">GPUStack 算力资源监控：</span>
          <a
            :href="consoleUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="tip-link"
          >{{ consoleUrl }}</a>
          <Icon
            icon="tdesign:copy-filled"
            class="copy-icon"
            @click.stop="handleCopy(consoleUrl, '访问地址')"
          />
          <span class="tip-divider">|</span>
          <span class="tip-meta">账号 {{ username }}</span>
          <Icon
            icon="tdesign:copy-filled"
            class="copy-icon"
            @click.stop="handleCopy(username, '账号')"
          />
          <span class="tip-divider">|</span>
          <span class="tip-meta tip-meta-password" :title="password">密码 {{ password }}</span>
          <Icon
            icon="tdesign:copy-filled"
            class="copy-icon"
            @click.stop="handleCopy(password, '密码')"
          />
        </span>
      </template>
    </Alert>
  </div>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue'
import { Alert } from 'ant-design-vue'
import { Icon } from '@/components/Icon'
import { useMessage } from '@/hooks/web/useMessage'
import {
  getGpuStackConsoleUrl,
  GPUSTACK_DEFAULT_PASSWORD,
  GPUSTACK_DEFAULT_USERNAME,
  isGpuStackMonitorTipDismissed,
  setGpuStackMonitorTipDismissed,
} from '@/utils/gpustack'

defineOptions({ name: 'GpuStackMonitorTip' })

const { createMessage } = useMessage()
const visible = ref(!isGpuStackMonitorTipDismissed())
const consoleUrl = computed(() => getGpuStackConsoleUrl())
const username = GPUSTACK_DEFAULT_USERNAME
const password = GPUSTACK_DEFAULT_PASSWORD

function handleClose() {
  setGpuStackMonitorTipDismissed()
  visible.value = false
}

async function handleCopy(text: string, label: string) {
  if (!text) {
    return
  }
  try {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(text)
    } else {
      const textarea = document.createElement('textarea')
      textarea.value = text
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand('copy')
      document.body.removeChild(textarea)
    }
    createMessage.success(`${label}已复制`)
  } catch {
    createMessage.error('复制失败，请手动复制')
  }
}
</script>

<style lang="less" scoped>
.gpustack-monitor-tip {
  margin: 12px 25px 12px;

  :deep(.ant-alert) {
    padding: 6px 12px;
  }

  :deep(.ant-alert-message) {
    margin: 0;
  }

  .tip-line {
    display: inline-flex;
    flex-wrap: nowrap;
    align-items: center;
    gap: 6px;
    max-width: 100%;
    line-height: 1.5;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .tip-text {
    flex-shrink: 0;
    color: rgba(0, 0, 0, 0.65);
  }

  .tip-link {
    flex: 0 1 auto;
    max-width: 28%;
    min-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tip-divider {
    flex-shrink: 0;
    color: rgba(0, 0, 0, 0.25);
    user-select: none;
  }

  .tip-meta {
    flex-shrink: 0;
    color: rgba(0, 0, 0, 0.65);
  }

  .tip-meta-password {
    flex-shrink: 1;
    min-width: 0;
    max-width: 220px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .copy-icon {
    flex-shrink: 0;
    cursor: pointer;
    color: #4287fc;
    font-size: 14px;

    &:hover {
      color: #1677ff;
    }
  }
}
</style>

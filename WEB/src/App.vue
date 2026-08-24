<script lang="ts" setup>
import 'dayjs/locale/zh-cn'

import { App, ConfigProvider } from 'ant-design-vue'
import { storeToRefs } from 'pinia'

import { computed } from 'vue'
import { AppProvider } from '@/components/Application'
import { useTitle } from '@/hooks/web/useTitle'
import { usePlatformBranding } from '@/hooks/web/usePlatformBranding'
import { useLocale } from '@/locales/useLocale'
import { useAppStore } from '@/store/modules/app'

// support Multi-language
const { getAntdLocale } = useLocale()
const appStore = useAppStore()
const { themeConfig } = storeToRefs(appStore)

const componentSize = computed(() => appStore.getComponentSize)
// 初始化平台标识（登录背景等）并监听页面标题
usePlatformBranding()
useTitle()
</script>

<template>
  <ConfigProvider :locale="getAntdLocale" :theme="themeConfig" :component-size="componentSize">
    <App class="h-full w-full">
      <AppProvider>
        <RouterView />
      </AppProvider>
    </App>
  </ConfigProvider>
</template>

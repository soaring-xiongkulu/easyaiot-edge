import { unref, watch } from 'vue'
import { useTitle as usePageTitle } from '@vueuse/core'
import { useRouter } from 'vue-router'
import { useI18n } from '@/hooks/web/useI18n'
import { useGlobSetting } from '@/hooks/setting'
import { usePlatformBranding } from '@/hooks/web/usePlatformBranding'
import { useLocaleStore } from '@/store/modules/locale'

import { REDIRECT_NAME } from '@/router/constant'

/**
 * Listening to page changes and dynamically changing site titles
 */
export function useTitle() {
  const { title } = useGlobSetting()
  const { config } = usePlatformBranding()
  const { t } = useI18n()
  const { currentRoute } = useRouter()
  const localeStore = useLocaleStore()

  const pageTitle = usePageTitle()

  watch(
    [() => currentRoute.value.path, () => localeStore.getLocale, () => config.value.platformName],
    () => {
      const route = unref(currentRoute)

      if (route.name === REDIRECT_NAME)
        return

      const siteTitle = config.value.platformName || title
      const tTitle = t(route?.meta?.title)
      pageTitle.value = tTitle ? ` ${tTitle} - ${siteTitle} ` : `${siteTitle}`
    },
    { immediate: true },
  )
}

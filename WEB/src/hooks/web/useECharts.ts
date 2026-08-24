import type { EChartsOption } from 'echarts'
import type { Ref } from 'vue'
import { tryOnUnmounted, useDebounceFn, useTimeoutFn } from '@vueuse/core'
import { computed, nextTick, ref, unref, watch } from 'vue'
import { useEventListener } from '@/hooks/event/useEventListener'
import { useBreakpoint } from '@/hooks/event/useBreakpoint'
import echarts from '@/utils/lib/echarts'
import { useRootSetting } from '@/hooks/setting/useRootSetting'
import { useMenuSetting } from '@/hooks/setting/useMenuSetting'

export function useECharts(elRef: Ref<HTMLDivElement>, theme: 'light' | 'dark' | 'default' = 'default') {
  const { getDarkMode: getSysDarkMode } = useRootSetting()
  const { getCollapsed } = useMenuSetting()

  const getDarkMode = computed(() => {
    return theme === 'default' ? getSysDarkMode.value : theme
  })
  let chartInstance: echarts.ECharts | null = null
  let resizeFn: Fn = resize
  const cacheOptions = ref({}) as Ref<EChartsOption>
  let removeResizeFn: Fn = () => {}

  resizeFn = useDebounceFn(resize, 200)

  const getOptions = computed(() => {
    if (getDarkMode.value !== 'dark')
      return cacheOptions.value

    return {
      backgroundColor: 'transparent',
      ...cacheOptions.value,
    } as EChartsOption
  })

  function isInstanceAlive(instance: echarts.ECharts | null, el?: HTMLDivElement | null) {
    if (!instance)
      return false
    if (typeof instance.isDisposed === 'function' && instance.isDisposed())
      return false
    const dom = typeof instance.getDom === 'function' ? instance.getDom() : null
    if (!dom || !dom.isConnected)
      return false
    if (el && dom !== el)
      return false
    return true
  }

  function disposeInstance() {
    if (!chartInstance)
      return
    try {
      if (!chartInstance.isDisposed?.())
        chartInstance.dispose()
    }
    catch {
      // ignore dispose errors from already-detached nodes
    }
    chartInstance = null
    removeResizeFn()
    removeResizeFn = () => {}
  }

  function initCharts(t = theme) {
    const el = unref(elRef)
    if (!el || !unref(el))
      return

    // Modal destroyOnClose 会重建 DOM；旧实例仍挂着已销毁节点时必须重建
    if (!isInstanceAlive(chartInstance, el))
      disposeInstance()

    if (chartInstance)
      return

    chartInstance = echarts.init(el, t)
    const { removeEvent } = useEventListener({
      el: window,
      name: 'resize',
      listener: resizeFn,
    })
    removeResizeFn = removeEvent
    const { widthRef, screenEnum } = useBreakpoint()
    if (unref(widthRef) <= screenEnum.MD || el.offsetHeight === 0) {
      useTimeoutFn(() => {
        resizeFn()
      }, 30)
    }
  }

  function setOptions(options: EChartsOption, clear = true) {
    cacheOptions.value = options
    return new Promise((resolve) => {
      const trySet = (retry = 0) => {
        const el = unref(elRef)
        if (!el || el.offsetHeight === 0) {
          if (retry < 20) {
            useTimeoutFn(() => trySet(retry + 1), 50)
            return
          }
          resolve(null)
          return
        }

        nextTick(() => {
          if (!isInstanceAlive(chartInstance, el))
            disposeInstance()

          if (!chartInstance)
            initCharts(getDarkMode.value as 'default')

          if (!chartInstance) {
            if (retry < 20) {
              useTimeoutFn(() => trySet(retry + 1), 50)
              return
            }
            resolve(null)
            return
          }

          clear && chartInstance.clear()
          chartInstance.setOption(unref(getOptions))
          chartInstance.resize()
          resolve(null)
        })
      }

      useTimeoutFn(() => trySet(), 30)
    })
  }

  function resize() {
    const el = unref(elRef)
    if (!isInstanceAlive(chartInstance, el))
      return
    chartInstance?.resize({
      animation: {
        duration: 300,
        easing: 'quadraticIn',
      },
    })
  }

  watch(
    () => getDarkMode.value,
    (theme) => {
      if (chartInstance) {
        disposeInstance()
        initCharts(theme as 'default')
        setOptions(cacheOptions.value)
      }
    },
  )

  watch(getCollapsed, (_) => {
    useTimeoutFn(() => {
      resizeFn()
    }, 300)
  })

  tryOnUnmounted(() => {
    disposeInstance()
  })

  function getInstance(): echarts.ECharts | null {
    const el = unref(elRef)
    if (!isInstanceAlive(chartInstance, el))
      disposeInstance()
    if (!chartInstance)
      initCharts(getDarkMode.value as 'default')

    return chartInstance
  }

  return {
    setOptions,
    resize,
    echarts,
    getInstance,
    dispose: disposeInstance,
  }
}

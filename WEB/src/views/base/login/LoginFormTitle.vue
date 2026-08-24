<script lang="ts" setup>
import {computed, unref} from 'vue'
import {LoginStateEnum, useLoginState} from './useLogin'
import {useI18n} from '@/hooks/web/useI18n'
import {usePlatformBranding} from '@/hooks/web/usePlatformBranding'

const {t} = useI18n()
const {config} = usePlatformBranding()

const {getLoginState} = useLoginState()

const getFormTitle = computed(() => {
  const titleObj = {
    [LoginStateEnum.RESET_PASSWORD]: t('sys.login.forgetFormTitle'),
    [LoginStateEnum.LOGIN]: t('sys.login.signInFormTitle'),
    [LoginStateEnum.REGISTER]: t('sys.login.signUpFormTitle'),
    [LoginStateEnum.MOBILE]: t('sys.login.mobileSignInFormTitle'),
    [LoginStateEnum.QR_CODE]: t('sys.login.qrSignInFormTitle'),
  }
  const defaultTitle = titleObj[unref(getLoginState)]
  if (unref(getLoginState) === LoginStateEnum.LOGIN && config.value.loginFormTitle.trim()) {
    return config.value.loginFormTitle
  }
  return defaultTitle
})
</script>

<template>
  <div style="display: flex;justify-content: center;align-items: center;gap: 1rem;">
    <h2 class="enter-x mb-3 text-center text-2xl font-bold xl:text-left xl:text-3xl form-title">
      {{ getFormTitle }}
    </h2>
  </div>
</template>

<style>
  .form-title{
    text-shadow: 0 0 16px #266CFBFF;padding: 1rem 0.58rem;
  }
</style>

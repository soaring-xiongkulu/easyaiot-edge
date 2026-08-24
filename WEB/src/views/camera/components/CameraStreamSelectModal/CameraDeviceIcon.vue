<template>
  <svg
    class="camera-device-icon"
    :class="{ 'is-fill': fill }"
    :width="fill ? undefined : size"
    :height="fill ? undefined : size"
    viewBox="0 0 80 80"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
    preserveAspectRatio="xMidYMid meet"
  >
    <defs>
      <linearGradient :id="`${uid}-dome`" x1="24" y1="14" x2="56" y2="46" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#eef3ff" />
        <stop offset="45%" stop-color="#c7d9fc" />
        <stop offset="100%" stop-color="#93b4fd" />
      </linearGradient>
      <linearGradient :id="`${uid}-dome-shade`" x1="40" y1="12" x2="40" y2="48" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#fff" stop-opacity="0.55" />
        <stop offset="100%" stop-color="#266cfb" stop-opacity="0" />
      </linearGradient>
      <linearGradient :id="`${uid}-base`" x1="22" y1="48" x2="58" y2="56" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#dbeafe" />
        <stop offset="100%" stop-color="#bfdbfe" />
      </linearGradient>
      <radialGradient :id="`${uid}-lens`" cx="38%" cy="36%" r="62%" fx="34%" fy="30%">
        <stop offset="0%" stop-color="#3b5998" />
        <stop offset="55%" stop-color="#1e3a8a" />
        <stop offset="100%" stop-color="#0f172a" />
      </radialGradient>
      <radialGradient :id="`${uid}-lens-glass`" cx="32%" cy="28%" r="45%" fx="28%" fy="24%">
        <stop offset="0%" stop-color="#fff" stop-opacity="0.65" />
        <stop offset="100%" stop-color="#fff" stop-opacity="0" />
      </radialGradient>
      <linearGradient :id="`${uid}-ring`" x1="28" y1="24" x2="52" y2="40" gradientUnits="userSpaceOnUse">
        <stop offset="0%" stop-color="#64748b" />
        <stop offset="50%" stop-color="#334155" />
        <stop offset="100%" stop-color="#64748b" />
      </linearGradient>
      <filter :id="`${uid}-soft-shadow`" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="2" stdDeviation="2.5" flood-color="#266cfb" flood-opacity="0.18" />
      </filter>
    </defs>

    <!-- 壁装支架 -->
    <rect x="37" y="58" width="6" height="10" rx="1.5" fill="#cbd5e1" />
    <rect x="35" y="66" width="10" height="2.5" rx="1.2" fill="#94a3b8" opacity="0.7" />

    <!-- 底座 -->
    <rect x="22" y="52" width="36" height="6" rx="2.5" :fill="`url(#${uid}-base)`" />
    <rect x="24" y="53.5" width="32" height="1.2" rx="0.6" fill="#fff" opacity="0.55" />

    <!-- 半球主体 -->
    <ellipse cx="40" cy="32" rx="22" ry="19" :fill="`url(#${uid}-dome)`" :filter="`url(#${uid}-soft-shadow)`" />
    <ellipse cx="40" cy="28" rx="18" ry="13" :fill="`url(#${uid}-dome-shade)`" />
    <ellipse
      cx="40"
      cy="32"
      rx="22"
      ry="19"
      stroke="#266cfb"
      stroke-width="0.75"
      stroke-opacity="0.22"
    />

    <!-- 装饰缝线 -->
    <path
      d="M22 30 Q40 24 58 30"
      stroke="#266cfb"
      stroke-width="0.6"
      stroke-opacity="0.12"
      fill="none"
    />

    <!-- 镜头金属环 -->
    <circle cx="40" cy="32" r="11.5" :fill="`url(#${uid}-ring)`" />
    <circle cx="40" cy="32" r="10.2" fill="none" stroke="#475569" stroke-width="0.5" opacity="0.5" />

    <!-- 镜头 -->
    <circle cx="40" cy="32" r="9" :fill="`url(#${uid}-lens)`" />
    <circle cx="40" cy="32" r="6.2" fill="#0f172a" opacity="0.55" />
    <circle cx="40" cy="32" r="3.2" fill="#1e293b" />
    <ellipse cx="36.5" cy="28.5" rx="3.2" ry="2.4" :fill="`url(#${uid}-lens-glass)`" />

    <!-- 红外补光灯 -->
    <circle cx="27.5" cy="40" r="1.6" fill="#266cfb" opacity="0.35" />
    <circle cx="27.5" cy="40" r="0.7" fill="#93c5fd" opacity="0.8" />
    <circle cx="52.5" cy="40" r="1.6" fill="#266cfb" opacity="0.35" />
    <circle cx="52.5" cy="40" r="0.7" fill="#93c5fd" opacity="0.8" />
  </svg>
</template>

<script lang="ts" setup>
import { useId } from 'vue';

defineOptions({ name: 'CameraDeviceIcon' });

const uid = useId().replace(/:/g, '');

withDefaults(
  defineProps<{
    size?: number | string;
    /** 撑满父容器 */
    fill?: boolean;
  }>(),
  {
    size: 32,
    fill: false,
  },
);
</script>

<style scoped>
.camera-device-icon {
  display: block;
  flex-shrink: 0;

  &.is-fill {
    width: 100%;
    height: 100%;
  }
}
</style>

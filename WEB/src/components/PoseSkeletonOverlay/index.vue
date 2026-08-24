<template>
  <div ref="wrapRef" class="pose-skeleton-overlay" :style="wrapStyle">
    <slot />
    <canvas
      v-show="ready"
      ref="canvasRef"
      class="pose-skeleton-overlay__canvas"
      :width="canvasW"
      :height="canvasH"
    />
  </div>
</template>

<script lang="ts" setup>
import { nextTick, ref, watch } from 'vue';
import { drawPoseSkeletonOnCanvas, type PosePerson } from '@/utils/poseSkeleton';

const props = withDefaults(
  defineProps<{
    persons?: PosePerson[];
    highlightPersonIndex?: number;
    imageNaturalWidth?: number;
    imageNaturalHeight?: number;
    imageDisplayWidth?: number;
    imageDisplayHeight?: number;
  }>(),
  {
    persons: () => [],
  },
);

const wrapRef = ref<HTMLDivElement | null>(null);
const canvasRef = ref<HTMLCanvasElement | null>(null);
const ready = ref(false);
const canvasW = ref(0);
const canvasH = ref(0);

const wrapStyle = ref<Record<string, string>>({});

function redraw() {
  const canvas = canvasRef.value;
  if (!canvas || !props.persons?.length) {
    ready.value = false;
    return;
  }
  const nw = props.imageNaturalWidth || 0;
  const nh = props.imageNaturalHeight || 0;
  const dw = props.imageDisplayWidth || nw;
  const dh = props.imageDisplayHeight || nh;
  if (!nw || !nh || !dw || !dh) {
    ready.value = false;
    return;
  }

  const scaleX = dw / nw;
  const scaleY = dh / nh;
  canvasW.value = Math.round(dw);
  canvasH.value = Math.round(dh);
  ready.value = true;

  nextTick(() => {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, canvasW.value, canvasH.value);
    ctx.save();
    ctx.scale(scaleX, scaleY);
    drawPoseSkeletonOnCanvas(ctx, props.persons, {
      highlightPersonIndex: props.highlightPersonIndex,
    });
    ctx.restore();
  });
}

watch(
  () => [
    props.persons,
    props.highlightPersonIndex,
    props.imageNaturalWidth,
    props.imageNaturalHeight,
    props.imageDisplayWidth,
    props.imageDisplayHeight,
  ],
  () => redraw(),
  { deep: true },
);

defineExpose({ redraw });
</script>

<style scoped lang="less">
.pose-skeleton-overlay {
  position: relative;
  display: inline-block;
  width: 100%;
  height: 100%;
}
.pose-skeleton-overlay__canvas {
  position: absolute;
  left: 0;
  top: 0;
  pointer-events: none;
  width: 100%;
  height: 100%;
}
</style>

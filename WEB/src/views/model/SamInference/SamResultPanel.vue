<template>
  <div v-if="loading" class="video-placeholder">
    <SearchOutlined class="icon" />
    <span>推理中...</span>
  </div>
  <div v-else-if="resultImageUrl" class="detection-result">
    <img :src="resultImageUrl" alt="检测结果" class="preview-image" />
    <div class="detection-overlay">
      <div class="detection-info">
        <div class="detection-count">检测数量: {{ detectionCount }}</div>
        <div class="confidence">平均置信度: {{ averageConfidence }}%</div>
      </div>
    </div>
  </div>
  <div v-else class="video-placeholder">
    <ExperimentOutlined class="icon" />
    <span>检测结果将显示在这里</span>
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { ExperimentOutlined, SearchOutlined } from '@ant-design/icons-vue';
import type { SamPredictResult } from '@/api/device/sam';

const props = defineProps<{
  loading: boolean;
  result: SamPredictResult | null;
}>();

const resultImageUrl = computed(() => {
  const b64 = props.result?.result_image_base64;
  return b64 ? `data:image/jpeg;base64,${b64}` : '';
});

const detectionCount = computed(() => props.result?.predictions?.length ?? 0);

const averageConfidence = computed(() => {
  const preds = props.result?.predictions;
  if (!preds?.length) return 0;
  const sum = preds.reduce((acc, p) => acc + (p.confidence || 0), 0);
  return Math.round((sum / preds.length) * 1000) / 10;
});
</script>

<style lang="less" scoped>
@text-secondary: #6C757D;
@gray-color: #ADB5BD;
@light-text: #212529;
@shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);

.video-placeholder {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 20px;
  color: @text-secondary;
  width: 100%;
  min-height: 200px;

  .icon {
    font-size: 64px;
    color: @gray-color;
    opacity: 0.5;
  }

  span {
    font-size: 16px;
    color: @text-secondary;
    font-weight: 500;
  }
}

.detection-result {
  width: 100%;
  height: 100%;
  max-width: 100%;
  max-height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  overflow: hidden;
  box-sizing: border-box;
  flex-shrink: 0;

  .preview-image {
    max-width: 100%;
    max-height: 100%;
    width: auto;
    height: auto;
    object-fit: contain;
    display: block;
    box-sizing: border-box;
  }

  .detection-overlay {
    position: absolute;
    top: 16px;
    right: 16px;
    background: rgba(44, 62, 80, 0.9);
    color: #fff;
    padding: 12px 18px;
    border-radius: 6px;
    font-size: 14px;
    font-weight: bold;
    backdrop-filter: blur(10px);
    box-shadow: @shadow-lg;
    border: 1px solid rgba(255, 255, 255, 0.1);
    pointer-events: none;
    z-index: 1;

    .detection-info {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
  }
}
</style>

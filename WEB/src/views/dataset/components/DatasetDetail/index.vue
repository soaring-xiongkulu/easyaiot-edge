<template>
  <div class="dataset-detail-page">
    <AnnotationTool module="DATASET"/>
  </div>
</template>
<script setup lang="ts">
import AnnotationTool from '@/views/dataset/components/AnnotationTool/index.vue';

defineOptions({name: 'DatasetDetail'});
</script>
<style lang="less" scoped>
.dataset-detail-page {
  height: calc(100vh - 96px);
  min-height: 560px;
  padding: 0 12px 12px;
  box-sizing: border-box;

  :deep(.annotation-container) {
    height: 100%;
    max-height: none;
    border-radius: 8px;
    overflow: hidden;
  }
}
</style>

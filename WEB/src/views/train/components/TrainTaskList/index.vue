<template>
  <div class="train-container bg-white p-6 rounded-xl shadow-lg transition-all duration-300">
    <a-alert
      type="info"
      show-icon
      message="边缘端已移除模型训练"
      description="不再提供训练任务、训练日志与发布训练结果等接口。"
    />
  </div>
</template>

<script lang="ts" setup name="TrainTaskList">
defineProps({
  modelId: [String, Number],
});
</script>

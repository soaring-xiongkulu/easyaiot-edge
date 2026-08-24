<template>
  <SpaceDirectoryManage
    ref="spaceManageRef"
    space-kind="snap"
    title="抓拍空间"
    detail-path-prefix="/snap-space-manage"
    :embedded="embedded"
    :active="active"
  />
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import SpaceDirectoryManage from '../SpaceDirectoryManage/index.vue';

defineOptions({ name: 'SnapSpace' });

defineProps<{
  embedded?: boolean;
  active?: boolean;
}>();

const spaceManageRef = ref<InstanceType<typeof SpaceDirectoryManage> | null>(null);

defineExpose({
  refresh: () => spaceManageRef.value?.refresh(),
});
</script>

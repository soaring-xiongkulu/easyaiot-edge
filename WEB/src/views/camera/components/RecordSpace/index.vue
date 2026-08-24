<template>
  <SpaceDirectoryManage
    ref="spaceManageRef"
    space-kind="record"
    title="录像空间"
    detail-path-prefix="/record-space-manage"
    :embedded="embedded"
    :active="active"
  />
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import SpaceDirectoryManage from '../SpaceDirectoryManage/index.vue';

defineOptions({ name: 'RecordSpace' });

defineProps<{
  embedded?: boolean;
  active?: boolean;
}>();

const spaceManageRef = ref<InstanceType<typeof SpaceDirectoryManage> | null>(null);

defineExpose({
  refresh: () => spaceManageRef.value?.refresh(),
});
</script>

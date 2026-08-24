<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="抓拍图片管理"
    :width="1500"
    :showOkBtn="false"
    :showCancelBtn="false"
    :maskClosable="true"
  >
    <SnapSpaceImageGallery ref="galleryRef" :space-id="modalSpaceId" />
  </BasicModal>
</template>

<script lang="ts" setup>
import { ref } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import SnapSpaceImageGallery from './SnapSpaceImageGallery.vue';

defineOptions({ name: 'SnapImageModal' });

defineEmits(['register']);

const galleryRef = ref<InstanceType<typeof SnapSpaceImageGallery> | null>(null);
const modalSpaceId = ref<number | null>(null);

const [register] = useModalInner(async (data) => {
  modalSpaceId.value = data?.space_id ?? null;
  await galleryRef.value?.refresh();
});
</script>

<style lang="less" scoped>
:deep(.snap-image-gallery) {
  height: 70vh;
  max-height: 700px;
  min-height: 550px;
}
</style>

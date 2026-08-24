<template>
  <BasicModal
    v-bind="$attrs"
    @register="register"
    title="告警图片"
    :footer="null"
    :maskClosable="true"
    @cancel="handleCancel"
  >
    <div class="monitor-dialog monitor-dialog--vod">
      <div v-if="poseMatchSummary" class="pose-intent-banner">
        <a-tag color="volcano">姿态意图</a-tag>
        <span>{{ poseMatchSummary }}</span>
      </div>
      <div class="monitor-dialog__vod-viewer">
        <div class="monitor-dialog__video-body">
          <div v-if="loading" class="monitor-dialog__loading">
            <Spin size="large" />
            <span>加载中...</span>
          </div>
          <PoseSkeletonOverlay
            v-else-if="imageUrl"
            :persons="posePersons"
            :highlight-person-index="highlightPersonIndex"
            :image-natural-width="imgNatural.w"
            :image-natural-height="imgNatural.h"
            :image-display-width="imgDisplay.w"
            :image-display-height="imgDisplay.h"
          >
            <img
              ref="imgRef"
              :src="imageUrl"
              alt="告警图片"
              class="monitor-dialog__alert-image"
              @error="handleImageError"
              @load="handleImageLoad"
            />
          </PoseSkeletonOverlay>
          <div v-else class="monitor-dialog__loading">
            <Icon icon="ant-design:picture-outlined" :size="48" />
            <span>图片加载失败</span>
          </div>
        </div>
      </div>
      <div v-if="showSkeletonToggle" class="pose-skeleton-toolbar">
        <a-switch v-model:checked="showSkeleton" size="small" />
        <span>叠加骨架</span>
      </div>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { BasicModal, useModalInner } from '@/components/Modal';
import { Spin } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { resolveAlertImageDisplayUrl } from '@/utils/alertMinioImage';
import PoseSkeletonOverlay from '@/components/PoseSkeletonOverlay/index.vue';
import {
  isPoseIntentAlertEvent,
  parseAlertPoseInfo,
  type PosePerson,
} from '@/utils/poseSkeleton';
import { formatPoseIntentAlertSummary } from '@/views/alert/alertDisplay';

const { createMessage } = useMessage();
const loading = ref(false);
const imageUrl = ref<string>('');
const imgRef = ref<HTMLImageElement | null>(null);
const imgNatural = ref({ w: 0, h: 0 });
const imgDisplay = ref({ w: 0, h: 0 });
const showSkeleton = ref(true);
const rawPosePersons = ref<PosePerson[]>([]);
const highlightPersonIndex = ref<number | undefined>(undefined);
const poseMatchSummary = ref('');
const alertEvent = ref('');

const posePersons = computed(() => (showSkeleton.value ? rawPosePersons.value : []));
const showSkeletonToggle = computed(() => rawPosePersons.value.length > 0);

function applyModalLayout() {
  setModalProps({
    defaultFullscreen: false,
    canFullscreen: false,
    width: 1000,
    title: '告警图片',
    minHeight: 0,
    bodyStyle: { padding: 0 },
    wrapClassName: 'monitor-dialog-wrap monitor-dialog-wrap--vod',
  });
}

function measureImageDisplay() {
  const img = imgRef.value;
  if (!img) return;
  imgNatural.value = { w: img.naturalWidth, h: img.naturalHeight };
  imgDisplay.value = { w: img.clientWidth, h: img.clientHeight };
}

const [register, { setModalProps, closeModal }] = useModalInner(async (data) => {
  applyModalLayout();
  loading.value = true;
  imageUrl.value = '';
  rawPosePersons.value = [];
  highlightPersonIndex.value = undefined;
  poseMatchSummary.value = '';
  alertEvent.value = data?.event || '';
  showSkeleton.value = true;

  try {
    const url = resolveAlertImageDisplayUrl(data?.image_url);
    if (!url) {
      createMessage.error('图片地址为空');
      return;
    }
    imageUrl.value = url;

    const parsed = parseAlertPoseInfo(data?.information);
    if (parsed?.persons?.length) {
      rawPosePersons.value = parsed.persons;
      const top = parsed.matches?.[0];
      if (top?.person_index != null) {
        highlightPersonIndex.value = top.person_index;
      }
    }
    const summary = formatPoseIntentAlertSummary(data?.information);
    if (summary) {
      poseMatchSummary.value = summary;
    } else if (isPoseIntentAlertEvent(alertEvent.value) && parsed?.matches?.length) {
      const m = parsed.matches[0];
      poseMatchSummary.value = [m.library_name, m.entry_name, m.similarity != null ? `${(m.similarity * 100).toFixed(1)}%` : '']
        .filter(Boolean)
        .join(' · ');
    }
  } catch (error: any) {
    console.error('加载图片失败:', error);
    const errorMsg = error?.response?.data?.message || error?.message || '加载图片失败';
    createMessage.error(errorMsg);
  } finally {
    loading.value = false;
  }
});

watch(showSkeleton, () => {
  setTimeout(measureImageDisplay, 50);
});

const handleImageError = () => {
  createMessage.error('图片加载失败');
  imageUrl.value = '';
};

const handleImageLoad = () => {
  measureImageDisplay();
};

function handleCancel() {
  imageUrl.value = '';
  loading.value = false;
  rawPosePersons.value = [];
  closeModal();
}
</script>

<style lang="less">
.monitor-dialog-wrap--vod {
  .monitor-dialog__video-body {
    .monitor-dialog__alert-image {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
      margin: 0;
      padding: 0;
      background: #000;
    }
  }
}
.pose-intent-banner {
  padding: 8px 12px;
  background: #fff7e6;
  border-bottom: 1px solid #ffd591;
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}
.pose-skeleton-toolbar {
  padding: 8px 12px;
  display: flex;
  align-items: center;
  gap: 8px;
  background: #fafafa;
  border-top: 1px solid #f0f0f0;
}
</style>

<template>
  <div class="product-info nvr-card-info">
    <div class="status online">NVR</div>
    <div class="title o2">{{ item.name }}</div>
    <div class="props">
      <div class="prop">
        <div class="label">IP / 端口</div>
        <div
          class="value copyable-value"
          style="cursor: pointer"
          :title="copyTarget"
          @click="handleCopy"
        >
          <span>{{ item.ip }}:{{ item.port }}</span>
          <Icon icon="tdesign:copy-filled" :size="14" color="#4287FCFF" class="copy-icon" />
        </div>
      </div>
      <div class="flex" style="justify-content: space-between">
        <div class="prop">
          <div class="label">品牌</div>
          <div class="value">{{ item.vendor_label || '-' }}</div>
        </div>
        <div class="prop">
          <div class="label">挂载摄像头</div>
          <div class="value">{{ item.camera_count }} 路</div>
        </div>
      </div>
    </div>
    <div class="btns" @click.stop>
      <div class="btn" title="挂载摄像头" @click="emit('open', item)">
        <Icon icon="ant-design:cluster-outlined" :size="16" color="#3B82F6" />
      </div>
      <div class="btn" title="详情" @click="emit('view', item)">
        <Icon icon="ant-design:eye-filled" :size="15" color="#3B82F6" />
      </div>
      <div class="btn" title="编辑" @click="emit('edit', item)">
        <Icon icon="ant-design:edit-filled" :size="15" color="#3B82F6" />
      </div>
      <Popconfirm
        title="删除后挂载摄像头将解除关联，是否确认？"
        ok-text="是"
        cancel-text="否"
        @confirm="emit('delete', item)"
      >
        <div class="btn">
          <Icon icon="material-symbols:delete-outline-rounded" :size="15" color="#DC2626" />
        </div>
      </Popconfirm>
    </div>
  </div>
  <div class="product-img nvr-card-img">
    <img :src="deviceImage" alt="" class="img" @click="emit('view', item)" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Popconfirm } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { copyText } from '@/utils/copyTextToClipboard';
import HAIKANG_IMAGE from '@/assets/images/video/haikang.png';
import DAHUA_IMAGE from '@/assets/images/video/dahua.png';
import OTHER_IMAGE from '@/assets/images/video/other.png';
import type { NvrCardItem } from '@/views/camera/utils/nvrDeviceGroup';

const props = defineProps<{ item: NvrCardItem }>();
const emit = defineEmits<{
  open: [item: NvrCardItem];
  view: [item: NvrCardItem];
  edit: [item: NvrCardItem];
  delete: [item: NvrCardItem];
}>();

const { createMessage } = useMessage();

const copyTarget = computed(() => `${props.item.ip}:${props.item.port}`);

const deviceImage = computed(() => {
  const v = (props.item.vendor_label || '').toLowerCase();
  if (v.includes('海康') || v.includes('hik')) return HAIKANG_IMAGE;
  if (v.includes('大华') || v.includes('dahua')) return DAHUA_IMAGE;
  return OTHER_IMAGE;
});

function handleCopy() {
  copyText(copyTarget.value, '已复制');
  createMessage.success('复制成功');
}
</script>

<style lang="less" scoped>
.nvr-card-info .copyable-value {
  display: flex;
  align-items: center;
  gap: 4px;

  .copy-icon {
    flex-shrink: 0;
  }
}

.nvr-card-img .img {
  cursor: pointer;
}
</style>

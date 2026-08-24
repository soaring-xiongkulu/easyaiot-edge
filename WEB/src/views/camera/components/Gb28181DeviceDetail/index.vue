<template>
  <div class="gb-device-detail">
    <PageHeader
      class="gb-detail-header"
      :title="title || sipDeviceId"
      :sub-title="`国标设备 · ${channelHint}`"
      @back="emit('back')"
    />
    <div class="gb-detail-body">
      <Channel
        :device-identification="sipDeviceId"
        embedded
        enable-location
        @set-location="(record) => emit('setLocation', record)"
      />
    </div>
  </div>
</template>

<script lang="ts" setup>
import { PageHeader } from 'ant-design-vue';
import Channel from '@/views/gb28181/components/Channel/index.vue';

defineProps<{
  sipDeviceId: string;
  title?: string;
  channelHint?: string;
}>();

const emit = defineEmits<{
  back: [];
  setLocation: [record: { id: string; name?: string }];
}>();
</script>

<style lang="less" scoped>
.gb-device-detail {
  display: flex;
  flex-direction: column;
  min-height: 520px;
  background: #f5f5f5;

  .gb-detail-header {
    background: #fff;
    margin-bottom: 12px;
    padding: 8px 16px;
  }

  .gb-detail-body {
    flex: 1;
    background: #fff;
    border-radius: 8px;
    overflow: hidden;
  }
}
</style>

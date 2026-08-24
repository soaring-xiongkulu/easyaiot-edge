<template>
  <BasicModal
    v-model:open="visible"
    :title="title"
    width="1580px"
    :min-height="560"
    centered
    ok-text="开始播放"
    cancel-text="取消"
    :ok-button-props="{ disabled: selectedIndex < 0 }"
    wrap-class-name="camera-stream-select-modal"
    @ok="handleConfirm"
    @cancel="handleCancel"
  >
    <div class="camera-stream-select">
      <div v-if="taskName" class="select-header">
        <Icon icon="ant-design:deployment-unit-outlined" :size="15" color="#266CFB" />
        <div class="header-content">
          <span class="header-label">当前算法任务</span>
          <span class="header-name">{{ taskName }}</span>
        </div>
        <span class="header-count">{{ streams.length }} 路</span>
      </div>

      <div v-if="streams.length > 8" class="select-toolbar">
        <Input
          v-model:value="searchKeyword"
          allow-clear
          placeholder="搜索摄像头名称或 ID"
        >
          <template #prefix>
            <Icon icon="ant-design:search-outlined" :size="13" color="#b0b8c4" />
          </template>
        </Input>
      </div>

      <div v-if="filteredStreams.length === 0" class="select-empty">
        <Empty :description="searchKeyword ? '未找到匹配的摄像头' : '暂无可用推流地址'" />
      </div>

      <div v-else class="camera-grid">
        <div
          v-for="item in filteredStreams"
          :key="item.stream.device_id"
          class="camera-card"
          :class="{ selected: selectedIndex === item.index }"
          @click="selectedIndex = item.index"
          @dblclick="handleCardDblClick(item.index)"
        >
          <div class="card-cover">
            <img
              v-if="item.stream.cover_image_path"
              :src="item.stream.cover_image_path"
              :alt="item.stream.device_name"
              class="cover-img"
            />
            <div v-else class="cover-placeholder">
              <div class="cover-icon-wrap">
                <CameraDeviceIcon fill class="cover-camera-icon" />
              </div>
            </div>

            <span class="stream-badge" :class="isAiStream(item.stream) ? 'ai' : 'raw'">
              {{ isAiStream(item.stream) ? 'AI' : '原始' }}
            </span>
            <div v-if="selectedIndex === item.index" class="selected-mark">
              <Icon icon="ant-design:check-outlined" :size="10" color="#fff" />
            </div>
            <div class="cover-hover-play">
              <Icon icon="ant-design:play-circle-outlined" :size="18" color="#fff" />
            </div>
          </div>

          <div class="card-body">
            <div class="device-name" :title="item.stream.device_name">{{ item.stream.device_name }}</div>
            <div class="device-id" :title="item.stream.device_id">{{ item.stream.device_id }}</div>
          </div>
        </div>
      </div>

      <div v-if="selectedStream" class="select-footer-hint">
        <Icon icon="ant-design:info-circle-outlined" :size="13" color="#266CFB" />
        <span>已选 <strong>{{ selectedStream.device_name }}</strong> · 双击卡片可快速播放</span>
      </div>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from 'vue';
import { Empty, Input } from 'ant-design-vue';
import { BasicModal } from '@/components/Modal';
import { Icon } from '@/components/Icon';
import CameraDeviceIcon from './CameraDeviceIcon.vue';
import type { CameraStreamInfo } from '@/api/device/algorithm_task';

defineOptions({ name: 'CameraStreamSelectModal' });

const props = withDefaults(
  defineProps<{
    open?: boolean;
    streams?: CameraStreamInfo[];
    taskName?: string;
    title?: string;
  }>(),
  {
    open: false,
    streams: () => [],
    taskName: '',
    title: '选择播放摄像头',
  },
);

const emit = defineEmits<{
  'update:open': [value: boolean];
  confirm: [stream: CameraStreamInfo];
}>();

const visible = computed({
  get: () => props.open,
  set: (value: boolean) => emit('update:open', value),
});

const searchKeyword = ref('');
const selectedIndex = ref(0);

const filteredStreams = computed(() => {
  const keyword = searchKeyword.value.trim().toLowerCase();
  return props.streams
    .map((stream, index) => ({ stream, index }))
    .filter(({ stream }) => {
      if (!keyword) return true;
      return (
        stream.device_name?.toLowerCase().includes(keyword) ||
        stream.device_id?.toLowerCase().includes(keyword)
      );
    });
});

const selectedStream = computed(() => {
  if (selectedIndex.value < 0 || selectedIndex.value >= props.streams.length) {
    return null;
  }
  return props.streams[selectedIndex.value];
});

function isAiStream(stream: CameraStreamInfo) {
  return !!(stream.ai_http_stream || stream.ai_rtmp_stream);
}

function handleConfirm() {
  if (selectedStream.value) {
    emit('confirm', selectedStream.value);
    visible.value = false;
  }
}

function handleCancel() {
  visible.value = false;
}

function handleCardDblClick(index: number) {
  selectedIndex.value = index;
  handleConfirm();
}

watch(
  () => props.open,
  (open) => {
    if (open) {
      searchKeyword.value = '';
      selectedIndex.value = props.streams.length > 0 ? 0 : -1;
    }
  },
);

watch(
  () => props.streams,
  (streams) => {
    if (streams.length === 0) {
      selectedIndex.value = -1;
    } else if (selectedIndex.value < 0 || selectedIndex.value >= streams.length) {
      selectedIndex.value = 0;
    }
  },
);
</script>

<style lang="less" scoped>
@primary: #266cfb;
@primary-light: #eff4ff;
@primary-border: #d6e4ff;
@neutral-bg: #f5f7fa;
@neutral-border: #e8ecf2;
@text-primary: #1f2937;
@text-secondary: #8b95a5;
@text-muted: #b0b8c4;

.camera-stream-select {
  .select-header {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 18px;
    margin-bottom: 16px;
    background: @neutral-bg;
    border: 1px solid @neutral-border;
    border-radius: 8px;

    .header-content {
      flex: 1;
      min-width: 0;
      display: flex;
      align-items: baseline;
      gap: 8px;

      .header-label {
        font-size: 12px;
        color: @text-secondary;
        flex-shrink: 0;
      }

      .header-name {
        font-size: 15px;
        font-weight: 600;
        color: @text-primary;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
    }

    .header-count {
      flex-shrink: 0;
      font-size: 12px;
      color: @primary;
      background: @primary-light;
      border: 1px solid @primary-border;
      padding: 1px 8px;
      border-radius: 10px;
      line-height: 18px;
    }
  }

  .select-toolbar {
    margin-bottom: 14px;
  }

  .select-empty {
    padding: 48px 0;
    text-align: center;
  }

  .camera-grid {
    display: grid;
    grid-template-columns: repeat(8, 1fr);
    gap: 10px;
    max-height: 560px;
    overflow-y: auto;
    padding: 2px;
  }

  .camera-card {
    border: 1px solid @neutral-border;
    border-radius: 8px;
    overflow: hidden;
    cursor: pointer;
    background: #fff;
    transition: border-color 0.18s, box-shadow 0.18s;

    &:hover {
      border-color: @primary-border;
      box-shadow: 0 2px 8px rgba(38, 108, 251, 0.08);

      .cover-hover-play {
        opacity: 1;
      }
    }

    &.selected {
      border-color: @primary;
      box-shadow: 0 0 0 1px @primary;

      .card-body .device-name {
        color: @primary;
      }
    }

    .card-cover {
      position: relative;
      aspect-ratio: 16 / 9;
      overflow: hidden;
      background: @neutral-bg;

      .cover-img {
        width: 100%;
        height: 100%;
        object-fit: cover;
        display: block;
      }

      .cover-placeholder {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        background:
          linear-gradient(rgba(38, 108, 251, 0.04) 1px, transparent 1px),
          linear-gradient(90deg, rgba(38, 108, 251, 0.04) 1px, transparent 1px),
          linear-gradient(180deg, #f8faff 0%, @neutral-bg 100%);
        background-size: 14px 14px, 14px 14px, 100% 100%;

        .cover-icon-wrap {
          width: 90%;
          height: 90%;
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 2px;
        }

        .cover-camera-icon {
          opacity: 1;
        }
      }

      .stream-badge {
        position: absolute;
        top: 4px;
        left: 4px;
        padding: 0 5px;
        border-radius: 3px;
        font-size: 9px;
        font-weight: 500;
        line-height: 16px;
        z-index: 2;
        letter-spacing: 0.2px;

        &.ai {
          background: @primary-light;
          color: @primary;
          border: 1px solid @primary-border;
        }

        &.raw {
          background: #fff;
          color: @text-secondary;
          border: 1px solid @neutral-border;
        }
      }

      .selected-mark {
        position: absolute;
        top: 4px;
        right: 4px;
        z-index: 2;
        width: 16px;
        height: 16px;
        border-radius: 50%;
        background: @primary;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .cover-hover-play {
        position: absolute;
        inset: 0;
        z-index: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(31, 41, 55, 0.18);
        opacity: 0;
        transition: opacity 0.18s;
      }
    }

    .card-body {
      padding: 6px 8px 8px;
      border-top: 1px solid @neutral-border;

      .device-name {
        font-size: 12px;
        font-weight: 500;
        color: @text-primary;
        line-height: 16px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        transition: color 0.18s;
      }

      .device-id {
        margin-top: 1px;
        font-size: 10px;
        color: @text-muted;
        line-height: 14px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
    }
  }

  .select-footer-hint {
    display: flex;
    align-items: center;
    gap: 5px;
    margin-top: 12px;
    padding: 8px 12px;
    background: @primary-light;
    border: 1px solid @primary-border;
    border-radius: 6px;
    font-size: 12px;
    color: @text-secondary;

    strong {
      color: @primary;
      font-weight: 500;
    }
  }
}
</style>

<style lang="less">
.camera-stream-select-modal {
  .ant-modal {
    max-width: 96vw;
  }

  .ant-modal-body {
    padding: 16px 20px 12px;
  }

  .ant-modal-header {
    padding: 16px 20px;
  }

  .ant-modal-footer {
    padding: 12px 20px 16px;
  }
}
</style>

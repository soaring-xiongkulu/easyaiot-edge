<template>
  <div class="source-panel">
    <div class="source-intro">
      <Icon icon="ant-design:cloud-server-outlined"/>
      <div>
        <p class="intro-title">数据来源</p>
        <p class="intro-desc">除「添加」菜单导入外，可通过视频抽帧、无人值守自动打标或视频库持续向本数据集补充图片。</p>
      </div>
    </div>

    <Collapse v-model:activeKey="activeKeys" :bordered="false" class="source-collapse">
      <CollapsePanel key="frame">
        <template #header>
          <span class="panel-header-inner">
            <Icon icon="ant-design:video-camera-outlined"/>
            视频流抽帧
            <span class="panel-badge">RTMP / GB28181</span>
          </span>
        </template>
        <p class="panel-tip">创建任务后，系统按间隔从实时流抓取帧并写入当前数据集，适合监控场景持续采标。</p>
        <DatasetFrameTask @changed="emit('frame-tasks-changed')"/>
      </CollapsePanel>

      <CollapsePanel key="unattended">
        <template #header>
          <span class="panel-header-inner">
            <Icon icon="ant-design:cluster-outlined"/>
            无人值守扩充
            <span class="panel-badge">自动打标</span>
          </span>
        </template>
        <p class="panel-tip">
          在已配置的抽帧任务上，选择检测模型与摄像头，由系统在后台持续抽帧并自动标注，扩充本数据集，无需人工逐张打标。
        </p>
        <Button type="primary" @click="emit('open-unattended')">
          <template #icon>
            <Icon icon="ant-design:play-circle-outlined"/>
          </template>
          配置无人值守扩充
        </Button>
      </CollapsePanel>

      <CollapsePanel key="video">
        <template #header>
          <span class="panel-header-inner">
            <Icon icon="ant-design:play-square-outlined"/>
            视频库
            <span class="panel-badge">上传 · 抽帧</span>
          </span>
        </template>
        <p class="panel-tip">上传本地视频文件，可对单个视频执行抽帧，将帧图片加入数据集。</p>
        <DatasetVideo/>
      </CollapsePanel>
    </Collapse>
  </div>
</template>

<script setup lang="ts">
import {ref} from 'vue';
import {Collapse, CollapsePanel} from 'ant-design-vue';
import {Button} from '@/components/Button';
import {Icon} from '@/components/Icon';
import DatasetFrameTask from '@/views/dataset/components/DatasetFrameTask/index.vue';
import DatasetVideo from '@/views/dataset/components/DatasetVideo/index.vue';

defineOptions({name: 'DatasetSourcePanel'});

const emit = defineEmits<{
  'open-unattended': [];
  'frame-tasks-changed': [];
}>();

const activeKeys = ref(['frame', 'unattended']);
</script>

<style lang="less" scoped>
.source-panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.source-intro {
  display: flex;
  gap: 12px;
  padding: 12px 14px;
  background: #f6ffed;
  border: 1px solid #d9f7be;
  border-radius: 8px;
  font-size: 20px;
  color: #52c41a;

  .intro-title {
    margin: 0 0 4px;
    font-size: 14px;
    font-weight: 600;
    color: #262626;
  }

  .intro-desc {
    margin: 0;
    font-size: 12px;
    color: #8c8c8c;
    line-height: 1.5;
  }
}

.source-collapse {
  :deep(.ant-collapse-item) {
    border: 1px solid #f0f0f0 !important;
    border-radius: 8px !important;
    margin-bottom: 10px;
    overflow: hidden;
  }

  :deep(.ant-collapse-header) {
    font-weight: 500;
    background: #fafafa !important;
  }

  :deep(.ant-collapse-content-box) {
    padding: 12px !important;
  }
}

.panel-header-inner {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.panel-badge {
  font-size: 11px;
  font-weight: normal;
  color: #8c8c8c;
  padding: 0 6px;
  background: #f0f0f0;
  border-radius: 4px;
}

.panel-tip {
  margin: 0 0 12px;
  font-size: 12px;
  color: #8c8c8c;
  line-height: 1.5;
}
</style>

<template>
  <div class="phsyical-modal-title">
    <div class="title-content">
      <div class="product-phsyical-model-tab">
        <Tabs
          :activeKey="state.activeKey"
          :tabBarGutter="40"
          @tabClick="handleTabClick"
        >
          <TabPane key="properties" tab="属性"></TabPane>
          <TabPane key="services" tab="服务"></TabPane>
          <TabPane key="events" tab="事件"></TabPane>
        </Tabs>
      </div>
      
      <Alert type="info" show-icon class="info-alert">
        <template #message>
          <div v-show="!props.isEdit" class="alert-content">
            当前展示的是已发布到线上的{{ getTypeName(state.activeKey) }}定义，如需修改，请点击
            <Button size="small" type="link" class="edit-link-btn" @click="handleClickEdit(true)">"编辑物模型"</Button>
          </div>
          <div v-show="props.isEdit" class="alert-content">
            您正在编辑的是草稿，需点击发布后，物模型才会正式生效。
          </div>
        </template>
      </Alert>

      <div class="box" v-show="props.isEdit">
        <Space>
          <Button type="primary" @click="handleAddPhsyical">
            新增物模型
          </Button>
          <Button @click="handleClickEdit(false)">返回</Button>
        </Space>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup name="PhysicalModalTitle">
import { Alert, Space, TabPane, Tabs } from 'ant-design-vue';
import {reactive, withDefaults} from 'vue';
import { Button } from '@/components/Button'
// import { RedoOutlined } from '@ant-design/icons-vue';

  interface Props {
    isEdit: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    isEdit: false,
  });

  const emit = defineEmits(['showTsl', 'addPhsyical', 'update:isEdit', 'reload', 'release', 'update:functionType']);

  const state = reactive({
    activeKey: 'properties'
  });

  // 根据当前类型获取提示文字
  const getTypeName = (type: string) => {
    const typeMap = {
      properties: '属性',
      services: '服务',
      events: '事件'
    };
    return typeMap[type] || '属性';
  };

  const handleTabClick = (activeKey) => {
    state.activeKey = activeKey;
    emit('update:functionType', activeKey);
  };

  const handleClickEdit = (flag) => {
    emit('update:isEdit', flag);
  };

  // const handleShowTSL = () => {
  //   emit('showTsl');
  // };

  const handleAddPhsyical = () => {
    emit('addPhsyical');
  };

  const handleReload = () => {
    emit('reload');
  };

  const handleRelease = () => {
    emit('release');
  };
</script>

<style lang="less" scoped>
  .phsyical-modal-title {
    width: 100%;
    margin-bottom: 0;
    background-color: #fff;
    flex-shrink: 0;

    .title-content {
      display: flex;
      flex-direction: column;
      gap: 0;
    }

    .product-phsyical-model-tab {
      :deep(.ant-tabs) {
        margin-bottom: 0;

        .ant-tabs-nav {
          margin-bottom: 0;
        }

        .ant-tabs-tab {
          font-size: 14px;
          font-weight: 500;
          padding: 12px 8px;
          color: #666;

          &:hover {
            color: #1890ff;
          }
        }

        .ant-tabs-tab-active .ant-tabs-tab-btn {
          color: #1890ff;
          font-weight: 600;
        }

        .ant-tabs-ink-bar {
          height: 3px;
          border-radius: 2px;
        }

        .ant-tabs-content-holder {
          display: none;
        }
      }
    }

    .info-alert {
      margin: 12px 0 0;
      border-radius: 6px;
      font-size: 13px;
      line-height: 1.5;
      padding: 8px 12px;

      :deep(.ant-alert-icon) {
        margin-right: 8px;
        font-size: 14px;
      }

      :deep(.ant-alert-message) {
        margin-bottom: 0;
        padding: 0;
      }

      :deep(.ant-alert-content) {
        padding: 0;
      }

      .alert-content {
        display: inline;
        font-size: 13px;
        color: #666;

        .edit-link-btn {
          padding: 0;
          height: auto;
          font-size: 13px;
          vertical-align: baseline;
        }
      }
    }

    .box {
      display: flex;
      justify-content: flex-start;
      margin-top: 12px;
    }
  }
</style>

<template>
  <div class="device-drawer-wrapper">
    <Card class="device-tabs-card">
      <Tabs
        v-model:activeKey="activeKey"
        :animated="{ inkBar: true, tabPane: false }"
        :tabBarGutter="40"
        @tabClick="handleTabClick"
      >
        <TabPane key="SubDevice" tab="设备总览">
          <SubDevice
            v-if="activeKey === 'SubDevice'"
            :center-device-identification="description.deviceIdentification"
            :center-device-id="route.params.id || description.id"
            :center-device-name="description.deviceName"
            :center-connect-status="description.connectStatus"
          />
        </TabPane>

        <TabPane key="Detail" tab="基础信息">
          <Detail />
        </TabPane>

        <TabPane key="AccessGuide" tab="接入指引">
          <AccessGuide
            v-if="activeKey === 'AccessGuide'"
            scope="device"
            :node-type="description.deviceType"
            :product-identification="description.productIdentification"
            :device-identification="description.deviceIdentification"
            :device-name="description.deviceName"
            :product-name="description.productName"
            :password="description.password"
            :user-name="description.userName"
            :connector="description.connector"
            :parent-identification="description.parentIdentification"
            :protocol-type="description.protocolType"
            :device-numeric-id="String(route.params.id || description.id || '')"
          />
        </TabPane>

        <TabPane key="TingModel" tab="运行状态">
          <TingModel v-if="activeKey === 'TingModel'" />
        </TabPane>

        <TabPane v-if="isIndustrialProtocol" key="Points" tab="点位管理">
          <PointManagement
            v-if="activeKey === 'Points'"
            :device="description"
            @updated="handlePointsUpdated"
          />
        </TabPane>

        <TabPane key="Shadow" :tab="isIndustrialProtocol ? '点位影子' : '设备影子'">
          <Shadow v-if="activeKey === 'Shadow'" :device="description" />
        </TabPane>

        <TabPane v-if="isIndustrialProtocol" key="Operation" tab="寄存器操作">
          <DeviceOperation v-if="activeKey === 'Operation'" :device="description" />
        </TabPane>

        <TabPane v-if="!isIndustrialProtocol" key="Control" tab="功能调用">
          <Control v-if="activeKey === 'Control'" />
        </TabPane>

        <TabPane key="Event" :tab="isIndustrialProtocol ? '采集事件' : '事件日志'">
          <Event v-if="activeKey === 'Event'" :device="description" />
        </TabPane>

        <TabPane key="Service" :tab="isIndustrialProtocol ? '写入日志' : '指令日志'">
          <Service v-if="activeKey === 'Service'" :device="description" />
        </TabPane>

        <TabPane key="DeviceLog" :tab="isIndustrialProtocol ? '通信日志' : '设备日志'">
          <DeviceLog v-if="activeKey === 'DeviceLog'" :device="description" />
        </TabPane>

        <TabPane key="RelatedCameras" tab="关联摄像头">
          <RelatedCameras
            v-if="activeKey === 'RelatedCameras'"
            :iot-device-id="route.params.id"
            :device-name="description.deviceName"
          />
        </TabPane>

        <TabPane key="Topic" tab="Topic管理">
          <Topic v-if="activeKey === 'Topic'" />
        </TabPane>
      </Tabs>
    </Card>
  </div>
</template>
<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { Card, TabPane, Tabs } from 'ant-design-vue';
import TingModel from '../Model/index.vue';
import Detail from './Detail.vue';
import AccessGuide from '../AccessGuide/index.vue';
import Shadow from '../Shadow/index.vue';
import Control from '../Control/index.vue';
import DeviceOperation from '../DeviceOperation/index.vue';
import PointManagement from '../PointManagement/index.vue';
import Event from '../Event/index.vue';
import Service from '../Service/index.vue';
import DeviceLog from '../DeviceLog/index.vue';
import SubDevice from '../SubDevice/index.vue';
import RelatedCameras from '../RelatedCameras/index.vue';
import Topic from '../Topic/index.vue';
import { useRoute } from 'vue-router';
import { getDevicesInfo } from '@/api/device/devices';

defineOptions({ name: 'DeviceDetail' });

const INDUSTRIAL_PROTOCOLS = ['MODBUS_TCP', 'MODBUS_RTU', 'OPCUA'];

const description = reactive({
  id: '',
  clientId: '',
  appId: '',
  deviceIdentification: '',
  deviceName: '',
  deviceDescription: '',
  deviceStatus: '',
  connectStatus: '',
  isWill: '',
  productIdentification: '',
  createBy: '',
  createTime: '',
  updateBy: '',
  updateTime: '',
  remark: '',
  deviceVersion: '',
  deviceSn: '',
  ipAddress: '',
  macAddress: '',
  activeStatus: '',
  extension: '',
  activatedTime: '',
  lastOnlineTime: '',
  productName: '',
  manufacturerName: '',
  deviceType: '',
  protocolType: '',
  connector: '',
  userName: '',
  password: '',
  parentIdentification: '',
});

const route = useRoute();

const isIndustrialProtocol = computed(() => {
  if (INDUSTRIAL_PROTOCOLS.includes(description.protocolType)) return true;
  try {
    const extension =
      description.extension && description.extension !== '--'
        ? JSON.parse(description.extension)
        : {};
    return INDUSTRIAL_PROTOCOLS.includes(extension.protocolConfig?.type);
  } catch (_) {
    return false;
  }
});

function handlePointsUpdated(extension: string) {
  description.extension = extension;
}

const initDeviceDetail = async (record) => {
  const info = await getDevicesInfo(record?.id);
  Object.keys(description).forEach((item) => {
    description[item] = info.device?.[item] ?? info.product?.[item] ?? '--';
  });
  // 设备类型优先用设备字段，缺省时回落产品类型
  if (!info.device?.deviceType && info.product?.productType) {
    description.deviceType = info.product.productType;
  }
  if (info.device?.parentIdentification) {
    description.parentIdentification = info.device.parentIdentification;
  }
};

onMounted(() => {
  initDeviceDetail(route.params);
});

const activeKey = ref('SubDevice');

const handleTabClick = (key) => {
  activeKey.value = key;
};
</script>
<style lang="less">
@import '../styles/device-ops.less';
</style>

<style lang="less" scoped>
.device-drawer-wrapper {
  /* 父级是 min-height，height:100% 无法约束；用视口高度锁死，避免整页外滚 */
  height: calc(100vh - 80px);
  max-height: calc(100vh - 80px);
  overflow: hidden;
  background: #ffffff;
  padding: 12px 16px 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;

  .device-tabs-card {
    margin: 0;
    background: #ffffff;
    border-radius: 0;
    box-shadow: none;
    border: none;
    overflow: hidden;
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;

    :deep(.ant-card-body) {
      padding: 0;
      background: #ffffff;
      flex: 1;
      display: flex;
      flex-direction: column;
      min-height: 0;
      height: 100%;
      overflow: hidden;
    }

    :deep(.ant-tabs) {
      background-color: #ffffff;
      padding: 0;
      margin: 0;
      flex: 1;
      display: flex;
      flex-direction: column;
      min-height: 0;
      height: 100%;
      overflow: hidden;
    }

    :deep(.ant-tabs-nav) {
      margin-bottom: 10px;
      padding: 0 4px;
      flex-shrink: 0;
    }

    :deep(.ant-tabs-content-holder) {
      padding: 0;
      background: #ffffff;
      flex: 1;
      min-height: 0;
      overflow: hidden;
    }

    :deep(.ant-tabs-content) {
      height: 100%;
    }

    :deep(.ant-tabs-tabpane) {
      padding: 0;
      height: 100%;
      outline: none;

      > * {
        height: 100%;
        overflow-y: auto;
        background: #ffffff;
      }

      > .assoc-page {
        overflow: hidden;
      }

      > .access-guide {
        overflow: hidden;
      }
    }

    :deep(.ant-tabs-tab) {
      padding: 12px 8px;
      font-size: 14px;
      font-weight: 500;
      color: #666;
      transition: all 0.3s ease;

      &:hover {
        color: #1890ff;
      }
    }

    :deep(.ant-tabs-tab-active) {
      .ant-tabs-tab-btn {
        color: #1890ff;
        font-weight: 600;
      }
    }

    :deep(.ant-tabs-ink-bar) {
      height: 3px;
      border-radius: 2px;
    }
  }
}
</style>

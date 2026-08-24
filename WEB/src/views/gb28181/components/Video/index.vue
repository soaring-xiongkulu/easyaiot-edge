<template>
  <div class="video-wrapper">
    <BasicTable @register="registerTable" v-if="state.isTableMode">
      <template #toolbar>
        <Button type="primary" @click="openAccessInfoModal" preIcon="ant-design:export-outlined">
          导出接入配置
        </Button>
        <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
          切换视图
        </Button>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                icon: 'ant-design:eye-outlined',
                tooltip: {
                  title: '详情',
                  placement: 'top',
                },
                onClick: handleView.bind(null, record),
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>
    <div v-else class="card-list-wrapper">
      <VideoCardList :params="params" :api="queryVideoList" @get-method="getMethod"
                     @edit="handleEdit" @refresh="handleRefresh">
        <template #header>
          <Button type="primary" @click="openAccessInfoModal" preIcon="ant-design:export-outlined">
            导出接入配置
          </Button>
          <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
            切换视图
          </Button>
        </template>
      </VideoCardList>
    </div>
    <AccessInfoModal @register="registerAccessInfoModal" />
  </div>
</template>
<script lang="ts" setup name="noticeSetting">
import { reactive } from 'vue';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { useModal } from '@/components/Modal';
import { useMessage } from '@/hooks/web/useMessage';
import { getBasicColumns, getFormConfig } from './Data';
import VideoCardList from '@/views/gb28181/components/VideoCardList/index.vue';
import AccessInfoModal from './AccessInfoModal.vue';
import { queryVideoList, refreshChannelList, generateDeviceAccessInfo } from '@/api/device/gb28181';
import { Button } from '@/components/Button'
defineOptions({ name: 'Video' });

const state = reactive({
  isTableMode: false,
  activeKey: '1',
  pushActiveKey: '1',
  historyActiveKey: '1',
  SmsActiveKey: '1',
});

const [registerAccessInfoModal, { openModal: openAccessInfoModalInstance }] = useModal();

// 请求api时附带参数
const params = {};

let cardListReload = () => {
};

// 获取内部fetch方法;
function getMethod(m: any) {
  cardListReload = m;
}

//详情按钮事件
function handleView(record) {
  // TODO: 实现设备详情查看功能
  console.log('查看设备详情', record);
}

//编辑按钮事件
function handleEdit(record) {
  // TODO: 实现设备编辑功能
  console.log('编辑设备', record);
}

//刷新通道列表
function handleRefresh(record) {
  try {
    refreshChannelList(record['deviceIdentification']);
    createMessage.success('开始同步');
    setTimeout(() => {
      createMessage.success('通道同步完成');
    }, 2000);
    handleSuccess();
  }catch (error) {
    console.error(error)
    createMessage.success('通道同步失败');
    console.log('handleRefresh', error);
  }
}

// 切换视图
function handleClickSwap() {
  state.isTableMode = !state.isTableMode;
}

// 打开接入信息弹框：先打开弹框（使用弹窗内的「生成组数」），由弹窗内自动发起一次生成请求
function openAccessInfoModal() {
  openAccessInfoModalInstance(true, { content: '', count: 10 });
}

// 表格刷新
function handleSuccess() {
  reload({
    page: 0,
  });
  cardListReload();
}

const {createMessage} = useMessage();
const [
  registerTable,
  {
    reload,
  },
] = useTable({
  canResize: true,
  showIndexColumn: false,
  title: '国标设备列表',
  api: queryVideoList,
  columns: getBasicColumns(),
  useSearchForm: true,
  showTableSetting: false,
  pagination: true,
  formConfig: getFormConfig(),
  fetchSetting: {
    listField: 'data',
    totalField: 'total',
  },
  rowKey: 'id',
});
</script>

<style lang="less" scoped>
.video-wrapper {
  :deep(.iot-basic-table-action.left) {
    justify-content: center;
  }

  .card-list-wrapper {
    /* 与直连设备页面样式保持一致，无额外 padding 和背景 */
  }
}
</style>

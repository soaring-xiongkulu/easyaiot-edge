<template>
  <div class="device-wrapper" style="height: 100%">
    <BasicTable @register="registerTable" v-if="state.isTableMode">
      <template #toolbar>
        <Button type="primary" @click="openAddModal(true, { type: 'add' })"
                  preIcon="ant-design:plus-outlined">
          新增测试设备
        </Button>
        <Button type="default" @click="batchValidation"
                  preIcon="ant-design:partition-outlined">
          批量测试
        </Button>
        <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
          切换视图
        </Button>
        <PopConfirmButton
          placement="topRight"
          @confirm="handleDeleteAll"
          type="primary"
          color="error"
          :disabled="!checkedKeys.length"
          :title="`您确定要批量删除数据?`"
          preIcon="ant-design:delete-outlined"
        >批量删除
        </PopConfirmButton>
      </template>
      <template #bodyCell="{ column, record }">
        <template v-if="column.dataIndex === 'action'">
          <TableAction
            :actions="[
              {
                tooltip: {
                  title: '删除',
                  placement: 'top',
                },
                icon: 'material-symbols:delete-outline-rounded',

                popConfirm: {
                  placement: 'topRight',
                  title: '是否确认删除？',
                  confirm: handleDeleteProduct.bind(null, record),
                },
              },
            ]"
          />
        </template>
      </template>
    </BasicTable>
    <div v-else>
      <ChannelCardList
        :params="channelListParams"
        :api="queryChannelList"
        :show-location-action="enableLocation"
        @get-method="getMethod"
        @delete="handleDel"
        @edit="handleEdit"
        @play="handlePlay"
        @set-location="handleSetLocation"
        @device-record="handleDeviceRecord"
        @snapshot="handleSnapshot"
        @cloud-record="handleCloudRecord"
      >
        <template #header>
          <Button type="default" @click="handleClickSwap" preIcon="ant-design:swap-outlined">
            切换视图
          </Button>
        </template>
      </ChannelCardList>
    </div>
    <ChannelModal title="编辑通道" @register="registerAddModel" @success="handleSuccess"/>
    <DialogPlayer title="视频播放" @register="registerPlayerAddModel"
                  @success="handlePlayerSuccess"/>
  </div>
</template>
<script setup lang="ts">
import {computed, reactive, ref, watch} from 'vue';
import {BasicTable, TableAction, useTable} from "@/components/Table";
import {PopConfirmButton} from "@/components/Button";
import moment from "moment/moment";
import {getBasicColumns, getFormConfig} from "./Data";
import ChannelCardList from "@/views/gb28181/components/ChannelCardList/index.vue";
import {useMessage} from "@/hooks/web/useMessage";
import {useModal} from "@/components/Modal";
import {useRoute, useRouter} from "vue-router";
import ChannelModal from "@/views/gb28181/components/ChannelModal/index.vue";
import {batchDeleteGbChannels, deleteGbChannel, queryChannelList, snapshot} from "@/api/device/gb28181";
import DialogPlayer from "@/components/VideoPlayer/DialogPlayer.vue";
import {downloadByA} from "@/utils";
import {
  buildGbChannelLocationDevice,
  normalizeWvpChannelItem,
  resolveGbChannelPlayIds,
} from '@/views/camera/utils/gb28181Channel';
import type { DeviceLocationDrawerRecord } from '@/views/camera/utils/deviceLocation';

defineOptions({name: 'Channel'})

const props = defineProps<{
  /** 嵌入设备列表详情页时传入 SIP 设备编码 */
  deviceIdentification?: string;
  embedded?: boolean;
  /** 嵌入摄像头设备列表时展示「设置坐标」 */
  enableLocation?: boolean;
}>();

const emit = defineEmits<{
  setLocation: [record: DeviceLocationDrawerRecord];
}>();

const checkedKeys = ref<Array<string | number>>([]);
const {createMessage} = useMessage();
const route = useRoute();

const sipDeviceId = computed(
  () =>
    (props.deviceIdentification || route.params.deviceIdentification || '') as string,
);

const [registerAddModel, {openModal: openAddModal}] = useModal();
const [registerPlayerAddModel, {openModal: openPlayerAddModal}] = useModal();

const state = reactive({
  isTableMode: false,
  totalTargetDevices: 0,
  targetWait: 0,
  targetStart: 0,
  targetSuccess: 0,
  targetFailures: 0,
});

const [
  registerTable,
  {
    // setLoading,
    // setColumns,
    // getColumns,
    // getDataSource,
    // getRawDataSource,
    reload,
    // getPaginationRef,
    // setPagination,
    // getSelectRows,
    // getSelectRowKeys,
    // setSelectedRowKeys,
    // clearSelectedRowKeys,
  },
] = useTable({
  canResize: true,
  showIndexColumn: false,
  actionColOptions: {span: 4},
  title: '通道列表',
  api: queryChannelList,
  beforeFetch: (data) => {
    const {pageSize, page, order} = data;
    let params = {
      page,
      pageSize,
      sortOrder: order == 'descend' ? 'DESC' : 'ASC',
      deviceIdentification: sipDeviceId.value,
    };
    return params;
  },
  afterFetch: (data) => {
    const sip = sipDeviceId.value;
    return data.map((res) => {
      const row = normalizeWvpChannelItem(res, sip);
      const newDate = new Date(row.createdTime);
      row.createdTime = moment(newDate)?.format?.('YYYY-MM-DD HH:mm:ss') ?? row.createdTime;
      return row;
    });
  },
  columns: getBasicColumns(),
  useSearchForm: true,
  formConfig: getFormConfig(),
  fetchSetting: {
    listField: 'data',
    totalField: 'total',
  },
  rowKey: 'id',
  onChange,
  rowSelection: {
    type: 'checkbox',
    selectedRowKeys: checkedKeys,
    onSelect: onSelect,
    onSelectAll: onSelectAll,
    getCheckboxProps(record) {
      if (record.default || record.referencedByDevice) {
        return {disabled: true};
      } else {
        return {disabled: false};
      }
    },
  },
  onColumnsChange: (data) => {
    //console.log('ColumnsChanged', data);
  },
});

// 切换视图
function handleClickSwap() {
  state.isTableMode = !state.isTableMode;
}

// 批量测试（原 OTA 逻辑已移除；国标通道请使用 WVP/平台能力，勿调 /versions 接口）
function batchValidation() {
  createMessage.warning('国标设备通道不支持 OTA 批量测试，请使用物联网平台「固件/版本」相关菜单');
}

function onSelect(record, selected) {
  if (selected) {
    checkedKeys.value = [...checkedKeys.value, record.id];
  } else {
    checkedKeys.value = checkedKeys.value.filter((id) => id !== record.id);
  }
}

function onSelectAll(selected, selectedRows, changeRows) {
  const changeIds = changeRows.map((item) => item.id);
  if (selected) {
    checkedKeys.value = [...checkedKeys.value, ...changeIds];
  } else {
    checkedKeys.value = checkedKeys.value.filter((id) => {
      return !changeIds.includes(id);
    });
  }
}

async function handleDeleteAll() {
  if (!checkedKeys.value.length) {
    return;
  }
  try {
    const ids = checkedKeys.value.map((k) => Number(k)).filter((n) => !Number.isNaN(n));
    await batchDeleteGbChannels(ids);
    createMessage.success('删除成功');
  } catch (error: any) {
    console.error(error);
    createMessage.error(error?.message || '删除失败');
  }
  reloadList();
}

async function handleDeleteProduct(record) {
  try {
    const id = Number(record.id);
    if (Number.isNaN(id)) {
      createMessage.error('无效的通道 ID');
      return;
    }
    await deleteGbChannel(id);
    reloadList();
    createMessage.success('删除成功');
  } catch (error: any) {
    console.error(error);
    createMessage.error(error?.message || '删除失败');
  }
}

function reloadList() {
  checkedKeys.value = [];
  reload({page: 0});
  cardListReload();
}

function onChange() {
  //console.log('onChange', arguments);
}

/** 卡片列表请求参数（嵌入设备列表时必须用 props，不能依赖路由） */
const channelListParams = computed(() => ({
  deviceIdentification: sipDeviceId.value,
  deviceId: sipDeviceId.value,
}));

let cardListReload = () => {
};

watch(
  sipDeviceId,
  (id) => {
    if (!id) return;
    reload({ page: 0 });
    cardListReload();
  },
);

// 获取内部fetch方法;
function getMethod(m: any) {
  cardListReload = m;
}

//编辑按钮事件
function handleEdit(record) {
  openAddModal(true, {record});
  cardListReload();
}

function handleSetLocation(record: Record<string, any>) {
  const device = buildGbChannelLocationDevice(record, sipDeviceId.value);
  if (!device) {
    createMessage.warning('无法解析通道编码，请检查 WVP 通道数据');
    return;
  }
  emit('setLocation', device);
}

//播放按钮事件：设备号优先用路由（当前为某设备下的通道列表）；通道号用 channelId 或 deviceId
function handlePlay(record) {
  const ids = resolveGbChannelPlayIds(record, sipDeviceId.value);
  if (!ids) {
    createMessage.warning('无法解析通道编码，请检查 WVP 通道数据');
    return;
  }
  openPlayerAddModal(true, {
    ...record,
    deviceIdentification: ids.sipDeviceId,
    deviceId: ids.sipDeviceId,
    channelId: ids.channelId,
    http_stream: undefined,
  });
}

const router = useRouter();

function handleDeviceRecord(record) {
  const params = {
    deviceId: record.deviceId,
    channelId: record.channelId,
  };
  router.push({name: 'Gb28181DeviceRecord', params});
}

function handleCloudRecord(record) {
  const params = {
    deviceId: record.deviceId,
    channelId: record.channelId,
  };
  router.push({name: 'Gb28181CloudRecord', params});
}

function handleSnapshot(record) {
  try {
    let fileName = '', url = '';
    snapshot(record.deviceId, record.channelId).then(resp => {
      createMessage.success('抓拍成功');
      console.log(resp);
      url = resp.data;
      fileName = url.substring(url.lastIndexOf("/"));
      download_img(url, fileName);
    });
  }catch (error) {
    console.error(error)
    createMessage.error('抓拍失败');
  }
}

//图片编码
const getUrlBase64 = (url) => {
  return new Promise((resolve) => {
    let canvas = document.createElement("canvas");
    let ctx = canvas.getContext("2d");
    let img = new Image();
    img.crossOrigin = "Anonymous"; //允许跨域
    img.src = url;
    img.onload = function () {
      canvas.width = img.width;
      canvas.height = img.height;
      ctx.drawImage(img, 0, 0, img.width, img.height);
      let dataURL = canvas.toDataURL("image/png");
      canvas = null;
      resolve(dataURL);
    };
  });
};

// click事件调用方法
const download_img = (url, filename) => {
  getUrlBase64(url).then((base64) => {
    let link = document.createElement("a");
    link.href = base64;
    link.download = filename;
    link.click();
  });
};

//删除按钮事件
function handleDel(record) {
  handleDeleteProduct(record);
  cardListReload();
}

// 表格刷新
function handleSuccess() {
  reload({
    page: 0,
  });
  cardListReload();
}

// 表格刷新
function handlePlayerSuccess() {
}
</script>

<style lang="less" scoped>
:deep(.product-image) {
  width: 30px;
  height: 30px;
  margin-right: auto;
  margin-left: auto;

  img {
    width: 100%;
    height: 100%;
  }
}

:deep(.vben-basic-table-action.left) {
  justify-content: center;
}

.device-wrapper {
  :deep(.ant-tabs-nav) {
    padding: 5px 0 0 25px;
  }

  :deep(.ant-form-item) {
    margin-bottom: 10px;
  }

  :deep(.card-list) {
    margin: 16px 16px 0;
    display: flex;
    align-items: center;
    justify-content: space-around;
    gap: 24px;

    .card {
      flex: 1;
      background-color: #fff;
      min-width: 200px;
      min-height: 130px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: space-around;

      img {
        width: 100px;
        transition: all linear .3s;
      }

      .info {
        display: flex;
        flex-direction: column;
        align-items: center;

        .num {
          font-size: 26px;
          font-weight: 600;
        }

        .label {
          font-weight: 600;
        }
      }
    }
  }
}
</style>

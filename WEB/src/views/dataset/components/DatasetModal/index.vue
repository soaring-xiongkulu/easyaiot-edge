<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="getTitle"
    width="1400"
    placement="right"
    :showFooter="true"
    :showCancelBtn="false"
    :showOkBtn="false"
    destroy-on-close
  >
    <template #footer>
      <div class="footer-buttons">
        <Button @click="handleCancel">{{ state.isView ? '关闭' : '取消' }}</Button>
        <Button v-if="!state.isView" type="primary" :loading="state.editLoading" @click="handleOk">
          保存
        </Button>
      </div>
    </template>

    <Spin :spinning="state.editLoading">
      <div class="dataset-drawer-content">
        <Form
          :label-col="{ style: { width: '150px' } }"
          :wrapper-col="{ span: 21 }"
          :model="validateInfos"
          :disabled="state.isView"
        >
          <FormItem label="数据集名称" name="name" v-bind="validateInfos.name">
            <Input v-model:value="modelRef.name"/>
          </FormItem>
          <FormItem label="数据集类型" name="datasetType" v-bind="validateInfos.datasetType">
            <Select
              placeholder="数据集类型"
              :options="state.datasetTypeList"
              @change="handleDatasetTypeCLickChange"
              v-model:value="modelRef.datasetType"
              allowClear
            />
          </FormItem>
          <FormItem label="数据集版本" name="version" v-bind="validateInfos.version">
            <Input v-model:value="modelRef.version" placeholder="例如 v1.0.0"/>
          </FormItem>
          <FormItem label="数据集描述" name="description" v-bind="validateInfos.description">
            <Input v-model:value="modelRef.description" placeholder="选填"/>
          </FormItem>
          <FormItem label="数据集封面" name="coverPath" v-bind="validateInfos.coverPath">
            <Upload
              name="file"
              :max-count="1"
              @change="handleFileChange"
              :action="state.coverUploadUrl"
              :headers="headers"
              :showUploadList="true"
              accept="image/*"
              :disabled="state.isView"
            >
              <Button type="primary">
                {{ t('component.upload.choose') }}
              </Button>
            </Upload>
          </FormItem>
        </Form>
      </div>
    </Spin>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import {computed, reactive} from 'vue';
import {BasicDrawer, useDrawerInner} from '@/components/Drawer';
import {Form, FormItem, Input, Select, Spin, Upload,} from 'ant-design-vue';
import {useMessage} from '@/hooks/web/useMessage';
import {useI18n} from "@/hooks/web/useI18n";
import {useGlobSetting} from "@/hooks/setting";
import {createDataset, updateDataset} from "@/api/device/dataset";
import {getAccessToken, getTenantId} from '@/utils/auth';
import { Button } from '@/components/Button'
const {t} = useI18n()

defineOptions({name: 'DatasetModal'})

const {createMessage} = useMessage();

const headers = reactive({
  Authorization: `Bearer ${getAccessToken()}`,
  'tenant-id': getTenantId(),
});
const {uploadUrl} = useGlobSetting();

const state = reactive({
  coverUploadUrl: `${uploadUrl}/dataset/upload-cover`,
  record: null,
  isEdit: false,
  isView: false,
  fileList: [],
  loading: false,
  editLoading: false,
  datasetTypeList: [
    {value: 0, label: '图片'},
    {value: 1, label: '文本'},
  ],
});

const modelRef = reactive({
  id: null,
  name: '',
  version: 'v1.0.0',
  coverPath: '',
  description: '',
  datasetType: 0,
});

const getTitle = computed(() => (state.isEdit ? '编辑数据集' : state.isView ? '查看数据集' : '新增数据集'));

function handleFileChange(info: Record<string, any>) {
  const file = info.file;
  const status = file?.status;
  const response = file?.response;
  if (status === 'done') {
    if (response && (response.code === 0 || response.code === 200)) {
      const path = response.data?.url || response.data || response.url || '';
      if (path) {
        modelRef.coverPath = path;
        createMessage.success('封面上传成功');
      } else {
        modelRef.coverPath = '';
        createMessage.error('上传成功但未获取到封面地址');
        console.error('上传响应:', response);
      }
    } else {
      modelRef.coverPath = '';
      createMessage.error(response?.msg || '封面上传失败');
      console.error('上传失败:', response);
    }
  } else if (status === 'error') {
    modelRef.coverPath = '';
    createMessage.error(response?.msg || file?.error?.message || '封面上传失败');
    console.error('上传错误:', file?.error);
  } else if (status === 'removed') {
    modelRef.coverPath = '';
  }
}

const [register, {closeDrawer}] = useDrawerInner((data) => {
  const {isEdit, isView, record} = data;
  state.isEdit = isEdit;
  state.isView = isView;
  if (state.isEdit || state.isView) {
    datasetEdit(record);
  } else {
    resetFields();
    modelRef.version = 'v1.0.0';
  }
});

const emits = defineEmits(['success']);

const rulesRef = reactive({
  name: [{required: true, message: '请输入数据集名称', trigger: ['change']}],
  version: [{required: true, message: '请输入数据集版本号', trigger: ['change']}],
  description: [],
  datasetType: [{required: true, message: '请输入数据集类型', trigger: ['change']}],
  coverPath: [{required: true, message: '请上传数据集封面', trigger: ['change']}],
});

const useForm = Form.useForm;
const {validate, resetFields, validateInfos} = useForm(modelRef, rulesRef);

function handleDatasetTypeCLickChange(value) {
  //console.log('handleCLickChange', value)
}

async function datasetEdit(record) {
  try {
    state.editLoading = true;
    Object.keys(modelRef).forEach((item) => {
      modelRef[item] = record[item];
    });
    if (!modelRef.version) {
      modelRef.version = 'v1.0.0';
    }
    state.editLoading = false;
    state.record = record;
  } catch (error) {
    console.error(error)
  }
}

function handleCancel() {
  resetFields();
  closeDrawer();
}

function handleOk() {
  validate().then(async () => {
    let api = createDataset;
    if (modelRef?.id) {
      api = updateDataset;
    }
    state.editLoading = true;
    api(modelRef)
      .then(() => {
        createMessage.success('操作成功');
        closeDrawer();
        resetFields();
        emits('success');
      })
      .finally(() => {
        state.editLoading = false;
      });
  }).catch((err) => {
    if (!err?.errorFields?.length) {
      createMessage.error('操作失败');
    }
    console.error(err);
  });
}
</script>
<style lang="less" scoped>
.dataset-drawer-content {
  padding: 8px 16px 0;

  :deep(.ant-form-item-label) {
    & > label::after {
      content: '';
    }
  }
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>

<template>
  <BasicModal
    @register="register"
    :title="getTitle"
    @cancel="handleCancel"
    :width="700"
    @ok="handleOk"
    :canFullscreen="false"
  >
    <div class="product-modal">
      <Spin :spinning="state.editLoading">
        <Form
          :labelCol="{ span: 3 }"
          :model="validateInfos"
          :wrapperCol="{ span: 21 }"
          :disabled="state.isView"
        >
          <FormItem label="快捷键编号" name="shortcut" v-bind=validateInfos.shortcut>
            <InputNumber
              v-model:value="modelRef.shortcut"
              step="1"
              min="0"
              max="9"
              allowClear
            />
          </FormItem>
          <FormItem label="标签名称" name="name"
                    v-bind=validateInfos.name>
            <Input v-model:value="modelRef.name"/>
          </FormItem>
          <FormItem label="标签颜色" name="color" v-bind=validateInfos.color>
            <Input type="color" v-model:value="modelRef.color" style="width: 100px"/>
          </FormItem>
          <FormItem label="标签描述" name="description" v-bind=validateInfos.description>
            <Input v-model:value="modelRef.description"/>
          </FormItem>
        </Form>
      </Spin>
    </div>
  </BasicModal>
</template>

<script lang="ts" setup>
import {computed, reactive} from 'vue';
import {useRoute} from 'vue-router';
import {BasicModal, useModalInner} from '@/components/Modal';
import {Form, FormItem, Input, InputNumber, Spin,} from 'ant-design-vue';
import {useMessage} from '@/hooks/web/useMessage';
import {createDatasetTag, updateDatasetTag} from "@/api/device/dataset";

defineOptions({name: 'DatasetTagModal'})

const {createMessage} = useMessage();
const route = useRoute();

const state = reactive({
  record: null,
  isEdit: false,
  isView: false,
  datasetId: null as number | null,
  fileList: [],
  loading: false,
  editLoading: false,
});

const modelRef = reactive({
  id: null,
  shortcut: 1,
  name: '',
  color: '',
  description: '',
  datasetId: null,
  warehouseId: null,
});

const getTitle = computed(() => (state.isEdit ? '编辑数据集标签' : state.isView ? '查看数据集标签' : '新增数据集标签'));

function resolveDatasetId(datasetId: unknown, record?: Record<string, unknown> | null): number | null {
  const candidates = [
    datasetId,
    record?.datasetId,
    route.params['id'],
  ];
  for (const value of candidates) {
    const num = Number(value);
    if (Number.isFinite(num) && num > 0) return num;
  }
  return null;
}

const [register, {closeModal}] = useModalInner((data) => {
  const {datasetId, isEdit, isView, record} = data;
  state.isEdit = isEdit;
  state.isView = isView;
  state.datasetId = resolveDatasetId(datasetId, record);
  modelRef.datasetId = state.datasetId;
  if (state.isEdit || state.isView) {
    datasetEdit(record);
  }
});

const emits = defineEmits(['success']);

const rulesRef = reactive({
  shortcut: [{required: true, message: '请输入快捷键编号', trigger: ['change']}],
  name: [{required: true, message: '请输入标签名称', trigger: ['change']}],
  color: [{required: true, message: '请输入标签颜色', trigger: ['change']}],
  description: [{required: true, message: '请输入描述', trigger: ['change']}],
});

const useForm = Form.useForm;
const {validate, resetFields, validateInfos} = useForm(modelRef, rulesRef);

async function datasetEdit(record) {
  try {
    state.editLoading = true;
    const preservedDatasetId = state.datasetId ?? modelRef.datasetId;
    Object.keys(modelRef).forEach((item) => {
      if (item === 'datasetId') return;
      if (record[item] !== undefined && record[item] !== null) {
        modelRef[item] = record[item];
      }
    });
    state.datasetId = resolveDatasetId(preservedDatasetId, record) ?? preservedDatasetId;
    modelRef.datasetId = state.datasetId;
    state.editLoading = false;
    state.record = record;
  } catch (error) {
    console.error(error)
    //console.log('datasetEdit ...', error);
  }
}

function handleCancel() {
  //console.log('handleCancel');
  resetFields();
}

function buildSubmitPayload() {
  const datasetId = resolveDatasetId(state.datasetId ?? modelRef.datasetId, state.record);
  if (!datasetId) return null;
  return {
    id: modelRef.id ?? undefined,
    name: modelRef.name,
    color: modelRef.color,
    description: modelRef.description ?? '',
    shortcut: Number(modelRef.shortcut),
    datasetId,
    warehouseId: modelRef.warehouseId ?? undefined,
  };
}

function handleOk() {
  validate().then(async () => {
    const payload = buildSubmitPayload();
    if (!payload) {
      createMessage.error('数据集ID不能为空');
      return;
    }
    let api = createDatasetTag;
    if (payload.id) {
      api = updateDatasetTag;
    }
    state.editLoading = true;
    api(payload)
      .then(() => {
        createMessage.success('操作成功');
        closeModal();
        resetFields();
        emits('success');
      })
      .finally(() => {
        state.editLoading = false;
      });
  }).catch((err) => {
    createMessage.error('操作失败');
    console.error(err);
  });
}
</script>
<style lang="less" scoped>
.product-modal {
  :deep(.ant-form-item-label) {
    & > label::after {
      content: '';
    }
  }
}
</style>

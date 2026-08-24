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
        <Button @click="handleCancel">取消</Button>
        <Button type="primary" :loading="state.editLoading" @click="handleOk">保存</Button>
      </div>
    </template>

    <Spin :spinning="state.editLoading">
      <div class="product-drawer-content">
        <Divider orientation="left">基础信息</Divider>
        <Form
          :label-col="SETUP_FORM_LABEL_COL"
          :wrapper-col="SETUP_FORM_WRAPPER_COL"
          class="section-form"
        >
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="产品名称" required v-bind="validateInfos.productName">
                <Input v-model:value="modelRef.productName" placeholder="支持中文、英文、数字、下划线和中划线" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="产品类型" required v-bind="validateInfos.productType">
                <Select
                  v-model:value="modelRef.productType"
                  placeholder="请选择产品类型"
                  :options="productTypeList"
                  :disabled="state.isEdit"
                  allowClear
                />
              </FormItem>
            </Col>
            <Col v-if="state.isEdit" :span="12">
              <FormItem label="产品标识">
                <Input :value="modelRef.productIdentification" disabled />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="应用场景" v-bind="validateInfos.appId">
                <Input v-model:value="modelRef.appId" placeholder="请输入应用场景" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="产品型号" v-bind="validateInfos.model">
                <Input v-model:value="modelRef.model" placeholder="建议包含字母或数字" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="厂商ID" v-bind="validateInfos.manufacturerId">
                <Input v-model:value="modelRef.manufacturerId" placeholder="支持英文、数字、下划线和中划线" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="厂商名称" v-bind="validateInfos.manufacturerName">
                <Input v-model:value="modelRef.manufacturerName" placeholder="请输入厂商名称" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="设备类型" v-bind="validateInfos.deviceType">
                <Select
                  v-model:value="modelRef.deviceType"
                  placeholder="请选择设备类型"
                  :options="deviceType"
                  allowClear
                />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="状态" v-bind="validateInfos.status">
                <Select
                  v-model:value="modelRef.status"
                  placeholder="请选择状态"
                  :options="statusList"
                />
              </FormItem>
            </Col>
            <Col :span="24">
              <FormItem label="产品描述" v-bind="validateInfos.remark">
                <Textarea v-model:value="modelRef.remark" placeholder="请输入产品描述" :rows="3" />
              </FormItem>
            </Col>
          </Row>
        </Form>

        <Divider orientation="left">接入配置</Divider>
        <Form
          :label-col="SETUP_FORM_LABEL_COL"
          :wrapper-col="SETUP_FORM_WRAPPER_COL"
          class="section-form"
        >
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="协议类型" required v-bind="validateInfos.protocolType">
                <Select
                  v-model:value="modelRef.protocolType"
                  placeholder="请选择协议类型"
                  :options="protoTypeList"
                  allowClear
                />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="数据格式" v-bind="validateInfos.dataFormat">
                <Select
                  v-model:value="modelRef.dataFormat"
                  placeholder="请选择数据格式"
                  :options="dataTypeList"
                />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="连接实例" v-bind="validateInfos.connector">
                <Input v-model:value="modelRef.connector" :placeholder="connectorPlaceholder" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="认证方式" v-bind="validateInfos.authMode">
                <Select
                  v-model:value="modelRef.authMode"
                  placeholder="请选择认证方式"
                  :options="authModeList"
                  allowClear
                />
              </FormItem>
            </Col>
          </Row>
        </Form>

        <Divider orientation="left">认证信息</Divider>
        <Form
          :label-col="SETUP_FORM_LABEL_COL"
          :wrapper-col="SETUP_FORM_WRAPPER_COL"
          class="section-form"
        >
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="用户名" v-bind="validateInfos.userName">
                <Input v-model:value="modelRef.userName" placeholder="设备接入用户名" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="密码" v-bind="validateInfos.password">
                <InputPassword v-model:value="modelRef.password" placeholder="设备接入密码" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="签名密钥" v-bind="validateInfos.signKey">
                <Input v-model:value="modelRef.signKey" placeholder="签名密钥（可选）" />
              </FormItem>
            </Col>
          </Row>
        </Form>

        <Divider orientation="left">加密配置</Divider>
        <Form
          :label-col="SETUP_FORM_LABEL_COL"
          :wrapper-col="SETUP_FORM_WRAPPER_COL"
          class="section-form"
        >
          <Row :gutter="16">
            <Col :span="12">
              <FormItem label="传输加密" v-bind="validateInfos.encryptMethod">
                <Select
                  v-model:value="modelRef.encryptMethod"
                  placeholder="请选择加密方式"
                  :options="encryptMethodList"
                  allowClear
                />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="加密密钥" v-bind="validateInfos.encryptKey">
                <Input v-model:value="modelRef.encryptKey" placeholder="加密密钥" />
              </FormItem>
            </Col>
            <Col :span="12">
              <FormItem label="加密向量" v-bind="validateInfos.encryptVector">
                <Input v-model:value="modelRef.encryptVector" placeholder="加密向量" />
              </FormItem>
            </Col>
          </Row>
          <div class="form-hint">创建后产品标识由系统自动生成；产品类型创建后不可修改。</div>
        </Form>
      </div>
    </Spin>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, reactive, watch } from 'vue';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { Col, Divider, Form, FormItem, Input, Row, Select, Spin, Textarea } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { useMessage } from '@/hooks/web/useMessage';
import {
  authModeList,
  createEmptyProduct,
  dataTypeList,
  deviceType,
  encryptMethodList,
  isIndustrialProtocol,
  productTypeList,
  protoTypeList,
  statusList,
} from '@/views/product/Data';
import { addDeviceProfile, editDeviceProfile } from '@/api/device/product';
import { SETUP_FORM_LABEL_COL, SETUP_FORM_WRAPPER_COL } from '@/views/node/utils/constants';

defineOptions({ name: 'ProductFormDrawer' });

const { createMessage } = useMessage();
const InputPassword = Input.Password;

const state = reactive({
  isEdit: false,
  editLoading: false,
});

const modelRef = reactive(createEmptyProduct());
const getTitle = computed(() => (state.isEdit ? '编辑产品' : '新增产品'));
const industrialProduct = computed(() => isIndustrialProtocol(modelRef.protocolType));
const connectorPlaceholder = computed(() =>
  industrialProduct.value
    ? '工业协议可留空（Sink 主动轮询）'
    : 'MQTT 连接实例标识',
);

watch(
  () => modelRef.protocolType,
  (protocol) => {
    if (isIndustrialProtocol(protocol)) {
      if (!modelRef.dataFormat || modelRef.dataFormat === 'JSON') {
        modelRef.dataFormat = 'BINARY';
      }
    } else if (!state.isEdit && modelRef.dataFormat === 'BINARY') {
      modelRef.dataFormat = 'JSON';
    }
  },
);

const emits = defineEmits(['success', 'register', 'update']);

const rulesRef = reactive({
  productName: [{ required: true, message: '请输入产品名称', trigger: ['change'] }],
  productType: [{ required: true, message: '请选择产品类型', trigger: ['change'] }],
  protocolType: [{ required: true, message: '请选择协议类型', trigger: ['change'] }],
});

const { validate, resetFields, validateInfos } = Form.useForm(modelRef, rulesRef);

const [register, { closeDrawer }] = useDrawerInner((data) => {
  const { isEdit, record } = data || {};
  state.isEdit = !!isEdit || !!record?.id;

  if (state.isEdit && record) {
    fillProduct(record);
  } else {
    resetModel();
  }
});

function resetModel() {
  Object.assign(modelRef, createEmptyProduct());
  resetFields();
}

function fillProduct(record: Record<string, any>) {
  Object.keys(modelRef).forEach((key) => {
    if (key === 'encryptMethod') {
      const val = record[key];
      modelRef[key] = val === null || val === undefined || val === '' ? '' : String(val);
      return;
    }
    modelRef[key] = record[key] ?? '';
  });
}

function handleCancel() {
  resetModel();
  closeDrawer();
}

function buildPayload() {
  const payload: Record<string, any> = { ...modelRef };
  delete payload.templateIdentification;
  delete payload.createBy;
  delete payload.createTime;
  delete payload.updateBy;
  delete payload.updateTime;
  if (payload.encryptMethod !== '' && payload.encryptMethod !== null && payload.encryptMethod !== undefined) {
    payload.encryptMethod = Number(payload.encryptMethod);
  } else {
    payload.encryptMethod = null;
  }
  return payload;
}

async function handleOk() {
  try {
    await validate();
    state.editLoading = true;
    const payload = buildPayload();
    const api = modelRef.id ? editDeviceProfile : addDeviceProfile;
    await api(payload);
    createMessage.success('操作成功');
    closeDrawer();
    resetModel();
    emits('success');
    emits('update');
  } catch (err: any) {
    if (!err?.errorFields) {
      createMessage.error(err?.response?.data?.msg || err?.message || '操作失败');
    }
  } finally {
    state.editLoading = false;
  }
}
</script>

<style lang="less" scoped>
.product-drawer-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.section-form {
  :deep(.ant-form-item) {
    margin-bottom: 16px;
  }
}

.form-hint {
  color: rgba(0, 0, 0, 0.45);
  font-size: 13px;
  line-height: 1.5;
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
}
</style>

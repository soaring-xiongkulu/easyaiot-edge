<template>
  <BasicModal
    @register="register"
    @cancel="handleCancel"
    :width="900"
    @ok="handleOk"
    :canFullscreen="false"
  >
    <div class="product-modal" v-if="operateType == 'add' && !state.isTestAccess">
      <div class="product-modal">
        <Spin :spinning="state.editLoading">
          <Form
            :labelCol="{ span: 4 }"
            :model="validateInfos"
            :wrapperCol="{ span: 20 }"
          >
            <FormItem label="IP" name="ip" v-bind=validateInfos.ip>
              <Input v-model:value="modelRef.ip"/>
            </FormItem>
            <FormItem label="HTTP端口" name="httpPort" v-bind=validateInfos.httpPort>
              <Input v-model:value="modelRef.httpPort"/>
            </FormItem>
            <FormItem label="SECRET" name="secret" v-bind=validateInfos.secret>
              <Input v-model:value="modelRef.secret"/>
            </FormItem>
          </Form>
          <Button style="width: 95%;height: 38px;float: right;" type="primary" @click="test">流媒体节点测试</Button>
        </Spin>
      </div>
    </div>
    <div class="product-modal" v-else>
      <div class="product-modal">
        <Spin :spinning="state.editLoading">
          <Form
            :labelCol="{ span: 8 }"
            :model="validateInfos"
            :wrapperCol="{ span: 16 }"
          >
            <Row :gutter="0">
              <Col :span="12">
                <FormItem label="IP" name="ip" v-bind=validateInfos.ip>
                  <Input v-model:value="modelRef.ip"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="RTMP PORT" name="rtmpPort" v-bind=validateInfos.rtmpPort>
                  <Input v-model:value="modelRef.rtmpPort"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="HTTP端口" name="httpPort" v-bind=validateInfos.httpPort>
                  <Input v-model:value="modelRef.httpPort"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="RTMPS PORT" name="rtmpSSlPort" v-bind=validateInfos.rtmpSSlPort>
                  <Input v-model:value="modelRef.rtmpSSlPort"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="HOOK IP" name="hookIp" v-bind=validateInfos.hookIp>
                  <Input v-model:value="modelRef.hookIp"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="SECRET" name="secret" v-bind=validateInfos.secret>
                  <Input v-model:value="modelRef.secret"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="SDP IP" name="sdpIp" v-bind=validateInfos.sdpIp>
                  <Input v-model:value="modelRef.sdpIp"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="流IP" name="streamIp" v-bind=validateInfos.streamIp>
                  <Input v-model:value="modelRef.streamIp"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="收流端口">
                  <Row :gutter="0">
                    <Col :span="11">
                      <Input v-model:value="modelRef.rtpPortRange1"/>
                    </Col>
                    <span style="margin: 0 5px">-</span>
                    <Col :span="11">
                      <Input v-model:value="modelRef.rtpPortRange2"/>
                    </Col>
                  </Row>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="HTTPS PORT" name="httpSSlPort" v-bind=validateInfos.httpSSlPort>
                  <Input v-model:value="modelRef.httpSSlPort"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="RTSP PORT" name="rtspPort" v-bind=validateInfos.rtspPort>
                  <Input v-model:value="modelRef.rtspPort"/>
                </FormItem>
              </Col>
              <Col :span="12">
                <FormItem label="RTSPS PORT" name="rtspSSLPort" v-bind=validateInfos.rtspSSLPort>
                  <Input v-model:value="modelRef.rtspSSLPort"/>
                </FormItem>
              </Col>
            </Row>
          </Form>
        </Spin>
      </div>
    </div>
  </BasicModal>
</template>
<script lang="ts" setup>
import {reactive, ref, unref} from 'vue';
import {BasicModal, useModalInner} from '@/components/Modal';
import { Col, Form, FormItem, Input, Row, Spin } from 'ant-design-vue';
import {useMessage} from '@/hooks/web/useMessage';
import {useRoute} from "vue-router";
import {checkMediaServer, saveOrUpdateMediaServer} from "@/api/device/gb28181";
import { Button } from '@/components/Button'
defineOptions({name: 'PullProxyModal'})

const {createMessage} = useMessage();
const route = useRoute()

const state = reactive({
  isTestAccess: false,
  editLoading: false,
  nodeTypeList: [
    {label: 'ZLMediaKit', value: 'ZLMediaKit'}
  ],
});

const modelRef = reactive({
  id: '',
  ip : '',
  httpPort: '',
  secret: '',
  type: 'zlm',
  rtmpPort : '',
  rtmpSSlPort: '',
  hookIp: '',
  sdpIp: '',
  streamIp: '',
  rtpPortRange1: '',
  rtpPortRange2: '',
  httpSSlPort: '',
  rtspPort: '',
  rtspSSLPort: '',
  autoConfig: true,
  rtpEnable: true,
  rtpPortRange: '',
  sendRtpPortRange: '',
  flvPort: 80,
  flvSSLPort: 80,
  wsFlvPort: 80,
  wsFlvSSLPort: 80,
  rtpProxyPort: 10000,
  hookAliveInterval: null,
  status: false,
  recordAssistPort: 0,
  createTime: null,
  updateTime: null,
  lastKeepaliveTime: null,
  defaultServer: false,
  recordDay: 0,
  recordPath: null,
  transcodeSuffix: null
});

const checkedKeys = ref<Array<string | number>>([]);

const operateType = ref('add');

const [register, { closeModal, setModalProps }] = useModalInner((data) => {
  console.log('data ...', data);
  operateType.value = data.type;
  setModalProps({
    title: data.type == 'add' ? '新增媒体节点' : '编辑媒体节点',
  });
  unref(operateType) == 'edit' && editMedia(data.record);
});

const editMedia = (record) => {
  for (const key in record) {
    modelRef[key] = record[key];
  }
  if(record.rtpPortRange !== '') {
    modelRef.rtpPortRange1 = record.rtpPortRange.split(',')[0];
    modelRef.rtpPortRange2 = record.rtpPortRange.split(',')[1];
  }
};

const emits = defineEmits(['success']);

function handleCLickChange(value) {
  //console.log('handleCLickChange', value)
}

const rulesRef = reactive({
  ip: [{required: true, message: '请输入IP', trigger: ['change']}],
  httpPort: [{required: true, message: '请输入HTTP端口', trigger: ['change']}],
  secret: [{required: true, message: '请输入SECRET', trigger: ['change']}],
  rtmpPort: [{required: true, message: '请输入rtmpPort', trigger: ['change']}],
  rtmpSSlPort: [{required: true, message: '请输入rtmpSSlPort', trigger: ['change']}],
  hookIp: [{required: true, message: '请输入hookIp', trigger: ['change']}],
  sdpIp: [{required: true, message: '请输入sdpIp', trigger: ['change']}],
  streamIp: [{required: true, message: '请输入streamIp', trigger: ['change']}],
  rtpPortRange1: [{required: true, message: '请输入rtpPortRange1', trigger: ['change']}],
  rtpPortRange2: [{required: true, message: '请输入rtpPortRange2', trigger: ['change']}],
  httpSSlPort: [{required: true, message: '请输入httpSSlPort', trigger: ['change']}],
  rtspPort: [{required: true, message: '请输入rtspPort', trigger: ['change']}],
  rtspSSLPort: [{required: true, message: '请输入rtspSSLPort', trigger: ['change']}],
});

const useForm = Form.useForm;
const {validate, resetFields, validateInfos} = useForm(modelRef, rulesRef);

function handleCancel() {
  state.isTestAccess = false;
  resetFields();
}

function test() {
  state.editLoading = true;
  checkMediaServer(modelRef)
    .then((res) => {
      for (const key in res) {
        modelRef[key] = res[key];
      }
      state.isTestAccess = true;
      createMessage.success('流媒体节点测试通过');
    })
    .catch((err) => {
      state.isTestAccess = false;
      createMessage.error(err?.message || '流媒体节点测试失败');
      console.error(err);
    })
    .finally(() => {
      state.editLoading = false;
    });
}

/** 保存前将端口类字段转为数字，避免 JSON 字符串导致后端解析异常 */
function normalizeMediaServerPayload() {
  const numericFields = [
    'httpPort', 'httpSSlPort', 'rtmpPort', 'rtmpSSlPort', 'rtspPort', 'rtspSSLPort',
    'flvPort', 'flvSSLPort', 'wsFlvPort', 'wsFlvSSLPort', 'rtpProxyPort', 'recordAssistPort',
    'recordDay',
  ] as const;
  const payload: Record<string, any> = { ...modelRef };
  for (const key of numericFields) {
    const val = payload[key];
    if (val !== '' && val != null) {
      payload[key] = Number(val);
    }
  }
  payload.rtpPortRange = `${modelRef.rtpPortRange1},${modelRef.rtpPortRange2}`;
  payload.sendRtpPortRange = payload.rtpPortRange;
  return payload;
}

function handleOk() {
  if (unref(operateType) === 'add' && !state.isTestAccess) {
    createMessage.warn('必须先通过流媒体节点测试');
    return;
  }
  validate().then(async () => {
    if (unref(operateType) === 'add' && !modelRef.id) {
      createMessage.error('缺少媒体节点 ID，请先完成流媒体节点测试');
      return;
    }
    state.editLoading = true;
    saveOrUpdateMediaServer(normalizeMediaServerPayload())
      .then(() => {
        createMessage.success('操作成功');
        state.isTestAccess = false;
        closeModal();
        resetFields();
        emits('success');
      })
      .catch((err) => {
        createMessage.error(err?.message || '保存失败');
        console.error(err);
      })
      .finally(() => {
        state.editLoading = false;
      });
  }).catch((err) => {
    createMessage.error('请完善表单信息');
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

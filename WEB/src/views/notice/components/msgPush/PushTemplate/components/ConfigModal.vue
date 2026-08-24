<!-- eslint-disable vue/v-on-event-hyphenation -->
<template>
  <BasicModal
    @register="registerModal"
    @cancel="handleCancel"
    @ok="handleOk"
    width="1100px"
    :canFullscreen="false"
  >
    <div class="config-modal-box">
      <BasicForm
        @register="registerForm"
        :showAdvancedButton="false"
        :showActionButtonGroup="false"
      >
        <!-- 应用 -->
        <template #agentId="{ model, field }">
          <FormItemRest>
            <Select
              v-model:value="model[field]"
              :options="formData.agent"
              @focus="getMessageConfigQuery"
              placeholder="请选择"
            />
          </FormItemRest>
        </template>
        <!-- 用户分组 -->
        <template #userGroupId="{ model, field }">
          <FormItemRest>
            <Select
              v-model:value="model[field]"
              :options="formData.userGroupList"
              @focus="getUserGroupQueryByMsgType"
              placeholder="请选择"
            />
          </FormItemRest>
        </template>
        <!-- 消息模板 -->
        <template #refTemplateId="{ model, field }">
          <FormItemRest>
            <Select
              v-model:value="model[field]"
              :options="formData.templateList"
              @focus="loadTemplateOptions"
              @change="onTemplateChange"
              placeholder="请选择消息模板"
              show-search
              option-filter-prop="label"
            />
          </FormItemRest>
        </template>
        <!-- 模版变量 -->
        <template #templateDataList>
          <FormItemRest>
            <EditTable :columns="templateColumns" v-model:list="formData.templateDataList" />
          </FormItemRest>
        </template>
        <!-- 附件 -->
        <template #attachments>
          <FormItemRest>
            <UploadAttachment v-model:attachment="formData.attachments" />
          </FormItemRest>
        </template>
        <!-- http参数 -->
        <template #tabActive="{ model, field }">
          <FormItemRest>
            <HttpParams
              ref="httpParamsRef"
              v-model:value="model[field]"
              :requestType="getFieldsValue()?.method"
            />
          </FormItemRest>
        </template>
        <template #message="{ model, field }">
          <Textarea v-model:value="model[field]" :rows="3" />
          <!-- <Textarea
            v-model:value="model[field]"
            placeholder="变量格式:\${name};
        示例:尊敬的\${name},\${time}有设备触发告警,请注意处理"
            :rows="3"
            @change="handleMessageChange"
          /> -->
        </template>
        <!-- 变量 -->
        <template #variableDefinitions>
          <FormItemRest>
            <VariableDefinitions v-model:variableDefinitions="formData.variableDefinitions" />
          </FormItemRest>
        </template>
      </BasicForm>
      <Describe ref="describeRef" />
    </div>
  </BasicModal>
</template>
<script lang="ts" setup>
  import { computed, ref } from 'vue';
  import { BasicModal, useModalInner } from '/@/components/Modal';
  import { BasicForm, useForm } from '/@/components/Form';

  import { useMessage } from '/@/hooks/web/useMessage';
  import {
    formSchemas,
    templateColumns,
    needsPushUserGroup,
  } from '../Data';
  import VariableDefinitions from './VariableDefinitions.vue';
  import Describe from './Describe.vue';
  import {
    messagePrepareAdd,
    messagePrepareUpdate,
    messageTemplateQueryByType,
    messageTemplateGet,
    messageConfigQuery,
  } from '/@/api/modules/notice';
  import { userGroupQueryByMsgType } from '/@/api/modules/user';
  import { Select, Textarea, FormItemRest } from 'ant-design-vue';
  import UploadAttachment from './UploadAttachment.vue';
  import HttpParams from './HttpParams.vue';
  import EditTable from '@/views/notice/components/configuration/EditTable.vue';
  // interface IVariableDefinitions {
  //   id: string;
  //   name: string;
  //   type: string;
  //   format: string;
  //   value?: string;
  // }

  const emits = defineEmits(['success']);
  const { createMessage } = useMessage();
  const httpParamsRef = ref(null);
  const describeRef = ref(null);
  const opertionType = ref('add');

  const MSG_TYPE_MAP: Record<string, number> = {
    sms: 1,
    email: 3,
    weixin: 4,
    http: 5,
    ding: 6,
    feishu: 7,
  };
  const currentMsgType = ref<number | null>(null);

  const DESCRIBE_TYPE_MAP: Record<string, string> = {
    sms: 'sms',
    email: 'email',
    weixin: 'weixin',
    http: 'webhook',
    ding: 'ding',
    feishu: 'feishu',
  };

  const formData = ref({
    variableDefinitions: [],
    attachments: [],
    templateDataList: [],
    userGroupList: [],
    templateList: [],
    agent: [],
    selectedTemplate: null as { radioType?: string; webHook?: string } | null,
  });

  const isVariable = computed(() => {
    return formData.value?.variableDefinitions?.length > 0;
  });

  const [registerModal, { setModalProps, closeModal }] = useModalInner((data) => {
    handleNoticeType(data.pushType);
    if (data.type == 'edit') {
      editConfigModal(data?.record);
    }
    setModalProps({
      title: data.type == 'add' ? '新增推送' : '编辑推送',
    });
    opertionType.value = data.type;
  });

  const [
    registerForm,
    {
      getFieldsValue,
      validate,
      setFieldsValue,
      resetFields,
    },
  ] = useForm({
    schemas: formSchemas({ isVariable }),
    labelWidth: '100px',
    layout: 'vertical',
    baseColProps: { span: 24 },
  });

  function editConfigModal(record) {
    const { refTemplateId, msgName, userGroupId, previewUser, msgType, id } = record;
    if (msgType != null) {
      currentMsgType.value = +msgType;
    }
    setTimeout(async () => {
      setFieldsValue({ id, msgType, refTemplateId, msgName, userGroupId, previewUser });
      await syncTemplateMeta(refTemplateId, +msgType);
      if (needsPushUserGroup(msgType, formData.value.selectedTemplate)) {
        getUserGroupQueryByMsgType();
      }
      loadTemplateOptions();
    });
  }

  // 类型
  function handleNoticeType(type: string) {
    const msgType = MSG_TYPE_MAP[type] ?? 3;
    currentMsgType.value = msgType;
    changeNoticeType(type);
    describeRef.value?.setNoticeType(DESCRIBE_TYPE_MAP[type] || 'email');
    setTimeout(() => {
      setFieldsValue({ msgType });
      loadTemplateOptions();
    });
    reset();
  }

  function changeNoticeType(_type: string) {
    // 推送仅配置：推送名称 + 消息模板 + 用户分组
  }

  // function changeMessage(value) {
  //   variableReg(value);
  // }

  // const spliceStr = (value) => {
  //   let variableFieldsStr = value;
  //   return variableFieldsStr || '';
  // };

  // const variableReg = (value) => {
  //   const _val = spliceStr(value);
  //   // 已经存在的变量
  //   const oldKey = formData.value.variableDefinitions?.map((m) => m.id);
  //   // 正则提取${}里面的值
  //   const pattern = /(?<=\$\{).*?(?=\})/g;
  //   const titleList = _val.match(pattern)?.filter((f) => f);
  //   const newKey = [...new Set(titleList)];
  //   const result = newKey?.map((m) =>
  //     oldKey.includes(m)
  //       ? formData.value.variableDefinitions.find((item) => item.id === m)
  //       : {
  //           id: m,
  //           name: '',
  //           type: 'string',
  //           format: '%s',
  //         },
  //   );
  //   formData.value.variableDefinitions = result as IVariableDefinitions[];
  // };

  // const handleMessageChange = (e) => {
  //   const value = e?.target?.value || e;
  //   value && changeMessage(value);
  // };

  const reset = () => {
    formData.value.variableDefinitions = [];
    formData.value.attachments = [];
    formData.value.templateDataList = [];
    formData.value.templateList = [];
    formData.value.userGroupList = [];
    formData.value.selectedTemplate = null;
    httpParamsRef.value?.reset?.();
  };

  const handleCancel = () => {
    resetFields();
    reset();
  };

  const handleOk = () => {
    validate()
      .then(async () => {
        const configKey = {
          1: 't_Msg_Sms',
          2: 't_Msg_Sms',
          3: 't_Msg_Mail',
          4: 't_Msg_Wx_Cp',
          5: 't_Msg_Http',
          6: 't_Msg_Ding',
          7: 't_Msg_Feishu',
        };
        const { id, msgType, refTemplateId, msgName, userGroupId, previewUser } = getFieldsValue();
        const _msgType = +msgType;
        const needUserGroup = needsPushUserGroup(_msgType, formData.value.selectedTemplate);
        const t_Msg: Record<string, unknown> = {
          msgType: _msgType,
          msgName,
          refTemplateId,
          userGroupId: needUserGroup ? userGroupId || null : null,
          previewUser: previewUser || null,
        };
        if (opertionType.value == 'edit') {
          t_Msg.id = id;
        }
        const params = {
          msgType: _msgType,
          [configKey[_msgType]]: t_Msg,
        };
        opertionType.value == 'add'
          ? await messagePrepareAdd(params)
          : await messagePrepareUpdate(params);
        createMessage.success(opertionType.value == 'add' ? '添加成功' : '编辑成功');
        closeModal();
        emits('success');
        handleCancel();
      })
      .catch((error) => {
        console.log(error);
        createMessage.error('操作失败');
      });
  };

  function resolveMsgType(): number | null {
    const fromForm = getFieldsValue()?.msgType;
    const raw = currentMsgType.value ?? fromForm;
    if (raw == null || raw === '') return null;
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }

  async function syncTemplateMeta(templateId: string | undefined, msgType: number) {
    if (!templateId) {
      formData.value.selectedTemplate = null;
      setFieldsValue({ templateRadioType: undefined, templateWebHook: undefined, userGroupId: undefined });
      return;
    }
    try {
      const ret = await messageTemplateGet({ id: templateId, msgType });
      const tpl = (ret && typeof ret === 'object' && 'radioType' in ret ? ret : (ret as { data?: object })?.data) as
        | { radioType?: string; webHook?: string }
        | undefined;
      const meta = {
        radioType: tpl?.radioType,
        webHook: tpl?.webHook,
      };
      formData.value.selectedTemplate = meta;
      setFieldsValue({
        templateRadioType: meta.radioType,
        templateWebHook: meta.webHook,
      });
      if (!needsPushUserGroup(msgType, meta)) {
        setFieldsValue({ userGroupId: undefined });
      }
    } catch (e) {
      console.error(e);
      formData.value.selectedTemplate = null;
    }
  }

  async function onTemplateChange(templateId: string) {
    const msgType = resolveMsgType();
    if (msgType == null) return;
    await syncTemplateMeta(templateId, msgType);
    if (needsPushUserGroup(msgType, formData.value.selectedTemplate)) {
      getUserGroupQueryByMsgType();
    }
  }

  async function loadTemplateOptions() {
    try {
      const msgType = resolveMsgType();
      if (msgType == null) return;
      const ret = await messageTemplateQueryByType({ msgType });
      let list: Array<Record<string, unknown>> = [];
      if (Array.isArray(ret)) {
        list = ret;
      } else if (ret && typeof ret === 'object') {
        const data = (ret as { data?: unknown }).data;
        list = Array.isArray(data) ? data : [];
      }
      formData.value.templateList = list.map((item) => ({
        label: String(item.name || item.title || item.msgName || item.id || ''),
        value: item.id,
      }));
    } catch (error) {
      console.error(error);
    }
  }

  // 目标用户
  async function getUserGroupQueryByMsgType() {
    try {
      const msgType = resolveMsgType();
      if (msgType == null) return;
      const ret = await userGroupQueryByMsgType({ msgType });
      const rows = Array.isArray(ret) ? ret : [];
      formData.value.userGroupList = rows.map((item) => ({
        label: item.userGroupName,
        value: item.id,
      }));
    } catch (error) {
      console.error(error);
    }
  }

  function resolveConfigApps(configurationMap, msgType) {
    const configKey = { 4: 'wxCpApp', 6: 'dingdingApp' };
    const key = configKey[+msgType];
    if (!key || !configurationMap) return [];
    let apps = configurationMap[key];
    if (!apps && +msgType === 4) {
      apps = configurationMap.weixinApply;
    }
    if (typeof apps === 'string') {
      try {
        apps = JSON.parse(apps);
      } catch {
        apps = [];
      }
    }
    if (!Array.isArray(apps)) {
      apps = apps ? [apps] : [];
    }
    return apps;
  }

  // 应用
  async function getMessageConfigQuery() {
    try {
      const _msgType = resolveMsgType();
      if (_msgType == null) return;
      const ret = await messageConfigQuery({ msgType: _msgType });
      const rows = Array.isArray(ret) ? ret : ret?.data ?? [];
      const row = rows.find((item) => +item.msgType === _msgType) ?? rows[0];
      formData.value.agent = resolveConfigApps(row?.configurationMap, _msgType).map((item) => ({
        label: item.appName,
        value: item.agentId,
      }));
    } catch (error) {
      console.error(error);
    }
  }
</script>
<style lang="less" scoped>
  .config-modal-box {
    display: flex;

    form,
    .describe-wapper {
      flex: 1;
    }

    .describe-wapper {
      margin-left: 20px;
    }

    :deep(.message-item) {
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 140px;
      height: 140px;
      padding: 5px;
      border-radius: 3px;

      span:nth-child(1) {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100px;
        height: 100px;
        border-radius: 15px;
        background: #1d39c4;
        color: #fff;
        font-size: 67px;
      }

      span:nth-child(2) {
        margin-top: 6px;
      }
    }

    :deep(.active) {
      border: solid 1px #1d39c4;

      span:nth-child(2) {
        color: #1d39c4;
      }
    }

    :deep(.server-port),
    :deep(.server-ssl) {
      display: flex;
      align-items: center;

      & > div {
        margin-top: 10px;
        margin-bottom: 0;
        margin-left: 5px;
      }
    }

    :deep(.server-ssl) {
      & > div {
        margin-top: 7px;
      }
    }

    :deep(.upload-attachment-warpper) {
      .uaw-add {
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 5px;
        border: 1px dashed #d9d9d9;
        border-radius: 5px;
        background: #fff;
        color: rgb(0 0 0 / 85%);
      }

      .uaw-add:hover {
        border-color: #5c85ff;
        color: #5c85ff;
      }
    }

    .cmb-monaco-editor {
      height: 200px;
      padding: 3px 3px 3px 0;
      overflow: hidden;
      border: solid 1px #d9d9d9;
      border-radius: 3px;
    }

    .error {
      color: #ed6f6f;
    }

    :deep(.iot-basic-help .anticon-info-circle) {
      vertical-align: text-bottom !important;
    }

    :deep(.message-warpper) {
      display: flex;
    }
    :deep(.hidden-label) {
      .ant-form-item-label {
        visibility: hidden;
      }
    }

    :deep(.none-label) {
      .ant-form-item-label {
        display: none;
      }
    }
  }
</style>

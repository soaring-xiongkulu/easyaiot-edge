<template>
  <div class="edit">
    <BasicModal :width="800" @register="register"  :title="props.title" @ok="handleSubmit" @cancel="handleCancel">
      <Typography v-if="!hideTab">
        <TypographyParagraph>
          <blockquote>
            {{ tipText }}
          </blockquote>
        </TypographyParagraph>
      </Typography>

      <Tabs
        v-if="!hideTab && visibleTabs.length > 1"
        v-model:activeKey="tabsActive"
        type="card"
        @change="handleTabsChange"
      >
        <TabPane v-for="v in visibleTabs" :key="v.key" :tab="v.label" />
      </Tabs>
      <EditInner
        ref="formRef"
        :disabled="disabled"
        @show-inner="handleShowInner"
        :checkIdentifier="handleCheckIdentifier"
        :handleCheckSubuct="handleCheckSubuct"
      />
    </BasicModal>

    <!-- 结构体参数弹窗 -->
    <!-- <BasicModal
      @register="registerInnerModal"
      title="创建参数"
      width="800px"
      @ok="handleInnerSubmit"
      @cancel="handleInnerCancel"
    >
      <EditInner ref="innerRef" isInner />
    </BasicModal> -->

    <EditChild
      @register="registerInnerModal"
      ref="innerRef"
      :tab="tabsActive"
      :disabled="disabled"
      @show-inside="handleShowInside"
      @close="() => handleInnerClose('inner')"
      @submit="handleInnerSubmit"
      :handleCheckSubuct="handleCheckSubuct"
    />

    <EditChild
      @register="registerInnerInsideModal"
      ref="innerInsideRef"
      isInner
      :disabled="disabled"
      :tab="tabsActive"
      @close="() => handleInnerClose('inside')"
      @submit="handleInnerSubmit"
      :handleCheckSubuct="handleCheckSubuct"
    />
  </div>
</template>

<script lang="ts" setup name="Edit">
import {BasicModal, useModal, useModalInner} from '@/components/Modal';
import {TabPane, Tabs, Typography, TypographyParagraph} from 'ant-design-vue';
import EditInner from './EditInner.vue';
import EditChild from './EditChild.vue';
import {computed, nextTick, ref, withDefaults} from 'vue';
import {
  BoolFormSchemas,
  EditFormSchemas,
  EventSchemas,
  IntFormSchemas,
  normalizePropertyDatatype,
  normalizePropertyMethod,
  PropsSchemas,
  ServerSchemas,
  ServiceParamSchemas,
  SubuctRender,
  SubuctSchemas,
  tabsOptions,
  TextFormSchemas,
} from '../data/ProductData';
import {FormSchema} from '@/components/Form/index';
import {checkIdentifier} from '@/api/device/phsyicalModal';
import {throttle} from 'lodash-es';
import { isIndustrialProtocol } from '../Data';

  interface Props {
    title: string;
    productIdentification: string;
    protocolType?: string;
  }

  const props = withDefaults(defineProps<Props>(), {
    title: '物模型',
    productIdentification: '',
    protocolType: '',
  });

  const industrial = computed(() => isIndustrialProtocol(props.protocolType));
  const visibleTabs = computed(() =>
    industrial.value ? tabsOptions.filter((item) => item.key === 'properties') : tabsOptions,
  );
  const tipText = computed(() =>
    industrial.value
      ? '工业协议物模型只需定义属性。属性标识必须与设备点位 identifier 一致；寄存器地址 / NodeId 在设备点位管理中配置。'
      : '属性一般是设备的运行状态，如当前温度等；服务是设备可被调用的方法，支持定义参数，如执行某项任务；事件则是设备上报的通知，如告警，需要被及时处理。',
  );

  const emit = defineEmits(['submit', 'register', 'update:editFunctionType']);

  // 外部表单ref
  const formRef = ref();
  // 结构体参数弹窗ref
  const innerRef = ref();
  //
  const innerInsideRef = ref();
  // 最终参数
  const params = ref<{ innerJson: any[]; id: string }>({
    innerJson: [],
    id: '',
  });

  const tabsActive = ref('properties');

  // 隐藏tab，查看、编辑模式下隐藏
  const hideTab = ref(false);
  // 查看模式下禁用
  const disabled = ref(false);

  // 是否触发了编辑结构体函数
  const isEditInnerSubuct = ref<number | null>(null);
  const isEditIsideSubuct = ref<number | null>(null);
  // 当前展示弹窗为哪个字段
  const fieldArr = ref<string[]>([]);

  const [register, { closeModal }] = useModalInner(async ({ modalType, functionType, ...obj }) => {
    hideTab.value = modalType !== 'add';
    disabled.value = modalType === 'view';

    formRef.value.setFormProps({
      disabled: disabled.value,
    });
    await nextTick();

    // 工业协议仅支持属性，避免新增时切到服务/事件
    let resolvedType = functionType ?? 'properties';
    if (industrial.value) {
      resolvedType = 'properties';
    }

    //console.log(modalType, 'modalType', functionType, obj);
    // alert(functionType)
    // 工业/历史数据归一化：float→DOUBLE、rw→w 等，保证表单可正确回显
    if (resolvedType === 'properties') {
      obj.datatype = normalizePropertyDatatype(obj.datatype);
      obj.method = normalizePropertyMethod(obj.method);
    }
    // 根据功能类型切换
    handleTabsChange(resolvedType, obj['datatype'] ?? 'INT');
    // 没有该字段表示为新增模式
    if (!obj?.id) return;

    params.value = obj;

    if(obj['datatype'] == 'BOOL' && (obj['enumlist'] !== '' || obj['enumlist'] !== null || obj['enumlist'] !== undefined)) {
      let tmp = JSON.parse(obj['enumlist']);
      obj['boolClose'] = tmp['0'];
      obj['boolOpen'] = tmp['1'];
    }
    if(resolvedType == 'services') {
      obj['propertyName'] = obj['serviceName']
      obj['propertyCode'] = obj['serviceCode']
      // 保证参数数组存在，便于增加参数
      if (!obj.inputParams) obj.inputParams = [];
      if (!obj.outParams) obj.outParams = [];
    } else if(resolvedType == 'events') {
      obj['propertyName'] = obj['eventName']
      obj['propertyCode'] = obj['eventCode']
    }
    // alert(JSON.stringify(obj));
    formRef.value.setData(obj);

    // 判断是否为结构体参数
    let field;
    switch (resolvedType) {
      case 'properties':
        field = ['innerJson'];
        break;
      case 'services':
        field = ['inputParams', 'outParams'];
        break;
      case 'events':
        field = ['outParams'];
        break;
    }
    field.forEach((e) => {
      // 服务参数始终绑定渲染，便于空列表时也能「增加参数」
      if (resolvedType === 'services' || obj[e]?.length) {
        setTimeout(() => {
          formRef.value.updateSchema({
            field: e,
            render({ field: _field }) {
              return SubuctRender({
                btnClick: handleShowInner,
                handleEdit,
                list: obj[e] || [],
                field: _field,
                handleDel,
                disabled: disabled.value,
              });
            },
          });
        }, 100);
      }
    });
  });

  const [registerInnerModal, { openModal: openInnerModal }] = useModal();

  const [registerInnerInsideModal, { openModal: openInsideModal }] = useModal();

  const defaultValue = {
    // 读写类型 w：读写 r：只读
    method: 'r',
    // 调用类型 ASYNC：异步 SYNC：同步
    callType: 'ASYNC',
    // 事件类型 INFO：信息 ALERT：告警 ERROR：故障
    eventType: 'INFO',
    boolClose: '关',
    boolOpen: '开',
    length: '10240',
  };

  const handleTabsChange = (key, datatype) => {
    emit('update:editFunctionType', key);
    let schemas: Array<(e) => FormSchema[]> = [];
    let field = '';
    let removeField: string[] = [];
    const fields = [
      ...IntFormSchemas({}),
      ...BoolFormSchemas(),
      ...TextFormSchemas(),
      ...SubuctSchemas({}),
      ...PropsSchemas({}),
    ];
    switch (key) {
      case 'properties':
        schemas = [PropsSchemas];
        field = 'propertyCode';
        removeField = [...ServerSchemas({}), ...EventSchemas({}), ...fields].map((e) => e.field);
        break;
      case 'services':
        schemas = [ServerSchemas];
        field = 'serviceCode';
        removeField = [...PropsSchemas({}), ...EventSchemas({}), ...fields].map((e) => e.field);
        break;
      case 'events':
        schemas = [EventSchemas];
        field = 'eventCode';
        removeField = [...PropsSchemas({}), ...ServerSchemas({}), ...fields].map((e) => e.field);
        break;
    }
    // formRef.value.setSchemas([EditFormSchemas(false, key)], field, [...EditFormSchemas(false, 'properties'), ...fields].map((e) => e.field));

    formRef.value.setSchemas(schemas, field, removeField);
    // formRef.value.removeAllSchemas();

    // 初始化radio
    formRef.value.setData([...EditFormSchemas(false, false), ...fields].map((e) => e.field));

    if (key === 'properties') {
      formRef.value.handleChangeDataType(datatype);
      if (!hideTab.value) {
        formRef.value.setData({
          datatype: defaultValue['datatype'] ?? 'INT',
        });
      }
    }
    if (key === 'services') {
      if (!params.value.inputParams) params.value.inputParams = [];
      if (!params.value.outParams) params.value.outParams = [];
      // 新增模式下绑定参数列表渲染
      if (!hideTab.value) {
        setTimeout(() => {
          ['inputParams', 'outParams'].forEach((e) => {
            formRef.value.updateSchema({
              field: e,
              render({ field: _field }) {
                return SubuctRender({
                  btnClick: handleShowInner,
                  handleEdit,
                  list: params.value[e] || [],
                  field: _field,
                  handleDel,
                  disabled: disabled.value,
                });
              },
            });
          });
        }, 100);
      }
    }
    tabsActive.value = key;
  };

  // 展示结构体参数
  const handleShowInner = async (field: string) => {
    fieldArr.value.push(field);

    if (fieldArr.value.length >= 2) {
      return handleShowInside(fieldArr.value[fieldArr.value.length - 1]);
    }

    if (!params.value[field]) {
      params.value[field] = [];
    }
    // 新增时防止第二弹窗内部数据混乱到第一条数据
    isEditInnerSubuct.value = params.value[field].length;

    openInnerModal();

    nextTick(async () => {
      const schemaFn = tabsActive.value === 'services' ? ServiceParamSchemas : PropsSchemas;
      innerRef.value.setSchemas([schemaFn], 'propertyCode');
      await nextTick();
      //alert(1111);
      innerRef.value.handleChangeDataType('INT');
    });
  };

  const handleShowInside = (field: string) => {
    // alert(9999999);
    fieldArr.value.push(field);
    const [parent, child] = fieldArr.value;
    if (!params.value[parent][isEditInnerSubuct.value ?? 0]) {
      params.value[parent][isEditInnerSubuct.value ?? 0] = {
        [child]: [],
      };
      isEditIsideSubuct.value = 0;
    }
    openInsideModal();
    nextTick(async () => {
      const schemaFn = tabsActive.value === 'services' ? ServiceParamSchemas : PropsSchemas;
      innerInsideRef.value.setSchemas([schemaFn], 'propertyCode');
      await nextTick();
      innerInsideRef.value.handleChangeDataType('INT');
    });
  };

  // 结构体参数编辑
  const handleEdit = (field: string, i: number) => {
    let obj;
    fieldArr.value.push(field);
    let tempRef;
    if (fieldArr.value.length >= 2) {
      isEditIsideSubuct.value = i;
      openInsideModal();
      tempRef = innerInsideRef;
      obj = params.value[fieldArr.value[0]][isEditInnerSubuct.value][field][i];
    } else {
      isEditInnerSubuct.value = i;
      openInnerModal();
      tempRef = innerRef;

      obj = params.value[field][i];
    }
    const schemaFn = tabsActive.value === 'services' ? ServiceParamSchemas : PropsSchemas;
    tempRef.value.setSchemas([schemaFn], 'propertyCode');
    tempRef.value.setData(obj);

    setTimeout(() => {
      // 数据类型在setData之后才能生成其字段表单
      tempRef.value.setData(obj);
      handleChangeSubuct(obj);
    }, 100);
  };

  // 结构体参数删除
  const handleDel = (field: string, i: number) => {
    const [parent, child] = fieldArr.value;
    // 有第三层
    if (fieldArr.value.length >= 2) {
      params.value[parent][isEditInnerSubuct.value ?? 0][child ?? field].splice(i, 1);
    } else {
      params.value[parent ?? field].splice(i, 1);
    }
  };

  const handleInnerSubmit = (res) => {
    const [parent, child] = fieldArr.value;
    const obj = params.value[parent];
    let tempRef;
    if (res.datatype === 'TEXT' && !res.length) {
      res.length = '10240';
    }

    // alert(JSON.stringify(fieldArr));

    if (fieldArr.value.length >= 2) {
      tempRef = innerRef;
      // 编辑状态
      if (isEditIsideSubuct.value !== null) {
        obj[isEditInnerSubuct.value ?? 0][child].splice(isEditIsideSubuct.value, 1, res);
      } else {
        if (obj[isEditInnerSubuct.value ?? 0][child]) {
          obj[isEditInnerSubuct.value ?? 0][child].push(res);
        } else {
          obj[isEditInnerSubuct.value ?? 0][child] = [res];
        }
      }
      isEditInnerSubuct.value = isEditInnerSubuct.value || 0;
    } else {
      tempRef = formRef;
      // 编辑状态
      if (isEditInnerSubuct.value !== null) {
        const temp = obj.splice(isEditInnerSubuct.value, 1);
        // 不改变位置
        obj.splice(isEditInnerSubuct.value, 0, { ...temp[0], ...res });
      } else {
        obj.push(res);
      }
    }

    let list;
    if (fieldArr.value.length >= 2) {
      list = obj[isEditInnerSubuct.value ?? 0][child];
    } else {
      list = obj;
    }
    tempRef.value.validateFields([fieldArr.value[fieldArr.value.length - 1]]);

    // alert(JSON.stringify(list));

    tempRef.value.updateSchema({
      field: fieldArr.value[fieldArr.value.length - 1],
      render({ field }) {
        return SubuctRender({
          btnClick: fieldArr.value.length >= 2 ? handleShowInside : handleShowInner,
          handleEdit,
          list,
          field,
          handleDel,
          disabled: disabled.value,
        });
      },
    });
  };

  const handleInnerClose = (type: 'inner' | 'inside') => {
    if (type === 'inner') {
      fieldArr.value = [];
      isEditInnerSubuct.value = null;
    } else {
      fieldArr.value.splice(1, fieldArr.value.length - 1);
      isEditIsideSubuct.value = null;
    }
  };

  const handleSubmit = () => {
    // 如果为查看模式直接关闭
    if (disabled.value) {
      return handleCancel();
    }
    formRef.value.getData().then((res) => {
      const temp = {
        ...params.value,
        ...res,
        // 功能类型
        functionType: tabsActive.value,
      };

      const {
        name,
        functionType,
        propertyCode,
        eventType,
        status,
        createTime,
        datatype,
        id,
        remark,
        ...functionJson
      } = temp;

      delete functionJson.functionJson;

      emit('submit', {
        name,
        functionType,
        propertyCode,
        eventType,
        status,
        createTime,
        datatype,
        functionJson,
        id,
        remark,
      });
      handleCancel();
    });
  };

  const handleChangeSubuct = (obj) => {
    let field = 'innerJson';
    // alert(JSON.stringify(obj));

    if (!obj[field]?.length) return;

    setTimeout(() => {
      innerRef.value.updateSchema({
        field,
        render({ field: _field }) {
          return SubuctRender({
            btnClick: handleShowInside,
            handleEdit,
            list: obj[field],
            field: _field,
            handleDel,
            disabled: disabled.value,
          });
        },
      });
    }, 100);
  };

  const handleCancel = () => {
    formRef.value.reset();
    params.value = {
      innerJson: [],
      id: '',
    };
    tabsActive.value = 'properties';
    nextTick(() => {
      closeModal();
    });
  };

  // 检查标识符是否重复
  const handleCheckIdentifier = throttle((propertyCode: string) => {
    return new Promise<void>((resolve, reject) => {
      const _params = {
        propertyCode,
        productIdentification: props.productIdentification,
        id: params.value.id ?? '',
      };
      // alert(4548/933545);
      checkIdentifier(_params).then((res) => {
        if (!res.status) return resolve();
        return reject();
      });
    });
  }, 800);

  // 校验结构体参数
  const handleCheckSubuct = (field: string) => {
    const parent = fieldArr.value[0];
    return new Promise<void>((resolve, reject) => {
      if (!parent) {
        if (params.value[field].length) return resolve();
        return reject();
      } else {
        if (params.value[parent][isEditInnerSubuct.value ?? 0][field].length) return resolve();
        return reject();
      }
    });
  };
</script>

<style lang="less" scoped></style>

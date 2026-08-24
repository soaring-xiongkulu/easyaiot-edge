<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="drawerTitle"
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
        <Button type="primary" @click="handleSubmit">保存</Button>
      </div>
    </template>

    <div class="rulechain-drawer-content">
      <template v-if="tplType === 'add' || tplType === 'edit'">
        <BasicForm @register="registerForm" :model="model" />
      </template>
      <!-- 导入规则 -->
      <template v-else-if="tplType === 'import'">
        <UploadDragger
          v-model:fileList="fileList"
          name="file"
          accept=".json"
          :multiple="false"
          :customRequest="httpRequest"
          @change="handleUploadChange"
        >
          <CloudUploadOutlined :style="{ fontSize: '50px', color: '#1890ff' }" />
          <p class="ant-upload-text">单击或拖动文件到此区域进行上传</p>
          <p class="ant-upload-hint"> 导入JSON格式的文件上传规则链 </p>
        </UploadDragger>
      </template>
    </div>
  </BasicDrawer>
</template>
<script lang="ts">
  import { defineComponent, ref } from 'vue';
  import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
  import { BasicForm, FormSchema, useForm } from '@/components/Form';
  import { updateflows, addFlows, getFlows } from '@/api/device/rule-chains';
  import { useMessage } from '@/hooks/web/useMessage';
  import { Upload } from 'ant-design-vue';
  import { CloudUploadOutlined } from '@ant-design/icons-vue';
  import { Button } from '@/components/Button';
  import { isNodeRedDemoFlow } from '@/utils/noderedDemo';

  const schemas: FormSchema[] = [
    {
      field: 'label',
      component: 'Input',
      label: '名称',
      colProps: {
        span: 24,
      },
      rules: [
        {
          required: true,
          // @ts-ignore
          validator: async (rule, value) => {
            if (!value) {
              /* eslint-disable-next-line */
              return Promise.reject('值不能为空');
            }
            return Promise.resolve();
          },
          trigger: 'change',
        },
      ],
    },
    {
      field: 'disabled',
      component: 'Checkbox',
      label: '状态',
      colProps: {
        span: 24,
      },
      defaultValue: false,
    },
  ];
  const UploadDragger = Upload.Dragger;
  export default defineComponent({
    components: { BasicDrawer, BasicForm, UploadDragger, CloudUploadOutlined, Button },
    props: {
      userData: { type: Object },
    },
    setup(_, { emit }) {
      const modelRef = ref({});
      const { createMessage } = useMessage();
      const tplType = ref<string>('add');
      const drawerTitle = ref('添加规则');
      const [
        registerForm,
        {
          validateFields,
          resetFields,
          setFieldsValue,
        },
      ] = useForm({
        labelWidth: 150,
        schemas,
        showActionButtonGroup: false,
        actionColOptions: {
          span: 24,
        },
      });

      const detail = ref({});
      const flowsId = ref('');

      const [register, { closeDrawer, setDrawerProps }] = useDrawerInner((data) => {
        detail.value = {};
        data && onDataReceive(data);
      });

      function onDataReceive(_data) {
        console.log('Data Received', _data);
        const { info, isEdit, data } = _data;
        resetFields();
        tplType.value = info;
        const ModalTitle = tplType.value === 'add' ? '添加规则' : isEdit ? '编辑规则' : '导入规则';
        drawerTitle.value = ModalTitle;
        if (isEdit && data && data.id) {
          flowsId.value = data.id;
          getFlows(data.id).then((res) => {
            detail.value = res;
          }).catch((error) => {
            console.error('获取规则链详情失败:', error);
          });
          setFieldsValue({
            ...data,
          });
        }
        setDrawerProps({ title: ModalTitle });
      }

      function handleCancel() {
        closeDrawer();
      }

      async function handleSubmit() {
        try {
          let params = {};
          const res = await validateFields();
          params = { ...res, nodes: [], configs: [] };

          try {
            if (tplType.value === 'add') {
              await addFlows(params);
            } else if (tplType.value === 'edit') {
              if (!flowsId.value || flowsId.value === 'undefined') {
                createMessage.error('规则链ID无效！');
                return;
              }
              if (isNodeRedDemoFlow({ id: flowsId.value, label: (params as any)?.label })) {
                createMessage.warning('EasyAIoT 演示规则链为只读，禁止修改');
                return;
              }
              await updateflows(flowsId.value, params);
            }
            createMessage.success('操作成功！');
            closeDrawer();
            emit('success', {});
          } catch (error: any) {
            console.error(error);
            createMessage.error(error?.message || '操作失败！');
          }
        }catch (error) {
          console.error(error)
          console.log('not passing', error);
        }
      }

      function handleChange(list: string[]) {
        console.log(`已上传文件${JSON.stringify(list)}`);
      }

      const handleUploadChange = (info) => {
        const status = info.file.status;
        if (status !== 'uploading') {
          console.log(info.file, info.fileList);
        }
        if (status === 'done') {
          console.log(`${info.file.name} file uploaded successfully.`);
        } else if (status === 'error') {
          console.log(`${info.file.name} file upload failed.`);
        }
      };

      function httpRequest(data) {
        const isJson = data.file.type === 'application/json';
        if (isJson) {
          const reader = new FileReader();
          reader.onload = (evt) => {
            try {
              console.log(evt);
              data.onSuccess();
            }catch (error) {
              console.error(error)
              createMessage.error(String(error));
              data.onError();
            }
          };
          reader.readAsText(data.file);
        } else {
          createMessage.error('应用库只能上传JSON文件');
        }
      }

      return {
        httpRequest,
        fileList: ref([]),
        handleUploadChange,
        handleChange,
        handleSubmit,
        handleCancel,
        register,
        schemas,
        registerForm,
        model: modelRef,
        tplType,
        drawerTitle,
      };
    },
  });
</script>
<style lang="less" scoped>
.rulechain-drawer-content {
  padding: 8px 16px 0;
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>

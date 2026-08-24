<template>
  <BasicModal
    v-bind="$attrs"
    title="导入用户"
    :width="920"
    :useWrapper="false"
    wrapClassName="user-import-modal"
    :confirm-loading="uploadLoading"
    ok-text="开始导入"
    @register="register"
    @ok="handleSubmit"
  >
    <Table
      class="user-import-table"
      size="small"
      bordered
      :pagination="false"
      :columns="guideColumns"
      :data-source="guideRows"
      row-key="msgType"
      style="margin-bottom: 16px"
    />

    <div class="user-import-actions">
      <Button :loading="downloadLoading" preIcon="ant-design:download-outlined" @click="handleDownloadTemplate">下载导入模版</Button>
    </div>

    <Upload.Dragger
      :file-list="fileList"
      accept=".xlsx,.xls"
      :max-count="1"
      :before-upload="beforeUpload"
      @remove="handleRemove"
    >
      <p class="ant-upload-drag-icon">
        <InboxOutlined />
      </p>
      <p class="ant-upload-text">点击或拖拽 Excel 文件到此处</p>
      <p class="ant-upload-hint">仅支持 .xlsx、.xls 格式</p>
    </Upload.Dragger>
  </BasicModal>
</template>

<script lang="ts" setup>
  import { h, ref } from 'vue';
  import { Table, Upload } from 'ant-design-vue';
  import { InboxOutlined } from '@ant-design/icons-vue';
  import type { UploadFile } from 'ant-design-vue';
  import { Button } from '@/components/Button';
  import { BasicModal, useModalInner } from '/@/components/Modal';
  import { useMessage } from '/@/hooks/web/useMessage';
  import Icon from '@/components/Icon/index';
  import { messagePreviewUserExportExcel, messagePreviewUserImport } from '/@/api/modules/user';
  import { IMPORT_GUIDE_ROWS } from '../Data';

  defineOptions({ name: 'UserImportModal' });

  const emit = defineEmits<{ success: [] }>();

  const guideRows = IMPORT_GUIDE_ROWS.map((row, index) => ({ ...row, key: index }));

  const { createMessage, notification } = useMessage();
  const uploadLoading = ref(false);
  const downloadLoading = ref(false);
  const selectedFile = ref<File | null>(null);
  const fileList = ref<UploadFile[]>([]);

  const guideColumns = [
    { title: '消息通知类型', dataIndex: 'msgType', width: 120 },
    { title: '目标用户格式', dataIndex: 'format', width: 160 },
    { title: '填写提示', dataIndex: 'hint' },
    { title: '示例', dataIndex: 'previewUser', width: 300 },
  ];

  const [register, { closeModal, setModalProps }] = useModalInner(() => {
    selectedFile.value = null;
    fileList.value = [];
    uploadLoading.value = false;
    downloadLoading.value = false;
    setModalProps({ confirmLoading: false });
  });

  const parseImportErrors = (message: string) => {
    if (!message) {
      return ['导入失败'];
    }
    try {
      const parsed = JSON.parse(message);
      return Array.isArray(parsed) ? parsed : [message];
    } catch {
      return [message];
    }
  };

  const handleDownloadTemplate = async () => {
    downloadLoading.value = true;
    try {
      await messagePreviewUserExportExcel();
    } catch (error) {
      console.error(error);
      createMessage.error('下载模板失败');
    } finally {
      downloadLoading.value = false;
    }
  };

  const beforeUpload = (file: File) => {
    if (file.size > 1048576) {
      createMessage.warning('文件不能超过 1MB');
      return Upload.LIST_IGNORE;
    }
    selectedFile.value = file;
    fileList.value = [
      {
        uid: '-1',
        name: file.name,
        status: 'done',
      },
    ];
    return false;
  };

  const handleRemove = () => {
    selectedFile.value = null;
    fileList.value = [];
  };

  const handleSubmit = async () => {
    if (!selectedFile.value) {
      createMessage.warning('请先选择要导入的 Excel 文件');
      return;
    }
    uploadLoading.value = true;
    setModalProps({ confirmLoading: true });
    try {
      const formData = new FormData();
      formData.append('file', selectedFile.value);
      const ret = await messagePreviewUserImport(formData);
      createMessage.success(typeof ret === 'string' ? ret : ret?.msg || '导入成功');
      emit('success');
      closeModal();
    } catch (error) {
      console.error(error);
      const errorList = parseImportErrors(error instanceof Error ? error.message : '导入失败');
      notification.open({
        getContainer: () => document.querySelector('.user-warpper'),
        placement: 'topLeft',
        message: '导入失败',
        description: errorList.map((item) => h('div', item)),
        icon: () => h(Icon, { style: 'color: red', icon: 'mi:circle-error', size: 22 }),
      });
    } finally {
      uploadLoading.value = false;
      setModalProps({ confirmLoading: false });
    }
  };
</script>

<style lang="less" scoped>
  .user-import-actions {
    margin-bottom: 16px;
  }

  .user-import-table {
    :deep(.ant-table-cell) {
      white-space: normal;
      word-break: break-word;
      vertical-align: top;
      line-height: 1.5;
    }
  }
</style>

<style lang="less">
  .user-import-modal {
    .ant-modal-body {
      overflow: visible;
    }
  }
</style>

<script lang="ts" setup>
import { ref } from 'vue';
import { Spin } from 'ant-design-vue';
import { controlPlanePeerFormSchema } from '../../Data';
import { useMessage } from '@/hooks/web/useMessage';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { BasicForm, useForm } from '@/components/Form';
import { BasicTitle } from '@/components/Basic';
import { Icon } from '@/components/Icon';
import { Button } from '@/components/Button';
import { createControlPlanePeer } from '@/api/device/node';
import { NODE_TERM } from '../../utils/constants';

defineOptions({ name: 'ControlPlanePeerDrawer' });

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();
const submitting = ref(false);

const [registerForm, { resetFields, validate }] = useForm({
  labelWidth: 150,
  schemas: controlPlanePeerFormSchema,
  showActionButtonGroup: false,
  baseColProps: { span: 24 },
});

const [registerDrawer, { closeDrawer }] = useDrawerInner(async () => {
  resetFields();
});

async function handleSubmit() {
  let values: Record<string, string>;
  try {
    values = (await validate()) as Record<string, string>;
  } catch {
    return;
  }
  const name = String(values.name || '').trim();
  const apiBaseUrl = String(values.apiBaseUrl || '').trim();
  if (!name || !apiBaseUrl) {
    createMessage.warning('请填写中心节点名称与 API 地址');
    return;
  }
  submitting.value = true;
  try {
    await createControlPlanePeer({
      name,
      apiBaseUrl,
      peerToken: String(values.peerToken || '').trim() || undefined,
      remark: String(values.remark || '').trim() || undefined,
    });
    createMessage.success('中心节点已添加并完成互联同步');
    closeDrawer();
    emit('success');
  } finally {
    submitting.value = false;
  }
}

function handleCancel() {
  closeDrawer();
}
</script>

<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="registerDrawer"
    width="1400"
    placement="right"
    :showFooter="true"
    :showOkBtn="false"
    :showCancelBtn="false"
    destroy-on-close
    root-class-name="central-peer-drawer"
  >
    <template #title>
      <div class="central-drawer-header">
        <div class="central-drawer-header__main">
          <div class="central-drawer-header__icon">
            <Icon icon="ant-design:cluster-outlined" :size="22" />
          </div>
          <div>
            <BasicTitle span class="central-drawer-header__title">{{ NODE_TERM.addCentralNode }}</BasicTitle>
            <div class="central-drawer-header__meta">
              填写对端中心节点 API 信息，保存后将自动完成双向互联同步
            </div>
          </div>
        </div>
      </div>
    </template>

    <template #footer>
      <div class="footer-buttons">
        <Button @click="handleCancel">取消</Button>
        <Button type="primary" :loading="submitting" @click="handleSubmit">
          添加并同步
        </Button>
      </div>
    </template>

    <Spin :spinning="submitting">
      <div class="central-drawer-content">
        <div class="central-drawer-form-card">
          <BasicForm @register="registerForm" />
        </div>
      </div>
    </Spin>
  </BasicDrawer>
</template>

<style lang="less" scoped>
@import '../../utils/setup-panel.less';

.central-drawer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  width: 100%;
  padding-right: 32px;
}

.central-drawer-header__main {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.central-drawer-header__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: linear-gradient(135deg, #eef4ff, #dce8ff);
  color: @node-primary;
  flex-shrink: 0;
}

.central-drawer-header__title {
  font-size: 18px !important;
  font-weight: 600 !important;
}

.central-drawer-header__meta {
  margin-top: 2px;
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
  line-height: 1.5;
}

.central-drawer-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
  min-height: 100%;
  padding: 4px 0 8px;
}

.central-drawer-form-card {
  .setup-section-card();
  .setup-form-label();
}

.footer-buttons {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
}
</style>

<template>
  <BasicDrawer @register="register" title="推送详情" width="520px">
    <Description @register="registerDesc" />
  </BasicDrawer>
</template>

<script lang="ts" setup>
  import { ref } from 'vue';
  import { BasicDrawer, useDrawerInner } from '/@/components/Drawer';
  import { Description, useDescription } from '/@/components/Description/index';
  import { formatToDateTime } from '/@/utils/dateUtil';
  import { getHistoryDetailSchema, getMsgTypeLabel } from './Data.tsx';

  const record = ref<Record<string, any>>({});

  const [registerDesc, { setDescProps }] = useDescription({
    column: 1,
    layout: 'vertical',
  });

  const [register] = useDrawerInner((data) => {
    record.value = data?.record || {};
    setDescProps({
      schema: getHistoryDetailSchema(),
      data: {
        ...record.value,
        msgTypeLabel: getMsgTypeLabel(record.value.msgType),
        createTimeLabel: record.value.createTime
          ? formatToDateTime(record.value.createTime)
          : '-',
      },
    });
  });
</script>

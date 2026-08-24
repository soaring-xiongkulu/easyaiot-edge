<template><div><MsgTemplate pushType="sms" :columns="columns" /></div></template>
<script lang="ts" setup>
  import MsgTemplate from '../MsgTemplate/index.vue';
  const columns = [{ title: '短信模板ID', dataIndex: 'templateId' }];
</script>

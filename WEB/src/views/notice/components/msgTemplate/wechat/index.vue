<template><div><MsgTemplate pushType="weixin" :columns="columns" /></div></template>
<script lang="ts" setup>
  import MsgTemplate from '../MsgTemplate/index.vue';
  const columns = [{ title: '标题', dataIndex: 'title' }, { title: '内容', dataIndex: 'content' }];
</script>

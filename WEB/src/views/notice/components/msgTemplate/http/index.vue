<template><div><MsgTemplate pushType="http" :columns="columns" /></div></template>
<script lang="ts" setup>
  import MsgTemplate from '../MsgTemplate/index.vue';
  const columns = [{ title: 'URL', dataIndex: 'url' }, { title: '方法', dataIndex: 'method' }];
</script>

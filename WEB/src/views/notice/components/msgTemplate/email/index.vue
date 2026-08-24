<template>
  <div><MsgTemplate pushType="email" :columns="columns" /></div>
</template>
<script lang="ts" setup>
  import MsgTemplate from '../MsgTemplate/index.vue';
  const columns = [{ title: '邮件标题', dataIndex: 'title' }, { title: '内容', dataIndex: 'content' }];
</script>

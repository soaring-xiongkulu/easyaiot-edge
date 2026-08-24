<template>
  <div class="table-wrapper">
    <Table
      :columns="columns"
      :data-source="dataSource"
      bordered
      :pagination="false"
      :scroll="tableScroll"
    >
      <template #bodyCell="{ column, record }">
        <template
          v-if="
            [
              'key_',
              'value',
              'appName',
              'name',
              'agentId',
              'secret',
              'appSecret',
              'appKey',
              'domain',
              'path',
            ].includes(column.dataIndex)
          "
        >
          <Input v-model:value="record[column.dataIndex]" />
        </template>
        <template v-else-if="column.dataIndex === 'time'">
          <DatePicker
            v-model:value="record[column.dataIndex]"
            allowClear
            showTime
            valueFormat="x"
          />
        </template>
        <template v-else-if="column.dataIndex === 'operation'">
          <Button type="text" danger @click="handleDelete(record.id)">
            <template #icon>
              <DeleteOutlined />
            </template>
          </Button>
        </template>
      </template>
    </Table>
    <Button type="dashed" @click="handleAdd" style="width: 100%; margin-top: 5px">
      <template #icon>
        <PlusOutlined />
      </template>
      添加
    </Button>
  </div>
</template>

<script setup lang="ts">
  import { PlusOutlined, DeleteOutlined } from '@ant-design/icons-vue';
  import { PropType, computed } from 'vue';
  import { Table, Input, DatePicker } from 'ant-design-vue';
  import { Button } from '@/components/Button';

  type Emits = {
    (e: 'update:list', data: any[]): void;
  };
  const emit = defineEmits<Emits>();

  const props = defineProps({
    list: {
      type: Array as PropType<any[]>,
      default: () => [],
    },
    columns: {
      type: Array as PropType<any[]>,
      default: () => [],
    },
  });

  const dataSource = computed({
    get: () => props.list,
    set: (val) => emit('update:list', val),
  });

  const tableScroll = computed(() => {
    const hasFixed = props.columns.some((col) => col.fixed);
    if (!hasFixed) return undefined;
    const width = props.columns.reduce(
      (sum, col) => sum + (Number(col.width) || 120),
      0,
    );
    return { x: width };
  });

  const handleDelete = (id: number) => {
    const idx = dataSource.value.findIndex((f) => f.id === id);
    dataSource.value.splice(idx, 1);
  };
  const handleAdd = () => {
    const value = props.columns.reduce((p, c) => {
      if (!['operation'].includes(c.dataIndex)) {
        p[c.dataIndex] = '';
      }
      return p;
    }, {});
    dataSource.value.push({
      id: dataSource.value.length,
      ...value,
    });
    // console.log(' dataSource.value ...', dataSource.value);
  };
</script>

<style lang="less" scoped></style>

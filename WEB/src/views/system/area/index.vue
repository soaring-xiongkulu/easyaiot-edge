<script lang="ts" setup>
import AreaModal from './AreaModal.vue'
import { columns } from './area.data'
import { useI18n } from '@/hooks/web/useI18n'
import { useModal } from '@/components/Modal'
import { IconEnum } from '@/enums/appEnum'
import { BasicTable, useTable } from '@/components/Table'
import { getAreaTree } from '@/api/system/area'
import { Button } from '@/components/Button'
defineOptions({ name: 'SystemArea' })

const { t } = useI18n()

const [registerModal, { openModal }] = useModal()

const [register, { expandAll, collapseAll, reload }] = useTable({
  title: 'IP 地区列表',
  api: getAreaTree,
  columns,
  rowKey: 'id',
  isTreeTable: true,
  pagination: true,
  striped: false,
  useSearchForm: false,
  showTableSetting: true,
  bordered: true,
  showIndexColumn: false,
  canResize: true,
})

function handleCreate() {
  openModal(true, { isUpdate: false })
}
</script>

<template>
  <div>
    <BasicTable class="p-4" @register="register">
      <template #toolbar>
        <Button type="primary" :preIcon="IconEnum.ADD" @click="handleCreate">
          IP 查询
        </Button>
        <Button @click="expandAll">
          {{ t('component.tree.expandAll') }}
        </Button>
        <Button @click="collapseAll">
          {{ t('component.tree.unExpandAll') }}
        </Button>
      </template>
    </BasicTable>
    <AreaModal @register="registerModal" @success="reload()" />
  </div>
</template>

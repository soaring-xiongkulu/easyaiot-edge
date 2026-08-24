<template>
  <BasicDrawer
    v-bind="$attrs"
    @register="register"
    :title="drawerTitle"
    width="840"
    placement="right"
    :mask-closable="true"
    :show-footer="false"
  >
    <div class="group-policy-drawer">
      <div class="summary-card" :class="summaryCardClass">
        <div class="summary-card__icon">
          <Icon :icon="groupTypeIcon" :size="28" />
        </div>
        <div class="summary-card__main">
          <div class="summary-card__title-row">
            <span class="summary-card__name">{{ groupName }}</span>
            <Tag :color="groupTypeTagColor">{{ groupTypeLabel }}</Tag>
          </div>
          <div class="summary-card__meta">
            <span v-if="groupMeta">{{ groupMeta }}</span>
            <span v-if="childCount != null" class="summary-card__count">
              {{ childCount }} 个{{ kindLabel }}空间
            </span>
          </div>
          <div class="summary-card__current">
            当前默认保存：
            <strong>{{ formatSaveTimeLabel(initialSaveTime) }}</strong>
          </div>
        </div>
      </div>

      <section class="policy-section">
        <div class="section-head">
          <h3 class="section-title">默认保存时长</h3>
          <span class="section-desc">点击下方常用选项，或自定义天与小时</span>
        </div>

        <div class="preset-grid">
          <button
            v-for="preset in saveTimePresets"
            :key="preset.key"
            type="button"
            class="preset-chip"
            :class="{ 'preset-chip--active': saveTime === preset.value }"
            @click="selectPreset(preset.value)"
          >
            <span class="preset-chip__label">{{ preset.label }}</span>
            <span v-if="preset.hint" class="preset-chip__hint">{{ preset.hint }}</span>
          </button>
        </div>

        <div class="custom-row">
          <span class="custom-row__label">自定义时长</span>
          <SaveTimeInput v-model:value="saveTime" class="custom-row__input-wrap" />
        </div>

        <div v-if="previewLabel" class="preview-text">
          将设为 <strong>{{ previewLabel }}</strong>
        </div>

        <div class="section-actions">
          <Button @click="closeDrawer">取消</Button>
          <Button
            type="primary"
            :loading="confirmLoading"
            :disabled="!hasChanged"
            @click="handleSubmit"
          >
            保存
          </Button>
        </div>
      </section>
    </div>
  </BasicDrawer>
</template>

<script lang="ts" setup>
import { computed, ref } from 'vue';
import { Tag } from 'ant-design-vue';
import { BasicDrawer, useDrawerInner } from '@/components/Drawer';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import { updateSnapSpaceGroupPolicy } from '@/api/device/snap';
import { updateRecordSpaceGroupPolicy } from '@/api/device/record';
import SaveTimeInput from './SaveTimeInput.vue';
import {
  DEFAULT_SAVE_TIME,
  formatSaveTimeLabel,
  getSpaceKindLabel,
  isValidSaveTime,
  type SpaceFolderType,
  type SpaceKind,
} from '@/views/camera/utils/spaceSaveTime';

defineOptions({ name: 'GroupSaveTimeDrawer' });

interface GroupPolicyDrawerData {
  spaceKind?: SpaceKind;
  groupType?: SpaceFolderType;
  groupKey?: string;
  groupName?: string;
  saveTime?: number;
  childCount?: number;
  ip?: string;
  port?: number;
  sipDeviceId?: string;
}

const SAVE_TIME_PRESETS = [
  { key: '1h', label: '1 小时', value: 1, hint: '推荐默认' },
  { key: '24h', label: '1 天', value: 24, hint: '' },
  { key: '7d', label: '7 天', value: 168, hint: '' },
  { key: '30d', label: '30 天', value: 720, hint: '约 1 个月' },
  { key: '90d', label: '90 天', value: 2160, hint: '约 3 个月' },
  { key: 'forever', label: '永久保存', value: 0, hint: '占用持续增长' },
] as const;

const emit = defineEmits(['success', 'register']);

const { createMessage } = useMessage();

const spaceKind = ref<SpaceKind>('snap');
const groupType = ref<SpaceFolderType>('nvr');
const groupKey = ref('');
const groupName = ref('');
const childCount = ref<number | null>(null);
const groupIp = ref<string>();
const groupPort = ref<number>();
const sipDeviceId = ref<string>();
const saveTime = ref(DEFAULT_SAVE_TIME);
const initialSaveTime = ref(DEFAULT_SAVE_TIME);
const confirmLoading = ref(false);

const saveTimePresets = SAVE_TIME_PRESETS;

const kindLabel = computed(() => getSpaceKindLabel(spaceKind.value));

const drawerTitle = computed(() => `${groupTypeLabel.value} 分组${kindLabel.value}存储策略`);

const groupTypeLabel = computed(() => (groupType.value === 'nvr' ? 'NVR' : 'GB28181'));

const groupTypeIcon = computed(() =>
  groupType.value === 'nvr' ? 'ant-design:hdd-outlined' : 'ant-design:cluster-outlined',
);

const groupTypeTagColor = computed(() => (groupType.value === 'nvr' ? 'orange' : 'green'));

const summaryCardClass = computed(() =>
  groupType.value === 'nvr' ? 'summary-card--nvr' : 'summary-card--gb28181',
);

const groupMeta = computed(() => {
  if (groupType.value === 'nvr' && groupIp.value) {
    return `NVR ${groupIp.value}${groupPort.value ? `:${groupPort.value}` : ''}`;
  }
  if (groupType.value === 'gb28181' && sipDeviceId.value) {
    return `国标设备 ID ${sipDeviceId.value}`;
  }
  return '';
});

const previewLabel = computed(() => {
  if (saveTime.value == null || Number.isNaN(Number(saveTime.value))) return '';
  return formatSaveTimeLabel(Number(saveTime.value));
});

const hasChanged = computed(() => saveTime.value !== initialSaveTime.value);

const [register, { setDrawerProps, closeDrawer }] = useDrawerInner(async (data: GroupPolicyDrawerData) => {
  setDrawerProps({ confirmLoading: false });
  spaceKind.value = data?.spaceKind ?? 'snap';
  groupType.value = data?.groupType ?? 'nvr';
  groupKey.value = String(data?.groupKey ?? '');
  groupName.value = data?.groupName ?? '';
  childCount.value = data?.childCount ?? null;
  groupIp.value = data?.ip;
  groupPort.value = data?.port;
  sipDeviceId.value = data?.sipDeviceId;
  initialSaveTime.value = data?.saveTime ?? DEFAULT_SAVE_TIME;
  saveTime.value = initialSaveTime.value;
});

function selectPreset(value: number) {
  saveTime.value = value;
}

async function handleSubmit() {
  if (!groupKey.value) return;
  const hours = Number(saveTime.value);
  if (!isValidSaveTime(hours)) {
    createMessage.warning('保存时间须为永久，或不少于 1 小时');
    return;
  }
  if (!hasChanged.value) {
    createMessage.info('保存时长未变更');
    closeDrawer();
    return;
  }
  confirmLoading.value = true;
  setDrawerProps({ confirmLoading: true });
  try {
    const payload = {
      group_type: groupType.value,
      group_key: groupKey.value,
      save_time: hours,
    };
    const api = spaceKind.value === 'snap' ? updateSnapSpaceGroupPolicy : updateRecordSpaceGroupPolicy;
    const res = await api(payload);
    if (res?.code !== undefined && res.code !== 0) {
      createMessage.error(res.msg || '保存失败');
      return;
    }
    const updated = res?.data?.updated_count ?? 0;
    createMessage.success(
      `分组默认保存时间已设为 ${formatSaveTimeLabel(hours)}${updated ? `，已同步 ${updated} 个设备空间` : ''}`,
    );
    closeDrawer();
    emit('success');
  } catch (e) {
    console.error(e);
    createMessage.error('保存分组存储策略失败');
  } finally {
    confirmLoading.value = false;
    setDrawerProps({ confirmLoading: false });
  }
}
</script>

<style lang="less" scoped>
.group-policy-drawer {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding-bottom: 8px;
}

.summary-card {
  display: flex;
  gap: 16px;
  padding: 20px;
  border-radius: 10px;
  border: 1px solid #e8edf3;
  background: linear-gradient(135deg, #fafbfc 0%, #f4f7fb 100%);

  &--nvr {
    border-color: #f3e8d8;
    background: linear-gradient(135deg, #fffbf5 0%, #fdf6ea 100%);

    .summary-card__icon {
      color: #d4922f;
      background: rgba(212, 146, 47, 0.12);
    }
  }

  &--gb28181 {
    border-color: #dcefe8;
    background: linear-gradient(135deg, #f4fbf8 0%, #eaf6f1 100%);

    .summary-card__icon {
      color: #3fa882;
      background: rgba(63, 168, 130, 0.12);
    }
  }

  &__icon {
    flex-shrink: 0;
    width: 52px;
    height: 52px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 10px;
    color: #4d8fd8;
    background: rgba(77, 143, 216, 0.12);
  }

  &__main {
    flex: 1;
    min-width: 0;
  }

  &__title-row {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
    margin-bottom: 6px;
  }

  &__name {
    font-size: 18px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.88);
    line-height: 1.4;
    word-break: break-all;
  }

  &__meta {
    display: flex;
    flex-wrap: wrap;
    gap: 8px 12px;
    font-size: 13px;
    color: rgba(0, 0, 0, 0.55);
    margin-bottom: 8px;
  }

  &__count {
    color: rgba(0, 0, 0, 0.45);
  }

  &__current {
    font-size: 14px;
    color: rgba(0, 0, 0, 0.65);

    strong {
      color: rgba(0, 0, 0, 0.88);
      font-weight: 600;
    }
  }
}

.policy-section {
  padding: 20px;
  border-radius: 10px;
  border: 1px solid #eef1f5;
  background: #fff;
}

.section-head {
  margin-bottom: 16px;
}

.section-title {
  margin: 0 0 4px;
  font-size: 16px;
  font-weight: 600;
  color: rgba(0, 0, 0, 0.88);
}

.section-desc {
  font-size: 13px;
  color: rgba(0, 0, 0, 0.45);
}

.preset-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
  margin-bottom: 18px;
}

.preset-chip {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 2px;
  padding: 12px 14px;
  border: 1px solid #e5e9ef;
  border-radius: 8px;
  background: #fafbfc;
  cursor: pointer;
  text-align: left;
  transition:
    border-color 0.15s ease,
    background-color 0.15s ease,
    box-shadow 0.15s ease;

  &:hover {
    border-color: #b8ccf0;
    background: #f5f9ff;
  }

  &--active {
    border-color: #4d8fd8;
    background: #eff6ff;
    box-shadow: 0 0 0 2px rgba(77, 143, 216, 0.12);

    .preset-chip__label {
      color: #2563eb;
      font-weight: 600;
    }
  }

  &__label {
    font-size: 15px;
    color: rgba(0, 0, 0, 0.88);
    line-height: 1.3;
  }

  &__hint {
    font-size: 12px;
    color: rgba(0, 0, 0, 0.4);
    line-height: 1.3;
  }
}

.custom-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px 10px;
  padding: 14px 16px;
  border-radius: 8px;
  background: #f8fafc;
  border: 1px dashed #dde3ea;

  &__label {
    flex: 0 0 100%;
    font-size: 14px;
    font-weight: 500;
    color: rgba(0, 0, 0, 0.75);
    margin-bottom: 4px;
  }

  &__input-wrap {
    flex: 1 1 100%;
  }
}

.preview-text {
  margin-top: 14px;
  font-size: 14px;
  color: rgba(0, 0, 0, 0.65);
  line-height: 1.5;

  strong {
    color: rgba(0, 0, 0, 0.88);
    font-weight: 600;
  }
}

.section-actions {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  gap: 8px;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid #eef1f5;
}

@media (max-width: 720px) {
  .preset-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

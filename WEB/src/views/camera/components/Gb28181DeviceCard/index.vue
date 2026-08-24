<template>
  <div class="product-info">
    <div class="status">{{ item.onLine ? '在线' : '离线' }}</div>
    <div class="title o2">{{ item.name }}</div>
    <div class="props">
      <div class="prop">
        <div class="label">设备编码</div>
        <div class="value">{{ item.deviceIdentification }}</div>
      </div>
      <div class="flex" style="justify-content: space-between">
        <div class="prop">
          <div class="label">IP地址</div>
          <div class="value">{{ item.ip || '-' }}</div>
        </div>
        <div class="prop">
          <div class="label">媒体唯一标识</div>
          <div class="value">{{ item.mediaServerId || '-' }}</div>
        </div>
      </div>
    </div>
    <div class="btns" @click.stop>
      <div class="btn" title="刷新通道" @click="emit('refresh', item)">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 1024 1024">
          <path
            fill="#266CFBFF"
            d="M168 504.2c1-43.7 10-86.1 26.9-126c17.3-41 42.1-77.7 73.7-109.4S337 212.3 378 195c42.4-17.9 87.4-27 133.9-27s91.5 9.1 133.8 27A341.5 341.5 0 0 1 755 268.8c9.9 9.9 19.2 20.4 27.8 31.4l-60.2 47a8 8 0 0 0 3 14.1l175.7 43c5 1.2 9.9-2.6 9.9-7.7l.8-180.9c0-6.7-7.7-10.5-12.9-6.3l-56.4 44.1C765.8 155.1 646.2 92 511.8 92C282.7 92 96.3 275.6 92 503.8a8 8 0 0 0 8 8.2h60c4.4 0 7.9-3.5 8-7.8m756 7.8h-60c-4.4 0-7.9 3.5-8 7.8c-1 43.7-10 86.1-26.9 126c-17.3 41-42.1 77.8-73.7 109.4A342.45 342.45 0 0 1 512.1 856a342.24 342.24 0 0 1-243.2-100.8c-9.9-9.9-19.2-20.4-27.8-31.4l60.2-47a8 8 0 0 0-3-14.1l-175.7-43c-5-1.2-9.9 2.6-9.9 7.7l-.7 181c0 6.7 7.7 10.5 12.9 6.3l56.4-44.1C258.2 868.9 377.8 932 512.2 932c229.2 0 415.5-183.7 419.8-411.8a8 8 0 0 0-8-8.2"
          />
        </svg>
      </div>
      <div class="btn" title="查看通道" @click="emit('open', item)">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
          <path
            fill="#266CFBFF"
            fill-opacity=".15"
            d="M136 792h576V232H136zm64-488c0-4.4 3.6-8 8-8h112c4.4 0 8 3.6 8 8v48c0 4.4-3.6 8-8 8H208c-4.4 0-8-3.6-8-8z"
          />
          <path
            fill="#266CFBFF"
            d="M912 302.3L784 376V224c0-35.3-28.7-64-64-64H128c-35.3 0-64 28.7-64 64v576c0 35.3 28.7 64 64 64h592c35.3 0 64-28.7 64-64V648l128 73.7c21.3 12.3 48-3.1 48-27.6V330c0-24.6-26.7-40-48-27.7M712 792H136V232h576zm176-167l-104-59.8V458.9L888 399z"
          />
          <path
            fill="#266CFBFF"
            d="M208 360h112c4.4 0 8-3.6 8-8v-48c0-4.4-3.6-8-8-8H208c-4.4 0-8 3.6-8 8v48c0 4.4 3.6 8 8 8"
          />
        </svg>
      </div>
      <div class="btn" title="复制" @click="handleCopy">
        <img
          src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAABDpJREFUWEetV0FyWkcQff0VK1VKFningFOFbgAnAJ3A+ATGVQHJ2ZicAHQCS7sEVGVyAqETgE4gfAKziABXFmZjWQViXqpHf74+X4MEOOyomd/zpvu91z2CDX6pGlM716gBeA0gG4boQ9AXojcPcDH+UwarhJZVNsX3vDhkkXOcUZB64tsBBD0Q59c76E2OZeLbvxaATIU5Ci41EIkegca4JRf6X9cMUBBBEUQRDwF2BOhcNeXvOJC1AKSr/KQpNwaN8akcPZaB3bcsyC1yCFASBRT+LPAtvHElWhnAr1WW5sAZgcGoKXvrlG63zCyeoSiCutxxZnA9RX7SlsnKANIH/ACiTKI2asnJOgDcXgUi2+haEAaN4akcrQQgZL3WPmum2Bu3V2O4D+TuIYuBQRfE5HqGvaUAlO3G2LQVGNZwk/T7QPxywK7ywhjsLwDYPWRWiHeBQdkrM6I9bMmbTdIf/8aVU4ByBCDzG2sM8D5iK6BG0hFBT4gGgdzcoPT5VM7/BwBnIEoazwJIV9kAULeBibYB2k7f2TJT02180aXrKZ4rc78bQCjnGZEXTXtgoPqGAcrjhFGEXOiqfkct2f/ew6PziMmwJc/F1UNv7qtvpsr3BGoEjkdN+SOS1CGzW3NcUjCgoLc1x/k/p9J7CmCmQuXXBwKdUVNeiXM3Tce/LeknA2SqvNT6G6LoyuKsF0A3SVZtRmq5BC6uPPGSfqIAqAGHTXkgyXj9fev6nbXcuSWT2m0ufgFf2ZIXlkyFX/QWPoKtW/9UmamdH1GAQYmComYjXtbM78zxFprRyM4lSrHB/jhRwxcVvjOCY2/9iTpo2+1HX6p9XHDx4nxTAJZkzpsXDKNKlaZKtDFs3ne/KND9Ztv7ZwYnPh65bZkDqpqKcbVJ1OU8MnOMhaA9/GvRAXcrLAeCl0rQsMPpjNAftSS/TAmu3PF+IhHRwuYQN5r4mtlCftmY5YaRYIaLq/ZDJSmgGJ8WQFrmx5tDkgfpKs8AlAj0v02xv6kTRvJL+ImzYlvrJNmszOI9HBgI0Pi6g/NlM96SFqxu2/W1cwvA9ehlNUyAsGc8ZTgJMrssWveLr1kAWuvZM3xa5geR/VZYlgCv4zNeuKads68O6GSpQ8zPN8gZYztsTgcQM0M+OcxE7ud4oD06Obkm0+pmvAAoWMO5fxt4BaDGE0zxykfQCECkbY/kVmgwuTmQU1mGDxVryUpcGnRubnGyjLwRgHib1FltY7aHs4XemlPsPzU/LjSgdcqQzIp9MRF1Nz/OidrnFabnxZnwzt10/J48Zjx6uJLsp68oIYiaz91TjZjMgcYqh1s1JW/ijEcDkTjiD+ioA2YPmZ0a6NOsEKpgsfVqyg3aj9XbxyXvDDDbRt02qMd+ChDQAaYTLBk+niKvNwPuo/QBX+pLKHpougMFfRKdmxk+bkrUOLD/AJnzscretOw/AAAAAElFTkSuQmCC"
          alt=""
        />
      </div>
      <div class="btn" title="编辑" @click="emit('edit', item)">
        <img
          src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACIAAAAeCAYAAABJ/8wUAAAAAXNSR0IArs4c6QAAAwpJREFUWEftV0Fu00AUfd8hXVQs0l1IinBPQHoCnBuEExCk1i1sak7Q9AQNCyRoKjWcoPQEgRMknKBGokkQmyBBBWkzD41Tp67r2A4JEgu8tP//8+bPm/+eBf/II4vCUdxkSRl4IkQFgBlRtwNBRwn2+q/FDX9fCJDiBh0a2E+5KfeCePy1IZ1g/NxAipusUnCkixKoI4t675V8CoPKP+MjYwQHQAXEQGWwHuzMXEDMKnPDJbT1UYwI50tDXiZ1pWhzn4BD4n2vIWU/fi4gfjfCRePAaPAXWZxSkGMWpt89D0jBZkWInaTd0IDbfSNP/bjA7pxeim74eYUtHkOTmugIMNDvPSB+wSQg+vv5ECuDpnjJhS0egagKUD07kLdp8oN5kWTVZEoqlLnEt7MA21c3uaMEdU3S3oG8SMoPdLJNoETC4R14t2cujuS3aRkKrahbMA3UfZuVEXBMwO0dyNpCyKqL3NtiSwgLgKsMlKOGlb/Y6jYtpbyrbiqFWv9Q9hYGJF+lKUtoyfU0fQeM232DAwKLY8BQRLPfuCb93EfjL6TBGFnsQlCN5YkeZEQ92ImFdSS4sAaELCxD8CAMSAHuzyFO/Bt3q2Npmf634+a6NYsE9x/IH3FE33+M8FAJcsECBjEA8fHzobyf95hij+ZKDI+0UiYslDjMkoBOBVKwWQOwqwtomdc2z1fKSVHCpMDyhhkxuADKYeeVBCB2juS3aRoKpzoojeEJqLd7PsT6tFkRByqyI75fCOtBXKGJ5ijUugENmakjOYe5u99R8pOUgZanCUOs9Zu3HXdU8YmqhixguPY0YHHGyO0GZDppZ4HjvJFXtOl5j6R8D0h+g5ZkxsTUjyfrxKDbkJWkAv734nOWeIk2iU6vIev++7zNXZGx6s7OEZuaqNozlPspZ8SEsESzG5L4JBDe5qOCCjZ1d/T1TTUf9LFkRmjreaMIq9+QD2kWD8ZEAtGW/9cS2ldmxxWg9mMZJ4P62DT7jybi8jkc/Qfg/R7M6F0TgXi8ue28YjcZ5bpm6cpvMNhsJB8wSzUAAAAASUVORK5CYII="
          alt=""
        />
      </div>
      <Popconfirm
        title="删除后 WVP 国标设备及已同步的通道将移除，是否确认？"
        ok-text="是"
        cancel-text="否"
        @confirm="emit('delete', item)"
      >
        <div class="btn" title="删除">
          <Icon icon="material-symbols:delete-outline-rounded" :size="15" color="#DC2626" />
        </div>
      </Popconfirm>
    </div>
  </div>
  <div class="product-img">
    <img :src="deviceImage" alt="" class="img" @click="emit('view', item)" />
  </div>
</template>

<script lang="ts" setup>
import { computed } from 'vue';
import { Popconfirm } from 'ant-design-vue';
import { Icon } from '@/components/Icon';
import { useMessage } from '@/hooks/web/useMessage';
import HAIKANG_IMAGE from '@/assets/images/video/haikang.png';
import DAHUA_IMAGE from '@/assets/images/video/dahua.png';
import HUAWEI_IMAGE from '@/assets/images/video/huawei.png';
import OTHER_IMAGE from '@/assets/images/video/other.png';
import type { GbSipDeviceSummary } from '@/views/camera/utils/gb28181DeviceGroup';

export interface Gb28181CardItem {
  onLine: boolean;
  name: string;
  deviceIdentification: string;
  ip?: string;
  mediaServerId?: string;
  manufacturer?: string;
  _summary: GbSipDeviceSummary;
  _wvpRaw?: Record<string, any>;
}

const props = defineProps<{
  item: Gb28181CardItem;
}>();

const emit = defineEmits<{
  open: [item: Gb28181CardItem];
  refresh: [item: Gb28181CardItem];
  view: [item: Gb28181CardItem];
  edit: [item: Gb28181CardItem];
  delete: [item: Gb28181CardItem];
}>();

const { createMessage } = useMessage();

const deviceImage = computed(() => {
  const mfr = (props.item.manufacturer || '').toLowerCase();
  if (!mfr) return OTHER_IMAGE;
  if (mfr.includes('海康') || mfr.includes('hikvision') || mfr.includes('hik')) return HAIKANG_IMAGE;
  if (mfr.includes('大华') || mfr.includes('dahua') || mfr.includes('dh')) return DAHUA_IMAGE;
  if (mfr.includes('华为') || mfr.includes('huawei')) return HUAWEI_IMAGE;
  return OTHER_IMAGE;
});

async function handleCopy() {
  try {
    await navigator.clipboard.writeText(props.item.deviceIdentification);
    createMessage.success('复制成功');
  } catch {
    createMessage.error('复制失败');
  }
}

</script>

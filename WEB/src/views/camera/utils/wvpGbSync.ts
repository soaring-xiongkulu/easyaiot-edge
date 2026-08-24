import { syncGb28181Devices } from '@/api/device/camera';
import { getDeviceChannels, queryAllVideoList } from '@/api/device/gb28181';
import { resolveGbChannelPlayIds } from './gb28181Channel';
import { isGb28181Enabled } from '@/utils/deployProfile';

/** 提交给 VIDEO /directory/sync-gb28181 的国标通道项 */
export interface Gb28181ChannelSyncItem {
  sipDeviceId: string;
  channelId: string;
  name?: string;
  /** WVP 主坐标（WGS-84）；后端按坐标对回退：缺失或 (0,0) 时取国标 Catalog 坐标 */
  gbLongitude?: number | string | null;
  gbLatitude?: number | string | null;
  /** 国标 Catalog 原始上报坐标 */
  longitude?: number | string | null;
  latitude?: number | string | null;
  address?: string | null;
  gbAddress?: string | null;
}

/**
 * 经 dev-api/gb28181 拉取 WVP 设备与通道（与分屏监控相同网关），供设备目录同步入库。
 */
export async function collectWvpGbChannelsForSync(): Promise<{
  channels: Gb28181ChannelSyncItem[];
  wvpDeviceCount: number;
}> {
  if (!isGb28181Enabled()) {
    return { channels: [], wvpDeviceCount: 0 };
  }
  const { data: devices } = await queryAllVideoList();
  const sipList = (devices || [])
    .map((d) => String(d.deviceIdentification || d.deviceId || '').trim())
    .filter(Boolean);

  const channels: Gb28181ChannelSyncItem[] = [];
  for (const sip of sipList) {
    const { data: chList } = await getDeviceChannels(sip);
    for (const ch of chList || []) {
      const ids = resolveGbChannelPlayIds(ch, sip);
      if (!ids) continue;
      channels.push({
        sipDeviceId: ids.sipDeviceId,
        channelId: ids.channelId,
        name: String(ch.name || '').trim() || undefined,
        // 携带 WVP 坐标原始字段入库，坐标对回退逻辑统一在 VIDEO 后端处理
        gbLongitude: ch.gbLongitude,
        gbLatitude: ch.gbLatitude,
        longitude: ch.longitude,
        latitude: ch.latitude,
        address: ch.address,
        gbAddress: ch.gbAddress,
      });
    }
  }

  return { channels, wvpDeviceCount: sipList.length };
}

/**
 * 后台静默同步 WVP 国标通道到 VIDEO 默认分组（首页等场景自动入库，无需用户手动点「刷新」）。
 */
export async function syncGb28181DevicesInBackground(): Promise<{
  created: number;
  totalGbDevices: number;
  wvpDeviceCount: number;
}> {
  if (!isGb28181Enabled()) {
    return { created: 0, totalGbDevices: 0, wvpDeviceCount: 0 };
  }
  try {
    const { channels, wvpDeviceCount } = await collectWvpGbChannelsForSync();
    if (wvpDeviceCount === 0 || channels.length === 0) {
      return { created: 0, totalGbDevices: 0, wvpDeviceCount };
    }
    const payload = await syncGb28181Devices(channels);
    return {
      created: payload?.created ?? 0,
      totalGbDevices: payload?.total_gb_devices ?? 0,
      wvpDeviceCount,
    };
  } catch (e) {
    console.warn('后台同步国标设备失败', e);
    return { created: 0, totalGbDevices: 0, wvpDeviceCount: 0 };
  }
}

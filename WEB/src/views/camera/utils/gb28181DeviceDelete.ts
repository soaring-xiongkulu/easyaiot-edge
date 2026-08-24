import { deleteDevice as deleteGbSipDevice } from '@/api/device/gb28181';
import { deleteDevice as deleteVideoDevice, getDeviceList } from '@/api/device/camera';

/** 删除 WVP 国标 SIP 设备，并清理 VIDEO 中已同步的 gb28181 虚拟通道 */
export async function deleteGb28181SipDevice(sipDeviceId: string): Promise<void> {
  const sip = sipDeviceId.trim();
  if (!sip) {
    throw new Error('无效的设备编码');
  }

  const sourcePrefix = `gb28181://${sip}/`.toLowerCase();
  const idPrefix = `gb28181_${sip}_`;

  try {
    const res = await getDeviceList({ pageNo: 1, pageSize: 10000 });
    const devices = res?.data ?? [];
    const synced = devices.filter((d) => {
      const src = (d.source || '').trim().toLowerCase();
      return src.startsWith(sourcePrefix) || (d.id || '').startsWith(idPrefix);
    });
    await Promise.all(
      synced.map((d) =>
        deleteVideoDevice(d.id).catch((err) => {
          console.warn(`清理国标同步通道 ${d.id} 失败`, err);
        }),
      ),
    );
  } catch (err) {
    console.warn('查询国标同步通道失败，将仅删除 WVP 设备', err);
  }

  await deleteGbSipDevice(sip);
}

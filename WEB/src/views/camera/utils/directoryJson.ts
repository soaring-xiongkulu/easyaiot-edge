import {
  getDeviceList,
  getDirectoryMonitorTree,
  syncDirectoryFromJson,
  validateDirectoryJson,
  type DirectoryMonitorTreeData,
  type DeviceInfo,
  type MonitorTreeDeviceNode,
  type MonitorTreeDirectoryNode,
} from '@/api/device/camera';
import { formatCameraDeviceLabel } from '@/views/camera/utils/deviceLabel';

export const DEFAULT_DIRECTORY_NAME = '默认分组';

/**
 * 可编辑目录 JSON（根为数组，不含默认分组）
 * @example
 * [
 *   { "name": "一楼", "devices": ["device-id-1"], "children": [] }
 * ]
 */
export interface SimpleDirectoryNode {
  name: string;
  devices?: string[];
  children?: SimpleDirectoryNode[];
}

export interface CameraSelectOption {
  value: string;
  label: string;
}

export interface DirectoryJsonTemplate {
  key: string;
  label: string;
  hint: string;
  json: string;
  createdAt?: number;
}

const CUSTOM_TEMPLATE_STORAGE_KEY = 'easyaiot_directory_json_custom_templates';

/** 内置使用样例（不含默认分组） */
export const DIRECTORY_JSON_SAMPLES: DirectoryJsonTemplate[] = [
  {
    key: 'basic',
    label: '基础结构',
    hint: '单目录 + 设备 ID 列表',
    json: JSON.stringify(
      [{ name: '一楼', devices: ['替换为设备ID-1', '替换为设备ID-2'] }],
      null,
      2,
    ),
  },
  {
    key: 'nested',
    label: '多级目录',
    hint: '父子目录嵌套',
    json: JSON.stringify(
      [
        {
          name: '园区A',
          devices: [],
          children: [
            { name: '1号楼', devices: ['替换为设备ID-A'] },
            { name: '2号楼', devices: ['替换为设备ID-B'] },
          ],
        },
      ],
      null,
      2,
    ),
  },
  {
    key: 'move',
    label: '迁移设备',
    hint: '按区域划分设备，未写入的设备仍留在默认分组',
    json: JSON.stringify(
      [
        { name: '出入口', devices: ['门口相机设备ID'] },
        { name: '停车场', devices: ['车位相机设备ID'] },
      ],
      null,
      2,
    ),
  },
  {
    key: 'new-dir',
    label: '新建目录',
    hint: '新增业务目录并挂载设备',
    json: JSON.stringify(
      [
        {
          name: '园区A',
          devices: [],
          children: [{ name: '1号楼', devices: ['设备ID'] }],
        },
      ],
      null,
      2,
    ),
  },
];

export function loadCustomDirectoryTemplates(): DirectoryJsonTemplate[] {
  try {
    const raw = localStorage.getItem(CUSTOM_TEMPLATE_STORAGE_KEY);
    if (!raw) return [];
    const list = JSON.parse(raw);
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

export function saveCustomDirectoryTemplate(template: DirectoryJsonTemplate): void {
  const list = loadCustomDirectoryTemplates().filter((t) => t.key !== template.key);
  list.unshift({ ...template, createdAt: template.createdAt ?? Date.now() });
  localStorage.setItem(CUSTOM_TEMPLATE_STORAGE_KEY, JSON.stringify(list.slice(0, 20)));
}

export function removeCustomDirectoryTemplate(key: string): void {
  const list = loadCustomDirectoryTemplates().filter((t) => t.key !== key);
  localStorage.setItem(CUSTOM_TEMPLATE_STORAGE_KEY, JSON.stringify(list));
}

/** 复制到 JSON devices 数组的格式 */
export function formatDeviceIdsForCopy(ids: string[]): string {
  return ids.map((id) => `"${id}",`).join('\n');
}

function unwrapApiData<T>(response: any): T {
  if (response?.code !== undefined) {
    if (response.code !== 0) throw new Error(response.msg || '请求失败');
    return response.data as T;
  }
  return response as T;
}

function isDefaultDirectoryNode(dir: MonitorTreeDirectoryNode): boolean {
  return !!dir.is_default || dir.name === DEFAULT_DIRECTORY_NAME;
}

function mapOneToSimple(dir: MonitorTreeDirectoryNode): SimpleDirectoryNode {
  const item: SimpleDirectoryNode = { name: dir.name };
  const ids = (dir.devices || []).map((d) => d.id);
  if (ids.length) item.devices = ids;
  if (dir.children?.length) item.children = mapListToSimple(dir.children);
  return item;
}

/** 导出可编辑结构：仅根级非默认目录（与默认分组同级） */
function mapListToSimple(nodes: MonitorTreeDirectoryNode[]): SimpleDirectoryNode[] {
  return (nodes || [])
    .filter((dir) => !isDefaultDirectoryNode(dir))
    .map(mapOneToSimple);
}

export function collectCamerasFromMonitorTree(tree: MonitorTreeDirectoryNode[]): CameraSelectOption[] {
  const map = new Map<string, CameraSelectOption>();
  const walkDirs = (dirs: MonitorTreeDirectoryNode[]) => {
    dirs.forEach((dir) => {
      (dir.devices || []).forEach((d: MonitorTreeDeviceNode) => {
        if (!d.id || map.has(d.id)) return;
        map.set(d.id, {
          value: d.id,
          label: `${d.name || d.id} · ${d.id}`,
        });
      });
      if (dir.children?.length) walkDirs(dir.children);
    });
  };
  walkDirs(tree || []);
  return Array.from(map.values()).sort((a, b) => a.label.localeCompare(b.label, 'zh-CN'));
}

function parseMonitorTreeResponse(res: any): MonitorTreeDirectoryNode[] {
  if (!res || typeof res !== 'object') return [];
  if (Array.isArray((res as { tree?: unknown }).tree)) {
    return (res as DirectoryMonitorTreeData).tree;
  }
  if ((res as { code?: number }).code !== undefined) {
    const data = unwrapApiData<DirectoryMonitorTreeData>(res);
    return data?.tree || [];
  }
  if (Array.isArray(res)) return res as MonitorTreeDirectoryNode[];
  return [];
}

export async function fetchAllCameraSelectOptions(): Promise<CameraSelectOption[]> {
  const res = await getDeviceList({ pageNo: 1, pageSize: 5000 });
  let list: DeviceInfo[] = [];
  if (res?.code === 0 && Array.isArray(res.data)) {
    list = res.data;
  } else if (Array.isArray(res?.data)) {
    list = res.data;
  } else if (Array.isArray(res)) {
    list = res as DeviceInfo[];
  }
  return list
    .filter((d) => d?.id)
    .map((d) => ({
      value: d.id,
      label: `${formatCameraDeviceLabel(d)} · ${d.id}`,
    }))
    .sort((a, b) => a.label.localeCompare(b.label, 'zh-CN'));
}

export async function fetchDirectoryJsonPayload(): Promise<{
  jsonText: string;
  cameraOptions: CameraSelectOption[];
}> {
  const [treeRes, cameraOptions] = await Promise.all([
    getDirectoryMonitorTree(),
    fetchAllCameraSelectOptions(),
  ]);
  const tree = parseMonitorTreeResponse(treeRes);
  return {
    jsonText: JSON.stringify(mapListToSimple(tree), null, 2),
    cameraOptions,
  };
}

/** @deprecated 使用 fetchDirectoryJsonPayload */
export async function fetchDirectoryJsonText(): Promise<string> {
  const { jsonText } = await fetchDirectoryJsonPayload();
  return jsonText;
}

export function parseDirectoryJsonText(text: string): SimpleDirectoryNode[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.trim());
  } catch {
    throw new Error('JSON 格式无效');
  }

  let tree: unknown;
  if (Array.isArray(parsed)) {
    tree = parsed;
  } else if (parsed && typeof parsed === 'object' && Array.isArray((parsed as { tree?: unknown }).tree)) {
    tree = (parsed as { tree: unknown[] }).tree;
  } else {
    throw new Error('请使用目录数组，例如 [{ "name": "一楼", "devices": [] }]');
  }

  const validate = (node: unknown, path: string) => {
    if (!node || typeof node !== 'object') throw new Error(`${path} 须为对象`);
    const n = node as SimpleDirectoryNode;
    const name = n.name?.trim();
    if (!name) throw new Error(`${path}.name 不能为空`);
    if (name === DEFAULT_DIRECTORY_NAME) {
      throw new Error('请勿在 JSON 中编辑「默认分组」，该分组由系统保留');
    }
    if (n.devices != null) {
      if (!Array.isArray(n.devices) || n.devices.some((id) => typeof id !== 'string' || !id.trim())) {
        throw new Error(`${path}.devices 须为设备 ID 字符串数组`);
      }
    }
    if (n.children != null) {
      if (!Array.isArray(n.children)) throw new Error(`${path}.children 须为数组`);
      n.children.forEach((c, i) => validate(c, `${path}.children[${i}]`));
    }
  };

  const nodes = tree as SimpleDirectoryNode[];
  nodes.forEach((n, i) => validate(n, `[${i}]`));
  assertNoDuplicateDevices(nodes);
  return nodes;
}

/** 校验整棵树中设备 ID 不重复 */
export function assertNoDuplicateDevices(nodes: SimpleDirectoryNode[]): void {
  const seen = new Map<string, string>();

  const walk = (list: SimpleDirectoryNode[], parentDir: string) => {
    list.forEach((node) => {
      const dirLabel = parentDir ? `${parentDir} / ${node.name.trim()}` : node.name.trim();
      for (const rawId of node.devices || []) {
        const id = rawId.trim();
        if (!id) continue;
        const firstDir = seen.get(id);
        if (firstDir) {
          throw new Error(
            `摄像头「${id}」在「${firstDir}」与「${dirLabel}」中重复，一个摄像头只能出现一次`,
          );
        }
        seen.set(id, dirLabel);
      }
      if (node.children?.length) walk(node.children, dirLabel);
    });
  };

  walk(nodes, '');
}

function unwrapApiResponse(res: { code?: number; msg?: string }): void {
  if (res?.code !== undefined && res.code !== 0) {
    throw new Error(res.msg || '请求失败');
  }
}

/**
 * 同步可编辑目录（前端校验 + 后端校验并写入）
 */
export async function applyDirectoryJsonSync(tree: SimpleDirectoryNode[]): Promise<void> {
  assertNoDuplicateDevices(tree);
  const res = await syncDirectoryFromJson(tree);
  unwrapApiResponse(res as { code?: number; msg?: string });
}

/** 仅调用后端校验（可选，与 parse 前端校验双保险） */
export async function validateDirectoryJsonRemote(tree: SimpleDirectoryNode[]): Promise<void> {
  assertNoDuplicateDevices(tree);
  const res = await validateDirectoryJson(tree);
  unwrapApiResponse(res as { code?: number; msg?: string });
}

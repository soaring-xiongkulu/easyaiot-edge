import { ref, watch } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import { getSnapSpaceList, type SnapSpace } from '@/api/device/snap';
import { getRecordSpaceList, type RecordSpace } from '@/api/device/record';
import type {
  SpaceBreadcrumb,
  SpaceFolderNode,
  SpaceKind,
} from '@/views/camera/utils/spaceSaveTime';

import { SPACE_FOLDER_ROOT_KEY } from '@/views/camera/utils/spaceSaveTime';

export const SPACE_FOLDER_COLS = 10;
export const SPACE_FOLDER_PAGE_SIZE = 30;

export const ROOT_PARENT_KEY = SPACE_FOLDER_ROOT_KEY;

function normalizeFolderNodes(items: unknown[]): SpaceFolderNode[] {
  if (!Array.isArray(items)) return [];
  return items.map((item) => {
    const row = item as SpaceFolderNode & { id?: number };
    const nodeKey = row.node_key
      || (row.id != null ? `space_${row.id}` : `node_${row.space_name || row.name || ''}`);
    return {
      ...row,
      node_type: row.node_type || 'space',
      node_key: nodeKey,
      name: row.name || row.space_name || '',
      space_name: row.space_name || row.name || '',
    };
  });
}

export function useSpaceDirectoryManage(spaceKind: SpaceKind) {
  const loading = ref(false);
  const folderList = ref<SpaceFolderNode[]>([]);
  const searchKeyword = ref('');
  const pageNo = ref(1);
  const total = ref(0);
  const parentKey = ref(ROOT_PARENT_KEY);
  const breadcrumbs = ref<SpaceBreadcrumb[]>([{ key: ROOT_PARENT_KEY, name: '全部空间' }]);
  const isSearchMode = ref(false);
  const dataLoaded = ref(false);

  async function loadSpaces(options?: { page?: number; parent?: string }) {
    if (options?.page != null) {
      pageNo.value = options.page;
    }
    if (options?.parent != null) {
      parentKey.value = options.parent || ROOT_PARENT_KEY;
    }

    loading.value = true;
    try {
      const api = spaceKind === 'snap' ? getSnapSpaceList : getRecordSpaceList;
      const search = searchKeyword.value.trim() || undefined;
      const res = await api({
        pageNo: pageNo.value,
        pageSize: SPACE_FOLDER_PAGE_SIZE,
        search,
        parentKey: parentKey.value,
      });

      let items: SpaceFolderNode[] = [];
      let count = 0;
      let crumbs: SpaceBreadcrumb[] = [{ key: ROOT_PARENT_KEY, name: '全部空间' }];
      let searchMode = false;

      if (Array.isArray(res)) {
        items = normalizeFolderNodes(res);
        count = items.length;
        dataLoaded.value = true;
      } else if (res?.code === 0 || res?.code === 200) {
        items = normalizeFolderNodes(Array.isArray(res.data) ? res.data : []);
        count = Number(res.total) || items.length;
        if (Array.isArray(res.breadcrumbs) && res.breadcrumbs.length) {
          crumbs = res.breadcrumbs;
        }
        searchMode = !!res.is_search;
        if (res.parent_key) {
          parentKey.value = res.parent_key;
        }
      }

      folderList.value = items;
      total.value = count;
      breadcrumbs.value = crumbs;
      isSearchMode.value = searchMode;
      dataLoaded.value = true;
    } finally {
      loading.value = false;
    }
  }

  const debouncedSearch = useDebounceFn(() => {
    pageNo.value = 1;
    if (!searchKeyword.value.trim()) {
      parentKey.value = ROOT_PARENT_KEY;
    }
    loadSpaces();
  }, 300);

  watch(searchKeyword, () => {
    debouncedSearch();
  }, { flush: 'post' });

  function setPage(page: number) {
    if (page < 1 || page === pageNo.value) return;
    loadSpaces({ page });
  }

  function enterFolder(node: SpaceFolderNode) {
    if (node.node_type !== 'folder' || !node.node_key) return;
    pageNo.value = 1;
    loadSpaces({ page: 1, parent: node.node_key });
  }

  function navigateToBreadcrumb(key: string) {
    pageNo.value = 1;
    loadSpaces({ page: 1, parent: key || ROOT_PARENT_KEY });
  }

  async function refreshAll() {
    await loadSpaces();
  }

  async function init() {
    pageNo.value = 1;
    parentKey.value = ROOT_PARENT_KEY;
    await loadSpaces();
  }

  return {
    loading,
    folderList,
    searchKeyword,
    pageNo,
    total,
    parentKey,
    breadcrumbs,
    isSearchMode,
    dataLoaded,
    loadSpaces,
    setPage,
    enterFolder,
    navigateToBreadcrumb,
    refreshAll,
    init,
  };
}

export type { SnapSpace, RecordSpace };

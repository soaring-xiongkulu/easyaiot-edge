import type { AppRouteModule } from '@/router/types';
import { LAYOUT } from '@/router/constant';

const node: AppRouteModule = {
  path: '/node',
  name: 'NodeManage',
  component: LAYOUT,
  redirect: '/node/index',
  meta: {
    orderNo: 25,
    icon: 'ant-design:cluster-outlined',
    title: '集群管理',
    hideChildrenInMenu: true,
  },
  children: [
    {
      path: 'index',
      name: 'ComputeNodeIndex',
      component: () => import('@/views/node/index.vue'),
      meta: {
        title: '服务器节点',
        icon: 'ant-design:cluster-outlined',
        hideMenu: true,
      },
    },
  ],
};

export default node;

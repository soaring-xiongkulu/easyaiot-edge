<template>
  <div class="access-guide">
    <Tabs v-model:activeKey="activeTab" class="access-guide-tabs" size="small">
      <TabPane v-for="tab in visibleTabs" :key="tab.key" :tab="tab.label">
        <div class="guide-tab-body">
          <!-- 工业协议接入 -->
          <template v-if="tab.key === 'industrial'">
            <Alert :type="overview.type" show-icon :message="overview.message" class="guide-alert" />
            <CollapseContainer :title="`${industrialLabel} 接入步骤`" :can-expan="false">
              <List :data-source="industrialSteps" bordered size="small">
                <template #renderItem="{ item }">
                  <List.Item>
                    <Tag color="blue">{{ item.index }}</Tag>
                    <div class="guide-industrial-step">
                      <strong>{{ item.title }}</strong>
                      <span>{{ item.desc }}</span>
                    </div>
                  </List.Item>
                </template>
              </List>
            </CollapseContainer>
            <CollapseContainer title="注意事项" :can-expan="false">
              <List :data-source="industrialNotes" bordered size="small">
                <template #renderItem="{ item }">
                  <List.Item>
                    <Icon icon="ant-design:info-circle-outlined" class="guide-check-icon" />
                    <span>{{ item }}</span>
                  </List.Item>
                </template>
              </List>
            </CollapseContainer>
            <CollapseContainer title="验收清单" :can-expan="false">
              <List :data-source="industrialVerify" bordered size="small">
                <template #renderItem="{ item }">
                  <List.Item>
                    <Icon icon="ant-design:check-circle-outlined" class="guide-check-icon" />
                    <span>{{ item }}</span>
                  </List.Item>
                </template>
              </List>
            </CollapseContainer>
            <p class="guide-hint">
              完整联调文档与模拟脚本见仓库
              <code>docs/industrial/Modbus设备测试/</code>
            </p>
          </template>

          <!-- 推荐命令 -->
          <template v-else-if="tab.key === 'cmd'">
            <Alert
              v-if="isVideo"
              type="info"
              show-icon
              message="视频设备请走摄像头 / 国标接入；mqtt-demo 仅用于 MQTT 物模型联调。"
            />
            <template v-else>
              <div class="ops-toolbar ops-toolbar--flat">
                <span class="ops-field-label">
                  脚本目录 <code>{{ demoDir }}</code> · {{ typeLabel }}
                </span>
              </div>
              <Alert
                v-for="(w, i) in paramWarnings"
                :key="'w' + i"
                type="warning"
                show-icon
                :message="w"
                class="guide-alert"
              />
              <CollapseContainer
                v-for="card in demoCards"
                :key="card.id"
                :title="`${card.step} · ${card.title}`"
                :can-expan="true"
              >
                <template #action>
                  <Button
                    type="primary"
                    size="small"
                    preIcon="ant-design:copy-outlined"
                    @click="handleCopy(card.command, '命令已复制')"
                  >
                    复制命令
                  </Button>
                </template>
                <div class="guide-meta">
                  <Tag :color="card.optional ? 'default' : 'blue'">{{ card.script }}</Tag>
                  <span class="guide-meta__text">{{ card.goal }}</span>
                </div>
                <pre class="guide-code">{{ card.command }}</pre>
                <div class="guide-accept">验收：{{ card.accept }}</div>
              </CollapseContainer>
            </template>
          </template>

          <!-- 联调参数 -->
          <template v-else-if="tab.key === 'params'">
            <CollapseContainer title="联调参数" :can-expan="false">
              <BasicForm @register="registerParamForm" />
              <Alert
                v-for="(w, i) in paramWarnings"
                :key="i"
                type="warning"
                show-icon
                :message="w"
                class="guide-alert"
              />
              <p class="guide-hint">修改后「推荐命令」与「后台常驻」会自动更新。</p>
            </CollapseContainer>
          </template>

          <!-- 连接鉴权 -->
          <template v-else-if="tab.key === 'auth'">
            <Alert
              v-if="isSubset"
              type="warning"
              show-icon
              class="guide-alert"
              message="子设备通常不直连 MQTT，请用所属网关身份连接，或在联调参数中填网关标识。"
            />
            <Alert
              v-else-if="isVideo"
              type="info"
              show-icon
              class="guide-alert"
              message="视频设备优先摄像头 / 国标接入；下列参数仅 MQTT 物模型时参考。"
            />
            <Alert
              v-else
              type="info"
              show-icon
              class="guide-alert"
              message="生产需 EMQX HTTP 鉴权 → iot-sink /mqtt/auth；本地可先选 Broker 直通。"
            />
            <CollapseContainer title="连接参数" :can-expan="false">
              <Description
                :column="2"
                layout="vertical"
                bordered
                :use-collapse="false"
                :data="authDescData"
                :schema="authDescSchema"
              />
            </CollapseContainer>
          </template>

          <!-- Topic -->
          <template v-else-if="tab.key === 'topic'">
            <Alert
              :type="topicAlert.type"
              show-icon
              :message="topicAlert.message"
              class="guide-alert"
            />
            <div class="ops-surface">
              <div class="ops-surface-head">
                <div class="ops-surface-title">
                  Topic 清单
                  <span class="ops-count">({{ topicTableData.length }})</span>
                </div>
              </div>
              <div class="ops-surface-body ops-surface-body--table">
                <BasicTable v-if="topicTableData.length" @register="registerTopicTable">
                  <template #bodyCell="{ column, record }">
                    <template v-if="column.key === 'direction'">
                      <Tag :color="record.direction === '上行' ? 'processing' : 'warning'">
                        {{ record.direction }}
                      </Tag>
                    </template>
                    <template v-else-if="column.key === 'topic'">
                      <code class="guide-topic">{{ record.topic }}</code>
                    </template>
                  </template>
                  <template #action="{ record }">
                    <TableAction
                      :actions="[
                        {
                          icon: 'ant-design:copy-outlined',
                          tooltip: { title: '复制 Topic', placement: 'top' },
                          onClick: () => handleCopy(record.topic, 'Topic 已复制'),
                        },
                      ]"
                    />
                  </template>
                </BasicTable>
                <div v-else class="ops-empty">
                  <Icon icon="ant-design:inbox-outlined" class="ops-empty-icon" />
                  <p>当前类型无标准 MQTT Topic</p>
                </div>
              </div>
            </div>
          </template>

          <!-- 报文 -->
          <template v-else-if="tab.key === 'payload'">
            <CollapseContainer
              v-for="sample in payloadSamples"
              :key="sample.title"
              :title="sample.title"
              :can-expan="true"
            >
              <template #action>
                <Button
                  size="small"
                  type="primary"
                  preIcon="ant-design:copy-outlined"
                  @click="handleCopy(sample.body, '报文已复制')"
                >
                  复制
                </Button>
              </template>
              <div class="guide-meta">
                <span class="guide-meta__label">Topic</span>
                <code class="guide-topic">{{ sample.topic }}</code>
              </div>
              <CodeEditor
                :value="sample.body"
                :readonly="true"
                :bordered="true"
                :auto-format="true"
                class="guide-code-editor"
              />
              <p v-if="sample.hint" class="guide-hint">{{ sample.hint }}</p>
            </CollapseContainer>
          </template>

          <!-- 验收 -->
          <template v-else-if="tab.key === 'verify'">
            <Alert type="info" show-icon :message="verifyIntro" class="guide-alert" />
            <CollapseContainer title="检查清单" :can-expan="false">
              <List :data-source="verifySteps" bordered size="small">
                <template #renderItem="{ item, index }">
                  <List.Item>
                    <List.Item.Meta>
                      <template #avatar>
                        <span class="guide-step-badge">{{ index + 1 }}</span>
                      </template>
                      <template #title>{{ item }}</template>
                    </List.Item.Meta>
                  </List.Item>
                </template>
              </List>
            </CollapseContainer>
            <CollapseContainer title="页面对照" :can-expan="false">
              <List :data-source="observeHints" bordered size="small">
                <template #renderItem="{ item }">
                  <List.Item>
                    <Icon icon="ant-design:check-circle-outlined" class="guide-check-icon" />
                    <span>{{ item }}</span>
                  </List.Item>
                </template>
              </List>
            </CollapseContainer>
          </template>

          <!-- 后台常驻 -->
          <template v-else-if="tab.key === 'env'">
            <CollapseContainer title=".env 配置" :can-expan="false">
              <template #action>
                <Button
                  size="small"
                  preIcon="ant-design:copy-outlined"
                  @click="handleCopy(envFile, '.env 已复制')"
                >
                  复制 .env
                </Button>
              </template>
              <p class="guide-hint">
                保存为 <code>{{ demoDir }}/.env</code> 后执行下方启动脚本。
              </p>
              <CodeEditor
                :value="envFile"
                :readonly="true"
                :bordered="true"
                :auto-format="false"
                class="guide-code-editor"
              />
            </CollapseContainer>
            <CollapseContainer title="启动 / 停止" :can-expan="false">
              <template #action>
                <Button size="small" @click="handleCopy(startCmd, '已复制')">复制启动</Button>
                <Button size="small" class="ml-2" @click="handleCopy(stopCmd, '已复制')">复制停止</Button>
              </template>
              <pre class="guide-code">{{ startCmd }}
{{ stopCmd }}</pre>
              <p class="guide-hint">首次使用需安装依赖：<code>pip install paho-mqtt</code></p>
            </CollapseContainer>
          </template>
        </div>
      </TabPane>
    </Tabs>
  </div>
</template>

<script setup lang="ts">
import { computed, h, nextTick, reactive, ref, watch } from 'vue';
import { Alert, List, TabPane, Tabs, Tag } from 'ant-design-vue';
import { Button } from '@/components/Button';
import { CodeEditor } from '@/components/CodeEditor';
import { CollapseContainer } from '@/components/Container';
import { Description } from '@/components/Description';
import { BasicForm, useForm } from '@/components/Form';
import type { FormSchema } from '@/components/Form';
import { Icon } from '@/components/Icon';
import { BasicTable, TableAction, useTable } from '@/components/Table';
import { copyText } from '@/utils/copyTextToClipboard';
import type { AccessGuideProps, GuideTopicRow } from './types';
import {
  buildCredentials,
  buildDirectTopics,
  buildGatewayProxyTopics,
  buildIndustrialGuideSteps,
  buildIndustrialNotes,
  buildIndustrialVerifySteps,
  buildVerifySteps,
  gatewaySubPropertyPayload,
  gatewayTopoAddPayload,
  industrialProtocolLabel,
  isIndustrialProtocol,
  nodeTypeLabel,
  normalizeNodeType,
  overviewAlert,
  propertyReportPayload,
  resolveIds,
} from './guideContent';
import {
  buildDemoCommandCards,
  buildEnvFileContent,
  buildStartAllCommand,
} from './scriptDemo';

defineOptions({ name: 'AccessGuide' });

const props = withDefaults(defineProps<AccessGuideProps>(), {
  nodeType: 'COMMON',
  productIdentification: '',
  deviceIdentification: '',
  deviceName: '',
  productName: '',
  password: '',
  userName: '',
  connector: '',
  parentIdentification: '',
  protocolType: '',
  tenantId: 1,
  deviceNumericId: '',
});

const ALL_TABS = [
  { key: 'industrial', label: '工业接入', industrialOnly: true },
  { key: 'cmd', label: '推荐命令', mqttOnly: true },
  { key: 'params', label: '联调参数', mqttOnly: true },
  { key: 'auth', label: '连接鉴权', mqttOnly: false },
  { key: 'topic', label: 'Topic', mqttOnly: false },
  { key: 'payload', label: '报文', mqttOnly: false },
  { key: 'verify', label: '验收', mqttOnly: false },
  { key: 'env', label: '后台常驻', mqttOnly: true },
] as const;

const activeTab = ref('cmd');

const nodeType = computed(() => normalizeNodeType(props.nodeType));
const typeLabel = computed(() => nodeTypeLabel(props.nodeType));
const isSubset = computed(() => nodeType.value === 'SUBSET');
const isGateway = computed(() => nodeType.value === 'GATEWAY');
const isVideo = computed(() => nodeType.value === 'VIDEO_COMMON');
const isIndustrial = computed(() => isIndustrialProtocol(props.protocolType));
const industrialLabel = computed(() => industrialProtocolLabel(props.protocolType));
const industrialSteps = computed(() => buildIndustrialGuideSteps(props.protocolType));
const industrialNotes = computed(() => buildIndustrialNotes(props.protocolType));
const industrialVerify = computed(() => buildIndustrialVerifySteps(props.protocolType));
const overview = computed(() => overviewAlert(props));

const visibleTabs = computed(() => {
  if (isIndustrial.value) {
    return ALL_TABS.filter((t) => t.key === 'industrial' || t.key === 'verify');
  }
  if (isVideo.value) {
    return ALL_TABS.filter((t) => !t.mqttOnly && !(t as any).industrialOnly);
  }
  return ALL_TABS.filter((t) => !(t as any).industrialOnly);
});

const demoOpts = reactive({
  host: 'localhost',
  port: '1883',
  authMode: 'device' as 'device' | 'broker',
  tenantId: String(props.tenantId || 1),
  subProduct: '',
  subDevice: 'demo-sub-001',
  gatewayProduct: '',
  gatewayDevice: props.parentIdentification || '',
});

const authModeOptions = [
  { label: '设备鉴权', value: 'device' },
  { label: 'Broker 直通', value: 'broker' },
];

const paramSchemas = computed<FormSchema[]>(() => {
  const schemas: FormSchema[] = [
    {
      field: 'host',
      label: 'MQTT Host',
      component: 'Input',
      componentProps: { placeholder: 'localhost', allowClear: true },
      colProps: { span: 8 },
    },
    {
      field: 'port',
      label: 'Port',
      component: 'Input',
      componentProps: { placeholder: '1883', allowClear: true },
      colProps: { span: 8 },
    },
    {
      field: 'authMode',
      label: '鉴权模式',
      component: 'Select',
      componentProps: { options: authModeOptions, allowClear: false },
      colProps: { span: 8 },
    },
    {
      field: 'tenantId',
      label: 'tenantId',
      component: 'Input',
      componentProps: { placeholder: '1', allowClear: true },
      colProps: { span: 8 },
    },
  ];
  if (isGateway.value) {
    schemas.push(
      {
        field: 'subProduct',
        label: '子设备产品标识',
        component: 'Input',
        componentProps: { placeholder: 'SUBSET 产品', allowClear: true },
        colProps: { span: 12 },
      },
      {
        field: 'subDevice',
        label: '子设备标识',
        component: 'Input',
        componentProps: { placeholder: 'demo-sub-001', allowClear: true },
        colProps: { span: 12 },
      },
    );
  }
  if (isSubset.value) {
    schemas.push(
      {
        field: 'gatewayProduct',
        label: '网关产品标识',
        component: 'Input',
        componentProps: { placeholder: '所属网关产品', allowClear: true },
        colProps: { span: 12 },
      },
      {
        field: 'gatewayDevice',
        label: '网关设备标识',
        component: 'Input',
        componentProps: { placeholder: '所属网关设备', allowClear: true },
        colProps: { span: 12 },
      },
    );
  }
  return schemas;
});

const [registerParamForm, { setFieldsValue, resetSchema }] = useForm({
  labelWidth: 110,
  schemas: paramSchemas,
  showActionButtonGroup: false,
  baseColProps: { span: 24 },
  handleValuesChange: (values) => {
    Object.assign(demoOpts, values);
  },
});

/** 仅在「联调参数」Tab 已渲染表单后再同步，避免 useForm 未注册时报错导致整页空白 */
async function syncParamForm() {
  if (activeTab.value !== 'params') return;
  for (let attempt = 0; attempt < 2; attempt++) {
    await nextTick();
    try {
      await resetSchema(paramSchemas.value);
      await setFieldsValue({ ...demoOpts });
      return;
    } catch {
      // Tab 切换瞬间表单可能尚未完成 register
    }
  }
}

watch(
  paramSchemas,
  () => {
    void syncParamForm();
  },
  { deep: true },
);

watch(activeTab, (key) => {
  if (key === 'params') void syncParamForm();
});

function syncDefaults() {
  demoOpts.tenantId = String(props.tenantId || 1);
  if (props.parentIdentification && props.parentIdentification !== '--') {
    demoOpts.gatewayDevice = props.parentIdentification;
  }
  if (!visibleTabs.value.find((t) => t.key === activeTab.value)) {
    activeTab.value = visibleTabs.value[0]?.key ?? 'auth';
  }
  void syncParamForm();
}

watch(
  () => [
    props.nodeType,
    props.productIdentification,
    props.deviceIdentification,
    props.parentIdentification,
    props.tenantId,
    props.protocolType,
  ],
  () => syncDefaults(),
  { immediate: true },
);

const demoDir = '.scripts/mqtt-demo';
const startCmd = buildStartAllCommand();
const stopCmd = 'bash stop_mqtt_demo.sh';

const parentId = computed(() => {
  const v = props.parentIdentification?.trim();
  return v && v !== '--' ? v : '';
});

const demoCards = computed(() =>
  buildDemoCommandCards(props, { ...demoOpts, deviceNumericId: props.deviceNumericId }),
);
const envFile = computed(() =>
  buildEnvFileContent(props, { ...demoOpts, deviceNumericId: props.deviceNumericId }),
);

const paramWarnings = computed(() => {
  const list: string[] = [];
  if (demoOpts.authMode === 'device' && (!props.password || props.password === '--')) {
    list.push('未获取到密码，命令中 --password 为占位符。');
  }
  if (
    props.scope === 'product' &&
    !isSubset.value &&
    (!props.deviceIdentification || props.deviceIdentification === '--')
  ) {
    list.push('产品详情无具体设备，请先创建关联设备或手改 --device。');
  }
  if (isGateway.value && !demoOpts.subProduct) {
    list.push('网关代报需填写子设备产品标识（SUBSET）。');
  }
  if (isSubset.value && !demoOpts.gatewayProduct) {
    list.push('请填写所属网关产品标识。');
  }
  return list;
});

const observeHints = computed(() => {
  if (isIndustrial.value) {
    return [
      '「运行状态」按点位绑定的物模型属性（propertyCode）展示',
      '「点位影子」显示最新上报快照',
      '设备连接状态 ONLINE',
      '「寄存器操作」写入后可在写入日志 / 通信日志核对',
    ];
  }
  if (isGateway.value) {
    return [
      '网关连接状态变为在线',
      '「网关子设备」出现目标子设备',
      '子设备影子 / 运行状态随上报刷新',
      '对子设备功能调用时 07 终端打印 /sub/ 下行',
    ];
  }
  if (isSubset.value) {
    return [
      '所属网关在线且脚本以网关身份连接',
      '本设备影子 / 运行状态有代报数据',
      '功能调用下行出现在网关终端',
      '指令日志状态可到 SUCCESS',
    ];
  }
  return [
    '设备影子 params 持续刷新',
    '运行状态与物模型 propertyCode 对齐',
    '设备连接状态 ONLINE',
    '功能调用时下行终端有输出',
  ];
});

const credentials = computed(() => buildCredentials(props));
const verifySteps = computed(() =>
  isIndustrial.value ? buildIndustrialVerifySteps(props.protocolType) : buildVerifySteps(props),
);

const authDescData = computed(() => {
  const data: Record<string, string> = {};
  credentials.value.forEach((row, i) => {
    data[`field_${i}`] = row.value;
  });
  return data;
});

const authDescSchema = computed(() =>
  credentials.value.map((row, i) => ({
    field: `field_${i}`,
    label: row.label,
    render: (val: string) =>
      h('div', { class: 'auth-value-row' }, [
        h('code', { class: 'auth-value' }, val),
        row.copyable
          ? h(
              Button,
              {
                type: 'link',
                size: 'small',
                onClick: () => handleCopy(val, `${row.label}已复制`),
              },
              () => '复制',
            )
          : null,
      ]),
  })),
);

const ids = computed(() => resolveIds(props));

const allTopics = computed((): GuideTopicRow[] => {
  const { productId, deviceId } = ids.value;
  if (isVideo.value) return [];
  if (isSubset.value) {
    const gwD = parentId.value || demoOpts.gatewayDevice || '<网关设备标识>';
    const gwP = demoOpts.gatewayProduct?.trim() || '<网关产品标识>';
    return buildGatewayProxyTopics(gwP, gwD).map((row) => ({
      ...row,
      desc: `${row.desc}（payload 携带本子设备标识）`,
    }));
  }
  if (isGateway.value) {
    return [
      ...buildDirectTopics(productId, deviceId),
      ...buildGatewayProxyTopics(productId, deviceId),
    ];
  }
  return buildDirectTopics(productId, deviceId);
});

const topicTableData = computed(() =>
  allTopics.value.map((row, i) => ({ key: `${row.group}-${i}`, ...row })),
);

const [registerTopicTable] = useTable({
  columns: [
    { title: '分组', dataIndex: 'group', key: 'group', width: 88, ellipsis: true },
    { title: '方向', dataIndex: 'direction', key: 'direction', width: 72 },
    { title: 'Topic', dataIndex: 'topic', key: 'topic', ellipsis: true },
    { title: '说明', dataIndex: 'desc', key: 'desc', ellipsis: true, width: 200 },
  ],
  actionColumn: {
    width: 64,
    title: '操作',
    dataIndex: 'action',
    fixed: undefined,
  },
  dataSource: topicTableData,
  pagination: { pageSize: 8, size: 'small' },
  showIndexColumn: false,
  bordered: true,
  size: 'small',
  canResize: false,
  immediate: false,
});

const topicAlert = computed(() => {
  if (isSubset.value) {
    return { type: 'warning' as const, message: 'Topic 路径属于所属网关；子设备标识在 params。' };
  }
  if (isGateway.value) {
    return { type: 'info' as const, message: '含网关自身数据面与拓扑 / 子设备代理 Topic。' };
  }
  if (isVideo.value) {
    return { type: 'info' as const, message: '视频设备无默认 MQTT Topic。' };
  }
  return {
    type: 'info' as const,
    message:
      props.scope === 'product' ? '已按产品标识拼接，设备标识请替换。' : '已按当前设备标识拼接。',
  };
});

const payloadSamples = computed(() => {
  const { productId, deviceId, tenantId } = ids.value;
  if (isVideo.value) {
    return [{ title: '说明', topic: '—', body: '请使用摄像头 / 国标接入。', hint: '' }];
  }
  if (isSubset.value) {
    const gwD = parentId.value || demoOpts.gatewayDevice || '<网关设备标识>';
    const gwP = demoOpts.gatewayProduct?.trim() || '<网关产品标识>';
    return [
      {
        title: '网关代报子设备属性',
        topic: `/iot/${gwP}/${gwD}/sub/property/upstream/report`,
        body: gatewaySubPropertyPayload(tenantId, productId, deviceId),
        hint: '由所属网关 Publish；06 可自动发送。',
      },
    ];
  }
  if (isGateway.value) {
    const subP = demoOpts.subProduct || '<子设备产品标识>';
    const subD = demoOpts.subDevice || 'demo-sub-001';
    return [
      {
        title: '网关属性上报',
        topic: `/iot/${productId}/${deviceId}/property/upstream/report`,
        body: propertyReportPayload(tenantId),
        hint: '与 01 一致。',
      },
      {
        title: '拓扑添加子设备',
        topic: `/iot/${productId}/${deviceId}/topo/upstream/add`,
        body: gatewayTopoAddPayload(tenantId, subP, subD),
        hint: '06 自动发送；产品须 SUBSET。',
      },
      {
        title: '代报子设备属性',
        topic: `/iot/${productId}/${deviceId}/sub/property/upstream/report`,
        body: gatewaySubPropertyPayload(tenantId, subP, subD),
        hint: '路径为网关；子设备在 params。',
      },
    ];
  }
  return [
    {
      title: '属性上报（标准 JSON）',
      topic: `/iot/${productId}/${deviceId}/property/upstream/report`,
      body: propertyReportPayload(tenantId),
      hint: '与 01 一致；tenantId 必填。',
    },
  ];
});

const verifyIntro = computed(() => {
  if (isIndustrial.value) {
    return `完成 ${industrialLabel.value} 连接配置与点位后，按下列清单逐项核对。`;
  }
  if (isSubset.value) return '跑通 06/07 脚本后，按下列清单逐项核对。';
  if (isGateway.value) return '跑通 06 → 07 脚本后，按下列清单逐项核对。';
  return '跑通 01 → 02 脚本后，按下列清单逐项核对。';
});

function handleCopy(text: string, tip: string) {
  copyText(text, tip);
}
</script>

<style lang="less" scoped>
@import '../styles/device-ops.less';
@import './guide.less';
</style>

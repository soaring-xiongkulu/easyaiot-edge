<template>
  <div class="record-replay-page">
    <div class="page-header">
      <div class="header-left">
        <Button
          type="text"
          class="back-btn"
          preIcon="ant-design:arrow-left-outlined"
          @click="goBack"
        >
          返回上一级
        </Button>
        <div v-if="spaceInfo" class="space-info">
          <h1 class="page-title">{{ spaceInfo.space_name }}</h1>
          <div class="page-meta">
            <a-tag color="blue">录像空间</a-tag>
            <span v-if="spaceInfo.device_id">设备 {{ spaceInfo.device_id }}</span>
            <span v-if="dayDetail">{{ dayDetail.total_segments }} 个片段 · {{ formatDuration(dayDetail.total_duration_sec) }}</span>
            <span v-if="dayDetail?.alert_segment_count" class="alert-stat">
              <WarningOutlined /> {{ dayDetail.alert_segment_count }} 个片段含告警
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="mode-toolbar">
      <RadioGroup
        v-model:value="contentTab"
        button-style="solid"
        size="middle"
        class="mode-radio-group"
        @change="handleContentTabChange"
      >
        <RadioButton value="alerts">
          <span class="mode-radio-item">
            <Icon icon="ant-design:alert-outlined" />
            算法告警
          </span>
        </RadioButton>
        <RadioButton value="replay">
          <span class="mode-radio-item">
            <Icon icon="ant-design:video-camera-outlined" />
            录像回放
          </span>
        </RadioButton>
      </RadioGroup>
      <span v-if="contentTab === 'alerts'" class="mode-hint">按日期查看设备算法告警，可跳转至对应录像片段</span>
      <span v-else class="mode-hint">从左侧选择录像片段开始播放，支持连续播放与时间轴定位</span>
    </div>

    <div class="content-body">
      <div
        v-if="alertsMounted"
        v-show="contentTab === 'alerts'"
        class="panel-shell"
      >
        <SpaceAlgorithmAlertPanel
          ref="alertPanelRef"
          :device-id="spaceInfo?.device_id"
          @view-record="handleViewRecordFromAlert"
        />
      </div>

      <div
        v-if="replayMounted"
        v-show="contentTab === 'replay'"
        class="replay-body"
      >
      <!-- 左侧：日期 + 片段树 -->
      <aside class="left-panel">
        <div class="panel-section">
          <div class="section-label">选择日期</div>
          <DatePicker
            v-model:value="selectedDate"
            value-format="YYYY-MM-DD"
            :disabled-date="disabledDate"
            style="width: 100%"
            @change="handleDateChange"
          />
          <div v-if="availableDates.length" class="date-hints">
            <span
              v-for="d in availableDates.slice(0, 5)"
              :key="d.date"
              class="date-chip"
              :class="{ active: d.date === selectedDateStr }"
              @click="selectDate(d.date)"
            >
              {{ d.date.slice(5) }} ({{ d.segment_count }})
            </span>
          </div>
        </div>

        <div class="panel-section segment-section">
          <div class="section-label">
            录像片段
            <span v-if="sessionGroups.length" class="count-badge">{{ sessionGroups.length }} 段会话</span>
            <Switch v-model:checked="continuousPlay" size="small" class="continuous-switch" />
            <span class="switch-label">连续播放</span>
          </div>
          <Spin :spinning="loading">
            <div v-if="!sessionGroups.length && !loading" class="empty-hint">
              <Empty description="该日暂无录像" :image="Empty.PRESENTED_IMAGE_SIMPLE" />
            </div>
            <div v-else class="segment-tree">
              <div
                v-for="group in sessionGroups"
                :key="group.group_id"
                class="session-group"
                :class="{ 'has-alert': group.has_alert, expanded: expandedGroups.has(group.group_id) }"
              >
                <div class="session-header" @click="toggleGroup(group.group_id)">
                  <CaretRightOutlined class="expand-icon" :class="{ expanded: expandedGroups.has(group.group_id) }" />
                  <div class="session-info" @click.stop="playSession(group)">
                    <VideoCameraOutlined />
                    {{ formatSegmentTime(group.start_time) }} - {{ formatSegmentTime(group.end_time) }}
                    <span class="duration-tag">{{ group.segment_count }} 片段</span>
                  </div>
                  <div v-if="group.has_alert" class="session-alert-badge">
                    <WarningOutlined /> {{ group.alert_count }}
                  </div>
                </div>
                <div v-show="expandedGroups.has(group.group_id)" class="session-segments">
                  <div
                    v-for="seg in group.segments"
                    :key="seg.id || seg.object_name"
                    class="segment-item nested"
                    :class="{ active: activeSegmentId === (seg.id || seg.object_name), 'has-alert': seg.has_alert }"
                    @click="playSegment(seg)"
                  >
                    <div class="segment-time">
                      {{ formatSegmentTime(seg.start_time) }}
                      <span class="duration-tag">{{ seg.duration || 30 }}s</span>
                    </div>
                    <div v-if="seg.has_alert" class="segment-alerts">
                      <a-tag color="red" size="small">{{ seg.alert_count }} 告警</a-tag>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </Spin>
        </div>
      </aside>

      <!-- 右侧：单屏播放器 + 时间轴 -->
      <main class="right-panel">
        <div
          class="player-wrapper"
          @mousemove="handlePlayerMouseMove"
          @mouseleave="hoverTimeSec = null"
        >
          <Jessibuca
            v-if="playUrl"
            ref="playerRef"
            :play-url="playUrl"
            :has-audio="false"
          />
          <div v-else class="player-placeholder">
            <VideoCameraOutlined :style="{ fontSize: '48px', color: '#434343' }" />
            <p>请选择左侧录像片段开始播放</p>
          </div>

          <!-- 悬浮时间轴波浪印记 -->
          <div class="timeline-overlay" :class="{ visible: showTimeline }">
            <div class="timeline-track" @click="handleTimelineClick">
              <div
                v-for="(item, idx) in timeline"
                :key="idx"
                class="timeline-bar"
                :class="{ alert: item.has_alert }"
                :style="barStyle(item)"
                :title="barTitle(item)"
              />
              <div
                v-if="hoverTimeSec !== null"
                class="timeline-cursor"
                :style="{ left: `${(hoverTimeSec / 86400) * 100}%` }"
              />
            </div>
            <div class="timeline-labels">
              <span>00:00</span>
              <span v-if="hoverTimeSec !== null" class="hover-time">{{ formatOffsetSec(hoverTimeSec) }}</span>
              <span>24:00</span>
            </div>
            <div class="timeline-legend">
              <span><i class="dot record" /> 有录像</span>
              <span><i class="dot alert" /> 含告警</span>
            </div>
          </div>
        </div>

        <div v-if="activeSegment" class="now-playing">
          <span>正在播放：{{ formatSegmentTime(activeSegment.start_time) }} - {{ formatSegmentTime(activeSegment.end_time) }}</span>
          <a-tag v-if="activeSegment.has_alert" color="red">含 {{ activeSegment.alert_count }} 条告警</a-tag>
          <a-tag v-if="continuousPlay" color="blue">连续播放中</a-tag>
        </div>
      </main>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router';
import { DatePicker, Empty, Spin, Switch, RadioButton, RadioGroup } from 'ant-design-vue';
import { VideoCameraOutlined, WarningOutlined, CaretRightOutlined } from '@ant-design/icons-vue';
import { Button } from '@/components/Button';
import { Icon } from '@/components/Icon';
import SpaceAlgorithmAlertPanel, {
  type SpaceAlertItem,
} from '@/views/camera/components/SpaceAlgorithmAlertPanel.vue';
import dayjs, { type Dayjs } from 'dayjs';
import Jessibuca from '@/components/Player/module/jessibuca.vue';
import { useMessage } from '@/hooks/web/useMessage';
import {
  getRecordSpace,
  getRecordVideoDates,
  getRecordVideosByDay,
  resolveAlertRecordSegment,
  type RecordDayDetail,
  type RecordDaySegment,
  type RecordTimelineItem,
  type RecordVideoDate,
  type RecordSessionGroup,
} from '@/api/device/record';
import { resolveAlertImageDisplayUrl } from '@/utils/alertMinioImage';
import { resolveAlertVideoUrl } from '@/utils/alertRecord';
import {
  buildCameraStorageQuery,
  parseSpaceFolderQuery,
} from '@/views/camera/utils/spaceSaveTime';

defineOptions({ name: 'RecordSpaceManage' });

const route = useRoute();
const router = useRouter();
const { createMessage } = useMessage();

function parseRouteSpaceId(param: unknown): number | null {
  let raw = param;
  if (Array.isArray(raw)) raw = raw[0];
  if (raw == null || raw === '') return null;
  const id = Number(raw);
  return Number.isFinite(id) && id > 0 ? id : null;
}

/** 页面激活期间固定的 spaceId，离开路由后立即置空，避免 keep-alive/异步竞态 */
const activeSpaceId = ref<number | null>(null);
let loadToken = 0;

function isOnRecordPage(): boolean {
  return route.name === 'RecordSpaceManage';
}

function bumpLoadToken(): number {
  loadToken += 1;
  return loadToken;
}

function isLoadStale(token: number): boolean {
  return token !== loadToken || !isOnRecordPage() || activeSpaceId.value == null;
}

function resetPageState() {
  clearSegmentTimer();
  playUrl.value = '';
  activeSegmentId.value = null;
  activeSegment.value = null;
  loading.value = false;
}

function teardownPage() {
  bumpLoadToken();
  activeSpaceId.value = null;
  spaceInfo.value = null;
  resetPageState();
}
const spaceInfo = ref<{ space_name: string; device_id?: string } | null>(null);
const availableDates = ref<RecordVideoDate[]>([]);
const selectedDate = ref<Dayjs>(dayjs());
const selectedDateStr = computed(() => selectedDate.value.format('YYYY-MM-DD'));
const dayDetail = ref<RecordDayDetail | null>(null);
const loading = ref(false);
const playUrl = ref('');
const activeSegmentId = ref<string | number | null>(null);
const activeSegment = ref<RecordDaySegment | null>(null);
const hoverTimeSec = ref<number | null>(null);
const showTimeline = ref(false);
const playerRef = ref();
const continuousPlay = ref(true);
const expandedGroups = ref(new Set<number>());
let segmentEndTimer: ReturnType<typeof setTimeout> | null = null;
const pendingAlertId = ref<string | null>(null);
const pendingSegmentId = ref<string | null>(null);
const alertPanelRef = ref<InstanceType<typeof SpaceAlgorithmAlertPanel> | null>(null);

type ContentTab = 'alerts' | 'replay';
const contentTab = ref<ContentTab>('alerts');
const alertsMounted = ref(contentTab.value === 'alerts');
const replayMounted = ref(contentTab.value === 'replay');

function normalizeContentTab(value: unknown): ContentTab {
  if (value === 'replay') return 'replay';
  if (value === 'alerts') return 'alerts';
  if (route.query.date || route.query.alertId || route.query.segmentId) return 'replay';
  return 'alerts';
}

function syncContentTabFromRoute() {
  contentTab.value = normalizeContentTab(route.query.view);
  if (contentTab.value === 'alerts') alertsMounted.value = true;
  else replayMounted.value = true;
}

async function handleContentTabChange() {
  const view = contentTab.value;
  if (view === 'alerts') alertsMounted.value = true;
  else replayMounted.value = true;
  // 与分屏监控一致：仅本地 v-show 切换，不写 URL（fullPath 变化会导致整页 remount）
  if (view === 'replay' && activeSpaceId.value != null && !availableDates.value.length) {
    const token = loadToken;
    await loadAvailableDates(token);
    if (!isLoadStale(token)) await loadDayDetail();
  }
}

const segments = computed(() => dayDetail.value?.segments || []);
const sessionGroups = computed(() => dayDetail.value?.session_groups || []);
const timeline = computed(() => dayDetail.value?.timeline_merged || dayDetail.value?.timeline || []);

function goBack() {
  teardownPage();
  router.push({
    path: '/camera/index',
    query: buildCameraStorageQuery('record', parseSpaceFolderQuery(route.query.folder)),
  });
}

function disabledDate(current: Dayjs) {
  if (!availableDates.value.length) return false;
  const d = current.format('YYYY-MM-DD');
  return !availableDates.value.some((item) => item.date === d);
}

function selectDate(date: string) {
  if (activeSpaceId.value == null) return;
  selectedDate.value = dayjs(date);
  void loadDayDetail();
}

function handleDateChange() {
  if (activeSpaceId.value == null) return;
  void loadDayDetail();
}

function formatDuration(sec: number) {
  if (!sec) return '0分钟';
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h > 0) return `${h}小时${m}分钟`;
  return `${m}分钟`;
}

function formatSegmentTime(iso?: string) {
  if (!iso) return '--:--:--';
  return dayjs(iso).format('HH:mm:ss');
}

function formatOffsetSec(sec: number) {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function barStyle(item: RecordTimelineItem) {
  const left = (item.start_offset_sec / 86400) * 100;
  const width = Math.max(((item.end_offset_sec - item.start_offset_sec) / 86400) * 100, 0.08);
  return { left: `${left}%`, width: `${width}%` };
}

function barTitle(item: RecordTimelineItem) {
  const start = formatOffsetSec(item.start_offset_sec);
  const end = formatOffsetSec(item.end_offset_sec);
  const segCount = item.segment_ids?.length || 1;
  const suffix = item.has_alert ? '（含告警）' : '';
  return segCount > 1 ? `${start} - ${end} · ${segCount} 片段${suffix}` : `${start} - ${end}${suffix}`;
}

function clearSegmentTimer() {
  if (segmentEndTimer) {
    clearTimeout(segmentEndTimer);
    segmentEndTimer = null;
  }
}

function toggleGroup(groupId: number) {
  const next = new Set(expandedGroups.value);
  if (next.has(groupId)) next.delete(groupId);
  else next.add(groupId);
  expandedGroups.value = next;
}

function playSession(group: RecordSessionGroup) {
  if (group.segments?.length) {
    playSegment(group.segments[0]);
  }
}

function findSegmentByQuery(): RecordDaySegment | null {
  const segId = pendingSegmentId.value;
  const alertId = pendingAlertId.value;
  if (segId) {
    const hit = segments.value.find((s) => String(s.id) === segId);
    if (hit) return hit;
  }
  if (alertId) {
    const hit = segments.value.find((s) =>
      (s.alerts || []).some((a) => String(a.id) === alertId),
    );
    if (hit) return hit;
  }
  return null;
}

function playNextSegment() {
  if (!continuousPlay.value || !activeSegment.value) return;
  const idx = segments.value.findIndex(
    (s) => (s.id || s.object_name) === activeSegmentId.value,
  );
  if (idx >= 0 && idx < segments.value.length - 1) {
    playSegment(segments.value[idx + 1], true);
  }
}

function scheduleNextSegment(seg: RecordDaySegment) {
  clearSegmentTimer();
  if (!continuousPlay.value) return;
  const durMs = (seg.duration || 30) * 1000 + 300;
  segmentEndTimer = setTimeout(() => playNextSegment(), durMs);
}

function handleTimelineClick(e: MouseEvent) {
  const target = e.currentTarget as HTMLElement;
  const rect = target.getBoundingClientRect();
  const ratio = (e.clientX - rect.left) / rect.width;
  const offsetSec = Math.max(0, Math.min(86400, Math.round(ratio * 86400)));
  hoverTimeSec.value = offsetSec;
  const hit = segments.value.find(
    (seg) => (seg.start_offset_sec ?? 0) <= offsetSec && (seg.end_offset_sec ?? 0) >= offsetSec,
  );
  if (hit) {
    playSegment(hit);
  }
}

function handlePlayerMouseMove(e: MouseEvent) {
  showTimeline.value = true;
  const target = (e.currentTarget as HTMLElement).querySelector('.timeline-track') as HTMLElement;
  if (!target) {
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const ratio = (e.clientX - rect.left) / rect.width;
    hoverTimeSec.value = Math.max(0, Math.min(86400, Math.round(ratio * 86400)));
    return;
  }
  const rect = target.getBoundingClientRect();
  const ratio = (e.clientX - rect.left) / rect.width;
  hoverTimeSec.value = Math.max(0, Math.min(86400, Math.round(ratio * 86400)));
}

function getVideoUrl(seg: RecordDaySegment) {
  return resolveAlertVideoUrl(seg.url || '');
}

function playSegment(seg: RecordDaySegment, auto = false) {
  const url = getVideoUrl(seg);
  if (!url) {
    if (!auto) createMessage.warning('录像地址无效');
    return;
  }
  activeSegmentId.value = seg.id || seg.object_name;
  activeSegment.value = seg;
  playUrl.value = url;
  scheduleNextSegment(seg);

  // 展开含当前片段的会话组
  for (const group of sessionGroups.value) {
    if (group.segments.some((s) => (s.id || s.object_name) === (seg.id || seg.object_name))) {
      expandedGroups.value = new Set([...expandedGroups.value, group.group_id]);
      break;
    }
  }
}

async function loadSpaceInfo(token: number) {
  const id = activeSpaceId.value;
  if (id == null || isLoadStale(token)) return;
  try {
    const res = await getRecordSpace(id);
    if (isLoadStale(token)) return;
    const data = (res as any)?.data ?? res;
    if (data) {
      spaceInfo.value = data;
    }
  } catch (e) {
    console.error(e);
    createMessage.error('加载录像空间信息失败');
  }
}

async function loadAvailableDates(token: number) {
  const id = activeSpaceId.value;
  if (id == null || isLoadStale(token)) return;
  try {
    const res = await getRecordVideoDates(id, {
      device_id: spaceInfo.value?.device_id,
    });
    if (isLoadStale(token)) return;
    const data = (res as any)?.data ?? res;
    availableDates.value = Array.isArray(data) ? data : [];
    if (availableDates.value.length && !availableDates.value.some((d) => d.date === selectedDateStr.value)) {
      selectedDate.value = dayjs(availableDates.value[0].date);
    }
  } catch (e) {
    if (!isLoadStale(token)) console.error(e);
  }
}

async function loadDayDetail() {
  const id = activeSpaceId.value;
  if (id == null || !isOnRecordPage()) return;
  const token = bumpLoadToken();
  loading.value = true;
  playUrl.value = '';
  activeSegmentId.value = null;
  activeSegment.value = null;
  clearSegmentTimer();
  try {
    const res = await getRecordVideosByDay(id, {
      date: selectedDateStr.value,
      device_id: spaceInfo.value?.device_id,
    });
    if (isLoadStale(token)) return;
    const data = (res as any)?.data ?? res;
    dayDetail.value = data as RecordDayDetail;

    if (dayDetail.value?.session_groups?.length) {
      expandedGroups.value = new Set([dayDetail.value.session_groups[0].group_id]);
    }

    const target = findSegmentByQuery();
    if (target) {
      playSegment(target);
      pendingAlertId.value = null;
      pendingSegmentId.value = null;
    } else if (data?.segments?.length) {
      playSegment(data.segments[0]);
    }
  } catch (e) {
    if (!isLoadStale(token)) {
      console.error(e);
      createMessage.error('加载录像片段失败');
      dayDetail.value = null;
    }
  } finally {
    if (!isLoadStale(token)) loading.value = false;
  }
}

async function initPage() {
  if (!isOnRecordPage()) return;
  syncContentTabFromRoute();
  const id = parseRouteSpaceId(route.params.spaceId);
  if (id == null) return;
  activeSpaceId.value = id;
  const token = bumpLoadToken();
  applyRouteQuery();
  await loadSpaceInfo(token);
  if (isLoadStale(token)) return;
  if (contentTab.value === 'replay') {
    await loadAvailableDates(token);
    if (isLoadStale(token)) return;
    await loadDayDetail();
  }
}

function applyRouteQuery() {
  const qDate = route.query.date as string | undefined;
  const qAlertId = route.query.alertId as string | undefined;
  const qSegmentId = route.query.segmentId as string | undefined;
  if (qDate) selectedDate.value = dayjs(qDate);
  pendingAlertId.value = qAlertId || null;
  pendingSegmentId.value = qSegmentId || null;
  if (qDate || qAlertId || qSegmentId) {
    contentTab.value = 'replay';
    replayMounted.value = true;
  }
}

async function handleViewRecordFromAlert(alert: SpaceAlertItem) {
  if (!alert.device_id || !alert.time) {
    createMessage.warning('缺少设备或告警时间');
    return;
  }
  contentTab.value = 'replay';
  replayMounted.value = true;
  selectedDate.value = dayjs(alert.time);
  pendingAlertId.value = alert.id ? String(alert.id) : null;
  pendingSegmentId.value = null;

  if (alert.id) {
    try {
      const res = await resolveAlertRecordSegment(alert.device_id, alert.id);
      const data = (res as { data?: Record<string, unknown> })?.data ?? res;
      if (data && typeof data === 'object') {
        const date = String((data as { date?: string }).date || '');
        const segment = (data as { segment?: { id?: number } }).segment;
        if (date) selectedDate.value = dayjs(date);
        if (segment?.id) pendingSegmentId.value = String(segment.id);
      }
    } catch {
      // 回退到按告警日期加载
    }
  }

  await loadDayDetail();
}

onMounted(() => {
  void initPage();
});

watch(
  () => (isOnRecordPage() ? route.params.spaceId : null),
  (param, prev) => {
    if (!isOnRecordPage()) {
      teardownPage();
      return;
    }
    if (param === prev && activeSpaceId.value != null) return;
    void initPage();
  },
);

watch(contentTab, (tab) => {
  if (tab === 'alerts') alertsMounted.value = true;
  else replayMounted.value = true;
});

watch(
  () => route.query.view,
  () => {
    syncContentTabFromRoute();
  },
);

watch(
  () => (isOnRecordPage() ? [route.query.date, route.query.alertId, route.query.segmentId] : null),
  () => {
    if (!isOnRecordPage() || activeSpaceId.value == null) return;
    applyRouteQuery();
    if (contentTab.value === 'replay') {
      void loadAvailableDates(loadToken).then(() => loadDayDetail());
    }
  },
);

onBeforeRouteLeave(() => {
  teardownPage();
});

onBeforeUnmount(() => {
  teardownPage();
});
</script>

<style lang="less" scoped>
.record-replay-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 100px);
  min-height: 600px;
  background: #f0f2f5;
}

.mode-toolbar {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
  padding: 12px 16px;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;

  .mode-radio-group {
    :deep(.ant-radio-button-wrapper) {
      height: auto;
      line-height: 1;
      padding: 6px 14px;
    }
  }

  .mode-radio-item {
    display: inline-flex;
    align-items: center;
    gap: 6px;
  }

  .mode-hint {
    color: #6b7280;
    font-size: 13px;
  }
}

.content-body {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  > .panel-shell,
  > .replay-body {
    flex: 1;
    min-height: 0;
  }
}

.panel-shell {
  margin: 12px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
  background: #fff;
}

.page-header {
  padding: 12px 20px 0;
  background: #fff;
  border-bottom: 1px solid #f0f0f0;

  .header-left {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .back-btn {
    color: #595959;
    padding-left: 0;
  }

  .page-title {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    line-height: 1.4;
  }

  .page-meta {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-top: 4px;
    font-size: 13px;
    color: #8c8c8c;

    .alert-stat {
      color: #ff4d4f;
    }
  }
}

.replay-body {
  display: flex;
  gap: 0;
  overflow: hidden;
  margin: 12px;
  border-radius: 8px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.left-panel {
  width: 320px;
  flex-shrink: 0;
  background: #fff;
  border-right: 1px solid #f0f0f0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.panel-section {
  padding: 16px;
  border-bottom: 1px solid #f5f5f5;

  .section-label {
    font-size: 13px;
    font-weight: 500;
    color: #595959;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 6px;

    .count-badge {
      background: #e6f4ff;
      color: #1677ff;
      font-size: 11px;
      padding: 0 6px;
      border-radius: 10px;
    }

    .continuous-switch {
      margin-left: auto;
    }

    .switch-label {
      font-size: 12px;
      font-weight: normal;
      color: #8c8c8c;
    }
  }
}

.session-group {
  margin-bottom: 6px;
  border-radius: 6px;
  border: 1px solid #f0f0f0;
  overflow: hidden;

  &.has-alert {
    border-left: 3px solid #ff4d4f;
  }

  .session-header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 10px;
    cursor: pointer;
    background: #fafafa;

    &:hover {
      background: #f5f5f5;
    }

    .expand-icon {
      font-size: 10px;
      color: #8c8c8c;
      transition: transform 0.2s;

      &.expanded {
        transform: rotate(90deg);
      }
    }

    .session-info {
      flex: 1;
      font-size: 13px;
      display: flex;
      align-items: center;
      gap: 6px;
      min-width: 0;
    }

    .session-alert-badge {
      font-size: 11px;
      color: #ff4d4f;
      flex-shrink: 0;
    }
  }

  .session-segments {
    padding: 4px 8px 8px 24px;
  }
}

.segment-item.nested {
  padding: 6px 10px;
  margin-bottom: 2px;
}

.date-hints {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;

  .date-chip {
    font-size: 12px;
    padding: 2px 8px;
    border-radius: 4px;
    background: #f5f5f5;
    cursor: pointer;
    color: #595959;

    &:hover, &.active {
      background: #e6f4ff;
      color: #1677ff;
    }
  }
}

.segment-section {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border-bottom: none;
}

.segment-tree {
  overflow-y: auto;
  max-height: calc(100vh - 320px);
}

.segment-item {
  padding: 10px 12px;
  border-radius: 6px;
  cursor: pointer;
  margin-bottom: 4px;
  border: 1px solid transparent;
  transition: all 0.2s;

  &:hover {
    background: #f5f5f5;
  }

  &.active {
    background: #e6f4ff;
    border-color: #91caff;
  }

  &.has-alert {
    border-left: 3px solid #ff4d4f;
  }

  .segment-time {
    font-size: 13px;
    color: #262626;
    display: flex;
    align-items: center;
    gap: 6px;

    .duration-tag {
      font-size: 11px;
      color: #8c8c8c;
      background: #f5f5f5;
      padding: 0 4px;
      border-radius: 3px;
    }
  }

  .segment-alerts {
    margin-top: 6px;
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 4px;
    font-size: 12px;
    color: #ff4d4f;

    .alert-icon {
      font-size: 12px;
    }
  }
}

.empty-hint {
  padding: 24px 0;
}

.right-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: #141414;
  min-width: 0;
}

.player-wrapper {
  flex: 1;
  position: relative;
  min-height: 400px;

  :deep(.jessibuca-container) {
    height: 100% !important;
  }
}

.player-placeholder {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
  gap: 12px;
}

.timeline-overlay {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 12px 16px 16px;
  background: linear-gradient(transparent, rgba(0, 0, 0, 0.75));
  opacity: 0;
  transition: opacity 0.25s;
  pointer-events: none;

  &.visible {
    opacity: 1;
  }
}

.timeline-track {
  position: relative;
  height: 28px;
  background: rgba(255, 255, 255, 0.08);
  border-radius: 4px;
  overflow: hidden;
  cursor: pointer;
  pointer-events: auto;
}

.timeline-bar {
  position: absolute;
  top: 4px;
  height: 20px;
  background: linear-gradient(180deg, #4096ff 0%, #1677ff 100%);
  border-radius: 2px;
  opacity: 0.85;

  &.alert {
    background: linear-gradient(180deg, #ff7875 0%, #ff4d4f 100%);
    box-shadow: 0 0 6px rgba(255, 77, 79, 0.5);
  }
}

.timeline-cursor {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 2px;
  background: #fff;
  box-shadow: 0 0 4px rgba(255, 255, 255, 0.8);
  transform: translateX(-1px);
}

.timeline-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.65);

  .hover-time {
    color: #fff;
    font-weight: 500;
  }
}

.timeline-legend {
  display: flex;
  gap: 16px;
  margin-top: 6px;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.55);

  .dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 2px;
    margin-right: 4px;
    vertical-align: middle;

    &.record { background: #1677ff; }
    &.alert { background: #ff4d4f; }
  }
}

.now-playing {
  padding: 10px 16px;
  background: #1f1f1f;
  color: #d9d9d9;
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 10px;
}
</style>

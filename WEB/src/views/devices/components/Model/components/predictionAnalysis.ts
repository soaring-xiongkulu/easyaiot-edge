import type { ThresholdRule } from '../../healthIndex';

export interface PredictionSample {
  ts: number;
  value: number;
}

export interface PredictionPoint extends PredictionSample {
  lower: number;
  upper: number;
}

export type PredictionRiskLevel = 'low' | 'medium' | 'high';
export type PredictionConnectionStatus = 'online' | 'offline' | 'unknown';

export interface PredictionAnalysisResult {
  available: boolean;
  reason: string;
  samples: PredictionSample[];
  forecast: PredictionPoint[];
  sampleCount: number;
  realtimeIncluded: boolean;
  latestValue: number | null;
  predictedValue: number | null;
  slopePerHour: number;
  projectedChangeRate: number;
  anomalyScore: number;
  anomalyText: string;
  faultRisk: number;
  riskLevel: PredictionRiskLevel;
  riskText: string;
  degradationScore: number;
  degradationText: string;
  forecastEndTs: number | null;
  thresholdHitTs: number | null;
  thresholdConfigured: boolean;
  modelFit: number;
  connectionStatus: PredictionConnectionStatus;
  connectionStatusText: string;
  connectionRisk: number;
  connectionText: string;
}

const MIN_SAMPLE_COUNT = 6;
const MAX_TRAINING_SAMPLES = 240;
const FORECAST_POINT_COUNT = 12;

function normalizeConnectionStatus(connectStatus?: string): PredictionConnectionStatus {
  const normalized = String(connectStatus || '').trim().toUpperCase();
  if (normalized === 'ONLINE') return 'online';
  if (normalized === 'OFFLINE') return 'offline';
  return 'unknown';
}

function connectionDiagnosis(connectionStatus: PredictionConnectionStatus) {
  if (connectionStatus === 'online') {
    return {
      connectionStatusText: '在线',
      connectionRisk: 0,
      connectionText: '设备当前在线，实时采集链路正常',
    };
  }
  if (connectionStatus === 'offline') {
    return {
      connectionStatusText: '离线',
      connectionRisk: 100,
      connectionText: '设备当前离线，已计入采集连续性与故障风险',
    };
  }
  return {
    connectionStatusText: '未知',
    connectionRisk: 0,
    connectionText: '未获取设备连接状态，暂不计入附加风险',
  };
}

function emptyResult(
  reason: string,
  connectionStatus: PredictionConnectionStatus,
): PredictionAnalysisResult {
  const connection = connectionDiagnosis(connectionStatus);
  return {
    available: false,
    reason,
    samples: [],
    forecast: [],
    sampleCount: 0,
    realtimeIncluded: false,
    latestValue: null,
    predictedValue: null,
    slopePerHour: 0,
    projectedChangeRate: 0,
    anomalyScore: 0,
    anomalyText: '数据不足',
    faultRisk: 0,
    riskLevel: 'low',
    riskText: '待分析',
    degradationScore: 0,
    degradationText: '待分析',
    forecastEndTs: null,
    thresholdHitTs: null,
    thresholdConfigured: false,
    modelFit: 0,
    connectionStatus,
    ...connection,
  };
}

function clamp(value: number, min = 0, max = 100) {
  return Math.min(max, Math.max(min, value));
}

function median(values: number[]) {
  if (!values.length) return 0;
  const sorted = values.slice().sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2
    ? sorted[middle]
    : (sorted[middle - 1] + sorted[middle]) / 2;
}

function violatesThreshold(value: number, rule: ThresholdRule) {
  const threshold = Number(rule?.value);
  if (!Number.isFinite(threshold)) return false;
  if (rule.operator === '>') return value > threshold;
  if (rule.operator === '>=') return value >= threshold;
  if (rule.operator === '<') return value < threshold;
  if (rule.operator === '<=') return value <= threshold;
  if (rule.operator === '=') return value === threshold;
  return false;
}

function thresholdProximity(value: number, rules: ThresholdRule[]) {
  const distances = rules
    .map((rule) => Number(rule.value))
    .filter(Number.isFinite)
    .map((threshold) => Math.abs(value - threshold) / Math.max(Math.abs(threshold), 1));
  if (!distances.length) return 0;
  return clamp((1 - Math.min(...distances) / 0.2) * 100);
}

export function buildPredictionAnalysis(
  source: Array<{ ts: number; dataValue: unknown }>,
  realtimeValue?: unknown,
  realtimeTs?: number,
  thresholdRules: ThresholdRule[] = [],
  connectStatus?: string,
): PredictionAnalysisResult {
  const connectionStatus = normalizeConnectionStatus(connectStatus);
  const connection = connectionDiagnosis(connectionStatus);
  const byTimestamp = new Map<number, number>();
  source.forEach((row) => {
    const ts = Number(row?.ts);
    const value = Number(row?.dataValue);
    if (Number.isFinite(ts) && ts > 0 && Number.isFinite(value)) byTimestamp.set(ts, value);
  });

  const numericRealtime = Number(realtimeValue);
  const realtimeTimestamp = Number(realtimeTs) || Date.now();
  let realtimeIncluded = false;
  if (Number.isFinite(numericRealtime)) {
    byTimestamp.set(realtimeTimestamp, numericRealtime);
    realtimeIncluded = true;
  }

  const samples = Array.from(byTimestamp, ([ts, value]) => ({ ts, value }))
    .sort((left, right) => left.ts - right.ts)
    .slice(-MAX_TRAINING_SAMPLES);
  if (samples.length < MIN_SAMPLE_COUNT) {
    const result = emptyResult(
      `至少需要 ${MIN_SAMPLE_COUNT} 条有效数值数据，当前仅 ${samples.length} 条`,
      connectionStatus,
    );
    result.samples = samples;
    result.sampleCount = samples.length;
    result.realtimeIncluded = realtimeIncluded;
    return result;
  }

  const baseTs = samples[0].ts;
  const xValues = samples.map((sample) => (sample.ts - baseTs) / 3_600_000);
  const weights = samples.map((_, index) => 0.35 + (0.65 * index) / Math.max(samples.length - 1, 1));
  const weightSum = weights.reduce((sum, value) => sum + value, 0);
  const meanX = xValues.reduce((sum, value, index) => sum + value * weights[index], 0) / weightSum;
  const meanY = samples.reduce((sum, sample, index) => sum + sample.value * weights[index], 0) / weightSum;
  const covariance = samples.reduce(
    (sum, sample, index) =>
      sum + weights[index] * (xValues[index] - meanX) * (sample.value - meanY),
    0,
  );
  const varianceX = xValues.reduce(
    (sum, value, index) => sum + weights[index] * Math.pow(value - meanX, 2),
    0,
  );
  const slopePerHour = varianceX > 0 ? covariance / varianceX : 0;
  const intercept = meanY - slopePerHour * meanX;
  const fitted = xValues.map((value) => intercept + slopePerHour * value);
  const residuals = samples.map((sample, index) => sample.value - fitted[index]);
  const residualVariance =
    residuals.reduce((sum, value) => sum + value * value, 0) / Math.max(samples.length - 2, 1);
  const residualStd = Math.sqrt(residualVariance);
  const totalVariance = samples.reduce((sum, sample) => sum + Math.pow(sample.value - meanY, 2), 0);
  const residualSum = residuals.reduce((sum, value) => sum + value * value, 0);
  const modelFit = totalVariance > 0 ? clamp((1 - residualSum / totalVariance) * 100) : 100;

  const gaps = samples
    .slice(1)
    .map((sample, index) => sample.ts - samples[index].ts)
    .filter((gap) => gap > 0);
  const observedSpan = samples[samples.length - 1].ts - samples[0].ts;
  const forecastStep = Math.max(
    60_000,
    Math.min(median(gaps) || 300_000, Math.max(observedSpan / 6, 60_000)),
  );
  const lastSample = samples[samples.length - 1];
  const forecast: PredictionPoint[] = Array.from({ length: FORECAST_POINT_COUNT }, (_, index) => {
    const step = index + 1;
    const ts = lastSample.ts + forecastStep * step;
    const x = (ts - baseTs) / 3_600_000;
    const value = intercept + slopePerHour * x;
    const confidence = 1.96 * residualStd * Math.sqrt(1 + step / samples.length);
    return { ts, value, lower: value - confidence, upper: value + confidence };
  });

  const latestValue = lastSample.value;
  const predictedValue = forecast[forecast.length - 1].value;
  const projectedChangeRate =
    Math.abs(latestValue) > 1e-9
      ? ((predictedValue - latestValue) / Math.abs(latestValue)) * 100
      : predictedValue === latestValue
        ? 0
        : 100;
  const latestResidual = Math.abs(residuals[residuals.length - 1]);
  const anomalyZ = residualStd > 1e-9 ? latestResidual / residualStd : 0;
  const anomalyScore = Math.round(clamp((anomalyZ / 3) * 100));
  const anomalyText = anomalyScore >= 70 ? '异常偏离明显' : anomalyScore >= 35 ? '存在波动异常' : '趋势基本稳定';

  const numericRules = thresholdRules.filter((rule) => Number.isFinite(Number(rule?.value)));
  const thresholdConfigured = numericRules.length > 0;
  const currentThresholdHit = numericRules.some((rule) => violatesThreshold(latestValue, rule));
  const thresholdHitPoint = forecast.find((point) =>
    numericRules.some((rule) => violatesThreshold(point.value, rule)),
  );
  const proximity = thresholdConfigured ? thresholdProximity(latestValue, numericRules) : 0;
  const changeMagnitude = clamp(Math.abs(projectedChangeRate) * 2.5);
  const volatilityBase = Math.max(Math.abs(meanY), 1);
  const volatility = clamp((residualStd / volatilityBase) * 400);
  const thresholdRisk = currentThresholdHit ? 100 : thresholdHitPoint ? 82 : proximity;
  const dataFaultRisk = Math.round(
    clamp(
      thresholdConfigured
        ? thresholdRisk * 0.58 + anomalyScore * 0.25 + volatility * 0.17
        : anomalyScore * 0.5 + volatility * 0.3 + changeMagnitude * 0.2,
    ),
  );
  const faultRisk = connectionStatus === 'offline'
    ? Math.round(clamp(Math.max(72, dataFaultRisk + (100 - dataFaultRisk) * 0.35)))
    : dataFaultRisk;
  const riskLevel: PredictionRiskLevel = faultRisk >= 70 ? 'high' : faultRisk >= 35 ? 'medium' : 'low';
  const riskText = connectionStatus === 'offline'
    ? '设备当前离线，采集连续性和故障风险已上调'
    : currentThresholdHit
      ? '实时值已触发阈值'
      : thresholdHitPoint
        ? '预测窗口内可能触发阈值'
        : thresholdConfigured
          ? '预测窗口内未见阈值越界'
          : '未配置阈值，按趋势波动估算';

  const movingTowardThreshold = thresholdHitPoint != null || proximity >= 50;
  const degradationScore = Math.round(
    clamp(changeMagnitude * 0.45 + anomalyScore * 0.3 + volatility * 0.25 + (movingTowardThreshold ? 15 : 0)),
  );
  const degradationText = degradationScore >= 70
    ? '性能衰减趋势明显'
    : degradationScore >= 35
      ? '存在性能衰减迹象'
      : '暂未发现明显衰减';

  return {
    available: true,
    reason: '',
    samples,
    forecast,
    sampleCount: samples.length,
    realtimeIncluded,
    latestValue,
    predictedValue,
    slopePerHour,
    projectedChangeRate,
    anomalyScore,
    anomalyText,
    faultRisk,
    riskLevel,
    riskText,
    degradationScore,
    degradationText,
    forecastEndTs: forecast[forecast.length - 1]?.ts || null,
    thresholdHitTs: thresholdHitPoint?.ts || null,
    thresholdConfigured,
    modelFit: Math.round(modelFit),
    connectionStatus,
    ...connection,
  };
}

export type ThresholdOperator = '>' | '>=' | '<' | '<=' | '=';

export interface ThresholdRule {
  operator: ThresholdOperator;
  value: any;
  weight?: number;
  critical?: boolean;
}

export type ThresholdConfig = Record<string, ThresholdRule[]>;

export interface DeviceHealthResult {
  score: number | null;
  configuredCount: number;
  normalCount: number;
  nearCount: number;
  exceededCount: number;
  missingCount: number;
  criticalExceeded: boolean;
  totalWeight: number;
  penaltyWeight: number;
  maxSeverity: number;
  criticalProperties: string[];
}

const NEAR_THRESHOLD_RATIO = 0.1;
const NEAR_THRESHOLD_PENALTY_RATIO = 0.35;
const DEFAULT_HEALTH_WEIGHT = 10;
const IMPORTANT_HEALTH_WEIGHT = 20;
const CRITICAL_HEALTH_WEIGHT = 30;
const MAX_SEVERITY_MULTIPLIER = 10;
const PROPERTY_HEALTH_RATIO = 0.7;
const AVAILABILITY_HEALTH_RATIO = 0.3;

const CRITICAL_PROPERTY_KEYWORDS = ['voltage', '电压'];
const IMPORTANT_PROPERTY_KEYWORDS = [
  'current',
  'pressure',
  'temperature',
  'smoke',
  'alarm',
  'vibration',
  '电流',
  '压力',
  '温度',
  '烟感',
  '报警',
  '振动',
];

function normalizedPropertyCode(propertyCode: string) {
  return propertyCode.trim().toLowerCase();
}

export function isDefaultCriticalProperty(propertyCode: string) {
  const normalized = normalizedPropertyCode(propertyCode);
  return CRITICAL_PROPERTY_KEYWORDS.some((keyword) => normalized.includes(keyword));
}

export function getDefaultHealthWeight(propertyCode: string) {
  const normalized = normalizedPropertyCode(propertyCode);
  if (isDefaultCriticalProperty(propertyCode)) return CRITICAL_HEALTH_WEIGHT;
  if (IMPORTANT_PROPERTY_KEYWORDS.some((keyword) => normalized.includes(keyword))) {
    return IMPORTANT_HEALTH_WEIGHT;
  }
  return DEFAULT_HEALTH_WEIGHT;
}

function normalizeWeight(weight: unknown, propertyCode: string) {
  const numeric = Number(weight);
  if (Number.isFinite(numeric) && numeric >= 1 && numeric <= 100) return numeric;
  return getDefaultHealthWeight(propertyCode);
}

function comparableValue(value: any) {
  if (value !== null && typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
  return value === null || value === undefined ? '' : String(value);
}

export function compareThreshold(actual: any, rule: ThresholdRule) {
  const actualText = comparableValue(actual);
  const expectedText = comparableValue(rule?.value);
  const actualNumber = actualText.trim() === '' ? NaN : Number(actualText);
  const expectedNumber = expectedText.trim() === '' ? NaN : Number(expectedText);
  const numeric = Number.isFinite(actualNumber) && Number.isFinite(expectedNumber);
  const left: number | string = numeric ? actualNumber : actualText;
  const right: number | string = numeric ? expectedNumber : expectedText;

  if (rule?.operator === '=') return left === right;
  if (rule?.operator === '>') return left > right;
  if (rule?.operator === '>=') return left >= right;
  if (rule?.operator === '<') return left < right;
  if (rule?.operator === '<=') return left <= right;
  return false;
}

function isNearThreshold(actual: any, rule: ThresholdRule) {
  const actualNumber = Number(actual);
  const expectedNumber = Number(rule?.value);
  if (!Number.isFinite(actualNumber) || !Number.isFinite(expectedNumber)) return false;

  const nearBand = Math.max(Math.abs(expectedNumber) * NEAR_THRESHOLD_RATIO, 0.1);
  if (rule.operator === '>' || rule.operator === '>=') {
    return actualNumber < expectedNumber && expectedNumber - actualNumber <= nearBand;
  }
  if (rule.operator === '<' || rule.operator === '<=') {
    return actualNumber > expectedNumber && actualNumber - expectedNumber <= nearBand;
  }
  return false;
}

function exceededSeverity(actual: any, rule: ThresholdRule) {
  const actualNumber = Number(actual);
  const expectedNumber = Number(rule?.value);
  if (!Number.isFinite(actualNumber) || !Number.isFinite(expectedNumber)) return 0;

  const referenceBand = Math.max(Math.abs(expectedNumber) * NEAR_THRESHOLD_RATIO, 0.1);
  if (rule.operator === '>' || rule.operator === '>=') {
    return Math.max(0, actualNumber - expectedNumber) / referenceBand;
  }
  if (rule.operator === '<' || rule.operator === '<=') {
    return Math.max(0, expectedNumber - actualNumber) / referenceBand;
  }
  return 0;
}

function getScoreCap(maxSeverity: number) {
  if (maxSeverity >= 3) return 59;
  if (maxSeverity >= 1) return 79;
  return 100;
}

export function calculateWeightedHealthScore(
  totalWeight: number,
  penaltyWeight: number,
  maxSeverity: number,
  criticalExceeded: boolean,
) {
  if (!totalWeight) return null;
  if (criticalExceeded) return 0;
  const weightedScore = Math.round(
    100 * (1 - Math.min(1, Math.max(0, penaltyWeight) / totalWeight)),
  );
  return Math.min(weightedScore, getScoreCap(maxSeverity));
}

export function calculateAvailabilityAdjustedHealthScore(
  propertyScore: number | null,
  onlineDeviceCount: number,
  deviceCount: number,
  criticalExceeded = false,
) {
  if (!deviceCount) return null;
  if (criticalExceeded) return 0;
  const availabilityRate = Math.max(0, Math.min(1, onlineDeviceCount / deviceCount));
  const availabilityScore = Math.round(availabilityRate * 100);
  if (propertyScore == null) return availabilityScore;

  const connectivityCap = availabilityRate === 0 ? 59 : availabilityRate < 0.5 ? 79 : 100;
  return Math.min(
    connectivityCap,
    Math.round(
      propertyScore * PROPERTY_HEALTH_RATIO
        + propertyScore * availabilityRate * AVAILABILITY_HEALTH_RATIO,
    ),
  );
}

export function calculateDeviceHealth(
  thresholdConfig: ThresholdConfig,
  reportedData: Record<string, any>,
): DeviceHealthResult {
  const configuredProperties = Object.entries(thresholdConfig || {}).filter(
    ([propertyCode, rules]) => propertyCode.trim() && Array.isArray(rules) && rules.length > 0,
  );
  const configuredCount = configuredProperties.length;
  if (!configuredCount) {
    return {
      score: null,
      configuredCount: 0,
      normalCount: 0,
      nearCount: 0,
      exceededCount: 0,
      missingCount: 0,
      criticalExceeded: false,
      totalWeight: 0,
      penaltyWeight: 0,
      maxSeverity: 0,
      criticalProperties: [],
    };
  }

  let normalCount = 0;
  let nearCount = 0;
  let exceededCount = 0;
  let missingCount = 0;
  let criticalExceeded = false;
  let totalWeight = 0;
  let penaltyWeight = 0;
  let maxSeverity = 0;
  const criticalProperties: string[] = [];

  configuredProperties.forEach(([propertyCode, rules]) => {
    const weight = Math.max(...rules.map((rule) => normalizeWeight(rule.weight, propertyCode)));
    const critical = rules.some((rule) => rule.critical === true)
      || (rules.every((rule) => rule.critical === undefined) && isDefaultCriticalProperty(propertyCode));
    totalWeight += weight;
    const hasValue = Object.prototype.hasOwnProperty.call(reportedData || {}, propertyCode)
      && reportedData[propertyCode] !== null
      && reportedData[propertyCode] !== undefined
      && reportedData[propertyCode] !== '';
    if (!hasValue) {
      missingCount += 1;
      penaltyWeight += weight;
      return;
    }

    const actual = reportedData[propertyCode];
    const exceededRules = rules.filter((rule) => compareThreshold(actual, rule));
    if (exceededRules.length) {
      exceededCount += 1;
      const severity = Math.max(...exceededRules.map((rule) => exceededSeverity(actual, rule)));
      maxSeverity = Math.max(maxSeverity, severity);
      const severityMultiplier = Math.min(MAX_SEVERITY_MULTIPLIER, 1 + severity);
      penaltyWeight += weight * severityMultiplier;
      if (critical) {
        criticalExceeded = true;
        criticalProperties.push(propertyCode);
      }
      return;
    }

    const near = rules.some((rule) => isNearThreshold(actual, rule));
    if (near) {
      nearCount += 1;
      penaltyWeight += weight * NEAR_THRESHOLD_PENALTY_RATIO;
      return;
    }

    normalCount += 1;
  });

  const score = calculateWeightedHealthScore(
    totalWeight,
    penaltyWeight,
    maxSeverity,
    criticalExceeded,
  );

  return {
    score,
    configuredCount,
    normalCount,
    nearCount,
    exceededCount,
    missingCount,
    criticalExceeded,
    totalWeight,
    penaltyWeight,
    maxSeverity,
    criticalProperties,
  };
}

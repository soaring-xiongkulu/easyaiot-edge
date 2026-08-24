/** 物模型属性/服务参数：类型归一、控件选择、校验与强制转换 */

export type ControlWidget = 'switch' | 'number' | 'select' | 'datetime' | 'json' | 'text';

export interface ThingFieldMeta {
  code: string;
  name?: string;
  datatype?: string;
  unit?: string;
  min?: number | string | null;
  max?: number | string | null;
  step?: number | string | null;
  maxlength?: number | string | null;
  enumlist?: string | string[] | null;
  required?: number | boolean | null;
  description?: string;
}

export function normalizeDatatype(raw?: string): string {
  return String(raw || 'text').trim().toLowerCase();
}

export function parseEnumOptions(enumlist: ThingFieldMeta['enumlist']): { label: string; value: string }[] {
  if (!enumlist) return [];
  let list: any[] = [];
  if (Array.isArray(enumlist)) {
    list = enumlist;
  } else if (typeof enumlist === 'string') {
    const text = enumlist.trim();
    if (!text) return [];
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) list = parsed;
      else list = text.split(/[,，|/]/).map((s) => s.trim()).filter(Boolean);
    } catch {
      list = text.split(/[,，|/]/).map((s) => s.trim()).filter(Boolean);
    }
  }
  return list.map((item) => {
    if (item && typeof item === 'object') {
      const value = String(item.value ?? item.key ?? item.code ?? item.label ?? '');
      const label = String(item.label ?? item.name ?? value);
      return { label, value };
    }
    return { label: String(item), value: String(item) };
  }).filter((o) => o.value !== '');
}

export function resolveWidget(meta: ThingFieldMeta): ControlWidget {
  const dt = normalizeDatatype(meta.datatype);
  const enums = parseEnumOptions(meta.enumlist);
  if (enums.length > 0) return 'select';
  if (['bool', 'boolean'].includes(dt)) return 'switch';
  if (['int', 'integer', 'long', 'decimal', 'double', 'float', 'number'].includes(dt)) return 'number';
  if (['datetime', 'date', 'time'].includes(dt)) return 'datetime';
  if (['jsonobject', 'json', 'object', 'struct', 'subuct'].includes(dt)) return 'json';
  return 'text';
}

export function formatDisplayValue(value: any): string {
  if (value === undefined || value === null || value === '') return '--';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }
  return String(value);
}

export function valuesEqual(a: any, b: any): boolean {
  if (a === b) return true;
  if (a === undefined || a === null || a === '') {
    return b === undefined || b === null || b === '';
  }
  if (typeof a === 'object' || typeof b === 'object') {
    try {
      return JSON.stringify(a) === JSON.stringify(b);
    } catch {
      return false;
    }
  }
  return String(a) === String(b);
}

/** 将影子/上报值填入表单初始态 */
export function toFormValue(meta: ThingFieldMeta, raw: any): any {
  if (raw === undefined || raw === null || raw === '') {
    const widget = resolveWidget(meta);
    if (widget === 'switch') return false;
    if (widget === 'json') return '{\n  \n}';
    return undefined;
  }
  const widget = resolveWidget(meta);
  if (widget === 'switch') {
    if (typeof raw === 'boolean') return raw;
    const text = String(raw).toLowerCase();
    return text === '1' || text === 'true' || text === 'on';
  }
  if (widget === 'number') {
    const num = Number(raw);
    return Number.isFinite(num) ? num : undefined;
  }
  if (widget === 'json') {
    if (typeof raw === 'string') return raw;
    try {
      return JSON.stringify(raw, null, 2);
    } catch {
      return String(raw);
    }
  }
  return String(raw);
}

export function coerceAndValidate(
  meta: ThingFieldMeta,
  raw: any,
): { ok: true; value: any } | { ok: false; message: string } {
  const code = meta.code;
  const widget = resolveWidget(meta);
  const required = meta.required === 1 || meta.required === true;

  if (raw === undefined || raw === null || raw === '') {
    if (required) return { ok: false, message: `${code} 为必填` };
    return { ok: false, message: 'empty' };
  }

  const dt = normalizeDatatype(meta.datatype);

  try {
    if (widget === 'switch' || ['bool', 'boolean'].includes(dt)) {
      if (typeof raw === 'boolean') return { ok: true, value: raw };
      const text = String(raw).toLowerCase();
      if (['1', 'true', 'on'].includes(text)) return { ok: true, value: true };
      if (['0', 'false', 'off'].includes(text)) return { ok: true, value: false };
      return { ok: false, message: `${code} 必须是布尔值` };
    }

    if (widget === 'number' || ['int', 'integer', 'long', 'decimal', 'double', 'float', 'number'].includes(dt)) {
      const num = typeof raw === 'number' ? raw : Number(raw);
      if (!Number.isFinite(num)) return { ok: false, message: `${code} 必须是数字` };
      if (meta.min != null && meta.min !== '' && num < Number(meta.min)) {
        return { ok: false, message: `${code} 不能小于 ${meta.min}` };
      }
      if (meta.max != null && meta.max !== '' && num > Number(meta.max)) {
        return { ok: false, message: `${code} 不能大于 ${meta.max}` };
      }
      if (['int', 'integer', 'long'].includes(dt)) {
        return { ok: true, value: Math.trunc(num) };
      }
      return { ok: true, value: num };
    }

    if (widget === 'json') {
      if (typeof raw === 'object') return { ok: true, value: raw };
      const text = String(raw).trim();
      try {
        return { ok: true, value: JSON.parse(text) };
      } catch {
        return { ok: false, message: `${code} 不是合法 JSON` };
      }
    }

    const text = String(raw);
    if (meta.maxlength != null && meta.maxlength !== '' && text.length > Number(meta.maxlength)) {
      return { ok: false, message: `${code} 长度不能超过 ${meta.maxlength}` };
    }
    const enums = parseEnumOptions(meta.enumlist);
    if (enums.length > 0 && !enums.some((o) => o.value === text)) {
      return { ok: false, message: `${code} 不在枚举范围内` };
    }
    return { ok: true, value: text };
  } catch (e: any) {
    return { ok: false, message: e?.message || `${code} 校验失败` };
  }
}

export function datatypeLabel(datatype?: string): string {
  const dt = normalizeDatatype(datatype);
  const map: Record<string, string> = {
    int: '整数',
    integer: '整数',
    long: '整数',
    decimal: '小数',
    double: '小数',
    float: '小数',
    number: '数值',
    bool: '布尔',
    boolean: '布尔',
    text: '文本',
    string: '文本',
    datetime: '时间',
    date: '日期',
    jsonobject: 'JSON',
    json: 'JSON',
    object: 'JSON',
  };
  return map[dt] || (datatype || '文本');
}

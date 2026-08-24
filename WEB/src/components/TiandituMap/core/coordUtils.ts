import { fromLonLat, toLonLat } from 'ol/proj';
import type { LngLat } from '../types';

export function toMercator(lng: number, lat: number): [number, number] {
  return fromLonLat([lng, lat]) as [number, number];
}

export function toWgs84(coordinate: [number, number]): LngLat {
  const [lng, lat] = toLonLat(coordinate);
  return { lng, lat };
}

export function isValidLngLat(lng: unknown, lat: unknown): boolean {
  const lngNum = Number(lng);
  const latNum = Number(lat);
  return !Number.isNaN(lngNum) && !Number.isNaN(latNum)
    && lngNum >= -180 && lngNum <= 180
    && latNum >= -90 && latNum <= 90;
}

export function formatLngLat(lng: number, lat: number, precision = 6): string {
  return `${lng.toFixed(precision)}, ${lat.toFixed(precision)}`;
}

/** 计算两点间近似距离（米，Haversine） */
export function distanceMeters(a: LngLat, b: LngLat): number {
  const R = 6371000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** 轨迹总里程（米） */
export function trackDistanceMeters(points: LngLat[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    total += distanceMeters(points[i - 1], points[i]);
  }
  return total;
}

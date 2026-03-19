import { getToken, clearToken } from "./lib/auth";

export interface Meal {
  meal_date: string;
  meal_name: string;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  protein_density: number;
  purine_level: string;
  purine_mg: number;
  purine_confidence: string;
  purine_notes: string;
  gout_warning: number;
  water_ml: number;
}

export interface DailySummary {
  meal_date: string;
  meal_count: number;
  total_calories: number;
  total_protein_g: number;
  total_fat_g: number;
  total_carbs_g: number;
  total_fiber_g: number;
  day_gout_alert: number;
  max_purine_level: string;
}

export interface WeighIn {
  weigh_date: string;
  weight_kg: number;
  notes: string | null;
}

export interface WaterData {
  total_ml: number;
  purine_bonus_ml: number;
}

export interface Goal {
  target_calories: number;
  target_protein_g: number;
  target_water_ml: number | null;
}

export interface InjectionData {
  injection_date: string;
  days_since: number;
  dose_mg: number;
  site: string | null;
  hours_since: number;
  plasma_level: number;
  suppression: number;
}

async function apiFetch(url: string, options?: RequestInit): Promise<Response> {
  const headers = new Headers(options?.headers);
  const token = getToken();
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  const res = await fetch(url, { ...options, headers });

  if (res.status === 401) {
    clearToken();
    window.dispatchEvent(new CustomEvent("auth:logout"));
  }

  return res;
}

async function fetchJson<T>(url: string): Promise<T> {
  const res = await apiFetch(url);
  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}

export async function login(password: string): Promise<string> {
  const res = await fetch("/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ password }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: "Login failed" }));
    throw new Error(err.error || `HTTP ${res.status}`);
  }
  const data = await res.json();
  return data.token;
}

export function fetchStats(date: string): Promise<DailySummary> {
  return fetchJson<DailySummary>(`/api/stats?date=${date}`);
}

export function fetchMeals(date: string): Promise<Meal[]> {
  return fetchJson<Meal[]>(`/api/meals?date=${date}`);
}

export function fetchWeight(): Promise<WeighIn[]> {
  return fetchJson<WeighIn[]>("/api/weight");
}

export function fetchWater(date: string): Promise<WaterData> {
  return fetchJson<WaterData>(`/api/water?date=${date}`);
}

export function fetchGoal(): Promise<Goal | null> {
  return fetchJson<Goal | null>("/api/goal");
}

export interface AnalyticsDay {
  date: string;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  water_ml: number;
}

export function fetchAnalytics(days: number): Promise<AnalyticsDay[]> {
  return fetchJson<AnalyticsDay[]>(`/api/analytics?days=${days}`);
}

export interface CurvePoint {
  hour: number;
  plasma: number;
  suppression: number;
}

export interface InjectionHistoryEntry {
  date: string;
  dose_mg: number;
  site: string | null;
}

export interface KineticsData {
  curve: CurvePoint[];
  history: InjectionHistoryEntry[];
}

export function fetchKinetics(): Promise<KineticsData> {
  return fetchJson<KineticsData>("/api/kinetics");
}

export function fetchInjection(): Promise<InjectionData | null> {
  return fetchJson<InjectionData | null>("/api/injection");
}

export async function logInjection(
  dose_mg?: number,
  site?: string,
): Promise<InjectionData | null> {
  const res = await apiFetch("/api/injection", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ dose_mg, site }),
  });
  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<InjectionData | null>;
}

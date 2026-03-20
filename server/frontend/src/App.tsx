import { useEffect, useState, useCallback } from "react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  Legend,
} from "recharts";
import {
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  Droplets,
  Scale,
  Flame,
  Beef,
  Wheat,
  AlertTriangle,
  LogOut,
  Sun,
  Moon,
  Syringe,
  BarChart3,
  TrendingUp,
  LayoutDashboard,
  Activity,
  Languages,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import { isTokenValid, clearToken } from "./lib/auth";
import { LoginPage } from "./components/login-page";
import type {
  DailySummary,
  Meal,
  WeighIn,
  WaterData,
  Goal,
  InjectionData,
  AnalyticsDay,
  KineticsData,
  AppConfig,
} from "./api.ts";
import {
  fetchStats,
  fetchMeals,
  fetchWeight,
  fetchWater,
  fetchGoal,
  fetchInjection,
  fetchAnalytics,
  fetchKinetics,
  logInjection,
  fetchConfig,
} from "./api.ts";

function formatDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function displayDate(d: Date): string {
  return d.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function purineBadge(
  level: string,
  t: (key: string) => string,
): {
  color: string;
  bg: string;
  label: string;
} {
  switch (level.toLowerCase()) {
    case "high":
      return {
        color: "text-purine-high",
        bg: "bg-purine-high/20",
        label: t("purine.high"),
      };
    case "medium":
      return {
        color: "text-purine-med",
        bg: "bg-purine-med/20",
        label: t("purine.medium"),
      };
    default:
      return {
        color: "text-purine-low",
        bg: "bg-purine-low/20",
        label: t("purine.low"),
      };
  }
}

function confidenceBadge(
  confidence: string,
  t: (key: string) => string,
): {
  color: string;
  label: string;
} {
  switch (confidence?.toLowerCase()) {
    case "low":
      return { color: "text-purine-high", label: t("confidence.low") };
    case "medium":
      return { color: "text-purine-med", label: t("confidence.medium") };
    default:
      return { color: "text-purine-low", label: "" };
  }
}

function StatCard({
  icon,
  label,
  value,
  unit,
  color,
}: {
  icon: React.ReactNode;
  label: string;
  value: number;
  unit: string;
  color: string;
}) {
  return (
    <div className="glass glass-hover p-5">
      <div className="flex items-center gap-2 mb-2 opacity-60 text-sm">
        {icon}
        <span>{label}</span>
      </div>
      <div className="flex items-baseline gap-1">
        <span className={`text-3xl font-bold ${color}`}>
          {Math.round(value)}
        </span>
        <span className="text-sm opacity-50">{unit}</span>
      </div>
    </div>
  );
}

function GoalProgress({
  label,
  current,
  target,
  color,
  bgColor,
}: {
  label: string;
  current: number;
  target: number;
  color: string;
  bgColor: string;
}) {
  const pct = Math.min((current / target) * 100, 100);
  return (
    <div className="mb-3">
      <div className="flex justify-between text-sm mb-1">
        <span className="opacity-70">{label}</span>
        <span>
          <span className={color}>{Math.round(current)}</span>
          <span className="opacity-40"> / {target}</span>
        </span>
      </div>
      <div className="progress-bar">
        <div
          className={`progress-fill ${bgColor}`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}

function MealRow({ meal, gout }: { meal: Meal; gout: boolean }) {
  const { t } = useTranslation();
  const badge = purineBadge(meal.purine_level, t);
  const conf = confidenceBadge(meal.purine_confidence, t);
  return (
    <div className="glass glass-hover p-4 flex flex-col sm:flex-row sm:items-center gap-3">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-medium truncate">
            {meal.meal_name}
          </span>
          {gout && (
            <span className={`purine-badge ${badge.color} ${badge.bg}`}>
              {badge.label}
            </span>
          )}
          {gout && conf.label && (
            <span className={`text-xs ${conf.color}`}>
              {conf.label}
            </span>
          )}
          {gout && meal.gout_warning === 1 && (
            <span className="text-purine-high text-sm" title={t("purine.goutRisk")}>
              {"\u{1F480}"}
            </span>
          )}
        </div>
        {gout && meal.purine_mg > 0 && (
          <span className="text-xs opacity-40">
            {meal.purine_mg} {t("purine.mgLabel")}
          </span>
        )}
        {gout && meal.purine_notes && (
          <span className="text-xs opacity-50 italic block">
            {meal.purine_notes}
          </span>
        )}
      </div>
      <div className="flex gap-4 text-sm flex-shrink-0">
        <span className="text-cal">
          {Math.round(meal.calories)} cal
        </span>
        <span className="text-protein">
          {Math.round(meal.protein_g)}p
        </span>
        <span className="text-carbs">
          {Math.round(meal.carbs_g)}c
        </span>
        <span className="text-fat">
          {Math.round(meal.fat_g)}f
        </span>
      </div>
    </div>
  );
}

function WeightChart({ entries }: { entries: WeighIn[] }) {
  const { t } = useTranslation();
  const [mode, setMode] = useState<"bar" | "line">("line");

  if (entries.length === 0) {
    return (
      <p className="text-sm opacity-40">{t("weight.empty")}</p>
    );
  }

  const sorted = [...entries].sort(
    (a, b) => a.weigh_date.localeCompare(b.weigh_date),
  );
  const data = sorted.map((e) => ({
    date: e.weigh_date.slice(5),
    kg: e.weight_kg,
    notes: e.notes,
  }));

  const weights = data.map((d) => d.kg);
  const min = Math.min(...weights);
  const max = Math.max(...weights);
  const pad = Math.max((max - min) * 0.15, 0.3);

  const tooltipStyle = {
    backgroundColor: "var(--color-surface-raised)",
    border: "1px solid color-mix(in srgb, currentColor 15%, transparent)",
    borderRadius: "8px",
    fontSize: "12px",
  };

  return (
    <>
      <div className="flex justify-end mb-2">
        <div className="flex gap-1 bg-surface-raised rounded-lg p-0.5">
          <button
            onClick={() => setMode("bar")}
            className={`p-1.5 rounded-md transition-colors ${mode === "bar" ? "bg-protein/20 text-protein" : "opacity-40 hover:opacity-70"}`}
            title={t("weight.barMode")}
          >
            <BarChart3 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => setMode("line")}
            className={`p-1.5 rounded-md transition-colors ${mode === "line" ? "bg-protein/20 text-protein" : "opacity-40 hover:opacity-70"}`}
            title={t("weight.lineMode")}
          >
            <TrendingUp className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
      <ResponsiveContainer width="100%" height={160}>
        {mode === "bar" ? (
          <BarChart data={data}>
            <CartesianGrid
              strokeDasharray="3 3"
              stroke="currentColor"
              strokeOpacity={0.07}
            />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, opacity: 0.4 }}
              tickLine={false}
              axisLine={false}
            />
            <YAxis
              domain={[min - pad, max + pad]}
              tick={{ fontSize: 10, opacity: 0.4 }}
              tickLine={false}
              axisLine={false}
              width={36}
              tickFormatter={(v: number) => v.toFixed(1)}
            />
            <Tooltip
              contentStyle={tooltipStyle}
              formatter={(v) => [`${Number(v).toFixed(1)} kg`, t("weight.tooltip")]}
            />
            <Bar
              dataKey="kg"
              fill="var(--color-protein)"
              radius={[4, 4, 0, 0]}
              opacity={0.8}
            />
          </BarChart>
        ) : (
          <LineChart data={data}>
            <CartesianGrid
              strokeDasharray="3 3"
              stroke="currentColor"
              strokeOpacity={0.07}
            />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 10, opacity: 0.4 }}
              tickLine={false}
              axisLine={false}
            />
            <YAxis
              domain={[min - pad, max + pad]}
              tick={{ fontSize: 10, opacity: 0.4 }}
              tickLine={false}
              axisLine={false}
              width={36}
              tickFormatter={(v: number) => v.toFixed(1)}
            />
            <Tooltip
              contentStyle={tooltipStyle}
              formatter={(v) => [`${Number(v).toFixed(1)} kg`, t("weight.tooltip")]}
            />
            <Line
              type="monotone"
              dataKey="kg"
              stroke="var(--color-protein)"
              strokeWidth={2}
              dot={{ r: 3, fill: "var(--color-protein)" }}
              activeDot={{ r: 5 }}
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </>
  );
}

function WaterDisplay({
  totalMl,
  purineBonusMl,
}: {
  totalMl: number;
  purineBonusMl: number;
}) {
  const { t } = useTranslation();
  const glasses = totalMl / 250;
  return (
    <div>
      <div className="flex items-baseline gap-2">
        <Droplets className="text-water w-5 h-5" />
        <span className="text-2xl font-bold text-water">
          {totalMl}
        </span>
        <span className="text-sm opacity-50">
          ml ({glasses.toFixed(1)} {t("hydration.glasses")})
        </span>
      </div>
      {purineBonusMl > 0 && (
        <p className="text-xs opacity-40 mt-1">
          {t("hydration.purineBonus", { ml: purineBonusMl })}
        </p>
      )}
    </div>
  );
}

function getSuppressionPhase(
  suppression: number,
  t: (key: string) => string,
): {
  name: string;
  description: string;
  color: string;
  bgColor: string;
} {
  if (suppression >= 0.8) {
    return {
      name: t("phase.absorption"),
      description: t("phase.absorptionDesc"),
      color: "text-yellow-400",
      bgColor: "bg-yellow-400",
    };
  }
  if (suppression >= 0.5) {
    return {
      name: t("phase.peakSuppression"),
      description: t("phase.peakSuppressionDesc"),
      color: "text-green-400",
      bgColor: "bg-green-400",
    };
  }
  if (suppression >= 0.3) {
    return {
      name: t("phase.appetiteReturning"),
      description: t("phase.appetiteReturningDesc"),
      color: "text-orange-400",
      bgColor: "bg-orange-400",
    };
  }
  return {
    name: t("phase.timeToInject"),
    description: t("phase.timeToInjectDesc"),
    color: "text-red-400",
    bgColor: "bg-red-400",
  };
}

function siteLabel(site: string, t: (key: string) => string): string {
  const key = `site.${site}`;
  const result = t(key);
  return result === key ? site : result;
}

function InjectionSection({
  data,
  onLog,
}: {
  data: InjectionData | null;
  onLog: () => void;
}) {
  const { t } = useTranslation();
  const canLog = !data || data.days_since >= 7;

  if (!data) {
    return (
      <div className="injection-banner p-5 mb-5">
        <div className="flex items-center gap-2">
          <Syringe className="w-5 h-5 text-injection" />
          <span className="font-semibold text-sm">Mounjaro</span>
          <span className="ml-auto">
            <button
              onClick={onLog}
              className="injection-btn text-sm px-3 py-1.5 rounded-lg"
            >
              {t("injection.logBtn")}
            </button>
          </span>
        </div>
        <p className="text-xs opacity-50 mt-2">
          {t("injection.noData")}
        </p>
      </div>
    );
  }

  const phase = getSuppressionPhase(data.suppression, t);
  const suppressionPct = Math.round(data.suppression * 100);
  const progressPct = Math.min((data.days_since / 7) * 100, 100);
  const siteName = data.site ? siteLabel(data.site, t) : null;

  return (
    <div className="injection-banner p-5 mb-5">
      <div className="flex items-center gap-2 mb-3">
        <Syringe className="w-5 h-5 text-injection" />
        <span className="font-semibold text-sm">Mounjaro</span>
        <span className="ml-auto flex items-center gap-3">
          <span className="text-sm opacity-60">
            {t("injection.day", { count: data.days_since })}
          </span>
          {canLog && (
            <button
              onClick={onLog}
              className="injection-btn text-sm px-3 py-1.5 rounded-lg"
            >
              {t("injection.logBtn")}
            </button>
          )}
        </span>
      </div>
      <div className="flex items-center gap-2 mb-2">
        <span className={`font-semibold ${phase.color}`}>
          {phase.name}
        </span>
        <span className="text-sm opacity-50">
          — {t("injection.suppression", { pct: suppressionPct })}
        </span>
      </div>
      <p className="text-xs opacity-60 mb-3">{phase.description}</p>
      <div className="progress-bar mb-1">
        <div
          className={`progress-fill ${phase.bgColor}`}
          style={{ width: `${progressPct}%` }}
        />
      </div>
      <div className="flex justify-between text-[10px] opacity-30 mb-3">
        <span>0</span>
        <span>{t("injection.days7")}</span>
      </div>
      <div className="flex gap-4 text-xs opacity-50">
        <span>{data.dose_mg} mg</span>
        {siteName && <span>{siteName}</span>}
        <span>
          {t("injection.agoHours", { hours: Math.round(data.hours_since) })}
        </span>
      </div>
    </div>
  );
}

const RANGE_OPTIONS = [
  { days: 7, label: "7d" },
  { days: 14, label: "14d" },
  { days: 30, label: "30d" },
  { days: 90, label: "90d" },
];

const chartGrid = {
  strokeDasharray: "3 3",
  stroke: "currentColor",
  strokeOpacity: 0.07,
};
const chartAxis = { fontSize: 10, opacity: 0.4 };
const chartTooltip = {
  backgroundColor: "var(--color-surface-raised)",
  border: "1px solid color-mix(in srgb, currentColor 15%, transparent)",
  borderRadius: "8px",
  fontSize: "12px",
};

function AnalyticsTab() {
  const { t } = useTranslation();
  const [days, setDays] = useState(7);
  const [data, setData] = useState<AnalyticsDay[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    fetchAnalytics(days)
      .then(setData)
      .finally(() => setLoading(false));
  }, [days]);

  const chartData = data.map((d) => ({
    ...d,
    date: d.date.slice(5),
  }));

  return (
    <>
      <div className="flex justify-end mb-4">
        <div className="flex gap-1 bg-surface-raised rounded-lg p-0.5">
          {RANGE_OPTIONS.map((opt) => (
            <button
              key={opt.days}
              onClick={() => setDays(opt.days)}
              className={`px-3 py-1.5 rounded-md text-xs transition-colors ${
                days === opt.days
                  ? "bg-surface-base font-semibold shadow-sm"
                  : "opacity-40 hover:opacity-70"
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div className="text-center py-12 opacity-40">Loading...</div>
      ) : data.length === 0 ? (
        <div className="glass p-8 text-center opacity-40 text-sm">
          {t("analytics.empty")}
        </div>
      ) : (
        <div className="flex flex-col gap-5">
          <section className="glass p-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              {t("analytics.calories")}
            </h2>
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={chartData}>
                <CartesianGrid {...chartGrid} />
                <XAxis dataKey="date" tick={chartAxis} tickLine={false} axisLine={false} />
                <YAxis tick={chartAxis} tickLine={false} axisLine={false} width={40} />
                <Tooltip contentStyle={chartTooltip} />
                <Bar dataKey="calories" name="kcal" fill="var(--color-cal)" radius={[3, 3, 0, 0]} opacity={0.85} />
              </BarChart>
            </ResponsiveContainer>
          </section>

          <section className="glass p-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              {t("analytics.macros")}
            </h2>
            <ResponsiveContainer width="100%" height={200}>
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="gProt" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-protein)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--color-protein)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gCarbs" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-carbs)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--color-carbs)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gFat" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-fat)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--color-fat)" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="gFiber" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-fiber)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--color-fiber)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid {...chartGrid} />
                <XAxis dataKey="date" tick={chartAxis} tickLine={false} axisLine={false} />
                <YAxis tick={chartAxis} tickLine={false} axisLine={false} width={40} />
                <Tooltip contentStyle={chartTooltip} />
                <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: "11px", opacity: 0.7 }} />
                <Area type="monotone" dataKey="protein_g" name={t("analytics.protein")} stroke="var(--color-protein)" fill="url(#gProt)" strokeWidth={2} />
                <Area type="monotone" dataKey="carbs_g" name={t("analytics.carbs")} stroke="var(--color-carbs)" fill="url(#gCarbs)" strokeWidth={2} />
                <Area type="monotone" dataKey="fat_g" name={t("analytics.fat")} stroke="var(--color-fat)" fill="url(#gFat)" strokeWidth={2} />
                <Area type="monotone" dataKey="fiber_g" name={t("analytics.fiber")} stroke="var(--color-fiber)" fill="url(#gFiber)" strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </section>

          <section className="glass p-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              {t("analytics.hydration")}
            </h2>
            <ResponsiveContainer width="100%" height={160}>
              <BarChart data={chartData}>
                <CartesianGrid {...chartGrid} />
                <XAxis dataKey="date" tick={chartAxis} tickLine={false} axisLine={false} />
                <YAxis tick={chartAxis} tickLine={false} axisLine={false} width={40} />
                <Tooltip contentStyle={chartTooltip} formatter={(v) => [`${v} ml`, t("analytics.water")]} />
                <Bar dataKey="water_ml" name="ml" fill="var(--color-water)" radius={[3, 3, 0, 0]} opacity={0.75} />
              </BarChart>
            </ResponsiveContainer>
          </section>
        </div>
      )}
    </>
  );
}

function MounjaroTab() {
  const { t } = useTranslation();
  const [data, setData] = useState<KineticsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    fetchKinetics()
      .then(setData)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return <div className="text-center py-12 opacity-40">Loading...</div>;
  }

  if (!data || data.curve.length === 0) {
    return (
      <div className="glass p-8 text-center opacity-40 text-sm">
        {t("mounjaro.empty")}
      </div>
    );
  }

  const history = [...data.history].reverse();
  const nowHour = data.curve.findIndex((p) => p.hour === 0);
  const currentPlasma = data.curve[nowHour]?.plasma ?? 0;
  const currentSuppression = data.curve[nowHour]?.suppression ?? 0;

  return (
    <div className="flex flex-col gap-5">
      <div className="grid grid-cols-2 gap-3">
        <div className="glass p-4">
          <div className="text-xs opacity-50 mb-1">{t("mounjaro.plasmaConc")}</div>
          <div className="text-2xl font-bold text-injection">
            {currentPlasma.toFixed(2)}
            <span className="text-sm opacity-50 ml-1">mg-eq</span>
          </div>
        </div>
        <div className="glass p-4">
          <div className="text-xs opacity-50 mb-1">{t("mounjaro.appetiteSuppr")}</div>
          <div className="text-2xl font-bold text-green-400">
            {Math.round(currentSuppression * 100)}
            <span className="text-sm opacity-50 ml-1">%</span>
          </div>
        </div>
      </div>

      <section className="glass p-5">
        <h2 className="text-sm font-semibold opacity-60 mb-3">
          {t("mounjaro.plasmaCurve")}
        </h2>
        <ResponsiveContainer width="100%" height={200}>
          <AreaChart data={data.curve}>
            <defs>
              <linearGradient id="gPlasma" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--color-injection)" stopOpacity={0.4} />
                <stop offset="100%" stopColor="var(--color-injection)" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid {...chartGrid} />
            <XAxis
              dataKey="hour"
              tick={chartAxis}
              tickLine={false}
              axisLine={false}
              tickFormatter={(h: number) => h % 24 === 0 ? `d${h / 24}` : ""}
              interval={23}
            />
            <YAxis tick={chartAxis} tickLine={false} axisLine={false} width={36} />
            <Tooltip
              contentStyle={chartTooltip}
              labelFormatter={(h) => `+${h}h (d${(Number(h) / 24).toFixed(1)})`}
              formatter={(v) => [`${Number(v).toFixed(3)} mg-eq`, t("mounjaro.concentration")]}
            />
            <Area
              type="monotone"
              dataKey="plasma"
              stroke="var(--color-injection)"
              fill="url(#gPlasma)"
              strokeWidth={2}
            />
          </AreaChart>
        </ResponsiveContainer>
      </section>

      <section className="glass p-5">
        <h2 className="text-sm font-semibold opacity-60 mb-3">
          {t("mounjaro.supprCurve")}
        </h2>
        <ResponsiveContainer width="100%" height={180}>
          <AreaChart data={data.curve}>
            <defs>
              <linearGradient id="gSup" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--color-protein)" stopOpacity={0.4} />
                <stop offset="100%" stopColor="var(--color-protein)" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid {...chartGrid} />
            <XAxis
              dataKey="hour"
              tick={chartAxis}
              tickLine={false}
              axisLine={false}
              tickFormatter={(h: number) => h % 24 === 0 ? `d${h / 24}` : ""}
              interval={23}
            />
            <YAxis
              tick={chartAxis}
              tickLine={false}
              axisLine={false}
              width={36}
              domain={[0, 1]}
              tickFormatter={(v: number) => `${Math.round(v * 100)}%`}
            />
            <Tooltip
              contentStyle={chartTooltip}
              labelFormatter={(h) => `+${h}h (d${(Number(h) / 24).toFixed(1)})`}
              formatter={(v) => [`${(Number(v) * 100).toFixed(1)}%`, t("mounjaro.suppression")]}
            />
            <Area
              type="monotone"
              dataKey="suppression"
              stroke="var(--color-protein)"
              fill="url(#gSup)"
              strokeWidth={2}
            />
          </AreaChart>
        </ResponsiveContainer>
      </section>

      <section className="glass p-5">
        <h2 className="text-sm font-semibold opacity-60 mb-3">
          {t("mounjaro.history")}
        </h2>
        {history.length === 0 ? (
          <p className="text-sm opacity-40">{t("mounjaro.historyEmpty")}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {history.map((inj, i) => (
              <div
                key={i}
                className="flex items-center justify-between text-sm py-2 border-b border-current/5 last:border-0"
              >
                <span className="opacity-70">{inj.date}</span>
                <div className="flex gap-3 text-xs">
                  <span className="text-injection font-medium">
                    {inj.dose_mg} mg
                  </span>
                  {inj.site && (
                    <span className="opacity-50">
                      {siteLabel(inj.site, t)}
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function useDarkMode() {
  const [dark, setDark] = useState(() => {
    const stored = localStorage.getItem("metos_theme");
    return stored ? stored === "dark" : true;
  });

  useEffect(() => {
    document.documentElement.classList.toggle("light", !dark);
    localStorage.setItem("metos_theme", dark ? "dark" : "light");
  }, [dark]);

  return [dark, () => setDark((d) => !d)] as const;
}

type Tab = "dashboard" | "analytics" | "mounjaro";

const ALL_TABS: { id: Tab; icon: React.ReactNode }[] = [
  { id: "dashboard", icon: <LayoutDashboard className="w-4 h-4" /> },
  { id: "analytics", icon: <Activity className="w-4 h-4" /> },
  { id: "mounjaro", icon: <Syringe className="w-4 h-4" /> },
];

function TabBar({
  active,
  onChange,
  glp1,
}: {
  active: Tab;
  onChange: (t: Tab) => void;
  glp1: boolean;
}) {
  const { t } = useTranslation();
  const tabLabels: Record<Tab, string> = {
    dashboard: t("tab.dashboard"),
    analytics: t("tab.analytics"),
    mounjaro: t("tab.mounjaro"),
  };
  const tabs = glp1 ? ALL_TABS : ALL_TABS.filter((tab) => tab.id !== "mounjaro");
  return (
    <nav className="flex gap-1 bg-surface-raised rounded-xl p-1 mb-5">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onChange(tab.id)}
          className={`flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-lg text-sm transition-colors ${
            active === tab.id
              ? "bg-surface-base font-semibold shadow-sm"
              : "opacity-50 hover:opacity-80"
          }`}
        >
          {tab.icon}
          <span className="hidden sm:inline">{tabLabels[tab.id]}</span>
        </button>
      ))}
    </nav>
  );
}

export function App() {
  const { t, i18n } = useTranslation();
  const [dark, toggleDark] = useDarkMode();
  const [authed, setAuthed] = useState(() => isTokenValid());
  const [tab, setTab] = useState<Tab>("dashboard");
  const [date, setDate] = useState(() => new Date());
  const [stats, setStats] = useState<DailySummary | null>(null);
  const [meals, setMeals] = useState<Meal[]>([]);
  const [weight, setWeight] = useState<WeighIn[]>([]);
  const [water, setWater] = useState<WaterData | null>(null);
  const [goal, setGoal] = useState<Goal | null>(null);
  const [injection, setInjection] = useState<InjectionData | null>(null);
  const [config, setConfig] = useState<AppConfig>({ gout_tracking: true, glp1_tracking: true });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const dateStr = formatDate(date);

  const loadData = useCallback(async (d: string) => {
    setLoading(true);
    setError(null);
    try {
      const [s, m, wt, wa, g, inj, cfg] = await Promise.all([
        fetchStats(d),
        fetchMeals(d),
        fetchWeight(),
        fetchWater(d),
        fetchGoal(),
        fetchInjection(),
        fetchConfig(),
      ]);
      setStats(s);
      setMeals(m);
      setWeight(wt);
      setWater(wa);
      setGoal(g);
      setInjection(inj);
      setConfig(cfg);
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : "Failed to load data";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const onLogout = () => {
      clearToken();
      setAuthed(false);
    };
    window.addEventListener("auth:logout", onLogout);
    return () => window.removeEventListener("auth:logout", onLogout);
  }, []);

  useEffect(() => {
    if (authed) {
      void loadData(dateStr);
    }
  }, [authed, dateStr, loadData]);

  if (!authed) {
    return <LoginPage onLogin={() => setAuthed(true)} />;
  }

  function shiftDate(days: number) {
    setDate((prev) => {
      const next = new Date(prev);
      next.setDate(next.getDate() + days);
      return next;
    });
  }

  const hasGoutAlert = stats?.day_gout_alert === 1;

  return (
    <div className="max-w-3xl mx-auto px-4 py-6">
      <header className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight">
            MetOS
          </h1>
          <p className="text-[10px] opacity-30 tracking-wider">
            Κατά Μέθοδον
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => i18n.changeLanguage(i18n.language === "pl" ? "en" : "pl")}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors opacity-40 hover:opacity-100 text-xs font-semibold"
            aria-label="Switch language"
            title="Switch language"
          >
            <Languages className="w-4 h-4" />
          </button>
          <button
            onClick={toggleDark}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors opacity-40 hover:opacity-100"
            aria-label={t("header.toggleTheme")}
            title={t("header.toggleTheme")}
          >
            {dark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </button>
          <button
            onClick={() => {
              clearToken();
              setAuthed(false);
            }}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors opacity-40 hover:opacity-100"
            aria-label={t("header.logout")}
            title={t("header.logout")}
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </header>

      <TabBar active={tab} onChange={setTab} glp1={config.glp1_tracking} />

      {tab === "dashboard" && (
        <div className="flex items-center justify-center gap-2 mb-5">
          <button
            onClick={() => shiftDate(-1)}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors"
            aria-label="Previous day"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <button
            onClick={() => setDate(new Date())}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg hover:bg-surface-raised transition-colors text-sm"
          >
            <CalendarDays className="w-4 h-4" />
            <span>{displayDate(date)}</span>
          </button>
          <button
            onClick={() => shiftDate(1)}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors"
            aria-label="Next day"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      )}

      {error && (
        <div className="glass p-4 mb-4 border-purine-high/30 text-purine-high text-sm">
          {error}
        </div>
      )}

      {loading && (
        <div className="text-center py-12 opacity-40">
          Loading...
        </div>
      )}

      {!loading && !error && tab === "dashboard" && (
        <>
          {config.gout_tracking && hasGoutAlert && (
            <div className="gout-banner flex items-center gap-3 p-4 mb-5">
              <AlertTriangle className="w-5 h-5 text-purine-high flex-shrink-0" />
              <div>
                <span className="font-semibold text-purine-high">
                  {t("gout.warning")}
                </span>
                <p className="text-sm opacity-70 mt-0.5">
                  {t("gout.description")}
                </p>
              </div>
            </div>
          )}

          {config.glp1_tracking && (
            <InjectionSection
              data={injection}
              onLog={async () => {
                const result = await logInjection();
                setInjection(result);
              }}
            />
          )}

          <div className="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-5">
            <StatCard
              icon={<Flame className="w-4 h-4" />}
              label={t("stat.calories")}
              value={stats?.total_calories ?? 0}
              unit="kcal"
              color="text-cal"
            />
            <StatCard
              icon={<Beef className="w-4 h-4" />}
              label={t("stat.protein")}
              value={stats?.total_protein_g ?? 0}
              unit="g"
              color="text-protein"
            />
            <StatCard
              icon={<Wheat className="w-4 h-4" />}
              label={t("stat.carbs")}
              value={stats?.total_carbs_g ?? 0}
              unit="g"
              color="text-carbs"
            />
            <StatCard
              icon={<Flame className="w-4 h-4" />}
              label={t("stat.fat")}
              value={stats?.total_fat_g ?? 0}
              unit="g"
              color="text-fat"
            />
            <StatCard
              icon={<Wheat className="w-4 h-4" />}
              label={t("stat.fiber")}
              value={stats?.total_fiber_g ?? 0}
              unit="g"
              color="text-fiber"
            />
          </div>

          {goal && (
            <div className="glass p-5 mb-5">
              <h2 className="text-sm font-semibold opacity-60 mb-3">
                {t("goal.dailyGoals")}
              </h2>
              <GoalProgress
                label={t("goal.calories")}
                current={stats?.total_calories ?? 0}
                target={goal.target_calories}
                color="text-cal"
                bgColor="bg-cal"
              />
              <GoalProgress
                label={t("goal.protein")}
                current={stats?.total_protein_g ?? 0}
                target={goal.target_protein_g}
                color="text-protein"
                bgColor="bg-protein"
              />
              {goal.target_water_ml != null && (
                <GoalProgress
                  label={t("goal.water")}
                  current={water?.total_ml ?? 0}
                  target={Math.min(
                    goal.target_water_ml +
                      (water?.purine_bonus_ml ?? 0),
                    3500,
                  )}
                  color="text-water"
                  bgColor="bg-water"
                />
              )}
            </div>
          )}

          <section className="mb-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              {t("meals.title")} ({meals.length})
            </h2>
            {meals.length === 0 ? (
              <div className="glass p-6 text-center opacity-40 text-sm">
                {t("meals.empty")}
              </div>
            ) : (
              <div className="flex flex-col gap-2">
                {meals.map((meal, i) => (
                  <MealRow key={i} meal={meal} gout={config.gout_tracking} />
                ))}
              </div>
            )}
          </section>

          <section className="glass p-5 mb-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              {t("hydration.title")}
            </h2>
            <WaterDisplay
              totalMl={water?.total_ml ?? 0}
              purineBonusMl={water?.purine_bonus_ml ?? 0}
            />
          </section>

          <section className="glass p-5">
            <div className="flex items-center gap-2 mb-3">
              <Scale className="w-4 h-4 opacity-60" />
              <h2 className="text-sm font-semibold opacity-60">
                {t("weight.title")}
              </h2>
            </div>
            <WeightChart entries={weight} />
          </section>
        </>
      )}

      {!loading && !error && tab === "analytics" && (
        <AnalyticsTab />
      )}

      {!loading && !error && tab === "mounjaro" && (
        <MounjaroTab />
      )}
    </div>
  );
}

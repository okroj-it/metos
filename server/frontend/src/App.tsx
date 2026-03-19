import { useEffect, useState, useCallback } from "react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
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
} from "lucide-react";
import { isTokenValid, clearToken } from "./lib/auth";
import { LoginPage } from "./components/login-page";
import type {
  DailySummary,
  Meal,
  WeighIn,
  WaterData,
  Goal,
  InjectionData,
} from "./api.ts";
import {
  fetchStats,
  fetchMeals,
  fetchWeight,
  fetchWater,
  fetchGoal,
  fetchInjection,
  logInjection,
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

function purineBadge(level: string): {
  color: string;
  bg: string;
  label: string;
} {
  switch (level.toLowerCase()) {
    case "high":
      return {
        color: "text-purine-high",
        bg: "bg-purine-high/20",
        label: "wysoki",
      };
    case "medium":
      return {
        color: "text-purine-med",
        bg: "bg-purine-med/20",
        label: "średni",
      };
    default:
      return {
        color: "text-purine-low",
        bg: "bg-purine-low/20",
        label: "niski",
      };
  }
}

function confidenceBadge(confidence: string): {
  color: string;
  label: string;
} {
  switch (confidence?.toLowerCase()) {
    case "low":
      return { color: "text-purine-high", label: "niska pewność" };
    case "medium":
      return { color: "text-purine-med", label: "średnia pewność" };
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

function MealRow({ meal }: { meal: Meal }) {
  const badge = purineBadge(meal.purine_level);
  const conf = confidenceBadge(meal.purine_confidence);
  return (
    <div className="glass glass-hover p-4 flex flex-col sm:flex-row sm:items-center gap-3">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-medium truncate">
            {meal.meal_name}
          </span>
          <span className={`purine-badge ${badge.color} ${badge.bg}`}>
            {badge.label}
          </span>
          {conf.label && (
            <span className={`text-xs ${conf.color}`}>
              {conf.label}
            </span>
          )}
          {meal.gout_warning === 1 && (
            <span className="text-purine-high text-sm" title="Ryzyko dny">
              {"\u{1F480}"}
            </span>
          )}
        </div>
        {meal.purine_mg > 0 && (
          <span className="text-xs opacity-40">
            {meal.purine_mg} mg puryn
          </span>
        )}
        {meal.purine_notes && (
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
  const [mode, setMode] = useState<"bar" | "line">("line");

  if (entries.length === 0) {
    return (
      <p className="text-sm opacity-40">Brak danych ważenia.</p>
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
            title="Słupki"
          >
            <BarChart3 className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => setMode("line")}
            className={`p-1.5 rounded-md transition-colors ${mode === "line" ? "bg-protein/20 text-protein" : "opacity-40 hover:opacity-70"}`}
            title="Linia"
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
              formatter={(v) => [`${Number(v).toFixed(1)} kg`, "Waga"]}
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
              formatter={(v) => [`${Number(v).toFixed(1)} kg`, "Waga"]}
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
  const glasses = totalMl / 250;
  return (
    <div>
      <div className="flex items-baseline gap-2">
        <Droplets className="text-water w-5 h-5" />
        <span className="text-2xl font-bold text-water">
          {totalMl}
        </span>
        <span className="text-sm opacity-50">
          ml ({glasses.toFixed(1)} szklanek)
        </span>
      </div>
      {purineBonusMl > 0 && (
        <p className="text-xs opacity-40 mt-1">
          +{purineBonusMl} ml za wysokie puryny
        </p>
      )}
    </div>
  );
}

function getSuppressionPhase(suppression: number): {
  name: string;
  description: string;
  color: string;
  bgColor: string;
} {
  if (suppression >= 0.8) {
    return {
      name: "Wchłanianie",
      description: "Silne tłumienie — pilnuj białka!",
      color: "text-yellow-400",
      bgColor: "bg-yellow-400",
    };
  }
  if (suppression >= 0.5) {
    return {
      name: "Szczyt tłumienia",
      description: "Szczytowe tłumienie apetytu",
      color: "text-green-400",
      bgColor: "bg-green-400",
    };
  }
  if (suppression >= 0.3) {
    return {
      name: "Apetyt wraca",
      description: "Uważaj na impulsy jedzeniowe",
      color: "text-orange-400",
      bgColor: "bg-orange-400",
    };
  }
  return {
    name: "Czas na zastrzyk!",
    description: "Tłumienie wygasło",
    color: "text-red-400",
    bgColor: "bg-red-400",
  };
}

const SITE_LABELS: Record<string, string> = {
  brzuch_L: "Brzuch L",
  brzuch_P: "Brzuch P",
  udo_L: "Udo L",
  udo_P: "Udo P",
  ramie_L: "Ramię L",
  ramie_P: "Ramię P",
};

function InjectionSection({
  data,
  onLog,
}: {
  data: InjectionData | null;
  onLog: () => void;
}) {
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
              Zapisz zastrzyk
            </button>
          </span>
        </div>
        <p className="text-xs opacity-50 mt-2">
          Brak danych o zastrzyku.
        </p>
      </div>
    );
  }

  const phase = getSuppressionPhase(data.suppression);
  const suppressionPct = Math.round(data.suppression * 100);
  const progressPct = Math.min((data.days_since / 7) * 100, 100);
  const siteLabel = data.site ? (SITE_LABELS[data.site] ?? data.site) : null;

  return (
    <div className="injection-banner p-5 mb-5">
      <div className="flex items-center gap-2 mb-3">
        <Syringe className="w-5 h-5 text-injection" />
        <span className="font-semibold text-sm">Mounjaro</span>
        <span className="ml-auto flex items-center gap-3">
          <span className="text-sm opacity-60">
            dzień {data.days_since}
          </span>
          {canLog && (
            <button
              onClick={onLog}
              className="injection-btn text-sm px-3 py-1.5 rounded-lg"
            >
              Zapisz zastrzyk
            </button>
          )}
        </span>
      </div>
      <div className="flex items-center gap-2 mb-2">
        <span className={`font-semibold ${phase.color}`}>
          {phase.name}
        </span>
        <span className="text-sm opacity-50">
          — tłumienie {suppressionPct}%
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
        <span>7 dni</span>
      </div>
      <div className="flex gap-4 text-xs opacity-50">
        <span>{data.dose_mg} mg</span>
        {siteLabel && <span>{siteLabel}</span>}
        <span>
          {Math.round(data.hours_since)}h temu
        </span>
      </div>
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

export function App() {
  const [dark, toggleDark] = useDarkMode();
  const [authed, setAuthed] = useState(() => isTokenValid());
  const [date, setDate] = useState(() => new Date());
  const [stats, setStats] = useState<DailySummary | null>(null);
  const [meals, setMeals] = useState<Meal[]>([]);
  const [weight, setWeight] = useState<WeighIn[]>([]);
  const [water, setWater] = useState<WaterData | null>(null);
  const [goal, setGoal] = useState<Goal | null>(null);
  const [injection, setInjection] = useState<InjectionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const dateStr = formatDate(date);

  const loadData = useCallback(async (d: string) => {
    setLoading(true);
    setError(null);
    try {
      const [s, m, wt, wa, g, inj] = await Promise.all([
        fetchStats(d),
        fetchMeals(d),
        fetchWeight(),
        fetchWater(d),
        fetchGoal(),
        fetchInjection(),
      ]);
      setStats(s);
      setMeals(m);
      setWeight(wt);
      setWater(wa);
      setGoal(g);
      setInjection(inj);
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
      <header className="flex items-center justify-between mb-6">
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
            onClick={toggleDark}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors opacity-40 hover:opacity-100"
            aria-label="Przełącz motyw"
            title="Przełącz motyw"
          >
            {dark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </button>
          <button
            onClick={() => {
              clearToken();
              setAuthed(false);
            }}
            className="p-2 rounded-lg hover:bg-surface-raised transition-colors opacity-40 hover:opacity-100"
            aria-label="Wyloguj"
            title="Wyloguj"
          >
            <LogOut className="w-4 h-4" />
          </button>
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
      </header>

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

      {!loading && !error && (
        <>
          {hasGoutAlert && (
            <div className="gout-banner flex items-center gap-3 p-4 mb-5">
              <AlertTriangle className="w-5 h-5 text-purine-high flex-shrink-0" />
              <div>
                <span className="font-semibold text-purine-high">
                  Ostrzeżenie dnowe
                </span>
                <p className="text-sm opacity-70 mt-0.5">
                  Jeden lub więcej posiłków zawiera składniki
                  o wysokiej zawartości puryn.
                </p>
              </div>
            </div>
          )}

          <InjectionSection
            data={injection}
            onLog={async () => {
              const result = await logInjection();
              setInjection(result);
            }}
          />

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-5">
            <StatCard
              icon={<Flame className="w-4 h-4" />}
              label="Kalorie"
              value={stats?.total_calories ?? 0}
              unit="kcal"
              color="text-cal"
            />
            <StatCard
              icon={<Beef className="w-4 h-4" />}
              label="Białko"
              value={stats?.total_protein_g ?? 0}
              unit="g"
              color="text-protein"
            />
            <StatCard
              icon={<Wheat className="w-4 h-4" />}
              label="Węgl."
              value={stats?.total_carbs_g ?? 0}
              unit="g"
              color="text-carbs"
            />
            <StatCard
              icon={<Flame className="w-4 h-4" />}
              label="Tłuszcz"
              value={stats?.total_fat_g ?? 0}
              unit="g"
              color="text-fat"
            />
          </div>

          {goal && (
            <div className="glass p-5 mb-5">
              <h2 className="text-sm font-semibold opacity-60 mb-3">
                Cele dzienne
              </h2>
              <GoalProgress
                label="Kalorie"
                current={stats?.total_calories ?? 0}
                target={goal.target_calories}
                color="text-cal"
                bgColor="bg-cal"
              />
              <GoalProgress
                label="Białko"
                current={stats?.total_protein_g ?? 0}
                target={goal.target_protein_g}
                color="text-protein"
                bgColor="bg-protein"
              />
              {goal.target_water_ml != null && (
                <GoalProgress
                  label="Woda"
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
              Posiłki ({meals.length})
            </h2>
            {meals.length === 0 ? (
              <div className="glass p-6 text-center opacity-40 text-sm">
                Brak posiłków na ten dzień.
              </div>
            ) : (
              <div className="flex flex-col gap-2">
                {meals.map((meal, i) => (
                  <MealRow key={i} meal={meal} />
                ))}
              </div>
            )}
          </section>

          <section className="glass p-5 mb-5">
            <h2 className="text-sm font-semibold opacity-60 mb-3">
              Nawodnienie
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
                Trend wagi
              </h2>
            </div>
            <WeightChart entries={weight} />
          </section>
        </>
      )}
    </div>
  );
}

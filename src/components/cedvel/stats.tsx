import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { CalendarRange, CheckCircle2, Clock, Layers } from "lucide-react";
import { isSameDay } from "date-fns";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { PLAN_TYPE_LABEL, type PlanType } from "@/lib/cedvel/types";
import {
  categoryBreakdown,
  completionRate,
  lastSevenDays,
  typeStats,
  weekdayCounts,
} from "@/lib/cedvel/stats";
import { weekStartAt } from "@/lib/cedvel/dates";
import { useCedvel } from "@/lib/cedvel/store";

const TYPES: PlanType[] = ["lesson", "task", "event"];

export function StatsScreen({ onPremium }: { onPremium: () => void }) {
  const plans = useCedvel((s) => s.plans);
  const isPremium = useCedvel((s) => s.isPremium);
  const weekStartsOn = useCedvel((s) => s.weekStartsOn);
  const rate = completionRate(plans);
  const completed = plans.filter((p) => p.isCompleted).length;
  const ws = weekStartAt(new Date(), weekStartsOn);
  const weekCount = plans.filter((p) => {
    const d = new Date(p.startTime);
    return d >= ws && d < new Date(ws.getTime() + 7 * 86400000);
  }).length;
  const todayCount = plans.filter((p) =>
    isSameDay(new Date(p.startTime), new Date()),
  ).length;

  const weekData = weekdayCounts(plans, ws).map((d) => ({
    name: d.label,
    Tamam: d.done,
    Qalan: Math.max(0, d.total - d.done),
  }));
  const cats = categoryBreakdown(plans);
  const last7 = lastSevenDays(plans);

  return (
    <div className="px-5 pb-28 pt-4">
      <h1 className="font-display text-2xl font-semibold">Statistikalar</h1>

      <div className="mx-auto mt-6 flex size-44 items-center justify-center rounded-full border-[12px] border-border">
        <div
          className="flex size-full items-center justify-center rounded-full"
          style={{
            background: `conic-gradient(var(--color-primary) ${rate * 360}deg, var(--color-border) 0deg)`,
          }}
        >
          <div className="flex size-[calc(100%-24px)] flex-col items-center justify-center rounded-full bg-bg">
            <p className="font-display text-3xl font-semibold tabular-nums text-primary">
              {Math.round(rate * 100)}%
            </p>
            <p className="text-xs text-muted">Tamamlanma</p>
          </div>
        </div>
      </div>

      <div className="mt-6 grid grid-cols-2 gap-3">
        <StatCard icon={Layers} label="Ümumi plan" value={plans.length} />
        <StatCard icon={CheckCircle2} label="Tamamlanan" value={completed} />
        <StatCard
          icon={Clock}
          label="Gözləyən"
          value={plans.length - completed}
        />
        <StatCard icon={CalendarRange} label="Bu həftə" value={weekCount} />
      </div>

      <h2 className="mt-8 text-lg font-semibold">Növ üzrə irəliləyiş</h2>
      <div className="mt-3 space-y-4 rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
        {TYPES.map((t) => {
          const s = typeStats(plans, t);
          return (
            <div key={t}>
              <div className="mb-1.5 flex items-center justify-between text-sm">
                <span>{PLAN_TYPE_LABEL[t]}</span>
                <span className="tabular-nums text-muted">
                  {s.total === 0
                    ? "plan yoxdur"
                    : `${s.done}/${s.total} · ${Math.round(s.rate * 100)}%`}
                </span>
              </div>
              <Progress value={s.rate * 100} />
            </div>
          );
        })}
      </div>
      <p className="mt-2 text-xs text-subtle">
        Bugün {todayCount} plan · faizlər real tamamlanmadan hesablanır
      </p>

      <h2 className="mt-8 text-lg font-semibold">Təkmil statistika</h2>
      {isPremium ? (
        <div className="mt-3 space-y-4">
          <div className="rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
            <p className="mb-3 text-sm font-medium">Bu həftə</p>
            <div className="h-44">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={weekData} barGap={2}>
                  <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" />
                  <XAxis dataKey="name" tick={{ fontSize: 11 }} stroke="var(--color-muted)" />
                  <YAxis allowDecimals={false} tick={{ fontSize: 11 }} stroke="var(--color-muted)" width={24} />
                  <Tooltip />
                  <Bar dataKey="Tamam" fill="var(--color-primary)" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="Qalan" fill="var(--color-border)" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
            <p className="mb-3 text-sm font-medium">Kateqoriya üzrə</p>
            {cats.length === 0 ? (
              <p className="text-sm text-muted">Hələ plan yoxdur</p>
            ) : (
              <ul className="space-y-3">
                {cats.map((c) => (
                  <li key={c.name}>
                    <div className="mb-1 flex justify-between text-sm">
                      <span>{c.name}</span>
                      <span className="tabular-nums text-muted">
                        {c.done}/{c.total}
                      </span>
                    </div>
                    <Progress value={c.rate * 100} />
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
            <p className="mb-3 text-sm font-medium">Son 7 gün</p>
            <ul className="space-y-2">
              {last7.map((d) => (
                <li
                  key={d.day.toISOString()}
                  className="flex items-center justify-between text-sm"
                >
                  <span className="capitalize text-muted">{d.label}</span>
                  <span className="tabular-nums">
                    {d.done}/{d.total}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      ) : (
        <div className="mt-3 rounded-[var(--radius-xl)] bg-surface p-5 text-center shadow-card">
          <p className="text-sm text-muted">
            Həftəlik qrafik, kateqoriya və son 7 günün təhlili Premium-dadır.
          </p>
          <Button className="mt-4" onClick={onPremium}>
            Premium-a bax
          </Button>
        </div>
      )}
    </div>
  );
}

function StatCard({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Layers;
  label: string;
  value: number;
}) {
  return (
    <div className="rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
      <Icon className="size-5 text-primary" />
      <p className="mt-3 font-display text-2xl font-semibold tabular-nums">
        {value}
      </p>
      <p className="text-sm text-muted">{label}</p>
    </div>
  );
}

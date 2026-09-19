import { useMemo, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { addDays, isSameDay } from "date-fns";
import { Button } from "@/components/ui/button";
import { PlanCard } from "./plan-card";
import type { Plan } from "@/lib/cedvel/types";
import {
  formatDayMonth,
  formatDayMonthYear,
  formatShortWeekday,
  isInWeek,
  weekDays,
  weekStartAt,
} from "@/lib/cedvel/dates";
import { useCedvel } from "@/lib/cedvel/store";
import { cn } from "@/lib/utils";

export function WeeklyScreen({
  onOpen,
  onEdit,
}: {
  onOpen: (plan: Plan) => void;
  onEdit: (plan: Plan) => void;
}) {
  const plans = useCedvel((s) => s.plans);
  const weekStartsOn = useCedvel((s) => s.weekStartsOn);
  const [anchor, setAnchor] = useState(() => new Date());
  const today = new Date();
  const ws = weekStartAt(anchor, weekStartsOn);
  const days = weekDays(ws);
  const defaultDay = days.find((d) => isSameDay(d, today)) ?? days[0];
  const [selected, setSelected] = useState<Date>(defaultDay);

  const selectedSafe = isInWeek(selected, ws) ? selected : defaultDay;

  const dayPlans = useMemo(
    () =>
      plans
        .filter((p) => isSameDay(new Date(p.startTime), selectedSafe))
        .sort(
          (a, b) =>
            new Date(a.startTime).getTime() - new Date(b.startTime).getTime(),
        ),
    [plans, selectedSafe],
  );

  const end = addDays(ws, 6);

  const changeWeek = (delta: number) => {
    const nextWs = addDays(ws, 7 * delta);
    setAnchor(nextWs);
    const nextDays = weekDays(nextWs);
    const keep = nextDays.find((d) => isSameDay(d, today));
    setSelected(keep ?? nextDays[0]);
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col px-5 pb-28 pt-4">
      <header className="flex items-center justify-between">
        <h1 className="font-display text-2xl font-semibold">Həftəlik plan</h1>
        <div className="flex">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => changeWeek(-1)}
            aria-label="Əvvəlki həftə"
          >
            <ChevronLeft />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => changeWeek(1)}
            aria-label="Növbəti həftə"
          >
            <ChevronRight />
          </Button>
        </div>
      </header>
      <p className="text-sm text-muted">
        {formatDayMonth(ws)} – {formatDayMonthYear(end).split(",")[0]}
      </p>

      <div className="-mx-1 mt-4 flex gap-1.5 overflow-x-auto pb-1">
        {days.map((day) => {
          const isToday = isSameDay(day, today);
          const isSel = isSameDay(day, selectedSafe);
          const has = plans.some((p) => isSameDay(new Date(p.startTime), day));
          return (
            <button
              key={day.toISOString()}
              type="button"
              onClick={() => setSelected(day)}
              className={cn(
                "flex h-[72px] w-12 shrink-0 flex-col items-center justify-center rounded-[var(--radius-lg)]",
                isSel
                  ? "bg-primary text-primary-fg"
                  : "bg-surface text-fg shadow-card",
              )}
            >
              <span
                className={cn(
                  "text-xs uppercase",
                  isSel ? "text-primary-fg/70" : "text-muted",
                )}
              >
                {formatShortWeekday(day)}
              </span>
              <span className="text-lg font-semibold tabular-nums">{day.getDate()}</span>
              {has ? (
                <span
                  className={cn(
                    "mt-0.5 size-1.5 rounded-full",
                    isSel ? "bg-primary-fg" : "bg-primary",
                    isToday && !isSel && "bg-primary",
                  )}
                />
              ) : (
                <span className="mt-0.5 size-1.5" />
              )}
            </button>
          );
        })}
      </div>

      <h2 className="mt-5 text-sm font-medium text-muted">
        {formatDayMonthYear(selectedSafe)}
      </h2>

      {dayPlans.length === 0 ? (
        <p className="mt-10 text-center text-muted">Bu gün plan yoxdur</p>
      ) : (
        <ul className="mt-3 space-y-3">
          {dayPlans.map((p) => (
            <li key={p.id}>
              <PlanCard
                plan={p}
                showDate
                onOpen={() => onOpen(p)}
                onEdit={() => onEdit(p)}
              />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

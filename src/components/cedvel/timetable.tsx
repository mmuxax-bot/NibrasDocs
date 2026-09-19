import { useMemo, useRef, useState } from "react";
import { isSameDay } from "date-fns";
import { cn } from "@/lib/utils";
import type { Plan } from "@/lib/cedvel/types";
import {
  GRID_HOURS,
  formatHourLabel,
  formatShortWeekday,
  planOverlapsHour,
  slotDate,
  weekDays,
} from "@/lib/cedvel/dates";

export type CellRange = {
  day: Date;
  startHour: number;
  endHour: number;
};

export function Timetable({
  weekStart,
  plans,
  selection,
  onSelect,
  onOpenPlan,
}: {
  weekStart: Date;
  plans: Plan[];
  selection: CellRange | null;
  onSelect: (next: CellRange | null) => void;
  onOpenPlan: (plan: Plan) => void;
}) {
  const days = weekDays(weekStart);
  const today = new Date();
  const dragging = useRef(false);
  const mouseHandled = useRef(false);
  const selectionRef = useRef(selection);
  selectionRef.current = selection;

  const occupancy = useMemo(() => {
    const map = new Map<string, Plan[]>();
    for (const day of days) {
      for (const hour of GRID_HOURS) {
        const key = `${day.toDateString()}-${hour}`;
        map.set(
          key,
          plans.filter((p) => planOverlapsHour(p, day, hour)),
        );
      }
    }
    return map;
  }, [days, plans]);

  const applyCell = (day: Date, hour: number, extend: boolean) => {
    const occupied = occupancy.get(`${day.toDateString()}-${hour}`) ?? [];
    if (occupied.length > 0) {
      onOpenPlan(occupied[0]);
      onSelect(null);
      return;
    }
    const current = selectionRef.current;
    if (extend && current && isSameDay(current.day, day)) {
      const lo = Math.min(current.startHour, hour);
      const hi = Math.max(current.endHour - 1, hour);
      onSelect({ day, startHour: lo, endHour: hi + 1 });
      return;
    }
    if (
      current &&
      isSameDay(current.day, day) &&
      hour >= current.startHour &&
      hour < current.endHour &&
      current.endHour - current.startHour === 1
    ) {
      onSelect(null);
      return;
    }
    if (current && isSameDay(current.day, day)) {
      const lo = Math.min(current.startHour, hour);
      const hi = Math.max(current.endHour - 1, hour);
      onSelect({ day, startHour: lo, endHour: hi + 1 });
      return;
    }
    onSelect({ day, startHour: hour, endHour: hour + 1 });
  };

  const selected = (day: Date, hour: number) =>
    Boolean(
      selection &&
        isSameDay(selection.day, day) &&
        hour >= selection.startHour &&
        hour < selection.endHour,
    );

  return (
    <div className="overflow-x-auto overscroll-x-contain rounded-[var(--radius-lg)] bg-surface shadow-card">
      <div
        className="min-w-max"
        style={{
          width: "calc(var(--timetable-day) + 12 * var(--timetable-hour))",
        }}
      >
        <div className="sticky top-0 z-20 flex border-b border-border bg-surface">
          <div className="sticky left-0 z-30 flex w-[var(--timetable-day)] shrink-0 items-end justify-center bg-surface pb-2 text-xs font-medium text-muted">
            Gün
          </div>
          {GRID_HOURS.map((h) => (
            <div
              key={h}
              className="flex h-11 w-[var(--timetable-hour)] shrink-0 items-end justify-center pb-2 text-xs font-medium tabular-nums text-muted"
            >
              {formatHourLabel(h)}
            </div>
          ))}
        </div>

        {days.map((day) => {
          const isToday = isSameDay(day, today);
          return (
            <div
              key={day.toISOString()}
              className={cn(
                "flex border-b border-border last:border-b-0",
                isToday && "bg-primary/5",
              )}
            >
              <div
                className={cn(
                  "sticky left-0 z-10 flex w-[var(--timetable-day)] shrink-0 flex-col items-center justify-center bg-surface px-1",
                  isToday && "bg-primary/5 text-primary",
                )}
              >
                <span className="text-xs font-medium uppercase text-muted">
                  {formatShortWeekday(day)}
                </span>
                <span className="text-sm font-semibold tabular-nums">
                  {day.getDate()}
                </span>
              </div>
              {GRID_HOURS.map((hour) => {
                const key = `${day.toDateString()}-${hour}`;
                const inCell = occupancy.get(key) ?? [];
                const plan = inCell[0];
                const isSel = selected(day, hour);
                const startsHere =
                  plan &&
                  isSameDay(new Date(plan.startTime), day) &&
                  new Date(plan.startTime).getHours() === hour;
                return (
                  <button
                    key={hour}
                    type="button"
                    aria-label={`${formatShortWeekday(day)} ${formatHourLabel(hour)}`}
                    onPointerDown={(e) => {
                      if (e.pointerType !== "mouse" || plan) return;
                      dragging.current = true;
                      mouseHandled.current = true;
                      (e.currentTarget as HTMLButtonElement).setPointerCapture(
                        e.pointerId,
                      );
                      applyCell(day, hour, false);
                    }}
                    onPointerEnter={() => {
                      if (!dragging.current) return;
                      applyCell(day, hour, true);
                    }}
                    onPointerUp={() => {
                      dragging.current = false;
                    }}
                    onClick={() => {
                      if (mouseHandled.current) {
                        mouseHandled.current = false;
                        return;
                      }
                      applyCell(day, hour, false);
                    }}
                    className={cn(
                      "h-[var(--timetable-row)] w-[var(--timetable-hour)] shrink-0 border-l border-border px-0.5 text-left",
                      isSel && !plan && "bg-primary/15 ring-1 ring-inset ring-primary",
                      plan && `plan-dot-${plan.color} text-primary-fg`,
                    )}
                  >
                    {plan && startsHere ? (
                      <span className="block truncate text-xs font-medium leading-tight">
                        {plan.title}
                      </span>
                    ) : null}
                  </button>
                );
              })}
            </div>
          );
        })}
      </div>
    </div>
  );
}

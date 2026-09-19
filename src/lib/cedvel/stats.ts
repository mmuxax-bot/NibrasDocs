import { addDays, isSameDay } from "date-fns";
import type { Plan, PlanType } from "./types";
import { formatShortWeekday, weekStartMonday } from "./dates";

export function completionRate(plans: Plan[]): number {
  if (plans.length === 0) return 0;
  return plans.filter((p) => p.isCompleted).length / plans.length;
}

export function typeStats(plans: Plan[], type: PlanType) {
  const items = plans.filter((p) => p.type === type);
  const done = items.filter((p) => p.isCompleted).length;
  return {
    total: items.length,
    done,
    rate: items.length === 0 ? 0 : done / items.length,
  };
}

export function weekdayCounts(plans: Plan[], ws = weekStartMonday()) {
  return Array.from({ length: 7 }, (_, i) => {
    const day = addDays(ws, i);
    const dayPlans = plans.filter((p) =>
      isSameDay(new Date(p.startTime), day),
    );
    return {
      day,
      label: formatShortWeekday(day),
      total: dayPlans.length,
      done: dayPlans.filter((p) => p.isCompleted).length,
    };
  });
}

export function categoryBreakdown(plans: Plan[]) {
  const map = new Map<string, { total: number; done: number }>();
  for (const p of plans) {
    const key = p.category.trim() || "Digər";
    const cur = map.get(key) ?? { total: 0, done: 0 };
    cur.total += 1;
    if (p.isCompleted) cur.done += 1;
    map.set(key, cur);
  }
  return [...map.entries()].map(([name, v]) => ({
    name,
    total: v.total,
    done: v.done,
    rate: v.total ? v.done / v.total : 0,
  }));
}

export function lastSevenDays(plans: Plan[], today = new Date()) {
  return Array.from({ length: 7 }, (_, i) => {
    const day = addDays(today, i - 6);
    const dayPlans = plans.filter((p) =>
      isSameDay(new Date(p.startTime), day),
    );
    return {
      day,
      label: formatShortWeekday(day),
      total: dayPlans.length,
      done: dayPlans.filter((p) => p.isCompleted).length,
    };
  });
}

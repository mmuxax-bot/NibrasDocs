import {
  addDays,
  addHours,
  format,
  startOfDay,
  startOfWeek,
} from "date-fns";
import { az } from "date-fns/locale";
import type { Plan, WeekStart } from "./types";

export const azLocale = az;

export const WEEKDAY_OPTIONS: {
  value: WeekStart;
  label: string;
  short: string;
}[] = [
  { value: 1, label: "Bazar ertəsi", short: "B.e." },
  { value: 2, label: "Çərşənbə axşamı", short: "Ç.a." },
  { value: 3, label: "Çərşənbə", short: "Çər." },
  { value: 4, label: "Cümə axşamı", short: "C.a." },
  { value: 5, label: "Cümə", short: "Cüm." },
  { value: 6, label: "Şənbə", short: "Şən." },
  { value: 0, label: "Bazar", short: "Baz." },
];

/** Hour starts shown as columns (08:00–19:00). */
export const GRID_HOURS = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];

export function weekStartAt(date = new Date(), weekStartsOn: WeekStart = 1): Date {
  return startOfWeek(startOfDay(date), { weekStartsOn });
}

export function weekStartMonday(date = new Date()): Date {
  return weekStartAt(date, 1);
}

export function weekDays(ws: Date): Date[] {
  return Array.from({ length: 7 }, (_, i) => addDays(ws, i));
}

export function isInWeek(date: Date, ws: Date): boolean {
  const start = startOfDay(ws);
  const end = addDays(start, 7);
  return date >= start && date < end;
}

export function formatDayLong(d: Date): string {
  return format(d, "d MMMM yyyy", { locale: az });
}

export function formatWeekday(d: Date): string {
  return format(d, "EEEE", { locale: az });
}

export function formatTime(d: Date): string {
  return format(d, "HH:mm");
}

export function formatHourLabel(hour: number): string {
  return `${String(hour).padStart(2, "0")}:00`;
}

export function formatShortWeekday(d: Date): string {
  return format(d, "EEEEEE", { locale: az });
}

export function formatDayMonth(d: Date): string {
  return format(d, "d MMM", { locale: az });
}

export function formatDayMonthYear(d: Date): string {
  return format(d, "d MMMM yyyy, EEEE", { locale: az });
}

export function toLocalInput(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function fromLocalInput(value: string): Date {
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? new Date() : d;
}

export function defaultStartEnd(): { start: Date; end: Date } {
  const now = new Date();
  const start = addHours(now, 1);
  start.setMinutes(0, 0, 0);
  const end = addHours(start, 1);
  return { start, end };
}

export function slotDate(day: Date, hour: number, minute = 0): Date {
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, minute, 0, 0);
}

export function planOverlapsHour(plan: Plan, day: Date, hour: number): boolean {
  const a = new Date(plan.startTime).getTime();
  const b = new Date(plan.endTime).getTime();
  const s = slotDate(day, hour).getTime();
  const e = slotDate(day, hour + 1).getTime();
  return a < e && b > s;
}

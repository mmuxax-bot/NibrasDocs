export type PlanType = "lesson" | "task" | "event" | "note";
export type ThemeMode = "system" | "light" | "dark";
export type WeekStart = 0 | 1 | 2 | 3 | 4 | 5 | 6;
export type PlanColorId =
  | "plan-1"
  | "plan-2"
  | "plan-3"
  | "plan-4"
  | "plan-5"
  | "plan-6"
  | "plan-7";

export interface Plan {
  id: string;
  title: string;
  subtitle?: string;
  location?: string;
  startTime: string;
  endTime: string;
  type: PlanType;
  category: string;
  color: PlanColorId;
  isCompleted: boolean;
  note?: string;
  /** Minutes before start. `null` = no reminder. `0` = at start. */
  reminderOffsetMin?: number | null;
}

export const PLAN_TYPE_LABEL: Record<PlanType, string> = {
  lesson: "Dərs",
  task: "Tapşırıq",
  event: "Tədbir",
  note: "Qeyd",
};

export const PLAN_COLORS: { id: PlanColorId; label: string }[] = [
  { id: "plan-1", label: "Mürəkkəb" },
  { id: "plan-2", label: "Teal" },
  { id: "plan-3", label: "Terrakota" },
  { id: "plan-4", label: "Qum" },
  { id: "plan-5", label: "Meşə" },
  { id: "plan-6", label: "Slate" },
  { id: "plan-7", label: "Gül" },
];

export const DEFAULT_CATEGORIES = ["Dərs", "Tapşırıq", "Tədbir", "Şəxsi"];
export const FREE_PLAN_LIMIT = 7;
export const FREE_CATEGORY_LIMIT = 4;

export const REMINDER_OFFSETS: { min: number | null; label: string }[] = [
  { min: null, label: "Xəbərdarlıq yoxdur" },
  { min: 0, label: "Dərs başlayanda" },
  { min: 5, label: "5 dəqiqə əvvəl" },
  { min: 10, label: "10 dəqiqə əvvəl" },
  { min: 15, label: "15 dəqiqə əvvəl" },
  { min: 30, label: "30 dəqiqə əvvəl" },
  { min: 60, label: "1 saat əvvəl" },
];


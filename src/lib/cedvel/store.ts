import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Plan, ThemeMode, WeekStart } from "./types";
import {
  DEFAULT_CATEGORIES,
  FREE_CATEGORY_LIMIT,
  FREE_PLAN_LIMIT,
} from "./types";

function uid() {
  return crypto.randomUUID();
}

export interface CedvelState {
  _hasHydrated: boolean;
  plans: Plan[];
  isPremium: boolean;
  userName: string;
  themeMode: ThemeMode;
  categories: string[];
  onboardingDone: boolean;
  weekStartsOn: WeekStart;
  remindersEnabled: boolean;
  soundEnabled: boolean;
  setHasHydrated: (v: boolean) => void;
  completeOnboarding: () => void;
  setUserName: (name: string) => void;
  setThemeMode: (mode: ThemeMode) => void;
  setWeekStartsOn: (day: WeekStart) => void;
  setRemindersEnabled: (value: boolean) => void;
  setSoundEnabled: (value: boolean) => void;
  addCategory: (name: string) => { ok: true } | { ok: false; reason: string };
  removeCategory: (name: string) => void;
  addPlan: (input: Omit<Plan, "id">) => boolean;
  updatePlan: (plan: Plan) => void;
  deletePlan: (id: string) => void;
  toggleComplete: (id: string) => void;
  setPremium: (value: boolean) => void;
  clearAllPlans: () => void;
}

export const useCedvel = create<CedvelState>()(
  persist(
    (set, get) => ({
      _hasHydrated: false,
      plans: [],
      isPremium: false,
      userName: "Rəşad",
      themeMode: "system",
      categories: [...DEFAULT_CATEGORIES],
      onboardingDone: false,
      weekStartsOn: 1,
      remindersEnabled: true,
      soundEnabled: true,

      setHasHydrated: (v) => set({ _hasHydrated: v }),

      completeOnboarding: () => set({ onboardingDone: true }),

      setUserName: (name) => {
        const trimmed = name.trim();
        set({ userName: trimmed.length === 0 ? "Rəşad" : trimmed });
      },

      setThemeMode: (mode) => set({ themeMode: mode }),

      setWeekStartsOn: (day) => set({ weekStartsOn: day }),

      setRemindersEnabled: (value) => set({ remindersEnabled: value }),
      setSoundEnabled: (value) => set({ soundEnabled: value }),

      addCategory: (name) => {
        const trimmed = name.trim();
        if (!trimmed) return { ok: false, reason: "Ad boş ola bilməz" };
        const { categories, isPremium } = get();
        if (categories.includes(trimmed)) {
          return { ok: false, reason: "Bu kateqoriya artıq var" };
        }
        if (!isPremium && categories.length >= FREE_CATEGORY_LIMIT) {
          return { ok: false, reason: "limit" };
        }
        set({ categories: [...categories, trimmed] });
        return { ok: true };
      },

      removeCategory: (name) => {
        set((s) => ({
          categories: s.categories.filter((c) => c !== name),
        }));
      },

      addPlan: (input) => {
        const { plans, isPremium } = get();
        if (!isPremium && plans.length >= FREE_PLAN_LIMIT) return false;
        const plan: Plan = { ...input, id: uid() };
        set({ plans: [...plans, plan] });
        return true;
      },

      updatePlan: (plan) => {
        set((s) => ({
          plans: s.plans.map((p) => (p.id === plan.id ? plan : p)),
        }));
      },

      deletePlan: (id) => {
        set((s) => ({ plans: s.plans.filter((p) => p.id !== id) }));
      },

      toggleComplete: (id) => {
        set((s) => ({
          plans: s.plans.map((p) =>
            p.id === id ? { ...p, isCompleted: !p.isCompleted } : p,
          ),
        }));
      },

      setPremium: (value) => set({ isPremium: value }),

      clearAllPlans: () => set({ plans: [] }),
    }),
    {
      name: "cedvel-v1",
      partialize: (s) => ({
        plans: s.plans,
        isPremium: s.isPremium,
        userName: s.userName,
        themeMode: s.themeMode,
        categories: s.categories,
        onboardingDone: s.onboardingDone,
        weekStartsOn: s.weekStartsOn,
        remindersEnabled: s.remindersEnabled,
        soundEnabled: s.soundEnabled,
      }),
      onRehydrateStorage: () => () => {
        useCedvel.getState().setHasHydrated(true);
      },
    },
  ),
);

export function remainingFreeSlots(state: Pick<CedvelState, "isPremium" | "plans">) {
  if (state.isPremium) return Infinity;
  return Math.max(0, FREE_PLAN_LIMIT - state.plans.length);
}

export function canAddPlan(state: Pick<CedvelState, "isPremium" | "plans">) {
  return state.isPremium || state.plans.length < FREE_PLAN_LIMIT;
}

export function csvEscape(value: string) {
  return `"${value.replace(/"/g, '""')}"`;
}

export function exportPlansJson(plans: Plan[]) {
  return JSON.stringify(plans, null, 2);
}

export function exportPlansCsv(plans: Plan[]) {
  const header = [
    "Başlıq",
    "Alt başlıq",
    "Məkan",
    "Kateqoriya",
    "Başlama",
    "Bitmə",
    "Növ",
    "Tamamlanıb",
    "Qeyd",
  ].join(",");
  const rows = plans.map((p) =>
    [
      csvEscape(p.title),
      csvEscape(p.subtitle ?? ""),
      csvEscape(p.location ?? ""),
      csvEscape(p.category),
      p.startTime,
      p.endTime,
      p.type,
      p.isCompleted ? "bəli" : "xeyr",
      csvEscape(p.note ?? ""),
    ].join(","),
  );
  return [header, ...rows].join("\n");
}

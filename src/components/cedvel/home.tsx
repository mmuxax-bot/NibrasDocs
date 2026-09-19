import { useState } from "react";
import { addDays, isSameDay } from "date-fns";
import { ChevronLeft, ChevronRight, Search, Settings } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Timetable, type CellRange } from "./timetable";
import { FREE_PLAN_LIMIT } from "@/lib/cedvel/types";
import {
  WEEKDAY_OPTIONS,
  formatDayMonth,
  formatHourLabel,
  slotDate,
  weekStartAt,
} from "@/lib/cedvel/dates";
import {
  canAddPlan,
  remainingFreeSlots,
  useCedvel,
} from "@/lib/cedvel/store";
import type { Plan } from "@/lib/cedvel/types";

export function HomeScreen({
  onSearch,
  onSettings,
  onPremium,
  onAdd,
  onOpen,
}: {
  onSearch: () => void;
  onSettings: () => void;
  onPremium: () => void;
  onAdd: (range?: { start: Date; end: Date }) => void;
  onOpen: (plan: Plan) => void;
  onEdit: (plan: Plan) => void;
}) {
  const userName = useCedvel((s) => s.userName);
  const plans = useCedvel((s) => s.plans);
  const isPremium = useCedvel((s) => s.isPremium);
  const weekStartsOn = useCedvel((s) => s.weekStartsOn);
  const setWeekStartsOn = useCedvel((s) => s.setWeekStartsOn);
  const [anchor, setAnchor] = useState(() => new Date());
  const [selection, setSelection] = useState<CellRange | null>(null);
  const ws = weekStartAt(anchor, weekStartsOn);
  const end = addDays(ws, 6);
  const slots = remainingFreeSlots({ isPremium, plans });
  const canAdd = canAddPlan({ isPremium, plans });

  const addFromSelection = () => {
    if (!canAdd) {
      onPremium();
      return;
    }
    if (!selection) {
      onAdd();
      return;
    }
    onAdd({
      start: slotDate(selection.day, selection.startHour),
      end: slotDate(selection.day, selection.endHour),
    });
    setSelection(null);
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col px-4 pb-32 pt-4 lg:px-6">
      <header className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm text-muted">Salam, {userName}</p>
          <h1 className="font-display text-[1.65rem] font-semibold leading-tight tracking-tight">
            Cədvəl
          </h1>
        </div>
        <div className="flex shrink-0">
          <Button variant="ghost" size="icon" onClick={onSearch} aria-label="Axtar">
            <Search />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={onSettings}
            aria-label="Parametrlər"
          >
            <Settings />
          </Button>
        </div>
      </header>

      {!isPremium ? (
        <button
          type="button"
          onClick={onPremium}
          className="mt-3 flex w-full items-center justify-between rounded-[var(--radius-lg)] bg-surface px-4 py-3 text-left shadow-card"
        >
          <span className="text-sm font-medium">
            Premium: limitsiz plan
            <span className="mt-0.5 block text-xs font-normal text-muted">
              {slots} pulsuz yer qalıb · {FREE_PLAN_LIMIT} plan limiti
            </span>
          </span>
          <span className="text-sm font-semibold text-primary">Aç</span>
        </button>
      ) : null}

      <section className="mt-4">
        <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">
          Həftənin başlanğıcı
        </p>
        <div className="flex gap-1.5 overflow-x-auto pb-1">
          {WEEKDAY_OPTIONS.map((d) => (
            <button
              key={d.value}
              type="button"
              onClick={() => {
                setWeekStartsOn(d.value);
                setSelection(null);
              }}
              className={
                weekStartsOn === d.value
                  ? "h-10 shrink-0 rounded-full bg-primary px-3 text-sm font-medium text-primary-fg"
                  : "h-10 shrink-0 rounded-full bg-surface px-3 text-sm text-muted shadow-card"
              }
            >
              {d.short}
            </button>
          ))}
        </div>
      </section>

      <div className="mt-3 flex items-center justify-between">
        <p className="text-sm text-muted">
          {formatDayMonth(ws)} – {formatDayMonth(end)}
        </p>
        <div className="flex">
          <Button
            variant="ghost"
            size="icon"
            aria-label="Əvvəlki həftə"
            onClick={() => {
              setAnchor(addDays(ws, -7));
              setSelection(null);
            }}
          >
            <ChevronLeft />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label="Növbəti həftə"
            onClick={() => {
              setAnchor(addDays(ws, 7));
              setSelection(null);
            }}
          >
            <ChevronRight />
          </Button>
        </div>
      </div>

      <p className="mb-2 text-xs text-subtle">
        Saatlar yuxarıda, günlər solda. Boş xananı seçin — eyni gündən bir neçə
        saat da seçmək olar.
      </p>

      <Timetable
        weekStart={ws}
        plans={plans}
        selection={selection}
        onSelect={setSelection}
        onOpenPlan={onOpen}
      />

      {selection ? (
        <div className="mt-3 flex items-center gap-2 rounded-[var(--radius-lg)] bg-surface px-3 py-2 shadow-card">
          <p className="min-w-0 flex-1 text-sm">
            {selection.day.getDate()}{" "}
            {isSameDay(selection.day, new Date()) ? "· bu gün" : null} ·{" "}
            {formatHourLabel(selection.startHour)}–
            {formatHourLabel(selection.endHour)}
          </p>
          <Button variant="ghost" size="sm" onClick={() => setSelection(null)}>
            Ləğv
          </Button>
          <Button size="sm" onClick={addFromSelection}>
            Plan əlavə et
          </Button>
        </div>
      ) : null}
    </div>
  );
}

import { useState, type ReactNode } from "react";
import { toast } from "sonner";
import { Overlay } from "./overlay";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Plan, PlanColorId, PlanType } from "@/lib/cedvel/types";
import {
  PLAN_COLORS,
  PLAN_TYPE_LABEL,
  REMINDER_OFFSETS,
} from "@/lib/cedvel/types";
import { defaultStartEnd, fromLocalInput, toLocalInput } from "@/lib/cedvel/dates";
import { canAddPlan, useCedvel } from "@/lib/cedvel/store";
import { requestNotifyPermission } from "@/lib/cedvel/reminders";
import { cn } from "@/lib/utils";

const TYPES: PlanType[] = ["lesson", "task", "event", "note"];

export function PlanForm({
  plan,
  preset,
  onBack,
  onNeedPremium,
}: {
  plan?: Plan;
  preset?: { start: Date; end: Date };
  onBack: () => void;
  onNeedPremium: () => void;
}) {
  const categories = useCedvel((s) => s.categories);
  const addPlan = useCedvel((s) => s.addPlan);
  const updatePlan = useCedvel((s) => s.updatePlan);
  const isPremium = useCedvel((s) => s.isPremium);
  const plans = useCedvel((s) => s.plans);
  const editing = Boolean(plan);

  const defaults = defaultStartEnd();
  const [title, setTitle] = useState(plan?.title ?? "");
  const [subtitle, setSubtitle] = useState(plan?.subtitle ?? "");
  const [location, setLocation] = useState(plan?.location ?? "");
  const [note, setNote] = useState(plan?.note ?? "");
  const [type, setType] = useState<PlanType>(plan?.type ?? "lesson");
  const [category, setCategory] = useState(
    plan?.category ?? categories[0] ?? "Dərs",
  );
  const [color, setColor] = useState<PlanColorId>(plan?.color ?? "plan-1");
  const [start, setStart] = useState(
    toLocalInput(
      plan
        ? new Date(plan.startTime)
        : (preset?.start ?? defaults.start),
    ),
  );
  const [end, setEnd] = useState(
    toLocalInput(
      plan ? new Date(plan.endTime) : (preset?.end ?? defaults.end),
    ),
  );
  const [reminderOffsetMin, setReminderOffsetMin] = useState<number | null>(
    plan
      ? (plan.reminderOffsetMin ?? null)
      : 10,
  );

  const save = () => {
    if (!title.trim()) {
      toast.error("Başlıq daxil edin");
      return;
    }
    const startDate = fromLocalInput(start);
    let endDate = fromLocalInput(end);
    if (endDate <= startDate) {
      endDate = new Date(startDate.getTime() + 60 * 60 * 1000);
    }

    if (!editing && !canAddPlan({ isPremium, plans })) {
      toast.error("Pulsuz limit dolub. Premium-a keçin.");
      onNeedPremium();
      return;
    }

    const payload = {
      title: title.trim(),
      subtitle: subtitle.trim() || undefined,
      location: location.trim() || undefined,
      note: note.trim() || undefined,
      type,
      category,
      color,
      startTime: startDate.toISOString(),
      endTime: endDate.toISOString(),
      isCompleted: plan?.isCompleted ?? false,
      reminderOffsetMin,
    };

    if (editing && plan) {
      updatePlan({ ...payload, id: plan.id });
      toast.success("Plan yeniləndi");
    } else {
      const ok = addPlan(payload);
      if (!ok) {
        onNeedPremium();
        return;
      }
      toast.success("Plan əlavə olundu");
    }
    if (reminderOffsetMin != null) {
      void requestNotifyPermission();
    }
    onBack();
  };

  return (
    <Overlay
      title={editing ? "Planı redaktə et" : "Yeni plan"}
      onBack={onBack}
      action={
        <Button variant="ghost" onClick={save} className="text-primary">
          Saxla
        </Button>
      }
    >
      <form
        className="mx-auto flex max-w-lg flex-col gap-5 px-5 pb-10"
        onSubmit={(e) => {
          e.preventDefault();
          save();
        }}
      >
        <Field label="Başlıq *">
          <Input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Məsələn: Hesab dərsi"
          />
        </Field>
        <Field label="Alt başlıq">
          <Input
            value={subtitle}
            onChange={(e) => setSubtitle(e.target.value)}
            placeholder="Məsələn: Riyaziyyat"
          />
        </Field>
        <Field label="Məkan">
          <Input
            value={location}
            onChange={(e) => setLocation(e.target.value)}
            placeholder="Sinif 301"
          />
        </Field>

        <div className="grid grid-cols-2 gap-3">
          <Field label="Başlama">
            <Input
              type="datetime-local"
              value={start}
              onChange={(e) => setStart(e.target.value)}
            />
          </Field>
          <Field label="Bitmə">
            <Input
              type="datetime-local"
              value={end}
              onChange={(e) => setEnd(e.target.value)}
            />
          </Field>
        </div>

        <Field label="Növ">
          <div className="flex flex-wrap gap-2">
            {TYPES.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => {
                  setType(t);
                  const label = PLAN_TYPE_LABEL[t];
                  if (categories.includes(label)) setCategory(label);
                  if (t === "lesson" && reminderOffsetMin == null) {
                    setReminderOffsetMin(10);
                  }
                }}
                className={cn(
                  "h-10 rounded-full px-3.5 text-sm font-medium",
                  type === t
                    ? "bg-primary text-primary-fg"
                    : "bg-surface text-muted shadow-card",
                )}
              >
                {PLAN_TYPE_LABEL[t]}
              </button>
            ))}
          </div>
        </Field>

        <Field label={type === "lesson" ? "Dərs xəbərdarlığı" : "Xəbərdarlıq"}>
          <select
            value={reminderOffsetMin === null ? "none" : String(reminderOffsetMin)}
            onChange={(e) => {
              const v = e.target.value;
              setReminderOffsetMin(v === "none" ? null : Number(v));
            }}
            className="h-11 w-full rounded-[var(--radius-md)] border border-border bg-surface px-3 text-sm shadow-card focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/35"
          >
            {REMINDER_OFFSETS.map((o) => (
              <option
                key={String(o.min)}
                value={o.min === null ? "none" : String(o.min)}
              >
                {o.label}
              </option>
            ))}
          </select>
          {type === "lesson" ? (
            <p className="text-xs text-subtle">
              Vaxtı çatanda ekranın yuxarısında səsli bildiriş görünür.
            </p>
          ) : null}
        </Field>

        <Field label="Kateqoriya">
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="h-11 w-full rounded-[var(--radius-md)] border border-border bg-surface px-3 text-sm shadow-card focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/35"
          >
            {categories.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
            {plan && !categories.includes(plan.category) ? (
              <option value={plan.category}>{plan.category}</option>
            ) : null}
          </select>
        </Field>

        <Field label="Rəng">
          <div className="flex flex-wrap gap-2.5">
            {PLAN_COLORS.map((c) => (
              <button
                key={c.id}
                type="button"
                aria-label={c.label}
                onClick={() => setColor(c.id)}
                className={cn(
                  "size-9 rounded-full",
                  `plan-dot-${c.id}`,
                  color === c.id && "ring-2 ring-fg ring-offset-2 ring-offset-bg",
                )}
              />
            ))}
          </div>
        </Field>

        <Field label="Qeyd">
          <Textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={3}
          />
        </Field>

        <Button type="submit" className="h-12">
          {editing ? "Dəyişiklikləri saxla" : "Planı saxla"}
        </Button>
      </form>
    </Overlay>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-2">
      <Label>{label}</Label>
      {children}
    </div>
  );
}

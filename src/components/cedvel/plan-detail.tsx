import {
  Bell,
  CalendarDays,
  CheckCircle2,
  Circle,
  Clock3,
  MapPin,
  NotebookPen,
  Trash2,
} from "lucide-react";
import { Overlay } from "./overlay";
import { Button } from "@/components/ui/button";
import type { Plan } from "@/lib/cedvel/types";
import { PLAN_TYPE_LABEL, REMINDER_OFFSETS } from "@/lib/cedvel/types";
import { formatDayMonthYear, formatTime } from "@/lib/cedvel/dates";
import { useCedvel } from "@/lib/cedvel/store";
import { cn } from "@/lib/utils";

export function PlanDetail({
  plan,
  onBack,
  onEdit,
}: {
  plan: Plan;
  onBack: () => void;
  onEdit: () => void;
}) {
  const deletePlan = useCedvel((s) => s.deletePlan);
  const toggleComplete = useCedvel((s) => s.toggleComplete);

  return (
    <Overlay
      title="Plan təfərrüatı"
      onBack={onBack}
      action={
        <Button variant="ghost" onClick={onEdit}>
          Redaktə
        </Button>
      }
    >
      <div className="mx-auto max-w-lg px-5 pb-10">
        <div
          className={cn(
            "rounded-[var(--radius-xl)] border bg-surface p-5",
            `plan-ring-${plan.color}`,
          )}
        >
          <div className="flex items-center gap-2 text-sm font-medium text-muted">
            <span className={cn("size-2.5 rounded-full", `plan-dot-${plan.color}`)} />
            {PLAN_TYPE_LABEL[plan.type]}
            <span aria-hidden="true">·</span>
            {plan.category}
          </div>
          <h2
            className={cn(
              "mt-3 font-display text-2xl font-semibold",
              plan.isCompleted && "text-muted line-through",
            )}
          >
            {plan.title}
          </h2>
          {plan.subtitle ? (
            <p className="mt-1 text-muted">{plan.subtitle}</p>
          ) : null}
        </div>

        <dl className="mt-6 space-y-4">
          <Row
            icon={CalendarDays}
            label="Tarix"
            value={formatDayMonthYear(new Date(plan.startTime))}
          />
          <Row
            icon={Clock3}
            label="Vaxt"
            value={`${formatTime(new Date(plan.startTime))} – ${formatTime(new Date(plan.endTime))}`}
          />
          {plan.location ? (
            <Row icon={MapPin} label="Məkan" value={plan.location} />
          ) : null}
          {plan.note ? (
            <Row icon={NotebookPen} label="Qeyd" value={plan.note} />
          ) : null}
          <Row
            icon={Bell}
            label="Xəbərdarlıq"
            value={
              REMINDER_OFFSETS.find((o) => o.min === (plan.reminderOffsetMin ?? null))
                ?.label ?? "Xəbərdarlıq yoxdur"
            }
          />
          <Row
            icon={plan.isCompleted ? CheckCircle2 : Circle}
            label="Status"
            value={plan.isCompleted ? "Tamamlanıb" : "Gözləyir"}
          />
        </dl>

        <div className="mt-8 grid grid-cols-2 gap-3">
          <Button
            variant="outline"
            className="h-12 text-danger"
            onClick={() => {
              deletePlan(plan.id);
              onBack();
            }}
          >
            <Trash2 />
            Sil
          </Button>
          <Button
            className="h-12"
            onClick={() => {
              toggleComplete(plan.id);
              onBack();
            }}
          >
            {plan.isCompleted ? "Geri al" : "Tamamla"}
          </Button>
        </div>
      </div>
    </Overlay>
  );
}

function Row({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Clock3;
  label: string;
  value: string;
}) {
  return (
    <div className="flex gap-3">
      <Icon className="mt-0.5 size-5 text-muted" />
      <div>
        <dt className="text-xs text-subtle">{label}</dt>
        <dd className="text-[15px] font-medium">{value}</dd>
      </div>
    </div>
  );
}

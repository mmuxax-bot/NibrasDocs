import { MapPin, MoreHorizontal } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Plan } from "@/lib/cedvel/types";
import { PLAN_TYPE_LABEL } from "@/lib/cedvel/types";
import { formatDayMonth, formatTime } from "@/lib/cedvel/dates";
import { useCedvel } from "@/lib/cedvel/store";

export function PlanCard({
  plan,
  showDate = false,
  onOpen,
  onEdit,
}: {
  plan: Plan;
  showDate?: boolean;
  onOpen: () => void;
  onEdit: () => void;
}) {
  const toggleComplete = useCedvel((s) => s.toggleComplete);
  const deletePlan = useCedvel((s) => s.deletePlan);

  return (
    <article
      className={cn(
        "flex gap-3 rounded-[var(--radius-xl)] bg-surface p-3.5 shadow-card",
        `plan-ring-${plan.color} border`,
      )}
    >
      <button
        type="button"
        onClick={onOpen}
        className="flex min-w-0 flex-1 items-stretch gap-3 text-left"
      >
        <div className="flex w-12 shrink-0 flex-col items-center justify-center text-center">
          <span className="text-sm font-semibold tabular-nums">
            {formatTime(new Date(plan.startTime))}
          </span>
          <span className={cn("my-1 h-4 w-0.5 rounded-full", `plan-bar-${plan.color}`)} />
          <span className="text-xs text-muted tabular-nums">
            {formatTime(new Date(plan.endTime))}
          </span>
        </div>
        <span className={cn("w-1 shrink-0 self-stretch rounded-full", `plan-bar-${plan.color}`)} />
        <div className="min-w-0 flex-1">
          <p
            className={cn(
              "truncate text-[15px] font-semibold leading-snug",
              plan.isCompleted && "text-muted line-through",
            )}
          >
            {plan.title}
          </p>
          {plan.subtitle ? (
            <p className="truncate text-sm text-muted">{plan.subtitle}</p>
          ) : null}
          <p className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-subtle">
            <span>{PLAN_TYPE_LABEL[plan.type]}</span>
            <span aria-hidden="true">·</span>
            <span>{plan.category}</span>
            {showDate ? (
              <>
                <span aria-hidden="true">·</span>
                <span>{formatDayMonth(new Date(plan.startTime))}</span>
              </>
            ) : null}
            {plan.location ? (
              <span className="inline-flex items-center gap-0.5">
                <MapPin className="size-3" />
                {plan.location}
              </span>
            ) : null}
          </p>
        </div>
      </button>
      <div className="flex shrink-0 flex-col items-center justify-between">
        <label className="relative flex size-11 items-center justify-center">
          <input
            type="checkbox"
            checked={plan.isCompleted}
            onChange={() => toggleComplete(plan.id)}
            className="size-5 accent-primary"
            aria-label="Tamamla"
          />
        </label>
        <details className="relative">
          <summary className="flex size-11 list-none items-center justify-center rounded-[var(--radius-md)] text-muted [&::-webkit-details-marker]:hidden">
            <MoreHorizontal className="size-4" />
            <span className="sr-only">Əməliyyatlar</span>
          </summary>
          <div className="absolute right-0 z-10 mt-1 w-36 overflow-hidden rounded-[var(--radius-md)] bg-surface py-1 shadow-card">
            <button
              type="button"
              className="block w-full px-3 py-2.5 text-left text-sm hover:bg-bg"
              onClick={onEdit}
            >
              Redaktə et
            </button>
            <button
              type="button"
              className="block w-full px-3 py-2.5 text-left text-sm text-danger hover:bg-bg"
              onClick={() => deletePlan(plan.id)}
            >
              Sil
            </button>
          </div>
        </details>
      </div>
    </article>
  );
}

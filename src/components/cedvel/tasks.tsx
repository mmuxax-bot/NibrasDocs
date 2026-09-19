import { ListTodo } from "lucide-react";
import { PlanCard } from "./plan-card";
import type { Plan } from "@/lib/cedvel/types";
import { useCedvel } from "@/lib/cedvel/store";

export function TasksScreen({
  onOpen,
  onEdit,
}: {
  onOpen: (plan: Plan) => void;
  onEdit: (plan: Plan) => void;
}) {
  const plans = useCedvel((s) => s.plans);
  const tasks = plans
    .filter((p) => p.type === "task")
    .sort(
      (a, b) =>
        new Date(a.startTime).getTime() - new Date(b.startTime).getTime(),
    );
  const pending = tasks.filter((t) => !t.isCompleted);
  const done = tasks.filter((t) => t.isCompleted);

  return (
    <div className="px-5 pb-28 pt-4">
      <h1 className="font-display text-2xl font-semibold">Tapşırıqlar</h1>
      <div className="mt-3 flex gap-2">
        <Chip count={pending.length} label="Gözləyən" tone="warn" />
        <Chip count={done.length} label="Tamamlanan" tone="ok" />
      </div>

      {tasks.length === 0 ? (
        <div className="mt-16 flex flex-col items-center text-center">
          <ListTodo className="size-12 text-subtle" strokeWidth={1.4} />
          <p className="mt-3 text-muted">Tapşırıq yoxdur</p>
          <p className="mt-1 max-w-xs text-sm text-subtle">
            Yeni plan əlavə edərkən növü «Tapşırıq» seçin.
          </p>
        </div>
      ) : (
        <div className="mt-6 space-y-6">
          {pending.length > 0 ? (
            <section>
              <h2 className="mb-2 text-sm font-semibold text-muted">Gözləyən</h2>
              <ul className="space-y-3">
                {pending.map((p) => (
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
            </section>
          ) : null}
          {done.length > 0 ? (
            <section>
              <h2 className="mb-2 text-sm font-semibold text-muted">Tamamlanan</h2>
              <ul className="space-y-3">
                {done.map((p) => (
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
            </section>
          ) : null}
        </div>
      )}
    </div>
  );
}

function Chip({
  count,
  label,
  tone,
}: {
  count: number;
  label: string;
  tone: "warn" | "ok";
}) {
  return (
    <span
      className={
        tone === "ok"
          ? "rounded-full bg-success/12 px-3.5 py-2 text-sm text-success"
          : "rounded-full bg-danger/12 px-3.5 py-2 text-sm text-danger"
      }
    >
      <span className="font-semibold tabular-nums">{count}</span> {label}
    </span>
  );
}

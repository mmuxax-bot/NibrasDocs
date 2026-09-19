import type { ReactNode } from "react";
import {
  BarChart3,
  CalendarDays,
  ListTodo,
  Plus,
  LayoutGrid,
} from "lucide-react";
import { cn } from "@/lib/utils";

export type TabId = "home" | "week" | "tasks" | "stats";

const TABS: { id: TabId; label: string; icon: typeof CalendarDays }[] = [
  { id: "home", label: "Cədvəl", icon: CalendarDays },
  { id: "week", label: "Həftə", icon: LayoutGrid },
  { id: "tasks", label: "Tapşırıq", icon: ListTodo },
  { id: "stats", label: "Statistika", icon: BarChart3 },
];

export function Shell({
  tab,
  onTab,
  onAdd,
  children,
}: {
  tab: TabId;
  onTab: (t: TabId) => void;
  onAdd: () => void;
  children: ReactNode;
}) {
  return (
    <div className="relative mx-auto flex min-h-dvh max-w-lg flex-col bg-bg lg:max-w-[88rem] lg:flex-row">
      <aside className="hidden w-56 shrink-0 flex-col border-r border-border px-3 py-6 lg:flex">
        <p className="px-3 font-display text-xl font-semibold">Cədvəl</p>
        <p className="px-3 text-xs text-muted">Gününə nəzarət et</p>
        <nav className="mt-8 flex flex-1 flex-col gap-1">
          {TABS.map((t) => {
            const Icon = t.icon;
            const active = tab === t.id;
            return (
              <button
                key={t.id}
                type="button"
                onClick={() => onTab(t.id)}
                className={cn(
                  "flex h-11 items-center gap-3 rounded-[var(--radius-md)] px-3 text-sm font-medium",
                  active
                    ? "bg-primary text-primary-fg"
                    : "text-muted hover:bg-surface",
                )}
              >
                <Icon className="size-4" />
                {t.label}
              </button>
            );
          })}
        </nav>
        <button
          type="button"
          onClick={onAdd}
          className="mt-auto flex h-11 items-center justify-center gap-2 rounded-[var(--radius-md)] bg-primary text-sm font-medium text-primary-fg"
        >
          <Plus className="size-4" />
          Plan əlavə et
        </button>
      </aside>

      <div className="flex min-h-dvh min-w-0 flex-1 flex-col">{children}</div>

      <div className="pointer-events-none fixed inset-x-0 bottom-0 z-20 lg:hidden">
        <div className="pointer-events-auto mx-auto max-w-lg">
          <div className="relative border-t border-border bg-surface/95 pb-[max(0.5rem,env(safe-area-inset-bottom))] pt-2 backdrop-blur">
            <div className="grid grid-cols-5 items-end px-2">
              <NavBtn tab={TABS[0]} current={tab} onTab={onTab} />
              <NavBtn tab={TABS[1]} current={tab} onTab={onTab} />
              <div className="flex justify-center">
                <button
                  type="button"
                  onClick={onAdd}
                  aria-label="Plan əlavə et"
                  className="-mt-7 flex size-14 items-center justify-center rounded-full bg-primary text-primary-fg shadow-card"
                >
                  <Plus className="size-6" />
                </button>
              </div>
              <NavBtn tab={TABS[2]} current={tab} onTab={onTab} />
              <NavBtn tab={TABS[3]} current={tab} onTab={onTab} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function NavBtn({
  tab,
  current,
  onTab,
}: {
  tab: (typeof TABS)[number];
  current: TabId;
  onTab: (t: TabId) => void;
}) {
  const Icon = tab.icon;
  const active = current === tab.id;
  return (
    <button
      type="button"
      onClick={() => onTab(tab.id)}
      className={cn(
        "flex min-h-11 flex-col items-center justify-center gap-0.5 text-[11px] font-medium",
        active ? "text-primary" : "text-subtle",
      )}
    >
      <Icon className="size-5" />
      {tab.label}
    </button>
  );
}

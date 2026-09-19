import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Overlay } from "./overlay";
import { Input } from "@/components/ui/input";
import { PlanCard } from "./plan-card";
import type { Plan } from "@/lib/cedvel/types";
import { useCedvel } from "@/lib/cedvel/store";

export function SearchScreen({
  onBack,
  onOpen,
  onEdit,
}: {
  onBack: () => void;
  onOpen: (plan: Plan) => void;
  onEdit: (plan: Plan) => void;
}) {
  const plans = useCedvel((s) => s.plans);
  const [q, setQ] = useState("");
  const results = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (!query) return [];
    return plans.filter((p) => {
      return (
        p.title.toLowerCase().includes(query) ||
        (p.subtitle?.toLowerCase().includes(query) ?? false) ||
        (p.location?.toLowerCase().includes(query) ?? false) ||
        (p.note?.toLowerCase().includes(query) ?? false) ||
        p.category.toLowerCase().includes(query)
      );
    });
  }, [plans, q]);

  return (
    <Overlay title="Axtarış" onBack={onBack}>
      <div className="mx-auto max-w-lg px-5 pb-10">
        <Input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Plan, dərs, kateqoriya və ya məkan"
          autoFocus
        />
        {q.trim() === "" ? (
          <div className="mt-16 flex flex-col items-center text-center">
            <Search className="size-12 text-subtle" strokeWidth={1.4} />
            <p className="mt-3 text-muted">Axtarış etmək üçün yazın</p>
          </div>
        ) : results.length === 0 ? (
          <p className="mt-16 text-center text-muted">Nəticə tapılmadı</p>
        ) : (
          <ul className="mt-4 space-y-3">
            {results.map((p) => (
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
        )}
      </div>
    </Overlay>
  );
}

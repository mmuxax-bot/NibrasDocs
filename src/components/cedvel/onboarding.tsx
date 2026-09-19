import { useState } from "react";
import { CalendarDays, ChartColumn, Crown } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useCedvel } from "@/lib/cedvel/store";

const PAGES = [
  {
    icon: CalendarDays,
    title: "Gününü planla",
    subtitle:
      "Dərs, tapşırıq və tədbirlərini bir yerdə saxla. Sadə və aydın.",
  },
  {
    icon: ChartColumn,
    title: "İrəliləyişini gör",
    subtitle:
      "Statistika real datadan hesablanır — nə qədər tamamladığını izlə.",
  },
  {
    icon: Crown,
    title: "Premium ilə daha çox",
    subtitle:
      "Limitsiz plan, ixrac, kateqoriyalar və təkmil statistika.",
  },
] as const;

export function Onboarding({ onPrivacy }: { onPrivacy?: () => void }) {
  const [page, setPage] = useState(0);
  const [name, setName] = useState("Rəşad");
  const setUserName = useCedvel((s) => s.setUserName);
  const completeOnboarding = useCedvel((s) => s.completeOnboarding);

  const finish = () => {
    if (name.trim()) setUserName(name);
    completeOnboarding();
  };

  const isName = page === PAGES.length;
  const lastContent = page === PAGES.length - 1;

  return (
    <div className="flex min-h-dvh flex-col bg-bg px-6 pb-8 pt-[max(1rem,env(safe-area-inset-top))]">
      <div className="flex justify-end">
        <Button variant="ghost" className="text-muted" onClick={finish}>
          Keç
        </Button>
      </div>
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        {!isName ? (
          <>
            {PAGES.map((p, i) => {
              const Icon = p.icon;
              if (i !== page) return null;
              return (
                <div key={p.title} className="max-w-sm">
                  <div className="mx-auto mb-8 flex size-24 items-center justify-center rounded-full bg-primary/10 text-primary">
                    <Icon className="size-11" strokeWidth={1.6} />
                  </div>
                  <h1 className="font-display text-3xl font-semibold tracking-tight">
                    {p.title}
                  </h1>
                  <p className="mt-3 text-[15px] leading-relaxed text-muted">
                    {p.subtitle}
                  </p>
                </div>
              );
            })}
          </>
        ) : (
          <div className="w-full max-w-sm">
            <h1 className="font-display text-3xl font-semibold tracking-tight">
              Sənə necə müraciət edək?
            </h1>
            <p className="mt-2 text-muted">Adın ana səhifədə görünəcək</p>
            <Input
              className="mt-8 text-center text-base"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Məsələn: Rəşad"
              autoFocus
            />
          </div>
        )}
      </div>
      <div className="mx-auto mb-6 flex gap-1.5">
        {Array.from({ length: PAGES.length + 1 }).map((_, i) => (
          <span
            key={i}
            className={
              i === page
                ? "h-2 w-6 rounded-full bg-primary"
                : "h-2 w-2 rounded-full bg-border"
            }
          />
        ))}
      </div>
      <Button
        className="h-12 w-full text-base"
        onClick={() => {
          if (isName) finish();
          else setPage((p) => p + 1);
        }}
      >
        {isName ? "Başla" : lastContent ? "Davam et" : "Davam et"}
      </Button>
      <p className="mt-3 text-center text-xs text-subtle">
        Davam etməklə{" "}
        <button
          type="button"
          className="underline underline-offset-2"
          onClick={() => onPrivacy?.()}
        >
          məxfilik siyasəti
        </button>{" "}
        ilə razılaşırsınız. Məlumatlar yalnız bu cihazda saxlanılır.
      </p>
    </div>
  );
}

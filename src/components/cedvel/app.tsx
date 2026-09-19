import { useEffect, useState } from "react";
import { Toaster } from "sonner";
import { ThemeSync } from "./theme-sync";
import { Onboarding } from "./onboarding";
import { Shell, type TabId } from "./shell";
import { HomeScreen } from "./home";
import { WeeklyScreen } from "./weekly";
import { TasksScreen } from "./tasks";
import { StatsScreen } from "./stats";
import { SettingsScreen } from "./settings";
import { PremiumScreen } from "./premium";
import { PrivacyScreen } from "./privacy";
import { SearchScreen } from "./search";
import { PlanForm } from "./plan-form";
import { PlanDetail } from "./plan-detail";
import { ReminderHost } from "./reminder-host";
import { canAddPlan, useCedvel } from "@/lib/cedvel/store";

type View =
  | { name: "main" }
  | { name: "search" }
  | { name: "settings" }
  | { name: "premium" }
  | { name: "privacy" }
  | { name: "form"; planId?: string; start?: string; end?: string }
  | { name: "detail"; planId: string };

export function CedvelApp() {
  const onboardingDone = useCedvel((s) => s.onboardingDone);
  const plans = useCedvel((s) => s.plans);
  const isPremium = useCedvel((s) => s.isPremium);
  const [tab, setTab] = useState<TabId>("home");
  const [view, setView] = useState<View>({ name: "main" });
  const [booted, setBooted] = useState(false);

  useEffect(() => {
    const unsub = useCedvel.persist.onFinishHydration(() => setBooted(true));
    if (useCedvel.persist.hasHydrated()) setBooted(true);
    else useCedvel.persist.rehydrate();
    return unsub;
  }, []);

  if (!booted && onboardingDone) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center bg-bg">
        <p className="font-display text-3xl font-semibold text-primary">Cədvəl</p>
        <p className="mt-2 text-sm text-muted">Gününə nəzarət et</p>
      </div>
    );
  }

  if (!onboardingDone) {
    return (
      <>
        <ThemeSync />
        {view.name === "privacy" ? (
          <PrivacyScreen onBack={() => setView({ name: "main" })} />
        ) : (
          <Onboarding onPrivacy={() => setView({ name: "privacy" })} />
        )}
      </>
    );
  }

  const openAdd = (range?: { start: Date; end: Date }) => {
    if (!canAddPlan({ isPremium, plans })) {
      setView({ name: "premium" });
      return;
    }
    if (range) {
      setView({
        name: "form",
        start: range.start.toISOString(),
        end: range.end.toISOString(),
      });
      return;
    }
    setView({ name: "form" });
  };

  const planById = (id: string) => plans.find((p) => p.id === id);

  return (
    <>
      <ThemeSync />
      <Toaster position="bottom-center" richColors closeButton />
      <ReminderHost />
      <Shell tab={tab} onTab={setTab} onAdd={openAdd}>
        {tab === "home" ? (
          <HomeScreen
            onSearch={() => setView({ name: "search" })}
            onSettings={() => setView({ name: "settings" })}
            onPremium={() => setView({ name: "premium" })}
            onAdd={openAdd}
            onOpen={(p) => setView({ name: "detail", planId: p.id })}
            onEdit={(p) => setView({ name: "form", planId: p.id })}
          />
        ) : null}
        {tab === "week" ? (
          <WeeklyScreen
            onOpen={(p) => setView({ name: "detail", planId: p.id })}
            onEdit={(p) => setView({ name: "form", planId: p.id })}
          />
        ) : null}
        {tab === "tasks" ? (
          <TasksScreen
            onOpen={(p) => setView({ name: "detail", planId: p.id })}
            onEdit={(p) => setView({ name: "form", planId: p.id })}
          />
        ) : null}
        {tab === "stats" ? (
          <StatsScreen onPremium={() => setView({ name: "premium" })} />
        ) : null}
      </Shell>

      {view.name === "search" ? (
        <SearchScreen
          onBack={() => setView({ name: "main" })}
          onOpen={(p) => setView({ name: "detail", planId: p.id })}
          onEdit={(p) => setView({ name: "form", planId: p.id })}
        />
      ) : null}
      {view.name === "settings" ? (
        <SettingsScreen
          onBack={() => setView({ name: "main" })}
          onPremium={() => setView({ name: "premium" })}
          onPrivacy={() => setView({ name: "privacy" })}
        />
      ) : null}
      {view.name === "premium" ? (
        <PremiumScreen onBack={() => setView({ name: "main" })} />
      ) : null}
      {view.name === "privacy" ? (
        <PrivacyScreen onBack={() => setView({ name: "settings" })} />
      ) : null}
      {view.name === "form" ? (
        <PlanForm
          plan={view.planId ? planById(view.planId) : undefined}
          preset={
            view.start && view.end
              ? { start: new Date(view.start), end: new Date(view.end) }
              : undefined
          }
          onBack={() =>
            setView(
              view.planId
                ? { name: "detail", planId: view.planId }
                : { name: "main" },
            )
          }
          onNeedPremium={() => setView({ name: "premium" })}
        />
      ) : null}
      {view.name === "detail"
        ? (() => {
            const plan = planById(view.planId);
            if (!plan) return null;
            return (
              <PlanDetail
                plan={plan}
                onBack={() => setView({ name: "main" })}
                onEdit={() => setView({ name: "form", planId: plan.id })}
              />
            );
          })()
        : null}
    </>
  );
}

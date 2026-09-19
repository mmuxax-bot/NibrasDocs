import { useEffect, useState } from "react";
import { Bell, X } from "lucide-react";
import { useCedvel } from "@/lib/cedvel/store";
import {
  dueReminders,
  eventFromPlan,
  playReminderSound,
  showSystemNotification,
  unlockReminderAudio,
  type ReminderEvent,
} from "@/lib/cedvel/reminders";

const TEST_EVENT = "cedvel-test-reminder";

export function dispatchTestReminder() {
  window.dispatchEvent(new Event(TEST_EVENT));
}

export function ReminderHost() {
  const plans = useCedvel((s) => s.plans);
  const remindersEnabled = useCedvel((s) => s.remindersEnabled);
  const soundEnabled = useCedvel((s) => s.soundEnabled);
  const [queue, setQueue] = useState<ReminderEvent[]>([]);

  const push = (event: ReminderEvent) => {
    setQueue((q) => [...q, event]);
    if (soundEnabled) playReminderSound();
    showSystemNotification(event);
  };

  useEffect(() => {
    const unlock = () => unlockReminderAudio();
    window.addEventListener("pointerdown", unlock, { once: true });
    return () => window.removeEventListener("pointerdown", unlock);
  }, []);

  useEffect(() => {
    if (!remindersEnabled) return;
    const tick = () => {
      for (const plan of dueReminders(plans)) {
        push(eventFromPlan(plan));
      }
    };
    tick();
    const id = window.setInterval(tick, 4000);
    return () => window.clearInterval(id);
  }, [plans, remindersEnabled, soundEnabled]);

  useEffect(() => {
    const onTest = () => {
      push({
        id: `test-${Date.now()}`,
        title: "Riyaziyyat dərsi",
        body: "10 dəqiqə sonra başlayır · Sinif 301",
      });
    };
    window.addEventListener(TEST_EVENT, onTest);
    return () => window.removeEventListener(TEST_EVENT, onTest);
  }, [soundEnabled]);

  const current = queue[0];

  useEffect(() => {
    if (!current) return;
    const id = window.setTimeout(() => {
      setQueue((q) => q.slice(1));
    }, 10000);
    return () => window.clearTimeout(id);
  }, [current?.id]);

  if (!current) return null;

  return (
    <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center px-3 pt-[max(0.75rem,env(safe-area-inset-top))]">
      <div
        role="alert"
        className="reminder-banner pointer-events-auto flex w-full max-w-lg items-start gap-3 rounded-[var(--radius-lg)] bg-primary px-4 py-3 text-primary-fg shadow-card"
      >
        <Bell className="mt-0.5 size-5 shrink-0" />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold leading-tight">{current.title}</p>
          <p className="mt-0.5 text-xs text-primary-fg/75">{current.body}</p>
        </div>
        <button
          type="button"
          aria-label="Bağla"
          className="shrink-0 rounded-full p-1 text-primary-fg/80 hover:text-primary-fg"
          onClick={() => setQueue((q) => q.slice(1))}
        >
          <X className="size-4" />
        </button>
      </div>
    </div>
  );
}

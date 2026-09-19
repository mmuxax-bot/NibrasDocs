import type { Plan } from "./types";

export type ReminderEvent = {
  id: string;
  title: string;
  body: string;
  planId?: string;
};

const fired = new Set<string>();
const FIRED_KEY = "cedvel-fired-reminders";

function loadFired() {
  if (typeof sessionStorage === "undefined") return;
  try {
    const raw = sessionStorage.getItem(FIRED_KEY);
    if (!raw) return;
    for (const id of JSON.parse(raw) as string[]) fired.add(id);
  } catch {
    /* ignore */
  }
}

function saveFired() {
  if (typeof sessionStorage === "undefined") return;
  try {
    sessionStorage.setItem(FIRED_KEY, JSON.stringify([...fired]));
  } catch {
    /* ignore */
  }
}

loadFired();

export function reminderAt(plan: Plan): Date | null {
  if (plan.reminderOffsetMin == null) return null;
  const start = new Date(plan.startTime).getTime();
  if (Number.isNaN(start)) return null;
  return new Date(start - plan.reminderOffsetMin * 60_000);
}

export function dueReminders(plans: Plan[], now = Date.now()): Plan[] {
  const due: Plan[] = [];
  for (const plan of plans) {
    const at = reminderAt(plan);
    if (!at) continue;
    const start = new Date(plan.startTime).getTime();
    const t = at.getTime();
    if (t > now) continue;
    if (now - t > 30 * 60_000) continue;
    if (now > start + 60_000) continue;
    const key = `${plan.id}-${t}`;
    if (fired.has(key)) continue;
    fired.add(key);
    saveFired();
    due.push(plan);
  }
  return due;
}

export function markTestFired() {
  fired.add(`test-${Date.now()}`);
}

export function reminderBody(plan: Plan): string {
  const mins = plan.reminderOffsetMin ?? 0;
  const when =
    mins === 0 ? "indi başlayır" : `${mins} dəqiqə sonra başlayır`;
  const loc = plan.location ? ` · ${plan.location}` : "";
  return `${when}${loc}`;
}

export async function requestNotifyPermission(): Promise<boolean> {
  if (typeof Notification === "undefined") return false;
  if (Notification.permission === "granted") return true;
  if (Notification.permission === "denied") return false;
  const res = await Notification.requestPermission();
  return res === "granted";
}

export function showSystemNotification(event: ReminderEvent) {
  if (typeof Notification === "undefined") return;
  if (Notification.permission !== "granted") return;
  try {
    new Notification("Cədvəl", {
      body: `${event.title} — ${event.body}`,
      tag: event.id,
      silent: false,
    });
  } catch {
    /* ignore (insecure context, etc.) */
  }
}

export function playReminderSound() {
  const AudioCtx =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext?: typeof AudioContext })
      .webkitAudioContext;
  if (!AudioCtx) return;
  const ctx = new AudioCtx();
  void ctx.resume();
  const now = ctx.currentTime;
  const notes = [880, 1174.66, 1567.98];
  notes.forEach((freq, i) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "triangle";
    osc.frequency.value = freq;
    const t = now + i * 0.12;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.22, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.38);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.4);
  });
  window.setTimeout(() => void ctx.close(), 1600);
}

export function unlockReminderAudio() {
  try {
    const AudioCtx =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext?: typeof AudioContext })
        .webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    void ctx.resume().then(() => void ctx.close());
  } catch {
    /* ignore */
  }
}

export function eventFromPlan(plan: Plan): ReminderEvent {
  return {
    id: `${plan.id}-${reminderAt(plan)?.getTime() ?? 0}`,
    title: plan.title,
    body: reminderBody(plan),
    planId: plan.id,
  };
}

import { useState, type ReactNode } from "react";
import { toast } from "sonner";
import {
  Bell,
  ChevronRight,
  Download,
  Moon,
  Shield,
  Trash2,
  User,
  Volume2,
} from "lucide-react";
import { Overlay } from "./overlay";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  FREE_CATEGORY_LIMIT,
  type ThemeMode,
} from "@/lib/cedvel/types";
import { WEEKDAY_OPTIONS } from "@/lib/cedvel/dates";
import {
  exportPlansCsv,
  exportPlansJson,
  useCedvel,
} from "@/lib/cedvel/store";
import { requestNotifyPermission } from "@/lib/cedvel/reminders";
import { dispatchTestReminder } from "./reminder-host";

export function SettingsScreen({
  onBack,
  onPremium,
  onPrivacy,
}: {
  onBack: () => void;
  onPremium: () => void;
  onPrivacy: () => void;
}) {
  const service = useCedvel();
  const [name, setName] = useState(service.userName);
  const [newCat, setNewCat] = useState("");
  const [confirmClear, setConfirmClear] = useState(false);

  const saveName = () => {
    service.setUserName(name);
    toast.success("Ad saxlanıldı");
  };

  const addCat = () => {
    const res = service.addCategory(newCat);
    if (!res.ok) {
      if (res.reason === "limit") {
        toast.error("Pulsuz versiyada 4 kateqoriya limiti var");
        onPremium();
      } else {
        toast.error(res.reason);
      }
      return;
    }
    setNewCat("");
  };

  const exportData = (kind: "json" | "csv") => {
    if (!service.isPremium) {
      toast.error("İxrac Premium funksiyadır");
      onPremium();
      return;
    }
    const body =
      kind === "json"
        ? exportPlansJson(service.plans)
        : exportPlansCsv(service.plans);
    const blob = new Blob([body], {
      type: kind === "json" ? "application/json" : "text/csv",
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = kind === "json" ? "cedvel-planlar.json" : "cedvel-planlar.csv";
    a.click();
    URL.revokeObjectURL(url);
    void navigator.clipboard.writeText(body).then(
      () => toast.success(kind === "json" ? "JSON yükləndi və kopyalandı" : "CSV yükləndi və kopyalandı"),
      () => toast.success("Fayl yükləndi"),
    );
  };

  const themeLabel: Record<ThemeMode, string> = {
    system: "Sistem",
    light: "Açıq",
    dark: "Qaranlıq",
  };

  return (
    <Overlay title="Parametrlər" onBack={onBack}>
      <div className="mx-auto max-w-lg space-y-6 px-5 pb-12">
        <button
          type="button"
          onClick={onPremium}
          className="flex w-full items-center gap-3 rounded-[var(--radius-xl)] bg-primary px-5 py-4 text-left text-primary-fg"
        >
          <div className="min-w-0 flex-1">
            <p className="font-semibold">
              {service.isPremium ? "Premium aktivdir" : "Cədvəl Premium"}
            </p>
            <p className="text-sm text-primary-fg/70">
              {service.isPremium
                ? "Bütün funksiyalar açıqdır"
                : "Limitsiz plan, ixrac və təkmil statistika"}
            </p>
          </div>
          <ChevronRight className="size-5" />
        </button>

        <Section title="Profil">
          <div className="flex items-end gap-2">
            <div className="min-w-0 flex-1">
              <Label htmlFor="uname">Ad</Label>
              <Input
                id="uname"
                className="mt-1.5"
                value={name}
                placeholder="Məsələn: Rəşad"
                onChange={(e) => setName(e.target.value)}
              />
            </div>
            <Button onClick={saveName}>Saxla</Button>
          </div>
        </Section>

        <Section title="Ümumi">
          <p className="mb-2 text-sm text-muted">Tema</p>
          <div className="flex gap-2">
            {(["system", "light", "dark"] as ThemeMode[]).map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => service.setThemeMode(m)}
                className={
                  service.themeMode === m
                    ? "h-10 flex-1 rounded-[var(--radius-md)] bg-primary text-sm font-medium text-primary-fg"
                    : "h-10 flex-1 rounded-[var(--radius-md)] bg-bg text-sm text-muted"
                }
              >
                {themeLabel[m]}
              </button>
            ))}
          </div>
          <div className="mt-4 flex items-center justify-between py-2 text-sm">
            <span className="inline-flex items-center gap-2">
              <Moon className="size-4 text-muted" />
              Dil
            </span>
            <span className="text-muted">Azərbaycan</span>
          </div>
        </Section>

        <Section title="Cədvəl">
          <p className="mb-2 text-sm text-muted">Həftənin başlanğıcı</p>
          <div className="flex flex-wrap gap-1.5">
            {WEEKDAY_OPTIONS.map((d) => (
              <button
                key={d.value}
                type="button"
                onClick={() => service.setWeekStartsOn(d.value)}
                className={
                  service.weekStartsOn === d.value
                    ? "h-10 rounded-full bg-primary px-3 text-sm font-medium text-primary-fg"
                    : "h-10 rounded-full bg-bg px-3 text-sm text-muted"
                }
              >
                {d.label}
              </button>
            ))}
          </div>
        </Section>

        <Section title="Bildirişlər">
          <div className="flex items-center justify-between py-2 text-sm">
            <span className="inline-flex items-center gap-2">
              <Bell className="size-4 text-muted" />
              Dərs xəbərdarlığı
            </span>
            <button
              type="button"
              onClick={async () => {
                const next = !service.remindersEnabled;
                if (next) {
                  const ok = await requestNotifyPermission();
                  if (!ok && typeof Notification !== "undefined" && Notification.permission === "denied") {
                    toast.error("Brauzer bildirişə icazə vermir");
                  }
                }
                service.setRemindersEnabled(next);
              }}
              className={
                service.remindersEnabled
                  ? "h-8 rounded-full bg-primary px-3 text-xs font-medium text-primary-fg"
                  : "h-8 rounded-full bg-bg px-3 text-xs font-medium text-muted"
              }
            >
              {service.remindersEnabled ? "Açıq" : "Bağlı"}
            </button>
          </div>
          <div className="flex items-center justify-between py-2 text-sm">
            <span className="inline-flex items-center gap-2">
              <Volume2 className="size-4 text-muted" />
              Səs
            </span>
            <button
              type="button"
              onClick={() => service.setSoundEnabled(!service.soundEnabled)}
              className={
                service.soundEnabled
                  ? "h-8 rounded-full bg-primary px-3 text-xs font-medium text-primary-fg"
                  : "h-8 rounded-full bg-bg px-3 text-xs font-medium text-muted"
              }
            >
              {service.soundEnabled ? "Açıq" : "Bağlı"}
            </button>
          </div>
          <p className="mt-1 text-xs text-subtle">
            Xəbərdarlıq ekranın yuxarısında görünür və səs çıxır.
          </p>
          <Button
            variant="secondary"
            className="mt-3 w-full"
            onClick={() => {
              if (!service.remindersEnabled) {
                toast.error("Əvvəl xəbərdarlığı açın");
                return;
              }
              dispatchTestReminder();
            }}
          >
            Bildirişi sına
          </Button>
        </Section>

        <Section title="Kateqoriyalar">
          <ul className="flex flex-wrap gap-2">
            {service.categories.map((c) => (
              <li
                key={c}
                className="inline-flex items-center gap-1 rounded-full bg-bg px-3 py-1.5 text-sm"
              >
                {c}
                <button
                  type="button"
                  className="text-subtle hover:text-danger"
                  onClick={() => service.removeCategory(c)}
                  aria-label={`${c} sil`}
                >
                  ×
                </button>
              </li>
            ))}
          </ul>
          {!service.isPremium ? (
            <p className="mt-2 text-xs text-subtle">
              Pulsuz: {service.categories.length}/{FREE_CATEGORY_LIMIT} kateqoriya
            </p>
          ) : null}
          <div className="mt-3 flex gap-2">
            <Input
              value={newCat}
              onChange={(e) => setNewCat(e.target.value)}
              placeholder="Yeni kateqoriya"
            />
            <Button variant="secondary" onClick={addCat}>
              Əlavə
            </Button>
          </div>
        </Section>

        <Section title="Məlumat">
          <Row
            icon={Download}
            label="JSON ixrac et"
            onClick={() => exportData("json")}
          />
          <Row
            icon={Download}
            label="CSV ixrac et"
            onClick={() => exportData("csv")}
          />
          {!confirmClear ? (
            <Row
              icon={Trash2}
              label="Bütün planları sil"
              danger
              onClick={() => setConfirmClear(true)}
            />
          ) : (
            <div className="rounded-[var(--radius-md)] bg-bg p-3">
              <p className="text-sm">Bütün planlar silinəcək. Əminsiniz?</p>
              <div className="mt-2 flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setConfirmClear(false)}
                >
                  Xeyr
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => {
                    service.clearAllPlans();
                    setConfirmClear(false);
                    toast.success("Bütün planlar silindi");
                  }}
                >
                  Bəli, sil
                </Button>
              </div>
            </div>
          )}
        </Section>

        <Section title="Hüquqi">
          <Row icon={Shield} label="Məxfilik Siyasəti" onClick={onPrivacy} />
        </Section>

        <Section title="Haqqında">
          <div className="flex items-center justify-between py-2 text-sm">
            <span>Versiya</span>
            <span className="text-muted">1.1.0</span>
          </div>
          <div className="flex items-center justify-between py-2 text-sm">
            <span className="inline-flex items-center gap-2">
              <User className="size-4 text-muted" />
              Nibras Code
            </span>
            <span className="text-muted">Developer</span>
          </div>
        </Section>

        <p className="pt-2 text-center text-sm text-subtle">
          Cədvəl · Gününə nəzarət et
          <br />
          Nibras Code
        </p>
      </div>
    </Overlay>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-[var(--radius-xl)] bg-surface p-4 shadow-card">
      <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Row({
  icon: Icon,
  label,
  onClick,
  danger,
}: {
  icon: typeof Download;
  label: string;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center justify-between py-2.5 text-left text-sm ${danger ? "text-danger" : ""}`}
    >
      <span className="inline-flex items-center gap-2">
        <Icon className="size-4" />
        {label}
      </span>
      <ChevronRight className="size-4 text-subtle" />
    </button>
  );
}

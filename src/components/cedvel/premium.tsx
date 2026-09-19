import { Check } from "lucide-react";
import { toast } from "sonner";
import { Overlay } from "./overlay";
import { FREE_CATEGORY_LIMIT, FREE_PLAN_LIMIT } from "@/lib/cedvel/types";
import { useCedvel } from "@/lib/cedvel/store";

const FEATURES = [
  "Limitsiz plan və tapşırıq",
  "Limitsiz kateqoriya",
  "JSON və CSV ixrac",
  "Həftəlik qrafik və kateqoriya statistika",
];

export function PremiumScreen({ onBack }: { onBack: () => void }) {
  const isPremium = useCedvel((s) => s.isPremium);
  const setPremium = useCedvel((s) => s.setPremium);

  const activate = () => {
    setPremium(true);
    toast.success("Premium aktivləşdirildi");
    onBack();
  };

  return (
    <Overlay title="Cədvəl Premium" onBack={onBack} tone="ink">
      <div className="mx-auto max-w-lg px-6 pb-10">
        <h2 className="font-display text-3xl font-semibold">Sadə planlama. Güclü nəticə.</h2>
        <p className="mt-2 text-primary-fg/70">
          Pulsuz versiya {FREE_PLAN_LIMIT} plan və {FREE_CATEGORY_LIMIT} kateqoriya ilə
          işləyir. Premium limiti götürür.
        </p>

        <div className="mt-6 overflow-hidden rounded-[var(--radius-xl)] bg-white/8">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-primary-fg/60">
                <th className="px-4 py-3 text-left font-medium"> </th>
                <th className="px-3 py-3 font-medium">Pulsuz</th>
                <th className="px-3 py-3 font-medium">Premium</th>
              </tr>
            </thead>
            <tbody className="text-center">
              <Cmp label="Plan sayı" free={`${FREE_PLAN_LIMIT}`} pro="Limitsiz" />
              <Cmp label="Kateqoriya" free={`${FREE_CATEGORY_LIMIT}`} pro="Limitsiz" />
              <Cmp label="JSON / CSV ixrac" free="—" pro="Var" />
              <Cmp label="Təkmil statistika" free="Əsas" pro="Tam" />
            </tbody>
          </table>
        </div>

        <ul className="mt-6 space-y-2.5">
          {FEATURES.map((f) => (
            <li key={f} className="flex items-center gap-2.5 text-sm">
              <Check className="size-4 text-success" />
              {f}
            </li>
          ))}
        </ul>

        {isPremium ? (
          <div className="mt-8 rounded-[var(--radius-lg)] border border-success/40 bg-success/15 px-4 py-3 text-center text-sm font-medium">
            Premium aktivdir
          </div>
        ) : (
          <div className="mt-8 space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <Price title="Aylıq" price="2.99 ₼" onClick={activate} />
              <Price title="İllik" price="19.99 ₼" badge="Populyar" onClick={activate} />
            </div>
            <p className="text-center text-xs text-primary-fg/50">
              Ödəniş sistemi tezliklə qoşulacaq. İndi Premium lokal aktivləşir —
              heç bir məbləğ tutulmur.
            </p>
          </div>
        )}
      </div>
    </Overlay>
  );
}

function Cmp({
  label,
  free,
  pro,
}: {
  label: string;
  free: string;
  pro: string;
}) {
  return (
    <tr className="border-t border-white/10">
      <td className="px-4 py-2.5 text-left text-primary-fg/80">{label}</td>
      <td className="px-3 py-2.5 text-primary-fg/55">{free}</td>
      <td className="px-3 py-2.5 font-semibold">{pro}</td>
    </tr>
  );
}

function Price({
  title,
  price,
  badge,
  onClick,
}: {
  title: string;
  price: string;
  badge?: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="relative rounded-[var(--radius-lg)] border border-white/15 bg-white/8 px-3 py-4 text-center"
    >
      {badge ? (
        <span className="absolute -top-2 left-1/2 -translate-x-1/2 rounded-full bg-primary-fg px-2 py-0.5 text-[10px] font-semibold text-primary">
          {badge}
        </span>
      ) : null}
      <p className="text-xs text-primary-fg/70">{title}</p>
      <p className="mt-1 font-display text-xl font-semibold">{price}</p>
      <span className="mt-2 block text-xs font-medium">Aktivləşdir</span>
    </button>
  );
}

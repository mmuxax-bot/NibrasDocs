import type { ReactNode } from "react";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";

export function Overlay({
  title,
  onBack,
  action,
  children,
  tone = "default",
}: {
  title: string;
  onBack: () => void;
  action?: ReactNode;
  children: ReactNode;
  tone?: "default" | "ink";
}) {
  const ink = tone === "ink";
  return (
    <div
      className={
        ink
          ? "fixed inset-0 z-40 flex flex-col bg-primary text-primary-fg"
          : "fixed inset-0 z-40 flex flex-col bg-bg text-fg"
      }
    >
      <header className="flex items-center gap-1 px-3 pt-[max(0.75rem,env(safe-area-inset-top))] pb-2">
        <Button
          variant="ghost"
          size="icon"
          onClick={onBack}
          aria-label="Geri"
          className={ink ? "text-primary-fg hover:bg-white/10" : ""}
        >
          <ArrowLeft />
        </Button>
        <h1 className="min-w-0 flex-1 truncate text-base font-semibold">{title}</h1>
        {action}
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">{children}</div>
    </div>
  );
}

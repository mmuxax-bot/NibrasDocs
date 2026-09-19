import { useEffect } from "react";
import { useCedvel } from "@/lib/cedvel/store";

function apply(mode: "system" | "light" | "dark") {
  const dark =
    mode === "dark" ||
    (mode === "system" &&
      window.matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark", dark);
}

export function ThemeSync() {
  const themeMode = useCedvel((s) => s.themeMode);

  useEffect(() => {
    apply(themeMode);
    if (themeMode !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => apply("system");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [themeMode]);

  return null;
}

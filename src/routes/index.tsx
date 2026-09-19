import { createFileRoute } from "@tanstack/react-router";
import { CedvelApp } from "@/components/cedvel/app";

export const Route = createFileRoute("/")({ component: Home });

function Home() {
  return <CedvelApp />;
}

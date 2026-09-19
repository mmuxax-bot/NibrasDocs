import { createFileRoute, Link } from "@tanstack/react-router";
import { PrivacyArticle } from "@/components/cedvel/privacy-content";

export const Route = createFileRoute("/mexfilik")({
  component: MexfilikPage,
  head: () => ({
    meta: [
      { title: "Məxfilik Siyasəti – Cədvəl" },
      {
        name: "description",
        content: "Cədvəl tətbiqinin məxfilik siyasəti. Məlumatlar yalnız bu cihazda saxlanılır.",
      },
    ],
  }),
});

function MexfilikPage() {
  return (
    <div className="min-h-dvh bg-bg px-5 py-10">
      <div className="mx-auto max-w-lg">
        <Link to="/" className="text-sm font-medium text-primary">
          ← Cədvələ qayıt
        </Link>
        <div className="mt-6">
          <PrivacyArticle />
        </div>
      </div>
    </div>
  );
}

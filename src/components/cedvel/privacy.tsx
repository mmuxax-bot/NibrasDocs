import { Overlay } from "./overlay";
import { PrivacyArticle } from "./privacy-content";

export function PrivacyScreen({ onBack }: { onBack: () => void }) {
  return (
    <Overlay title="Məxfilik Siyasəti" onBack={onBack}>
      <div className="px-5 pb-12">
        <PrivacyArticle />
      </div>
    </Overlay>
  );
}

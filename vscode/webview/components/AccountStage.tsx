import { useState } from "preact/hooks";
import { pets } from "../pets";
import type { AccountInput } from "../pets/api";
import { stageCallbacks, usePetStage } from "../util/petStage";

// An account's chats as pets. Stays mounted while pets are on, so the pets
// keep their places; it folds away when the account has no chat to show, once
// the last pet has waved goodbye.
export function AccountStage({ stageKey, input }: { stageKey: string; input: AccountInput }) {
  const [petCount, setPetCount] = useState(0);
  const open = input.maxPets > 0 && (input.chats.length > 0 || petCount > 0);
  const ref = usePetStage(
    (el) => pets.createAccountStage(el, stageKey, { ...stageCallbacks, petsChanged: setPetCount }),
    input,
    open,
  );
  return (
    <div class={"stage-fold" + (open ? " open" : "")} aria-hidden={!open}>
      <div class="stage-clip">
        <div class="account-stage" ref={ref} />
      </div>
    </div>
  );
}

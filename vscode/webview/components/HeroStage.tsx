import { render } from "preact";
import { useEffect, useState } from "preact/hooks";
import type { Group } from "../../src/shared/types";
import { pets } from "../pets";
import type { HeroInput } from "../pets/api";
import { stageCallbacks, usePetStage } from "../util/petStage";
import { Ticker } from "./Ticker";

// The big Talpy: the whole dashboard at a glance, and in its box, under the
// counts, what the working chats do right now (the ticker, as in Plasma)
export function HeroStage({ input, groups }: { input: HeroInput; groups: Group[] }) {
  const [slot, setSlot] = useState<HTMLElement | null>(null);
  const ref = usePetStage((el) => pets.createHeroStage(el, stageCallbacks), input, true,
    (stage) => setSlot(stage?.tickerSlot?.() ?? null));
  useEffect(() => {
    if (slot) render(<Ticker groups={groups} />, slot);
  }, [slot, groups]);
  useEffect(() => () => { if (slot) render(null, slot); }, [slot]);
  return <div class="hero" ref={ref} />;
}

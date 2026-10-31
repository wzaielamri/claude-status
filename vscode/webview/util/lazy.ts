import { useEffect, useState } from "preact/hooks";

// A line's hover buttons, made the first time they're wanted: the pointer on
// the line (a finger too), or the keyboard (Tab to its name). Opening a list
// or a project then makes only the lines themselves, and stays quick.
export function useWoken(): [boolean, { onPointerEnter?: () => void; onFocusIn?: () => void }] {
  const [woken, setWoken] = useState(false);
  const wake = () => setWoken(true);
  return [woken, woken ? {} : { onPointerEnter: wake, onFocusIn: wake }];
}

// True from the frame after the first one: what can come a moment later
// (an opened project's plans and memories, after its chats)
export function useAfterFrame(): boolean {
  const [due, setDue] = useState(false);
  useEffect(() => {
    let timer = 0;
    const frame = requestAnimationFrame(() => (timer = window.setTimeout(() => setDue(true), 0)));
    return () => {
      cancelAnimationFrame(frame);
      clearTimeout(timer);
    };
  }, []);
  return due;
}

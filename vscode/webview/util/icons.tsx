// Small line icons drawn here: the webview loads nothing from outside (no
// codicon font), and currentColor makes them follow every theme.

import type { JSX } from "preact";

export type IconName = "refresh" | "remove" | "stop" | "close" | "share" | "chevron" | "server" | "eye" | "external" | "play" | "back" | "search" | "logout" | "edit" | "send" | "repeat" | "star" | "chat" | "move" | "filter" | "chart" | "shield" | "folder" | "mic" | "attach" | "camera" | "newChat" | "addAccount";

const shapes: Record<IconName, JSX.Element> = {
  repeat: (
    <>
      <path d="M2.75 7.5V6.25a2.5 2.5 0 0 1 2.5-2.5h7.5" />
      <path d="M10.75 1.75l2 2-2 2" />
      <path d="M13.25 8.5v1.25a2.5 2.5 0 0 1-2.5 2.5h-7.5" />
      <path d="M5.25 14.25l-2-2 2-2" />
    </>
  ),
  refresh: (
    <>
      <path d="M13.4 8.6A5.5 5.5 0 1 1 11.6 3.9" />
      <path d="M12.4 1.4v3.2H9.2" />
    </>
  ),
  remove: <path d="M2.75 8h10.5" />,
  stop: <rect x="3.75" y="3.75" width="8.5" height="8.5" rx="1.5" fill="currentColor" />,
  close: <path d="M4 4l8 8M12 4l-8 8" />,
  share: (
    <>
      <circle cx="11.75" cy="3.75" r="1.75" />
      <circle cx="4.25" cy="8" r="1.75" />
      <circle cx="11.75" cy="12.25" r="1.75" />
      <path d="M5.8 7.1l4.4-2.5M5.8 8.9l4.4 2.5" />
    </>
  ),
  chevron: <path d="M6 3.5L10.5 8 6 12.5" />,
  play: <path d="M5 3.25v9.5L12.5 8z" fill="currentColor" />,
  back: <path d="M7.5 3.5L3 8l4.5 4.5M3.25 8h9.75" />,
  filter: <path d="M2.5 3.5h11l-4.25 5v4l-2.5 1.25V8.5z" />,
  search: (
    <>
      <circle cx="7" cy="7" r="4.25" />
      <path d="M10.2 10.2l3.3 3.3" />
    </>
  ),
  logout: (
    <>
      <path d="M6.5 2.75H3.75c-.55 0-1 .45-1 1v8.5c0 .55.45 1 1 1H6.5" />
      <path d="M10 5l3 3-3 3M13 8H6.5" />
    </>
  ),
  server: (
    <>
      <rect x="2.25" y="2.25" width="11.5" height="5" rx="1.25" />
      <rect x="2.25" y="8.75" width="11.5" height="5" rx="1.25" />
      <path d="M4.75 4.75h.01M4.75 11.25h.01" stroke-width="1.8" />
    </>
  ),
  eye: (
    <>
      <path d="M1.5 8S3.9 3.5 8 3.5 14.5 8 14.5 8 12.1 12.5 8 12.5 1.5 8 1.5 8z" />
      <circle cx="8" cy="8" r="2" />
    </>
  ),
  edit: (
    <>
      <path d="M10.75 2.75l2.5 2.5-7.5 7.5-3.25 0.75 0.75-3.25z" />
      <path d="M9.25 4.25l2.5 2.5" />
    </>
  ),
  send: <path d="M2.5 8l11-5.5-3.5 11-2.5-4.5zM7.5 9l6-6.5" />,
  move: <path d="M2.5 8h8M7.75 5.25L10.5 8l-2.75 2.75M13.25 3v10" />,
  star: <path d="M8 1.9l1.85 3.8 4.15.6-3 2.93.7 4.13L8 11.4l-3.7 1.96.7-4.13-3-2.93 4.15-.6z" />,
  chat: <path d="M2.5 3.75c0-.7.55-1.25 1.25-1.25h8.5c.7 0 1.25.55 1.25 1.25v5.5c0 .7-.55 1.25-1.25 1.25H7l-3 2.75V10.5h-.25c-.7 0-1.25-.55-1.25-1.25z" />,
  // (a bubble with a plus: a new chat, not a new account)
  newChat: (
    <>
      <path d="M2.5 3.75c0-.7.55-1.25 1.25-1.25h8.5c.7 0 1.25.55 1.25 1.25v5.5c0 .7-.55 1.25-1.25 1.25H7l-3 2.75V10.5h-.25c-.7 0-1.25-.55-1.25-1.25z" />
      <path d="M8 4.5v4M6 6.5h4" />
    </>
  ),
  addAccount: (
    <>
      <circle cx="6.25" cy="5" r="2.5" />
      <path d="M1.75 13.5c0-2.5 2-4.25 4.5-4.25s4.5 1.75 4.5 4.25M12.75 2.75v4M10.75 4.75h4" />
    </>
  ),
  chart: <path d="M2.5 13.5h11M4.5 11V8M8 11V3.5M11.5 11V6" />,
  shield: <path d="M8 1.75l5 2v4c0 3.1-2.15 5.35-5 6.5-2.85-1.15-5-3.4-5-6.5v-4z" />,
  folder: <path d="M2 4c0-.55.45-1 1-1h3.5l1.5 1.75h5c.55 0 1 .45 1 1V12c0 .55-.45 1-1 1H3c-.55 0-1-.45-1-1z" />,
  mic: (
    <>
      <rect x="6" y="1.75" width="4" height="7.5" rx="2" />
      <path d="M3.75 7.5a4.25 4.25 0 0 0 8.5 0M8 11.75v2.5M5.75 14.25h4.5" />
    </>
  ),
  attach: <path d="M11.25 5v5.75a3.25 3.25 0 0 1-6.5 0V4.5a2.25 2.25 0 0 1 4.5 0v5.75a1.125 1.125 0 0 1-2.25 0V6" transform="rotate(45 8 8.1)" />,
  camera: (
    <>
      <path d="M1.75 5.5c0-.7.55-1.25 1.25-1.25h2l1.25-1.75h3.5l1.25 1.75h2c.7 0 1.25.55 1.25 1.25v6.25c0 .7-.55 1.25-1.25 1.25H3c-.7 0-1.25-.55-1.25-1.25z" />
      <circle cx="8" cy="8.5" r="2.5" />
    </>
  ),
  external: (
    <>
      <path d="M9.5 2.5h4v4M13.5 2.5L8 8" />
      <path d="M12 9.5v2.75c0 .7-.55 1.25-1.25 1.25h-7c-.7 0-1.25-.55-1.25-1.25v-7C2.5 4.55 3.05 4 3.75 4H6.5" />
    </>
  ),
};

export function Icon({ name, class: cls }: { name: IconName; class?: string }) {
  return (
    <svg
      class={"icon" + (cls ? " " + cls : "")}
      viewBox="0 0 16 16"
      width="16"
      height="16"
      fill="none"
      stroke="currentColor"
      stroke-width="1.3"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {shapes[name]}
    </svg>
  );
}

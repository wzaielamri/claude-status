import type { ComponentChildren } from "preact";
import { Icon, type IconName } from "../util/icons";

// A toolbar-style button: an icon, its label as tooltip and for screen readers
export function IconButton(props: {
  icon: IconName;
  label: string;
  title?: string; // a longer tooltip than the label
  onClick: () => void;
  class?: string;
  children?: ComponentChildren;
  disabled?: boolean; // (greyed out in its place, so every line's buttons stay in the same columns)
}) {
  return (
    <button
      type="button"
      class={"icon-btn" + (props.class ? " " + props.class : "")}
      title={props.title ?? props.label}
      aria-label={props.label}
      disabled={props.disabled}
      onClick={(e) => {
        e.stopPropagation();
        props.onClick();
      }}
    >
      <Icon name={props.icon} />
      {props.children}
    </button>
  );
}

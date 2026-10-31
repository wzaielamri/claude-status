import { Icon, type IconName } from "../util/icons";

// Small outlined label next to a chat's name: its profile, "VS Code", …
// (icon: one before its text, as big as the buttons')
export function Tag(props: {
  text: string;
  icon?: IconName;
  title?: string;
  active?: boolean; // outlined in the accent color
  warning?: boolean; // outlined and written in the error color
  pressed?: boolean;
  fill?: number; // 0…1: filled that far, as a progress bar
  onClick?: () => void;
}) {
  const cls = "tag" + (props.icon ? " with-icon" : "") + (props.active ? " active" : "") + (props.warning ? " warning" : "") + (props.fill !== undefined ? " progress" : "");
  const style = props.fill !== undefined ? { "--fill": `${Math.round(Math.min(1, Math.max(0, props.fill)) * 100)}%` } : undefined;
  if (props.onClick)
    return (
      <button type="button" class={cls + " clickable"} style={style} title={props.title} aria-pressed={props.pressed} onClick={props.onClick}>
        {props.icon ? <Icon name={props.icon} /> : null}
        {props.text}
      </button>
    );
  return (
    <span class={cls} style={style} title={props.title}>
      {props.icon ? <Icon name={props.icon} /> : null}
      {props.text}
    </span>
  );
}

import { ago, shareAccounts, machineStatus } from "../../src/shared/model";
import type { Group, PlanItem } from "../../src/shared/types";
import { post } from "../env";
import { groupKeyOf } from "../util/chat";
import { Icon } from "../util/icons";
import { useStore } from "../util/store";
import { togglePlans, toggleStarred, uiState } from "../util/ui";
import { useView } from "./context";
import { Elided } from "./Elided";
import { IconButton } from "./IconButton";
import { Tag } from "./Tag";

// The plans this account's chats wrote in plan mode (<config>/plans), newest
// first. Folded by default. A plan opens in the Markdown preview (an SSH
// host's: a copy, unless this window is connected to it); ▶ carries it out in a new
// chat, ◀ goes back to the chat that made it, and the share button shares it
// with the machine's other accounts. The plans you starred come first, under
// their own fold (★ Starred), however old.
export function PlansList({ group }: { group: Group }) {
  const view = useView();
  const ui = useStore(uiState);
  const key = groupKeyOf(group);
  const plans = group.plans ?? [];
  const starred = group.starredPlans ?? [];
  if (!plans.length && !starred.length) return null;
  const open = !!ui.plans[key];
  const starredOpen = !!ui.starred[`${key}|plans`];
  const host = group.host;
  const share = shareAccounts(machineStatus(view, host)).length >= 2;
  const copy = !!host && host !== view.hosts.find((h) => h.current)?.name;
  const ref = (plan: string) => (host ? { groupId: group.id, host, plan } : { groupId: group.id, plan });

  return (
    <div class="recent plans">
      <button
        type="button"
        class="recent-toggle small"
        aria-expanded={open}
        title="The plans this account's chats wrote in plan mode, newest first, and the ones you starred. Open one, carry it out in a new chat, go back to the chat that made it, or share it with your other accounts."
        onClick={() => togglePlans(key)}
      >
        <Icon name="chevron" class={open ? "open" : ""} />
        Plans ({plans.length})
      </button>
      {open && starred.length ? (
        <button
          type="button"
          class="recent-toggle starred-toggle small"
          aria-expanded={starredOpen}
          title="The plans of this account you starred (☆ next to a plan), newest first, however old they are. Click a plan's ★ to unstar it."
          onClick={() => toggleStarred(`${key}|plans`)}
        >
          <Icon name="chevron" class={starredOpen ? "open" : ""} />★ Starred ({starred.length})
        </button>
      ) : null}
      {open && starredOpen && starred.length ? <ul class="recent-list starred-list">{starred.map((p) => line(p))}</ul> : null}
      {open ? <ul class="recent-list">{plans.map((p) => line(p))}</ul> : null}
    </div>
  );

  function line(p: PlanItem) {
    return (
      <li key={p.key} class="recent-item">
        <button
          type="button"
          class="link recent-name"
          title={
            `${p.title}\n` +
            (copy
              ? `Click to read it: a copy, fetched from ${host}.`
              : "Click to read it in the Markdown preview. Its Open Source button edits it: what you change there is the plan.") +
            (p.cwd ? `\nFolder: ${host ? `${host}:` : ""}${p.cwd}` : "") +
            (p.shared ? "\nShared with your other accounts." : "") +
            (p.chatId ? "" : "\nThe chat that made it isn't here any more.")
          }
          onClick={() => post({ type: "openPlan", ...ref(p.key) })}
        >
          {p.title}
        </button>
        {p.shared ? (
          <span class="muted" title="Shared with your other accounts">
            ⇄
          </span>
        ) : null}
        {p.edited && p.chatId && !host ? (
          <Tag
            text="↩ Send"
            active
            title="You changed this plan since Claude wrote it. Click to send what you changed (and your comments on it) to the chat that made it: Claude revises the plan, in plan mode."
            onClick={() => post({ type: "sendPlanFeedback", ...ref(p.key) })}
          />
        ) : null}
        {p.starred ? (
          <button type="button" class="star-mark" title="Starred: it stays listed under Starred, however old it is. Click to unstar it." onClick={() => post({ type: "star", ...ref(p.key), on: false })}>
            ★
          </button>
        ) : null}
        {p.cwdShort ? <Elided text={p.cwdShort} class="recent-folder small muted" title={p.cwd} /> : <span class="recent-folder" />}
        <span class="recent-ago small muted nowrap">{ago(view.now - p.updatedAt)}</span>
        <div class="row-actions">
          {p.starred ? null : (
            <IconButton
              icon="star"
              label="Star"
              title="Star this plan: it stays listed under Plans → Starred, however old it is."
              onClick={() => post({ type: "star", ...ref(p.key), on: true })}
            />
          )}
          {copy || !p.chatId || host ? null : (
            <IconButton
              icon="send"
              label="Send your feedback to Claude"
              title={
                (p.edited ? "You changed this plan since Claude wrote it. " : "") +
                "Send what you changed in it, and your comments on its lines (the + next to a line, in its file), to the chat that made it: Claude revises the plan, in plan mode."
              }
              onClick={() => post({ type: "sendPlanFeedback", ...ref(p.key) })}
            />
          )}
          {copy ? null : (
            <IconButton
              icon="edit"
              label="Edit the plan"
              title="Edit the plan: its Markdown file opens in an editor tab. What you change there is the plan."
              onClick={() => post({ type: "openPlan", ...ref(p.key), edit: true })}
            />
          )}
          <IconButton
            icon="play"
            label="Carry it out…"
            title="Carry it out in a new chat: the plan is the chat's first message, with what you add; in a terminal, in the background or in a Claude Code panel, in the plan's folder or another one."
            onClick={() => post({ type: "carryOutPlan", ...ref(p.key) })}
          />
          {p.chatId ? (
            <IconButton
              icon="back"
              label="Continue the chat that made it"
              title="Continue the chat that made it, to change the plan with Claude: it comes up, or reopens (in a terminal or a Claude Code panel, as the switch of Recent chats says)."
              onClick={() => post({ type: "continuePlanChat", ...ref(p.key) })}
            />
          ) : null}
          {share ? (
            <IconButton
              icon="share"
              label="Share this plan…"
              title="Share this plan with your other accounts: one file on each of them, so a change shows on all of them. Sharing a chat shares its plan too."
              onClick={() => post({ type: "sharePlan", ...ref(p.key) })}
            />
          ) : null}
        </div>
      </li>
    );
  }
}

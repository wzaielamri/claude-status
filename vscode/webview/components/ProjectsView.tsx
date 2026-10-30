// The Projects tab: each project (a chat's git repository, else its folder),
// newest first, with what goes on there now (its open chats), Claude's last
// recap of it, how long Claude worked on it and what that cost (the last 7
// days and everything kept), its latest chats, plans and memories, and + for
// a new chat there. The numbers come from week.py --projects; what goes on
// now from the status (the view's state).

import { useEffect, useState } from "preact/hooks";
import type { ProjectRow, ProjectsData, Session } from "../../src/shared/types";
import { doingText, duration, petKeyOf, stateText } from "../../src/shared/model";
import { currencyOf, hoursText, moneyText } from "../../src/shared/week";
import { post } from "../env";
import { pets } from "../pets";
import { chatRefOf, hideHint } from "../util/chat";
import { Icon, memoryIcon } from "../util/icons";
import { useViewVisible } from "../util/petStage";
import { useStore } from "../util/store";
import { projectsAnswer, viewState } from "../util/stores";

const under = (folder: string | undefined | null, path: string) => !!folder && (folder === path || folder.startsWith(path + "/"));

// (as the Recap tab says it: €12.34, <$0.01)
function money(usd: number, cur: ProjectsData["currency"]): string {
  return moneyText(usd, currencyOf({ currency: cur ? { ...cur, date: cur.date ?? "", error: cur.error ?? "" } : undefined }));
}

export function ProjectsView() {
  const answer = useStore(projectsAnswer);
  const state = useStore(viewState);
  const [open, setOpen] = useState<Record<string, boolean>>({});
  // Asked when the tab is in sight, again every 10 minutes
  const visible = useViewVisible();
  useEffect(() => {
    if (!visible) return undefined;
    post({ type: "projects" });
    const t = setInterval(() => post({ type: "projects" }), 600000);
    return () => clearInterval(t);
  }, [visible]);
  if (!answer) return <div class="empty muted">Reading your chats by project…</div>;
  if (answer.error) return <div class="msg error" role="alert">Couldn't read your projects: {answer.error}</div>;
  const projects = answer.data?.projects ?? [];
  if (!projects.length) return <div class="empty muted">No projects yet: a project is a folder (or the git repository it's in) where you chatted with Claude.</div>;
  const groups = state?.status?.groups ?? [];
  const now = Date.now();
  return (
    <div class="projects">
      {projects.map((p, i) => {
        const unfolded = open[p.path] ?? false;
        return (
          <section key={p.path} class="project">
            <div class="project-head">
              <button type="button" class="project-name" aria-expanded={unfolded} onClick={() => setOpen({ ...open, [p.path]: !unfolded })}>
                <span class={"chevron" + (unfolded ? " open" : "")} aria-hidden="true"><Icon name="chevron" /></span>
                <span class="project-title">
                  <strong>{p.name}</strong>
                  <span class="small muted project-meta" title={p.path}>{p.short} · last at work {duration(Math.max(60000, now - p.lastAt))} ago</span>
                  <span class="small muted project-numbers">
                    7 days: {hoursText(p.weekMs)} · all: {hoursText(p.workedMs)} · {money(p.cost, answer.data?.currency)}
                  </span>
                </span>
              </button>
              <button type="button" class="icon-btn" title={`New chat in ${p.short}`} aria-label="New chat here"
                onClick={() => post({ type: "newChatIn", path: p.path, profileDir: p.chats[0]?.profileDir ?? "" })}>
                <Icon name="newChat" />
              </button>
              <button type="button" class="icon-btn project-hide" title={`Hide this project\n${hideHint("projects")}`} aria-label="Hide this project"
                onClick={() => post({ type: "hide", kind: "projects", id: p.path })}>
                <Icon name="close" />
              </button>
            </div>
            {unfolded ? <ProjectDetails p={p} groups={groups} now={now} cur={answer.data?.currency} /> : null}
          </section>
        );
      })}
    </div>
  );
}

function ProjectDetails({ p, groups, now, cur }: { p: ProjectRow; groups: NonNullable<NonNullable<ReturnType<typeof viewState.get>>["status"]>["groups"]; now: number;
                                                  cur: ProjectsData["currency"] }) {
  const sessions: Session[] = groups.flatMap((g) => g.sessions.filter((s) => under(s.cwd, p.path)));
  const recaps = groups.flatMap((g) => (g.recent ?? []).filter((r) => under(r.cwd, p.path) && r.recap?.text))
    .sort((a, b) => (b.lastActive ?? 0) - (a.lastActive ?? 0));
  const plans = groups.flatMap((g) => (g.plans ?? []).filter((x) => under(x.cwd, p.path)).map((x) => ({ x, g })))
    .sort((a, b) => (b.x.updatedAt ?? 0) - (a.x.updatedAt ?? 0));
  const memories = groups.flatMap((g) => (g.memories ?? []).filter((m) => m.folder && under(m.folder, p.path)).map((m) => ({ m, g })))
    .sort((a, b) => (b.m.updatedAt ?? 0) - (a.m.updatedAt ?? 0));
  return (
    <div class="project-details">
      {sessions.map((s) => {
        // (what a working chat does, as in the focus view; else how it stands, as its row says)
        const doing = s.state === "working" ? doingText(s, null) : "";
        return (
          <button key={s.key} type="button" class="focus-line" title={`${s.name}\n${doing || stateText(s, now)}\nClick to open this chat`}
            onClick={() => post({ type: "open", chat: chatRefOf(s) })}>
            <span class="pet-bar" style={{ background: pets.petColor(petKeyOf(s)) || "transparent" }} aria-hidden="true" />
            <span class={`focus-dot st-${s.state}`} aria-hidden="true" />
            <span class="focus-name">{s.name}</span>
            <span class="focus-what">{doing || stateText(s, now)}</span>
            <span class="focus-time small muted">{doing && s.since ? duration(now - s.since) : ""}</span>
          </button>
        );
      })}
      {recaps.length ? <p class="project-recap">“{recaps[0].recap!.text}”</p> : null}
      <ul class="week-chats">
        {p.chats.slice(0, 5).map((c) => (
          <li key={c.id}>
            <button type="button" class="week-chat" title={`Open “${c.name}”`}
              onClick={() => post({ type: "openWeekChat", chatId: c.id, profileDir: c.profileDir, name: c.name, cwd: c.cwd })}>
              <span class="week-chat-name">{c.name}</span>
              <span class="week-chat-folder small muted">{duration(Math.max(60000, now - c.lastAt))} ago</span>
              <span class="week-chat-value small muted">{hoursText(c.workedMs)} · {money(c.cost, cur)}</span>
            </button>
          </li>
        ))}
      </ul>
      {p.chatCount > 5 ? <div class="small muted">and {p.chatCount - 5} more {p.chatCount - 5 === 1 ? "chat" : "chats"}</div> : null}
      {plans.length || memories.length ? (
        <div class="project-files">
          {plans.slice(0, 4).map(({ x, g }) => (
            <button key={x.key} type="button" class="chip" title={x.title} onClick={() => post({ type: "openPlan", groupId: g.id, plan: x.key })}>
              <Icon name="task" />
              {x.title}
            </button>
          ))}
          {memories.slice(0, 4).map(({ m, g }) => (
            <button key={m.key} type="button" class="chip" title={m.description ?? m.name} onClick={() => post({ type: "openMemory", groupId: g.id, memory: m.key })}>
              <Icon name={memoryIcon(m.type)} />
              {m.name}
            </button>
          ))}
          {plans.length > 4 || memories.length > 4 ? (
            <span class="small muted">{[plans.length > 4 ? `${plans.length - 4} more plans` : "", memories.length > 4 ? `${memories.length - 4} more memories` : ""].filter(Boolean).join(" · ")} (under its account in Chats)</span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

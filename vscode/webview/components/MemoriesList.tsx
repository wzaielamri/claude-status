import { ago } from "../../src/shared/model";
import type { Group } from "../../src/shared/types";
import { post } from "../env";
import { deleteHint, groupKeyOf, hideHint } from "../util/chat";
import { Icon, memoryIcon } from "../util/icons";
import { useStore } from "../util/store";
import { toggleMemories, uiState } from "../util/ui";
import { useView } from "./context";
import { Elided } from "./Elided";
import { IconButton } from "./IconButton";

// What Claude keeps about you and your projects on this account: its
// memories (<config>/projects/<folder>/memory), newest first. Folded by
// default. One opens in the Markdown preview; the edit button opens its file.
// An SSH host's opens only in a window connected to that host.
export function MemoriesList({ group }: { group: Group }) {
  const view = useView();
  const ui = useStore(uiState);
  const key = groupKeyOf(group);
  const memories = group.memories ?? [];
  if (!memories.length) return null;
  const open = !!ui.memories[key];
  const host = group.host;
  const elsewhere = !!host && host !== view.hosts.find((h) => h.current)?.name;
  const ref = (memory: string, edit?: boolean) => ({ type: "openMemory" as const, groupId: group.id, memory, ...(host ? { host } : {}), ...(edit ? { edit } : {}) });

  return (
    <div class="recent plans memories">
      <button
        type="button"
        class="recent-toggle small"
        aria-expanded={open}
        title="What Claude keeps about you and your projects on this account, newest first: one note each, for the folder it was learned in. Claude reads them in new chats there."
        onClick={() => toggleMemories(key)}
      >
        <Icon name="chevron" class={open ? "open" : ""} />
        Memories ({memories.length})
      </button>
      {open ? (
        <ul class="recent-list">
          {memories.map((m) => (
            <li key={m.key} class={"recent-item" + (elsewhere ? " unavailable" : "")}>
              <Icon name={memoryIcon(m.type)} class="line-icon" />
              <button
                type="button"
                class="link recent-name"
                aria-disabled={elsewhere}
                title={
                  `${m.name}\n` +
                  (m.description ? `${m.description}\n` : "") +
                  (m.type ? `\nKind: ${m.type}` : "") +
                  (m.folder ? `\nFolder: ${host ? `${host}:` : ""}${m.folder}${m.folderGone ? " (not there any more)" : ""}` : "") +
                  (elsewhere ? `\n\nOpen it from a VS Code window connected to ${host}.` : "\n\nClick to read it.")
                }
                onClick={() => !elsewhere && post(ref(m.key))}
              >
                {m.description || m.name}
              </button>
              {m.folderShort || m.folder || m.type === "account" ? (
                <Elided text={m.folderShort || m.folder || "every folder"} class="recent-folder small muted"
                  title={m.folderGone ? `${m.folder} (not there any more)` : m.folder} />
              ) : (
                <span class="recent-folder" />
              )}
              <span class="recent-ago small muted nowrap">{ago(view.now - m.updatedAt)}</span>
              <div class="row-actions">
                {elsewhere ? null : (
                  <IconButton
                    icon="edit"
                    label="Edit this memory"
                    title="Edit this memory: its file opens in an editor tab. What you change there is what Claude remembers; it reads it in new chats in that folder."
                    onClick={() => post(ref(m.key, true))}
                  />
                )}
                {m.type === "account" ? null : (
                  <IconButton icon="trash" label="Delete this memory…" title={`Delete this memory…\n${deleteHint("memory")}`}
                    onClick={() => post({ type: "delete", kind: "memory", groupId: group.id, ...(host ? { host } : {}), id: m.key })} />
                )}
                <IconButton icon="close" label="Hide this memory" title={`Hide this memory\n${hideHint("memories", host)}`}
                  onClick={() => post({ type: "hide", kind: "memories", groupId: group.id, ...(host ? { host } : {}), id: m.key })} />
              </div>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

import { moreText, moreTitle } from "../../src/shared/model";
import { Icon } from "../util/icons";

// "Show N more" under a list that shows a page at a time (Recent chats,
// ★ Starred chats and plans, an opened project's chats, plans and memories):
// the next page of it (util/ui.ts: showMore). Folded again, the list shows
// its first page.
export function MoreButton({ shown, count, size, onClick }: { shown: number; count: number; size: number; onClick: () => void }) {
  if (shown >= count) return null;
  return (
    <button type="button" class="more-button small" title={moreTitle(shown, count)} onClick={onClick}>
      <Icon name="more" />
      {moreText(shown, count, size)}
    </button>
  );
}

# Sharing chats between accounts

With two or more Claude accounts on this computer (say `~/.claude` and `~/.claude-work`), a finished chat can move between them. Hover it (or one of your recent chats), press its share button and pick:

- **Continue on work:** shares the chat with that account and reopens it there with `claude --resume`. The quick way on when one account hits its limit.
- **Share with all accounts:** the chat shows up in every account's past chats.
- **Keep only on personal…** (asks first): the chat becomes a normal chat of that account again; the others lose it.

A chat a usage limit stopped gets **Continue on …** right under it, for the account with the most room left in that limit: the chat is shared with that account and reopens there in a terminal. If an idle Claude still has it open here, that one quits first (in a terminal as with ■, a background chat with `claude stop`); a chat in VS Code's Claude tab, close it there first.

A chat's plan goes with it: sharing a chat also shares the plan it wrote, so it goes on with its plan on the other account. A plan can be shared on its own too (its share button under **Plans**): it's one file on each account, so a change shows on all of them; **Keep only on …** takes it off the others.

**A second account to share with** is a second Claude config folder, logged into a *different* Claude account: profiles logged into the same account count as one, and sharing needs two. Add one in Talpy Den's settings, **Accounts** → **Add an account** (see [Accounts](usage.md#accounts)), and log in with the other account. By hand: `CLAUDE_CONFIG_DIR=~/.claude-work claude`, log in there (`/login`), and for its plan usage bars copy the `statusLine` entry from `~/.claude/settings.json` into `~/.claude-work/settings.json`, then run `./install.sh` again. Talpy Den finds every `~/.claude-*` folder by itself.

A shared chat is one transcript file hard-linked into each profile's `projects/<project>/` folder, so whichever account continues it writes to the same file and nothing is copied. Its subagent folder and undo checkpoints move to `~/.local/share/claude-status/shared-chats/<project>/`, and each profile links to them. Sharing uses no tokens and installs no hooks or settings.

- **Open in one place at a time.** Two Claudes on one chat would both write to its transcript. Talpy Den doesn't share or unshare a chat while Claude has it open somewhere, but nothing stops you from resuming it on a second account yourself: close it on one before you open it on the other.
- **The chat goes with it.** Everything in a chat is sent to whichever account continues it, work content included.
- If Claude forks a shared chat (e.g. when a background chat takes it over), the fork is a chat of its own on that account, tagged **⇄ shared copy**.
- **One filesystem.** A hard link can't cross filesystems, so your Claude folders and `~/.local/share` must be on the same disk or partition (or btrfs subvolume). Talpy Den checks first and says so otherwise, leaving everything as it was.
- **On an SSH host** with two or more accounts, the share button works the same, between that host's accounts: **Continue on …** opens the chat on the other account in a local terminal over ssh (`ssh -t <host> claude --resume …`). The sharing script is sent over the connection like the status script, so nothing is installed there, and the chat's folders go to the host's `~/.local/share/claude-status/shared-chats`. A chat can't move between this computer and a host.
- To undo sharing, use **Keep only on …**. Before you delete `~/.local/share/claude-status`, keep each shared chat on one account: their subagent folders and undo checkpoints are in there.

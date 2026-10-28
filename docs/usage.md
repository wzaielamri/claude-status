# Using Talpy Den

## What a click does

| Where | What it does |
|---|---|
| Panel icon | Left-click opens the popup, middle-click refreshes. Right-click: *Refresh*, *Show Removed Chats Again*, *Go to the Chat That Needs You* (when one does), *Open Usage Page on claude.ai*, the *Default Account* (with two accounts or more), and the settings. |
| The big Talpy | Click its headline (*… needs you*) to go to that chat. Click it to pet it, double-click to make it dance, drag it out of its burrow. |
| A chat's name | Jumps to the chat: its terminal tab, its VS Code window, or a terminal attached to the background job. |
| The line under a chat | Unfolds your last prompt, Claude's reply, the chat's tasks, and buttons that compare what it changed (all of it, or its last turn). |
| **±3** next to a chat | Compares the files the chat changed in VS Code. |
| An account's token line | Unfolds its last 14 days: tokens per day, chats, prompts, busiest folders and models. |
| The widget's keyboard shortcut | Goes to the chat that needs you, else opens the popup (set the key in the settings, on the Keyboard Shortcuts page). |
| Hovering a chat | ■ stops or interrupts a chat (it asks first), － hides a finished one, and the share button shares a chat with your other accounts. |
| A chat's pet | Opens its chat. |
| **+** next to an account | A field for what Claude should do (optional), then the account's recent folders and **Choose folder…** (an SSH host's: its home folder instead). Click one for a new chat there: in a terminal, in VS Code (the switch at the top of the list) or, with a task and **In the background**, as a background session. |
| *Recent chats* | Unfolds the account's older conversations; click one to reopen it, in a terminal or in VS Code (the switch at the top of the list). |
| *Plans* | Unfolds the account's plans: click one to open it. Hovering one: ▶ carries it out in a new chat, ◀ goes back to the chat that made it, and the share button shares it with your other accounts. |
| **plan ↗** next to a session | Opens the plan that chat wrote, to read. |
| **✎** next to it, or in a plan's row | Opens the plan's Markdown file to change it (your text editor; VS Code if the settings open plans there). |
| **↩ send to Claude** next to a session | You changed its plan: sends your changes to the chat, which revises the plan. |
| *Memories* | Unfolds the account's `CLAUDE.md` and what Claude remembers: click one to read it, ✎ to change it. |
| **Continue on …** under a session | A usage limit stopped it: continues it on that account, which has room left. |
| **Go on at …** under a session | A usage limit stopped it: it goes on by itself in the background once the limit resets (click again to cancel). In *Recent chats*, its **limit** tag does the same. |
| **☆** next to a session, recent chat or plan | Stars it: the account lists it under *Recent chats → ★ Starred* or *Plans → ★ Starred*, however old it is. **★** unstars it. |
| **Keep going** under a session | The same, and again after every later limit, until it's done (in *Recent chats*: **↻**). Click **↻ keeps going** to stop that. |
| A queued task under an account | Starts it now, or cancels it. |
| **⚠ same files** next to a session | Goes to the other chat that changes the same files. |
| Filter button at the top (**Focus**) | Shows only what needs you, the chats that finished a turn you haven't looked at yet and one line for each chat at work; **Show everything** goes back. |
| Microphone in the chat pane (**Dictate**) | Records your reply and writes it into the box (click again to stop); the first time, it offers to set dictation up. |
| Magnifier at the top | Finds a chat by the words in its name, folder or your prompts, and project folders, plans and memories with those words. |
| Server button at the top | Picks the SSH hosts to show. |
| **Log in…** at an account | An account that isn't logged in (a new one, or one you logged out of): a terminal opens with Claude's own login. |

## Settings

Right-click the widget → **Configure Talpy Den…**

| Setting | Default | |
|---|---|---|
| While a chat works, check every | 2000 ms | How often a working chat's line (what it's doing) is brought up to date; greyed out with live mode on, whose steps show as they happen (a working chat is checked every 6 s then) |
| While no chat works, check every | 20000 ms | For what changes while no chat does anything: plan usage and its forecast, a usage limit resetting, a queued task coming due, a Claude that crashed. A chat that starts, ends, starts working, asks for something or finishes its turn shows at once either way |
| Extra config dirs | – | Claude config folders besides `~/.claude` and `~/.claude-*` |
| Chats | click opens the pane | A click on a chat opens it beside the popup (off: in its terminal or VS Code tab) |
| Answer permission prompts from the widget | off | The hook that lets rows, the pane and notifications answer permission prompts and Claude's questions (see [Features](features.md)); changes Claude's settings at once |
| Live mode | off | A hook that notes each step of each chat as it happens (Claude doesn't wait for it), so rows, the pane and the line under the big Talpy follow every tool call; changes Claude's settings at once |
| Notify | both on | When a session needs input, and when it finishes a turn… |
| …if the turn took at least | 30 s | …that ran at least this long |
| While you're away | on, 5 min | Once the screen has been locked this long, one notification sums it all up when you're back |
| Phone | off | Meanwhile, send chats that need you (and, if you like, ones that finish) to your phone with KDE Connect: every paired phone that's reachable, or the one you pick; *Send a test* tries it |
| Sound | on, 70% | Sounds for needs input / finished / failed: from your sound theme, a file, or none |
| Keep finished background jobs | 24 h | 0 hides them right away |
| Recent chats per account | 5 | 0 hides the list |
| Check SSH hosts every | 30 s | |
| Plan usage on SSH hosts | once per account | An account on this computer and a host (or on two hosts) shows its plan usage where it's listed first, with the newest numbers of them all; or on every host, or on none |
| Panel | on | The default account's 5-hour usage next to the icon |
| Keyboard shortcut | goes to the chat | Goes to the chat that needs you (else opens the popup); the key itself is set on the Keyboard Shortcuts page |
| Icon | on | Blink while a chat needs you (until you open the popup), pulse when one finishes |
| Pet | on | Talpy in the popup and in notifications |
| Open plans and runs in | Okular if installed, else your browser | Plans and subagent runs (Markdown): in Okular, your browser (a page the widget makes), VS Code's Markdown preview (with the Talpy Den extension for VS Code 1.13 or newer), or your app for Markdown files |
| Chat pets per account | 5 | 0 keeps only the big Talpy |
| Popup | on | Token totals |
| Monday recap | on | On Mondays, sum up the last 7 days in a notification (it opens the Recap) |
| Dictation language | auto | The language you dictate in (`en`, `de`, `fr`…), or auto to let whisper tell; below it, set up dictation, download, delete or pick a speech model, or remove faster-whisper |
| Recap amounts in | US dollars | The Recap tab's amounts: US dollars (Claude's API prices), or another currency at the European Central Bank's rate of the day |

## Accounts

The **Accounts** page of the settings (on GNOME, the *Accounts* tab of its settings) lists the Claude accounts on this computer, or with **On:** those of an SSH host you picked in the popup: each one's folder, whom it's logged in as (Claude's own `claude auth status` says), whether it's the default, whether plain `claude` or VS Code's Claude runs on it, and its running chats. It works with one account or many, with `~/.claude` as a folder or as a link to one of them, with or without VS Code:

- **Add an account:** a name, e.g. `work`, makes `~/.claude-work` (with a `.profile-name` file holding its name), then opens a terminal with Claude's own login (`claude auth login`): Claude opens your browser, you sign in with the other account, and Claude keeps the login in that folder. The account is in the popup right away, with **Log in…** until you're logged in.
  - **Settings shared with** an account you pick: its `settings.json` (your status line too, so the plan usage bars work at once), `CLAUDE.md`, `keybindings.json`, and your own skills, agents, commands and output styles one by one, are linked into the new folder. A change on one account is a change on both. The links point at the real files, never through `~/.claude` (which may be switched to another account). The login, history, MCP servers, plugins and the skills claude.ai syncs for an account (`skills/synced`) stay per account. Or *Claude's defaults*: a fresh folder.
  - **A `claude-work` command** (on unless you untick it): `~/.local/bin/claude-work` runs Claude on the account in any terminal, in bash, zsh or fish. An existing program of that name is never replaced. Where `~/.claude` links to the account, it runs Claude under that name, as terminals do, since Claude keys its background service by the folder's name.
- **Log in…** for an account that isn't logged in; **Log out…** (asks first) is `claude auth logout`: Claude revokes the login and deletes it, and the account's chats and history stay. Not while chats run on it: they'd lose the login.
- **Remove…** (asks first) logs out, then moves the folder to the Trash, with its chats, history and settings: restore it from there if you change your mind. Its `claude-NAME` command goes too. Only for `~/.claude-NAME` folders that no chat, `~/.claude` (a link to it) or VS Code's Claude uses. Chats shared with your other accounts stay on them.
- **Make Default:** the default account is listed first in the popup (and in the VS Code extension), marked **default** where a machine has two or more accounts, its 5-hour usage goes next to the panel icon, and both VS Code's Claude and plain `claude` run on it. **Make Default** points them there: VS Code's Claude through its `claudeCode.environmentVariables` setting (only that entry of VS Code's settings file changes; its comments and the rest stay), plain `claude` by pointing the `~/.claude` link at the account. Where `~/.claude` is a folder, it's never turned into a link: plain `claude` stays on it, and `claude-NAME` runs the others. A link is only re-pointed, never made (also where there's no `~/.claude`): without `CLAUDE_CONFIG_DIR` set, plain `claude` reads its account settings from `~/.claude.json`, whatever the link says, so a `~/.claude` link of your own needs `export CLAUDE_CONFIG_DIR="$HOME/.claude"` in your shell (profile tools that make the link set it). Without VS Code and a `~/.claude` link there's nothing to switch, and **Make Default** doesn't show. The panel icon's right-click menu has the accounts too, under **Default Account**, to switch without opening the settings. Which account is the default: VS Code's Claude's where VS Code is installed (what the VS Code extension's status bar shows), else plain `claude`'s. When the two differ (say you switched VS Code's Claude by hand), the page says so, and **Make Default** on the default lines plain `claude` up with it.
  - **Not while it would cut a chat off:** a chat working in VS Code's Claude (VS Code's account changes, and its window reloads), or any Claude running through the name `~/.claude` (a chat in a terminal, VS Code or the background, or Claude's background service: pointed elsewhere, it would go on on the other account). Close those, or let them finish, then try again. Chats started on an account's own folder (`claude-work`, the **+** in the popup) aren't affected.
- **On an SSH host** (**On:** at the top), all of this works the same, on the host's own accounts: over ssh, with nothing installed there (`accounts.py` goes over the connection like the status script). Logging in opens a terminal here, where Claude's login runs on the host: open the address it shows in your browser and paste the code you get back. Its default account is the one its VS Code server's Claude uses (that server's settings), else plain `claude`'s there, and it's marked **default** in the host's part of the popup. **Make Default** there changes that server's setting (only that entry; the file's comments stay) and the host's `~/.claude` link, with the same checks, made on the host; removing an account puts it into the host's own Trash.

The widget never sees a login: you sign in on Claude's own pages, and Claude itself writes and deletes it (`.credentials.json` in the account's folder, which the widget never opens). On an SSH host the code you paste goes into that terminal, straight to Claude on the host. A login terminal in VS Code isn't kept or restored by VS Code.

Chats aren't copied between accounts: to move a chat to another account, share it (see [Sharing chats](sharing.md)).

**The icon** shows one number, the most urgent: red for chats that need you, else green for chats that finished since you last opened the popup (turns as long as the "finished" notifications ask for). While a chat works, Talpy glances around; hovering the icon lists every count.

**In the system tray (Plasma):** Talpy Den can sit in the system tray as well as (or instead of) on a panel: right-click the tray's arrow → **Configure System Tray…** → **Entries** → **Talpy Den**. It's off until you switch it on. *Shown when relevant* shows it while a chat runs; clicking it opens the same popup. With two Talpy Den widgets, only one of them (the one running longest) sends notifications and sounds, and they share their settings: a change in one shows in the other within a few seconds, and a new one starts with what the others use.

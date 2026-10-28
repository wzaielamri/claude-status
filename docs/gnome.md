# On GNOME

The same dashboard as a GNOME Shell extension: Talpy in the top bar, the popup with your accounts, sessions, plan usage, SSH hosts, notifications and pets, and its **Recap** tab. It uses the same scripts as the Plasma widget.

**Requirements:** GNOME Shell 49 or 50 (Ubuntu 26.04 LTS has 50), python3, jq (`sudo apt install jq`); zenity for *Choose folder…* (Ubuntu has it).

**Install:** `./install.sh` (it picks GNOME by itself in a GNOME session; `--gnome` to be sure), then log out and back in: GNOME loads new extension code only at login. Settings: the *Settings* entry at the bottom of the popup. Update the same way (`git pull`, `./install.sh`, log out and in); `./install.sh --uninstall` removes it.

**What's different from Plasma:**

- Not on GNOME yet: chats a usage limit stopped (and their **Continue on …** and **Go on at …**), Claude's recaps and permission modes, starting a chat with a task or in the background, queued tasks, finding a chat, starred chats, plans, memories, **⚠ same files**, the chat pane (replying, dictating, answering permission prompts and Claude's questions, the review). Nor are the **Projects** tab, the Focus view (the filter button), changes showing the moment they happen and *Live mode* (GNOME checks every few seconds instead), and in the Recap the Tokens number, the Day view's lane per chat, the share button's picture and the Monday recap. Nor are the share button on an SSH host's chats, **Log in…** for an SSH host that wants a password, and the *Phone* setting.
- Jumping to a session brings its window to the front. Konsole and tmux also switch to the right tab or pane; in Ptyxis and GNOME Terminal the window comes up, but not the tab. New chats open in your default terminal (`xdg-terminal-exec`, else Ptyxis, GNOME Terminal or Console).
- You can't pick the pets up (they do everything else, with the same Talpy as the widget).
- The menu at the bottom of the popup replaces the right-click menu; a middle click on the icon refreshes.
- Working sessions are blue rather than your accent color (Ubuntu's orange would look like "needs you").
- Sounds come from your GNOME sound theme and stay quiet with Do Not Disturb.
- The shortcut to the chat that needs you is **Super+Shift+C** (change it in the settings).
- GNOME turns extensions off while the screen is locked, so nothing notifies then; when you're back after 5 minutes or more, the summary comes as soon as the chats have been checked. After a shorter lock (or with the summary off), the first check notifies what changed meanwhile.

**Tested** in a headless GNOME Shell 50.1 on Ubuntu 26.04 (`tools/gnome/shell.sh`: the popup, jumping, notifications, settings, pets, install and uninstall), not yet on a physical Ubuntu desktop.

**GNOME Shell 43 and 44** (e.g. Debian 12) load extensions the older way. On them `./install.sh` builds a converted copy (`gnome/build.sh --gnome43`, which runs `gnome/gnome43/port43.py`): the same code with GNOME 43's imports, and small stand-ins (`gnome/gnome43/compat43*.js`) for the newer APIs it uses. If an update to the extension uses an API the converter doesn't know yet, the build stops and says which one. Tested in a headless GNOME Shell 43.9 on Debian 12. GNOME Shell 45 to 48 aren't supported.

**Troubleshooting:** messages go to GNOME's log: `journalctl --user -f -o cat /usr/bin/gnome-shell`. If clicking a session doesn't bring it up, check that the extension is enabled (`gnome-extensions info talpy-den@wzaielamri.github.io`): it's the extension that raises windows.

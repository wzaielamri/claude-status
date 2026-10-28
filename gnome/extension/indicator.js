// The panel button and its popup: polls code/talpy_den.py (and the SSH
// hosts you picked, through code/remote.py), sends notifications, and runs
// what you click through code/jump.py. A port of the Plasma widget's
// main.qml, CompactRepresentation.qml and FullRepresentation.qml.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import * as L from './logic.js';
import {Notifier} from './notifier.js';
import {Runner} from './runner.js';
import {Pets} from './ui/pets.js';
import {buildGroupSection, buildHostSection} from './ui/groupSection.js';
import {TalpyIcon} from './ui/talpyIcon.js';
import {buildPermsView} from './ui/permsView.js';
import {buildWeekView} from './ui/weekView.js';
import {box, column, iconButton, label, paragraph, textButton, Tooltips} from './ui/widgets.js';

const USAGE_PAGE = 'https://claude.ai/settings/usage';
const WEEK_REFRESH_S = 600;   // the Recap tab reads again while it's open

export const Indicator = GObject.registerClass(
class TalpyDenIndicator extends PanelMenu.Button {
    // away: {lockedAt, snapshot} when the screen was locked before this
    // (GNOME Shell turns extensions off while it's locked): the summary of
    // what happened meanwhile goes out once the first checks are back
    _init(extension, away = null) {
        super._init(0.5, 'Talpy Den', false);
        this._extension = extension;
        this._settings = extension.getSettings();
        this._notificationSettings = new Gio.Settings({schema_id: 'org.gnome.desktop.notifications'});
        this._soundSettings = new Gio.Settings({schema_id: 'org.gnome.desktop.sound'});
        this._runner = new Runner(GLib.build_filenamev([extension.path, 'code']));
        this.petsDir = GLib.build_filenamev([extension.path, 'pets']);
        this._notifier = new Notifier(this.petsDir);
        this._tracker = new L.Tracker();
        this.tips = new Tooltips();

        this._status = null;          // parsed output of talpy_den.py
        this._errorText = '';
        this._actionError = '';
        this._actionInfo = '';
        this._sshHosts = [];          // ~/.ssh/config's hosts (remote.py --hosts)
        this.remote = {};             // host -> {loading, ok, error, result, updatedAt}
        this._remotePolling = new Set();
        this._polling = false;
        this._timers = {};
        // Popup state kept by row key (rows are rebuilt with new data)
        this.ui = {expandedAgents: {}, expandedAgent: {}, expandedRecent: {}, expandedPeek: {}, expandedStats: {}, stopConfirm: '',
            stopConfirmBusy: false, shareConfirm: null, openMenu: null, tab: 'chats'};
        // The Recap tab's days and what week.py said of them (it runs only
        // while that tab is open: setTab, loadWeek)
        // (span: day, week or all; open: the day or project whose chats are unfolded)
        this.week = {span: 'week', back: 0, account: '', recap: null, error: '', busy: false, copied: '', open: ''};
        // The Permissions tab and what week.py --permissions said (it runs only
        // while that tab is open: setTab, loadPerms)
        // (asking: the rule whose Allow asks first; ruleBusy, ruleMessage: one
        // being written, what it did; rules: suggest rules (the recap-rules
        // setting); revoking: the permission you gave whose Revoke asks first;
        // ruleRevoked: the message is a revoke's; allGranted: all those
        // permissions shown, not the first few)
        // (asking, revoking, ruleBusy: host|id; ruleHost: where the last one was; allGranted: by host)
        this.perms = {data: null, error: '', busy: false, asking: '', ruleBusy: '', ruleMessage: '', ruleHost: '',
            rules: this._settings.get_boolean('recap-rules'), revoking: '', ruleRevoked: false, allGranted: {}};
        this._weekAsked = 0;
        // Turns that ended while the menu was closed (row key -> "done"), for
        // the hotkey; forgotten when the menu opens
        this._unseen = {};
        this._lastHotkey = null;   // {key, at}: where the hotkey went last
        this._digest = null;       // the "while you were away" card, until the popup has shown it
        this._digestSeen = false;
        this._away = away && this._settings.get_boolean('away-digest') ? {...away, heard: new Set()} : null;

        this._buildPanel();
        this._buildMenu();
        this._pets = new Pets(this);

        this._settingsIds = [
            ...['poll-interval', 'idle-poll-interval'].map(key =>
                this._settings.connect(`changed::${key}`, () => this._restartPollTimer())),
            this._settings.connect('changed::remote-poll-seconds', () => this._restartRemoteTimer()),
            this._settings.connect('changed::ssh-hosts', () => this._onHostsChanged()),
            ...['extra-config-dirs', 'keep-done-hours', 'recent-chats', 'show-tokens'].map(key =>
                this._settings.connect(`changed::${key}`, () => this.refreshAll())),
            ...['show-usage-in-panel', 'show-pet', 'chat-pets'].map(key =>
                this._settings.connect(`changed::${key}`, () => this.rerender())),
            this._settings.connect('changed::recap-rules', () => {
                this.perms.rules = this._settings.get_boolean('recap-rules');
                this.rerender();
            }),
            this._settings.connect('changed::recap-currency', () => {
                if (this.menu.isOpen && this.ui.tab === 'week')
                    this.loadWeek();
            }),
        ];
        this._restartPollTimer();
        this._restartRemoteTimer();
        this._loadHosts();
        if (this._away) {
            for (const host of this.shownHosts)
                this.pollHost(host);
            // hosts that don't answer soon are left out
            this._later('awayDigest', 20000, () => this._sendAwayDigest());
        }
    }

    // ---------------------------------------------------------------- data

    get groups() {
        return this._status ? this._status.groups : [];
    }

    get shownHosts() {
        return this._settings.get_strv('ssh-hosts').map(h => h.trim()).filter(h => h.length);
    }

    // Everything on the dashboard: this computer's accounts, then the hosts'
    get allGroups() {
        return this.groups.concat(L.remoteGroups(this.shownHosts, this.remote));
    }

    get now() {
        return this._status ? this._status.generatedAt : Date.now();
    }

    get canShareChats() {
        return this._status !== null && this._status.canShare === true;
    }

    get shareAccounts() {
        return this.groups.filter(g => !!g.shareProfile);
    }

    get petColors() {
        return this._pets.colors;
    }

    get remotePollSeconds() {
        return Math.max(10, this._settings.get_int('remote-poll-seconds'));
    }

    groupOfProfile(profileDir) {
        return this.groups.find(g => g.profileKeys.indexOf(profileDir) >= 0) || null;
    }

    stageFor(groupKey, chats) {
        return this._pets.stageFor(groupKey, chats);
    }

    get _configDirArgs() {
        return this._settings.get_string('extra-config-dirs').split(',').map(d => d.trim())
            .filter(d => d.length).flatMap(d => ['--config-dir', d]);
    }

    get _listArgs() {
        const args = ['--done-hours', String(Math.max(0, this._settings.get_int('keep-done-hours'))),
            '--recent', String(Math.max(0, this._settings.get_int('recent-chats')))];
        if (!this._settings.get_boolean('show-tokens'))
            args.push('--no-tokens');
        return args;
    }

    // ---------------------------------------------------------------- polling

    _restartPollTimer(refreshNow = true) {
        this._clearTimer('poll');
        this._pollMs = this._pollInterval();
        this._timers.poll = GLib.timeout_add(GLib.PRIORITY_DEFAULT, this._pollMs, () => {
            this.refresh();
            return GLib.SOURCE_CONTINUE;
        });
        if (refreshNow)
            this.refresh();
    }

    // Less often while nothing runs and the menu is closed (L.pollInterval)
    _pollInterval() {
        const overall = this._status ? L.overall(this.allGroups) : '';
        return L.pollInterval(this._settings.get_int('poll-interval'), this._settings.get_int('idle-poll-interval'),
            overall, this.menu.isOpen);
    }

    _adjustPollTimer() {
        if (this._pollInterval() !== this._pollMs)
            this._restartPollTimer(false);
    }

    _restartRemoteTimer() {
        this._clearTimer('remote');
        this._timers.remote = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, this.remotePollSeconds, () => {
            for (const host of this.shownHosts)
                this.pollHost(host);
            return GLib.SOURCE_CONTINUE;
        });
    }

    _clearTimer(name) {
        if (this._timers[name]) {
            GLib.source_remove(this._timers[name]);
            delete this._timers[name];
        }
    }

    _later(name, ms, callback) {
        this._clearTimer(name);
        this._timers[name] = GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
            delete this._timers[name];
            callback();
            return GLib.SOURCE_REMOVE;
        });
    }

    refreshAll() {
        this.refresh();
        for (const host of this.shownHosts)
            this.pollHost(host);
    }

    async refresh() {
        // A still-running poll is still coming: don't stack another
        if (this._polling)
            return;
        this._polling = true;
        // (poll.py runs talpy_den.py with its compiled code cached)
        const out = await this._runner.run('poll.py', [...this._configDirArgs, ...this._listArgs], {poll: true});
        this._polling = false;
        if (this._destroyed || out.cancelled)
            return;
        const result = L.statusResult(out.stdout, out.stderr);
        if (result.error) {
            this._errorText = result.error;
        } else {
            // The new status first: a reaction that fails mustn't keep the
            // popup on old data (on Plasma one froze it at a limit reset)
            this._errorText = result.errorText;
            this._status = result.status;
            try {
                this._track('', result.status.groups, result.status.generatedAt, '');
            } catch (e) {
                console.error(`Talpy Den: following the chats failed: ${e.message}\n${e.stack}`);
            }
        }
        this._render();
        this._adjustPollTimer();
    }

    // Notifications, pet reactions and the sound when sessions change state.
    // Each is on its own: one that fails doesn't stop the others.
    _track(source, groups, nowMs, host) {
        const out = this._tracker.track(source, groups, nowMs, host, {
            notifyWaiting: this._settings.get_boolean('notify-waiting'),
            notifyDone: this._settings.get_boolean('notify-done'),
            notifyDoneMinSeconds: this._settings.get_int('notify-done-min-seconds'),
        });
        const resets = this._tracker.celebrateResets(source, groups);
        const pose = this._settings.get_boolean('show-pet');
        this._noteUnseen(source, out);
        if (this._away) {
            this._away.heard.add(source);
            if (['', ...this.shownHosts.map(h => `ssh:${h}`)].every(s => this._away.heard.has(s)))
                this._sendAwayDigest();
        }
        const guard = (what, fn) => {
            try {
                fn();
            } catch (e) {
                console.error(`Talpy Den: ${what} failed: ${e.message}\n${e.stack}`);
            }
        };
        for (const c of out.close)
            guard('closing a notification', () => this._notifier.close(c.key, c.kind));
        for (const n of out.notify)
            guard('a notification', () => this._notifier.notify(n, pose, () => this._openFromNotification(n)));
        guard('closing notifications', () => this._notifier.closeMissing(source, out.present));
        for (const event of [...out.pets, ...resets])
            guard(`the pets' "${event.kind}"`, () => this._pets.event(event));
        if (out.sound)
            guard('a sound', () => this._playSound(out.sound));
    }

    // Turns that ended while you weren't looking (as long as the "finished"
    // notifications ask for), for the hotkey
    _noteUnseen(source, out) {
        const min = this._settings.get_int('notify-done-min-seconds') * 1000;
        for (const f of out.finished) {
            if (f.stop)
                delete this._unseen[f.key];   // (a limit stopped it: nothing to look at)
            else if (!this.menu.isOpen && f.took >= min)
                this._unseen[f.key] = 'done';
        }
        for (const key of Object.keys(this._unseen)) {
            if (L.keyOfSource(key, source) && (!out.present.has(key) || out.states[key] === 'working'))
                delete this._unseen[key];
        }
    }

    // ---------------------------------------------------------------- the hotkey and coming back

    // The hotkey (next-chat-shortcut): the chat that needs you (waiting the
    // longest, then a finished turn you haven't seen); pressed again soon
    // after, the next one; with none, the menu opens or closes
    goToNextChat() {
        const list = L.chatsNeedingYou(this.allGroups, this._unseen);
        const now = Date.now();
        const i = L.nextChatIndex(list, this._lastHotkey, now);
        if (i < 0) {
            this._lastHotkey = null;
            this.menu.toggle();
            return;
        }
        const c = list[i];
        this._lastHotkey = {key: c.key, at: now};
        if (this._unseen[c.key])
            delete this._unseen[c.key];
        this._openChat(c);
    }

    dismissDigest() {
        this._digest = null;
        this._notifier.close('away-digest', this._notifier.kindOf('away-digest'));
        this.rerender();
    }

    _buildDigestCard() {
        const d = this._digest;
        const card = column('claude-digest', {x_expand: true});
        const head = box('claude-line', {x_expand: true});
        head.add_child(label(d.title, 'claude-strong', {x_expand: true}));
        head.add_child(this.tips.add(iconButton('window-close-symbolic', () => this.dismissDigest()), 'Dismiss'));
        card.add_child(head);
        card.add_child(paragraph(d.body, 'claude-small'));
        if (d.first) {
            card.add_child(textButton('Open the chat that needs you', () => {
                this.dismissDigest();
                this._openChat(d.first);
            }, 'claude-text-button claude-confirm-button'));
        }
        return card;
    }

    _openChat(c) {
        if (c.host)
            this.remoteShow(c.host, c.session);
        else
            this.jumpTo(c.session.sessionId, c.session.profileDir);
    }

    // What happened while the screen was locked: a card at the top of the
    // popup until you've seen it, and (with notifications on) one
    // notification, instead of the ones that would have piled up (none were
    // sent meanwhile)
    _sendAwayDigest() {
        const away = this._away;
        this._away = null;
        this._clearTimer('awayDigest');
        if (!away || !this._status || this._destroyed)
            return;
        let digest = null;
        try {
            digest = L.awayDigest(away, this.allGroups, Date.now(), this._settings.get_int('away-minutes'));
        } catch (e) {
            console.error(`Talpy Den: the away summary failed: ${e.message}\n${e.stack}`);
        }
        if (!digest)
            return;
        this._digest = digest;
        this._digestSeen = false;
        this.rerender();
        if (!this._settings.get_boolean('notify-waiting') && !this._settings.get_boolean('notify-done'))
            return;
        const first = digest.first;
        // its own kind: closeMissing() closes 'waiting' notifications of chats that are gone
        this._notifier.notify({key: 'away-digest', kind: 'digest', waiting: !!first, title: digest.title,
            body: digest.body, icon: first ? 'dialog-warning-symbolic' : 'emblem-ok-symbolic', session: null,
            action: first ? 'Open the chat that needs you' : 'Show chats'},
        this._settings.get_boolean('show-pet'), () => (first ? this._openChat(first) : this.menu.open()));
    }

    _openFromNotification(n) {
        if (n.host)
            this.remoteShow(n.host, n.session);
        else
            this.jumpTo(n.session.sessionId, n.session.profileDir);
    }

    // One sound per poll at most: the most urgent. Quiet during Do Not Disturb.
    _playSound(kind) {
        if (!this._settings.get_boolean('notify-sound') || !this._notificationSettings.get_boolean('show-banners'))
            return;
        const sound = this._settings.get_string(
            kind === 'waiting' ? 'sound-waiting' : kind === 'failed' ? 'sound-failed' : 'sound-done');
        if (!sound)
            return;
        this._runner.run('notify_sound.py', [sound, '--volume', String(this._settings.get_int('sound-volume')),
            '--theme', this._soundSettings.get_string('theme-name')]);
    }

    // ---------------------------------------------------------------- actions

    async _helper(script, args) {
        const out = await this._runner.run(script, args);
        return L.helperResult(out.stdout, out.stderr);
    }

    _showError(text) {
        this._actionError = text;
        this._later('actionError', 10000, () => {
            this._actionError = '';
            this.rerender();
        });
        this.rerender();
    }

    _showInfo(text) {
        this._actionInfo = text;
        this._later('actionInfo', 12000, () => {
            this._actionInfo = '';
            this.rerender();
        });
        this.rerender();
    }

    _oops() {
        this._pets.event({kind: 'oops', text: "Hmm, that didn't work.", key: ''});
    }

    // A jump's answer: done (close the popup), or say what went wrong
    _jumped(result) {
        if (this._destroyed)
            return;
        if (result.ok) {
            this._actionError = '';
            this.menu.close();
            return;
        }
        this._showError(L.fmt("Couldn't open the session: %1", result.message));
        this._oops();
        if (!this.menu.isOpen) {
            this._notifier.notify({key: 'jump-error', kind: 'error', title: "Couldn't open the session",
                body: result.message, icon: 'dialog-error-symbolic', session: null},
            this._settings.get_boolean('show-pet'), null);
        }
    }

    // profileDir picks the right copy of a chat shared across profiles
    async jumpTo(sessionId, profileDir) {
        const profile = profileDir ? ['--profile', profileDir] : [];
        this._jumped(await this._helper('jump.py', [sessionId, ...profile, ...this._configDirArgs]));
    }

    // busy: you were told it's working or waiting (else only an idle one is stopped)
    async stopSession(sessionId, profileDir, busy = false) {
        const profile = profileDir ? ['--profile', profileDir] : [];
        const result = await this._helper('jump.py',
            ['--stop', sessionId, ...profile, ...busy ? ['--busy'] : [], ...this._configDirArgs]);
        if (this._destroyed)
            return;   // turned off meanwhile (e.g. the screen locked)
        if (!result.ok)
            this._showError(L.fmt("Couldn't stop the session: %1", result.message));
        this.refresh();
    }

    // Esc in the tmux pane of a working chat
    async interruptSession(sessionId, profileDir) {
        const profile = profileDir ? ['--profile', profileDir] : [];
        const result = await this._helper('jump.py', ['--interrupt', sessionId, ...profile, ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (!result.ok)
            this._showError(L.fmt("Couldn't interrupt the session: %1", result.message));
        this.refresh();
    }

    // Small helper actions whose only effect is on the widget's own list
    async runHelper(args) {
        const result = await this._helper('jump.py', [...args, ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (!result.ok)
            this._showError(result.message);
        this.refresh();
    }

    dismissSession(sessionId) {
        this.runHelper(['--dismiss', sessionId]);
    }

    // vscode: in VS Code's Claude extension instead of a terminal
    async newChat(profile, folder, vscode = false) {
        this.ui.openMenu = null;
        const cwd = folder ? ['--cwd', folder] : [];
        this._newChatDone(await this._helper('jump.py',
            ['--new-chat', profile, ...cwd, ...vscode ? ['--vscode'] : [], ...this._configDirArgs]));
    }

    // The folder dialog takes over from the popup; cancelling it does nothing
    async newChatChoosingFolder(profile, vscode = false) {
        this.ui.openMenu = null;
        this.menu.close();
        this._newChatDone(await this._helper('jump.py',
            ['--new-chat', profile, '--choose-folder', ...vscode ? ['--vscode'] : [], ...this._configDirArgs]));
    }

    // VS Code connected to an SSH host, with a new chat (in folder there, or home)
    async remoteNewChatVscode(host, folder) {
        this.ui.openMenu = null;
        const cwd = folder ? ['--cwd', folder] : [];
        this._newChatDone(await this._helper('jump.py', ['--remote-new-vscode', host, ...cwd]));
    }

    // Claude's own login for an account that isn't logged in, in a terminal
    // (accounts.py --login; an SSH host's account: its loginCommand over ssh)
    async logIn(group, host) {
        if (host) {
            this.remoteOpen(host, group.loginCommand);
            return;
        }
        const result = await this._helper('accounts.py', ['--login', group.chatProfile, ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (result.ok)
            this.menu.close();
        else
            this._showError(L.fmt("Couldn't log in: %1", result.message));
    }

    // A recent chat, reopened in VS Code's Claude extension (in its folder)
    async resumeInVscode(sessionId, profileDir) {
        const profile = profileDir ? ['--profile', profileDir] : [];
        this._jumped(await this._helper('jump.py', ['--resume', sessionId, ...profile, '--vscode', ...this._configDirArgs]));
    }

    // A recent chat of an SSH host, reopened in VS Code connected to it
    async remoteResumeVscode(host, sessionId, folder) {
        const cwd = folder ? ['--cwd', folder] : [];
        this._jumped(await this._helper('jump.py', ['--remote-resume-vscode', host, sessionId, ...cwd]));
    }

    // VS Code is here (only the account it runs on can use it)
    get vscodeInstalled() {
        return this._status?.vscode?.installed === true;
    }

    // There's a claude command here (host: on that SSH host)
    cliHere(host) {
        return L.cliInstalled(host ? this.remote[host]?.result : this._status);
    }

    // Where this account's chats open (logic.js openInVscode)
    openInVscode(group, host) {
        return L.openInVscode(group, this.vscodeInstalled, this.cliHere(host), this.newChatInVscode);
    }

    // Where chats open, new and recent: the Terminal | VS Code switch
    get newChatInVscode() {
        return this._settings.get_boolean('new-chat-in-vscode');
    }

    setNewChatInVscode(on) {
        this._settings.set_boolean('new-chat-in-vscode', on);
        this.rerender();
    }

    _newChatDone(result) {
        if (this._destroyed)
            return;
        if (result.ok) {
            this._actionError = '';
            this.menu.close();
        } else {
            this._showError(L.fmt("Couldn't open a new chat: %1", result.message));
        }
    }

    // ---------------------------------------------------------------- popup state

    rerender() {
        this._render(true);
    }

    togglePeek(rowKey) {
        this.ui.expandedPeek[rowKey] = !this.ui.expandedPeek[rowKey];
        this.rerender();
    }

    // The files a chat changed, before ↔ now (turn: since your last prompt),
    // side by side in VS Code (jump.py --changes)
    async showChanges(chatId, profileDir, turn = false) {
        const profile = profileDir ? ['--profile', profileDir] : [];
        const result = await this._helper('jump.py',
            ['--changes', chatId, ...profile, ...turn ? ['--turn'] : [], ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (result.ok) {
            this._actionError = '';
            this.menu.close();
        } else {
            this._showError(L.fmt("Couldn't compare the changes: %1", result.message));
        }
    }

    toggleAgents(rowKey) {
        this.ui.expandedAgents[rowKey] = !this.ui.expandedAgents[rowKey];
        this.rerender();
    }

    // One subagent unfolded: its task, last steps and report (key: L.agentKey)
    toggleAgent(key) {
        this.ui.expandedAgent[key] = !this.ui.expandedAgent[key];
        this.rerender();
    }

    // A subagent's whole run, saved as Markdown and opened in your app for
    // those (jump.py --agent-run; remote.py fetches it from an SSH host)
    async openAgentRun(session, agent, remoteHost = '') {
        const {script, args} = L.agentRunCommand(session, agent, remoteHost);
        const result = await this._helper(script, remoteHost ? args : [...args, ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (result.ok) {
            this._actionError = '';
            this.menu.close();
        } else {
            this._showError(L.fmt("Couldn't open the subagent's run: %1", result.message));
            this._oops();
        }
    }

    toggleStats(groupKey) {
        this.ui.expandedStats[groupKey] = !this.ui.expandedStats[groupKey];
        this.rerender();
    }

    toggleRecent(groupKey, wasOpen) {
        this.ui.expandedRecent[groupKey] = !wasOpen;
        this.rerender();
    }

    // busy: the chat wasn't idle when you were asked (stop it anyway)
    setStopConfirm(rowKey, busy = false) {
        this.ui.stopConfirm = rowKey;
        this.ui.stopConfirmBusy = busy;
        this.rerender();
    }

    _toggleMenu(type, key, extra = {}) {
        const open = this.ui.openMenu;
        this.ui.openMenu = open && open.type === type && open.key === key ? null : {type, key, ...extra};
        this.rerender();
    }

    toggleNewChat(groupKey) {
        this._toggleMenu('newchat', groupKey);
    }

    toggleShareMenu(rowKey, chat) {
        this._toggleMenu('share', rowKey, {chat});
    }

    // ---------------------------------------------------------------- SSH hosts

    async _loadHosts() {
        const result = await this._helper('remote.py', ['--hosts']);
        if (!this._destroyed && result.ok) {
            this._sshHosts = result.hosts;
            this._render();
        }
    }

    toggleHost(host) {
        const list = this.shownHosts;
        const i = list.indexOf(host);
        if (i >= 0)
            list.splice(i, 1);
        else
            list.push(host);
        this._settings.set_strv('ssh-hosts', list);
    }

    _onHostsChanged() {
        const next = {};
        for (const host of Object.keys(this.remote)) {
            if (!this.shownHosts.includes(host))
                this._forgetSource(`ssh:${host}`);   // shown again later, it starts afresh
        }
        for (const host of this.shownHosts) {
            if (host in this.remote)
                next[host] = this.remote[host];
            else
                GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {   // just picked: load it now
                    if (!this._destroyed)
                        this.pollHost(host);
                    return GLib.SOURCE_REMOVE;
                });
        }
        this.remote = next;
        this.rerender();
    }

    async pollHost(host) {
        if (this._remotePolling.has(host))
            return;   // still waiting for the last answer
        this._remotePolling.add(host);
        this._setRemote(host, {loading: true});
        const out = await this._runner.run('remote.py', ['--status', host, ...this._listArgs], {poll: true});
        this._remotePolling.delete(host);
        if (this._destroyed || out.cancelled || !this.shownHosts.includes(host))
            return;   // unpicked while its check was running
        const answer = L.helperResult(out.stdout, out.stderr);
        if (answer.ok && answer.result) {
            // on this computer's clock: the host's may be off
            const result = L.toLocalClock(answer.result, Date.now() - (answer.result.generatedAt || Date.now()));
            this._setRemote(host, {loading: false, ok: true, error: '', result, updatedAt: Date.now()});
            try {
                this._track(`ssh:${host}`, result.groups, result.generatedAt, host);
            } catch (e) {
                console.error(`Talpy Den: following ${host}'s chats failed: ${e.message}\n${e.stack}`);
            }
        } else {
            // keep the last answer to show (dimmed) with the error
            this._setRemote(host, {loading: false, ok: false, error: answer.error || answer.message || 'no answer'});
        }
    }

    // What a source's chats were (and their notifications): gone with the source
    _forgetSource(source) {
        this._tracker.forget(source);
        this._notifier.closeSource(source);
        for (const key of Object.keys(this._unseen)) {
            if (L.keyOfSource(key, source))
                delete this._unseen[key];
        }
    }

    _setRemote(host, patch) {
        if (!this.shownHosts.includes(host))
            return;
        const old = this.remote[host] || {loading: false, ok: false, error: '', result: null, updatedAt: 0};
        this.remote = Object.assign({}, this.remote, {[host]: Object.assign({}, old, patch)});
        this._render();
    }

    async _remoteAction(kind, host, args) {
        const result = await this._helper('remote.py', args);
        if (this._destroyed)
            return;
        if (result.ok) {
            this._actionError = '';
            if (kind === 'open')
                this.menu.close();
        } else {
            this._showError(kind === 'open' ? L.fmt("Couldn't open the session: %1", result.message)
                : kind === 'stop' ? L.fmt("Couldn't stop the session: %1", result.message) : result.message);
            this._oops();
            if (!this.menu.isOpen) {   // e.g. from a notification or the hotkey: say so
                this._notifier.notify({key: 'remote-error', kind: 'error', title: L.fmt("That didn't work on %1", host),
                    body: this._actionError, icon: 'dialog-error-symbolic', session: null},
                this._settings.get_boolean('show-pet'), null);
            }
        }
        if (kind !== 'open')
            this.pollHost(host);
    }

    // Bring up a session of an SSH host: background sessions and finished
    // chats open in a terminal (ssh); one running there shows where it runs
    // here (its VS Code window, the terminal of one, or the terminal with the
    // ssh connection)
    async remoteShow(host, session) {
        const cwd = session.cwd ? ['--cwd', session.cwd] : [];
        if (session.openCommand) {
            this.remoteOpen(host, session.openCommand);
        } else if (session.entrypoint === 'claude-vscode') {
            this._jumped(await this._helper('jump.py', ['--remote-vscode', host, session.sessionId, ...cwd]));
        } else {
            const vscode = session.vscodeTerminal ? ['--vscode-terminal', String(Math.trunc(session.vscodeTerminal)), ...cwd] : [];
            this._jumped(await this._helper('jump.py', ['--remote-terminal', host, '--name', session.name || '', ...vscode]));
        }
    }

    remoteOpen(host, command) {
        this.ui.openMenu = null;
        if (!command) {
            this._showError(L.fmt("This session runs in a terminal on %1; the widget can't bring it here.", host));
            return;
        }
        this._remoteAction('open', host, ['--open', host, command]);
    }

    remoteStop(host, command) {
        this._remoteAction('stop', host, ['--run', host, command]);
    }

    // A chat with a process on the host (talpy_den.py --end there; busy:
    // you were told it's working or waiting), or one in tmux interrupted
    remoteEnd(host, sessionId, profileDir, busy = false) {
        this._remoteAction('stop', host, ['--end', host, sessionId, ...profileDir ? [profileDir] : [], ...busy ? ['--busy'] : []]);
    }

    remoteInterrupt(host, sessionId, profileDir) {
        this._remoteAction('stop', host, ['--interrupt', host, sessionId, ...profileDir ? [profileDir] : []]);
    }

    remoteDismiss(host, sessionId) {
        this._remoteAction('dismiss', host, ['--dismiss', host, sessionId]);
    }

    remoteUndismissAll(host) {
        this._remoteAction('dismiss', host, ['--undismiss-all', host]);
    }

    // ---------------------------------------------------------------- shared chats
    // Share a chat with your other accounts, continue it on one of them, or
    // keep it on one only: jump.py does it (sharing.py).

    askKeepOnly(rowKey, chat, account) {
        this.ui.openMenu = null;
        this.ui.shareConfirm = {
            key: rowKey, chatId: chat.chatId, name: chat.name, profileKey: account.shareProfile,
            account: account.title,
            others: this.shareAccounts.filter(g => g !== account).map(g => g.title).join(', '),
        };
        this.rerender();
    }

    confirmKeepOnly() {
        const c = this.ui.shareConfirm;
        this.ui.shareConfirm = null;
        this.shareAction('keeponly', c.chatId, c.profileKey);
    }

    cancelKeepOnly() {
        this.ui.shareConfirm = null;
        this.rerender();
    }

    async shareAction(kind, chatId, profileKey) {
        this.ui.openMenu = null;
        this.rerender();
        const flag = {continue: '--continue', share: '--share', keeponly: '--unshare'}[kind];
        const profile = profileKey ? ['--profile', profileKey] : [];
        const result = await this._helper('jump.py', [flag, chatId, ...profile, ...this._configDirArgs]);
        if (this._destroyed)
            return;
        if (!result.ok) {
            this._showError(result.message);
            this._oops();
        } else if (kind === 'continue') {
            this._actionError = '';
            this.menu.close();
        } else {
            this._actionError = '';
            this._showInfo(result.message);
        }
        this.refresh();
    }

    // ---------------------------------------------------------------- panel

    _buildPanel() {
        const panelBox = box('panel-status-indicators-box claude-panel');
        const iconBin = new St.Widget({layout_manager: new Clutter.BinLayout(), y_align: Clutter.ActorAlign.CENTER});
        this._spark = new TalpyIcon('claude-spark');
        // the count of chats that need you, on the spark's corner
        this._badge = new St.Label({style_class: 'claude-badge', visible: false,
            x_align: Clutter.ActorAlign.END, y_align: Clutter.ActorAlign.START,
            translation_x: 6, translation_y: -4});
        iconBin.add_child(this._spark);
        iconBin.add_child(this._badge);
        this._usage = new St.Label({style_class: 'claude-panel-usage', y_align: Clutter.ActorAlign.CENTER, visible: false});
        panelBox.add_child(iconBin);
        panelBox.add_child(this._usage);
        this.add_child(panelBox);
    }

    // Middle-click refreshes; any other click opens the popup
    vfunc_event(event) {
        if (event.type() === Clutter.EventType.BUTTON_PRESS && event.get_button() === Clutter.BUTTON_MIDDLE) {
            this.refreshAll();
            return Clutter.EVENT_STOP;
        }
        return super.vfunc_event(event);
    }

    _updatePanel() {
        const groups = this.allGroups;
        const c = L.counts(groups);
        const overall = L.overall(groups, c);
        this._spark.setState(L.stateClass(overall), overall);
        this._badge.text = String(c.waiting);
        this._badge.visible = c.waiting > 0;
        const w = this._settings.get_boolean('show-usage-in-panel') ? L.panelWindow(groups) : null;
        this._usage.visible = w !== null;
        if (w) {
            this._usage.text = `${Math.round(w.pct)}%`;
            if (w.pct >= 90)
                this._usage.add_style_class_name('claude-fg-bad');
            else
                this._usage.remove_style_class_name('claude-fg-bad');
        }
    }

    // ---------------------------------------------------------------- popup

    _buildMenu() {
        this.menu.box.add_style_class_name('claude-menu');
        const popup = column('claude-popup', {x_expand: true});
        this.menu.box.add_child(popup);

        // Header: the tabs, the summary, SSH hosts, refresh
        const header = box('claude-header', {x_expand: true});
        this._headerSpark = new TalpyIcon('claude-spark claude-spark-small');
        this._headerSpark.setMoving(false);   // (moves while the popup shows)
        header.add_child(this._headerSpark);
        // (the title and the tabs keep their whole names: the summary gives way)
        const whole = actor => {
            actor.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
            return actor;
        };
        // The app's name is the first tab: your chats now. The others: your last
        // 7 days with Claude (ui/weekView.js), the permissions you gave (ui/permsView.js)
        this._tabs = {};
        for (const [tab, text] of [['chats', 'Talpy Den'], ['week', 'Recap'], ['perms', 'Permissions']]) {
            const b = new St.Button({style_class: 'claude-tab', can_focus: true, child: whole(new St.Label({text})),
                y_align: Clutter.ActorAlign.CENTER});
            b.connect('clicked', () => this.setTab(tab));
            this._tabs[tab] = b;
            header.add_child(b);
        }
        this._summary = label('', 'claude-summary', {x_expand: true, x_align: Clutter.ActorAlign.END});
        header.add_child(this._summary);
        const hostsContent = box('claude-button-box');
        hostsContent.add_child(new St.Icon({icon_name: 'network-server-symbolic', style_class: 'claude-button-icon'}));
        this._hostsCount = label('', '');
        hostsContent.add_child(this._hostsCount);
        const hostsButton = new St.Button({style_class: 'claude-icon-button', can_focus: true, child: hostsContent});
        hostsButton.connect('clicked', () => {
            this._loadHosts();   // in case ~/.ssh/config changed
            this._toggleMenu('hosts', '');
        });
        this.tips.add(hostsButton, () => ['SSH hosts', this.shownHosts.length > 0
            ? L.fmt('Showing Claude on %1. Click to pick hosts from ~/.ssh/config.', this.shownHosts.join(', '))
            : 'Show Claude sessions of your SSH hosts (from ~/.ssh/config) here too.']);
        header.add_child(hostsButton);
        header.add_child(this.tips.add(iconButton('view-refresh-symbolic', () => {
            this.refreshAll();
            this._loadTab();
        }), 'Refresh'));
        popup.add_child(header);

        // The big Talpy (pets.js) stays put while the list scrolls
        this._heroBin = new St.Bin({x_expand: true});
        popup.add_child(this._heroBin);

        this._messages = column('claude-messages', {x_expand: true});
        popup.add_child(this._messages);
        this._hostsPicker = new St.Bin({x_expand: true});
        popup.add_child(this._hostsPicker);

        this._scroll = new St.ScrollView({
            style_class: 'claude-scroll', x_expand: true,
            hscrollbar_policy: St.PolicyType.NEVER, vscrollbar_policy: St.PolicyType.AUTOMATIC,
        });
        this._list = column('claude-list', {x_expand: true});
        this._scroll.set_child(this._list);
        popup.add_child(this._scroll);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._undismissItem = this.menu.addAction('Show removed sessions again',
            () => this.runHelper(['--undismiss-all']), 'view-reveal-symbolic');
        this.menu.addAction('Open usage page on claude.ai', () => {
            Gio.AppInfo.launch_default_for_uri(USAGE_PAGE, global.create_app_launch_context(0, -1));
        }, 'web-browser-symbolic');
        this.menu.addAction('Settings', () => this._extension.openPreferences(), 'emblem-system-symbolic');

        this.menu.connect('open-state-changed', (menu, open) => {
            if (open) {
                this._unseen = {};   // seen now
                const area = Main.layoutManager.getWorkAreaForMonitor(Main.layoutManager.primaryIndex);
                this._scroll.style = `max-height: ${Math.round(area.height * 0.62)}px;`;
                this._loadHosts();
                this.rerender();
                this.refresh();  // it may have been checked a while ago (see _pollInterval)
                this._loadTab();
            } else {
                this.tips.hide();
                if (this._digestSeen)
                    this._digest = null;   // you've seen it
                this.ui.openMenu = null;
                this.ui.stopConfirm = '';
            }
            this._headerSpark.setMoving(open);
            this._pets.setActive(open && this.ui.tab === 'chats');
            this._weekTimer();
            this._adjustPollTimer();
        });
    }

    // ---------------------------------------------------------------- the week

    setTab(tab) {
        if (this.ui.tab === tab)
            return;
        this.ui.tab = tab;
        this._pets.setActive(this.menu.isOpen && tab === 'chats');   // (not drawn while another tab shows)
        this._weekTimer();
        this._loadTab();
        this._render(true);
    }

    // What the Recap or Permissions tab shows, read again
    _loadTab() {
        if (this.ui.tab === 'week')
            this.loadWeek();
        else if (this.ui.tab === 'perms')
            this.loadPerms();
    }

    setWeek({back = this.week.back, account = this.week.account, span = this.week.span}) {
        if (span !== this.week.span)
            back = 0;   // (a new span starts at today's)
        this.week.span = span;
        this.week.back = Math.max(0, back);
        this.week.account = account;
        this.loadWeek();
        this._render(true);
    }

    // Asks week.py for the days shown: it reads only what the chats'
    // transcripts added since it last ran
    async loadWeek() {
        const asked = ++this._weekAsked;
        const {back, account, span} = this.week;
        this.week.busy = true;
        this._render(true);
        const out = await this._runner.run('week.py',
            L.weekArgs(back, account, this.shownHosts, this.remote, this._configDirArgs, this._settings.get_string('recap-currency'), span),
            {poll: true});
        if (this._destroyed || out.cancelled || asked !== this._weekAsked)
            return;   // (other days were asked for since)
        const result = L.helperResult(out.stdout, out.stderr);
        this.week.busy = false;
        if (result.ok) {
            this.week.recap = result;
            this.week.error = '';
        } else {
            this.week.error = result.message || result.error || 'no answer';
        }
        this._render(true);
    }

    // Every 10 minutes while the popup shows the Recap or Permissions tab
    _weekTimer() {
        this._clearTimer('week');
        if (!this.menu.isOpen || this.ui.tab === 'chats')
            return;
        this._timers.week = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, WEEK_REFRESH_S, () => {
            this._loadTab();
            return GLib.SOURCE_CONTINUE;
        });
    }

    // Unfolds a day's or a project's chats (or folds them)
    weekUnfold(key) {
        this.week.open = this.week.open === key ? '' : key;
        this._render(true);
    }

    // ---------------------------------------------------------------- permissions

    // Asks week.py --permissions for the permissions you gave and the
    // prompts of the last 7 days
    async loadPerms() {
        if (this.perms.busy)
            return;
        this.perms.busy = true;
        this._render(true);
        const out = await this._runner.run('week.py', L.permsArgs(this._configDirArgs, this.shownHosts, this.remote), {poll: true});
        if (this._destroyed || out.cancelled)
            return;
        const result = L.helperResult(out.stdout, out.stderr);
        this.perms.busy = false;
        if (result.ok) {
            this.perms.data = result;
            this.perms.error = '';
        } else {
            this.perms.error = result.message || result.error || 'no answer';
        }
        this._render(true);
    }

    permsAsk(id) {
        this.perms.asking = id;
        this._render(true);
    }

    // Allows a rule the tab offers for the permission prompts you answered
    // (into the chats' folder's .claude/settings.local.json), or takes one it
    // added back; then reads them again
    async changeRule(rule, allow, host = '') {
        this.perms.asking = '';
        this.perms.ruleBusy = L.permsKey(host, rule.id);
        this.perms.ruleHost = host;
        this.perms.ruleMessage = '';
        this.perms.ruleRevoked = false;
        this._render(true);
        const result = await this._helper('week.py', L.weekRuleArgs(rule, allow, host));
        if (this._destroyed)
            return;
        this.perms.ruleBusy = '';
        this.perms.ruleMessage = result.ok ? result.message || '' : L.fmt('Nothing changed: %1', result.message || 'no answer');
        this.loadPerms();
    }

    permsRevokeAsk(id) {
        this.perms.revoking = id;
        this._render(true);
    }

    permsShowAllGranted(host = '') {
        this.perms.allGranted = {...this.perms.allGranted, [host]: true};
        this._render(true);
    }

    // Takes one of the permissions you gave (what lets chats go without
    // asking) out of its file; then reads them again
    async revokeGrant(grant, host = '') {
        this.perms.revoking = '';
        this.perms.ruleBusy = L.permsKey(host, grant.id);
        this.perms.ruleHost = host;
        this.perms.ruleMessage = '';
        this.perms.ruleRevoked = true;
        this._render(true);
        const result = await this._helper('week.py', L.weekRevokeArgs(grant, this._configDirArgs, host));
        if (this._destroyed)
            return;
        this.perms.ruleBusy = '';
        this.perms.ruleMessage = result.ok ? result.message || '' : L.fmt('Nothing changed: %1', result.message || 'no answer');
        this.loadPerms();
    }

    copyText(text) {
        St.Clipboard.get_default().set_text(St.ClipboardType.CLIPBOARD, text);
        this.week.copied = text;
        this._render(true);
        this._later('copied', 2000, () => {
            this.week.copied = '';
            this._render(true);
        });
    }

    // Rebuilds the popup's contents when what they show has changed (and
    // always when asked to: something was clicked)
    _render(force = false) {
        if (this._destroyed)
            return;
        this._updatePanel();
        this._pets.update();
        if (!this.menu.isOpen)
            return;
        const remote = Object.fromEntries(Object.entries(this.remote).map(([host, r]) =>
            [host, {...r, result: r.result ? {...r.result, generatedAt: 0} : null, updatedAt: Math.floor(r.updatedAt / 60000)}]));
        // A forecast moves a little with every check (fullAt in ms): only
        // what the bar shows (its warning, whole percents) rebuilds the popup
        const now = this.now;
        // and so do the stats: an account's (what its box draws) and a chat's (its recap line)
        const coarse = function (key, value) {
            if (key === 'forecast' && value)
                return [L.forecastWarning(this, now), Math.round(value.evenPct), Math.round(Math.min(100, value.atReset))];
            if (key === 'stats' && value)
                return Array.isArray(value.days) ? L.statsSignature(value) : L.chatRecapText(value);
            return value;
        };
        const signature = JSON.stringify([this._status ? {...this._status, generatedAt: 0} : null, this._errorText,
            remote, this._sshHosts, this.ui, this._actionError, this._actionInfo, Math.floor(this.now / 60000),
            this.ui.tab === 'week' ? [this.week.span, this.week.back, this.week.account, this.week.busy, this.week.error, this.week.copied,
                this.week.open, this.week.recap ? this.week.recap.generatedAt : 0] : null,
            this.ui.tab === 'perms' ? {...this.perms, data: this.perms.data ? this.perms.data.generatedAt : 0} : null,
            this._digest ? this._digest.body : null,
            this.petColors, this._settings.get_boolean('show-pet')], coarse);
        if (!force && signature === this._signature)
            return;
        this._signature = signature;
        this.tips.hide();

        const c = L.counts(this.allGroups);
        const overall = L.overall(this.allGroups, c);
        this._headerSpark.setState(L.stateClass(overall), overall);
        const chats = this.ui.tab === 'chats';
        for (const [tab, b] of Object.entries(this._tabs))
            b.checked = tab === this.ui.tab;   // (St.Button's :checked)
        this._heroBin.visible = chats;
        this._summary.text = this._pets.heroShown && chats ? '' : L.summaryText(c);   // the big Talpy's headline says it
        const hosts = this.shownHosts;
        this._hostsCount.text = hosts.length > 0 ? String(hosts.length) : '';
        this._undismissItem.label.text = L.fmt('Show removed sessions again (%1)', this._status?.dismissed || 0);
        this._undismissItem.visible = (this._status?.dismissed || 0) > 0;

        this._messages.destroy_all_children();
        if (this._actionError)
            this._messages.add_child(paragraph(this._actionError, 'claude-fg-bad claude-message'));
        if (this._actionInfo)
            this._messages.add_child(paragraph(this._actionInfo, 'claude-fg-ok claude-message'));
        if (this._errorText)
            this._messages.add_child(paragraph(this._errorText, 'claude-fg-bad claude-message'));
        if (this._digest) {
            this._messages.add_child(this._buildDigestCard());
            this._digestSeen = true;
        }

        this._hostsPicker.child?.destroy();
        this._hostsPicker.child = this.ui.openMenu?.type === 'hosts' ? this._buildHostsPicker() : null;

        // Rebuild the list where it was scrolled to
        const adjustment = this._scroll.vadjustment;
        const scrolled = adjustment.value;
        this._pets.detachStages();
        this._list.destroy_all_children();
        if (!chats) {
            // (the pets' stages wait, detached, for the Chats tab)
            this._list.add_child(this.ui.tab === 'week' ? buildWeekView(this) : buildPermsView(this));
            return;
        }
        this.groups.forEach((g, i) => {
            this._list.add_child(buildGroupSection(this, g, {last: i === this.groups.length - 1, accounts: this.groups.length}));
        });
        for (const host of hosts)
            this._list.add_child(buildHostSection(this, host));
        if (this._status !== null && this.groups.length === 0) {
            const empty = column('claude-placeholder', {x_expand: true});
            empty.add_child(label('No Claude Code config found', 'claude-group-title'));
            empty.add_child(paragraph('Looked for ~/.claude and ~/.claude-*. Add other folders in the settings.', 'claude-dim'));
            this._list.add_child(empty);
        }
        this._pets.pruneStages();
        if (scrolled > 0) {
            this._clearTimer('scroll');
            this._timers.scroll = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                delete this._timers.scroll;
                adjustment.value = Math.min(scrolled, adjustment.upper - adjustment.page_size);
                return GLib.SOURCE_REMOVE;
            });
        }
    }

    _buildHostsPicker() {
        const menu = column('claude-inline-menu', {x_expand: true});
        menu.add_child(label('Show Claude on SSH hosts', 'claude-menu-title'));
        const shown = this.shownHosts;
        for (const h of this._sshHosts) {
            const target = (h.user ? `${h.user}@` : '') + (h.hostname || h.name) + (h.jump ? ` via ${h.jump}` : '');
            const on = shown.includes(h.name);
            menu.add_child(textButton(target !== h.name ? `${h.name}  (${target})` : h.name,
                () => this.toggleHost(h.name), 'claude-menu-item',
                on ? 'object-select-symbolic' : 'network-server-symbolic'));
        }
        // picked hosts that aren't in ~/.ssh/config (any more)
        for (const host of shown) {
            if (!this._sshHosts.some(h => h.name === host))
                menu.add_child(textButton(host, () => this.toggleHost(host), 'claude-menu-item', 'object-select-symbolic'));
        }
        if (this._sshHosts.length === 0 && shown.length === 0)
            menu.add_child(label('No hosts in ~/.ssh/config', 'claude-dim claude-indent'));
        menu.add_child(textButton('Reload ~/.ssh/config', () => this._loadHosts(), 'claude-menu-item',
            'view-refresh-symbolic'));
        return menu;
    }

    _onDestroy() {
        this._destroyed = true;
        for (const id of this._settingsIds)
            this._settings.disconnect(id);
        for (const name of Object.keys(this._timers))
            this._clearTimer(name);
        this._runner.destroy();
        this._notifier.destroy();
        this._pets.destroy();
        this.tips.destroy();
        super._onDestroy();
    }
});

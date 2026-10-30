// Notifications in GNOME's message tray: one per session row (a newer one
// replaces it), and a "needs input" one is closed once you've answered.
// They outlive a screen lock: the indicator made after it takes them over
// (owner), and a click goes to that one.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';

import {keyOfSource} from './logic.js';

export class Notifier {
    constructor(petsDir) {
        this._petsDir = petsDir;
        this._source = null;
        this._shown = new Map();   // row key -> {notification, kind}
        this.owner = null;         // the indicator a click goes to (none while the screen is locked)
    }

    _icon(file) {
        return new Gio.FileIcon({file: Gio.File.new_for_path(GLib.build_filenamev([this._petsDir, file]))});
    }

    _getSource() {
        if (!this._source) {
            this._source = new MessageTray.Source({title: 'Talpy Den', icon: this._icon('talpy.svg')});
            this._source.connect('destroy', () => {
                this._source = null;
            });
            Main.messageTray.add(this._source);
        }
        return this._source;
    }

    // n: {key, kind, title, body, icon, session, action (the button's label)};
    // pose: show Talpy (the pet setting) in the matching pose instead of a plain icon;
    // onOpen(indicator): what a click does (one about no chat has no button)
    notify(n, pose, onOpen) {
        const old = this._shown.get(n.key);
        if (old)
            this.close(n.key, old.kind);
        const source = this._getSource();
        const kind = n.kind === 'digest' ? (n.waiting ? 'waiting' : 'done') : n.kind;
        const poseFile = kind === 'done' && n.session && n.session.reason === 'failed' ? 'notify-sad.svg'
            : {waiting: 'notify-oncall.svg', done: 'notify-trophy.svg', reset: 'notify-trophy.svg', error: 'notify-error.svg',
                limit: 'notify-limit.svg', login: 'notify-error.svg'}[kind];
        const notification = new MessageTray.Notification({
            source,
            title: n.title,
            body: n.body.trim(),
            gicon: pose && poseFile ? this._icon(poseFile) : new Gio.ThemedIcon({name: n.icon}),
        });
        if (onOpen) {
            const open = () => {
                if (this.owner)
                    onOpen(this.owner);
            };
            if (n.session || n.action)
                notification.addAction(n.action || 'Open chat', open);
            notification.connect('activated', open);
        }
        notification.connect('destroy', () => {
            if (this._shown.get(n.key)?.notification === notification)
                this._shown.delete(n.key);
        });
        this._shown.set(n.key, {notification, kind: n.kind});
        source.addNotification(notification);
    }

    kindOf(key) {
        return this._shown.get(key)?.kind || '';
    }

    close(key, kind) {
        const shown = this._shown.get(key);
        if (!shown || shown.kind !== kind)
            return;
        this._shown.delete(key);
        shown.notification.destroy();
    }

    // Every notification of a source you stopped showing (an unticked host)
    closeSource(source) {
        for (const [key, shown] of [...this._shown.entries()]) {
            if (keyOfSource(key, source))
                this.close(key, shown.kind);
        }
    }

    // Sessions of this source that exited no longer need anything
    closeMissing(source, present) {
        for (const key of [...this._shown.keys()]) {
            if (keyOfSource(key, source) && !present.has(key))
                this.close(key, 'waiting');
        }
    }

    destroy() {
        this._shown.clear();
        this._source?.destroy();
        this._source = null;
    }
}

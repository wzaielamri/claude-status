// Talpy Den for GNOME Shell: the panel button (indicator.js), the
// window raiser that code/jump.py calls (raiser.js) and the hotkey to the
// chat that needs you. Nothing runs until enable(), and disable() takes
// everything down again.
//
// GNOME Shell turns extensions off while the screen is locked: disable()
// then notes the time and what the dashboard showed, and the next enable()
// (unlocked) hands that to the indicator for its "while you were away"
// summary. What the indicator last saw of each chat (its tracker) is kept
// too, so the first check after unlocking tells what changed meanwhile.

import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {Indicator} from './indicator.js';
import {awaySnapshot} from './logic.js';
import {Raiser} from './raiser.js';

export default class TalpyDenExtension extends Extension {
    enable() {
        try {
            this._raiser = new Raiser();
            const away = this._lockedAt ? {lockedAt: this._lockedAt, snapshot: this._lockedSnapshot} : null;
            const tracker = this._lockedTracker;
            this._lockedAt = null;
            this._lockedSnapshot = null;
            this._lockedTracker = null;
            this._indicator = new Indicator(this, away, tracker);
            Main.panel.addToStatusArea(this.uuid, this._indicator);
            this._settings = this.getSettings();
            Main.wm.addKeybinding('next-chat-shortcut', this._settings, Meta.KeyBindingFlags.NONE,
                Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW | Shell.ActionMode.POPUP,
                () => this._indicator?.goToNextChat());
            this._keybinding = true;
        } catch (e) {
            // GNOME doesn't call disable() after a failed enable(): undo what
            // was set up (else the D-Bus object stays exported, and the next
            // enable() fails at once)
            this.disable();
            throw e;
        }
    }

    disable() {
        if (this._keybinding)
            Main.wm.removeKeybinding('next-chat-shortcut');
        this._keybinding = false;
        this._settings = null;
        this._lockedTracker = Main.sessionMode.isLocked ? this._indicator?._tracker || null : null;
        if (Main.sessionMode.isLocked && this._indicator?._status) {
            try {
                this._lockedSnapshot = awaySnapshot(this._indicator.allGroups);
                this._lockedAt = Date.now();
            } catch (e) {
                console.error(`Talpy Den: couldn't note the dashboard at locking: ${e.message}`);
            }
        }
        this._indicator?.destroy();
        this._indicator = null;
        this._raiser?.destroy();
        this._raiser = null;
    }
}

// The pets (port of the Plasma widget's PetStrip.qml and Pet.qml).
//
// The hero: the big Talpy at the top of the popup, on a stage lit in the
// whole dashboard's mood (orange and pulsing when a chat needs you, the
// accent while chats work, green when it's your turn, a starry night once
// everything is done), with a headline and the session counts.
//
// An account's stage: one pet per chat in its list (up to `chat-pets`). A pet
// wears the chat's name on a tag in the chat's color (the chat's row gets a
// bar in that color), stands in the row in the list's order, acts the chat
// out, opens it when clicked, and stays until the chat leaves the list; then
// it waves and digs away.
//
// Talpy itself (looks, moods, what it does) is talpy/talpy.js, shared with the
// Plasma widget and the VS Code extension; it's drawn with Cairo
// (cairoCanvas.js). Nothing moves while the popup is closed.

import Cairo from 'cairo';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';

import * as L from '../logic.js';
import {CairoCanvas} from './cairoCanvas.js';
import {Pictures} from './talpy/pictures.js';
import {Talpy, LILAC, calmColors} from './talpy/talpy.js';
import {box, dot, label, link} from './widgets.js';

// Colors that stay apart from each other on light and dark themes
const PALETTE = ['#e5534b', '#e8913a', '#c9a227', '#4caf50', '#26a69a', '#42a5f5', '#7e57c2', '#ec407a'];
const MOOD_COLORS = {needs: [245, 121, 0], error: [232, 68, 58], idle: [51, 184, 108]};
const NIGHT = [99, 113, 200];

function pick(list, last) {
    const choices = list.length > 1 ? list.filter(x => x !== last) : list;
    return choices[Math.floor(Math.random() * choices.length)];
}

function holidayGreeting() {
    const d = new Date(), m = d.getMonth() + 1, day = d.getDate();
    if ((m === 12 && day === 31) || (m === 1 && day === 1))
        return 'Happy New Year!';
    if (m === 12 && day >= 24 && day <= 26)
        return 'Merry Christmas!';
    if (m === 10 && day === 31)
        return 'Boo! Happy Halloween!';
    if (m === 2 && day === 14)
        return "Happy Valentine's Day!";
    return '';
}

function colorHash(key) {
    let h = 0;
    for (let i = 0; i < key.length; i++)
        h = (h * 31 + key.charCodeAt(i)) >>> 0;
    return h;
}

// GLib timers that all stop together
class Timers {
    constructor() {
        this._ids = new Map();
    }

    after(name, ms, fn) {
        this.stop(name);
        this._ids.set(name, GLib.timeout_add(GLib.PRIORITY_DEFAULT, Math.max(1, Math.round(ms)), () => {
            this._ids.delete(name);
            fn();
            return GLib.SOURCE_REMOVE;
        }));
    }

    every(name, ms, fn) {
        this.stop(name);
        this._ids.set(name, GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
            fn();
            return GLib.SOURCE_CONTINUE;
        }));
    }

    running(name) {
        return this._ids.has(name);
    }

    stop(name) {
        const id = this._ids.get(name);
        if (id) {
            GLib.source_remove(id);
            this._ids.delete(name);
        }
    }

    stopAll() {
        for (const id of this._ids.values())
            GLib.source_remove(id);
        this._ids.clear();
    }
}

// ---------------------------------------------------------------- one pet

class Pet {
    constructor(stage, key, opts) {
        this.stage = stage;
        this.key = key;                  // the chat's pet key ("" for the hero)
        this.lone = key === '';
        this.tint = opts.tint || '';
        this.label = opts.label || '';
        this.host = opts.host || '';
        this.chat = null;
        this.lastChat = null;
        this.leaving = false;
        this.arriving = false;
        this.travelTo = -1;              // where the next dig takes it (-1: it picks)
        this.clicks = 0;
        this.lastMood = '';
        this.timers = new Timers();

        const s = stage.size;
        this.talpy = new Talpy({colors: this.lone ? LILAC : calmColors(this.tint), theme: stage.pets.theme,
            travels: this.lone});
        this.talpy.onTravel = ms => this._travel(ms);
        this.talpy.tick(Date.now());
        this.actor = new St.Widget({reactive: true, track_hover: true, width: s.slot, height: s.canvasH + s.tag});
        // Talpy on its view, drawn from its sheets (Cairo surfaces): a chat's
        // pet as pictures (talpy/pictures.js), the hero live on its one sheet
        this.pictures = new Pictures(this.talpy, this.lone ? 1 : 5);
        this.sheets = [];
        this._sheetSize = '';
        this.view = new St.DrawingArea({width: s.canvasW, height: s.canvasH, x: Math.round((s.slot - s.canvasW) / 2)});
        this.view.connect('repaint', area => this._paint(area));
        this.actor.add_child(this.view);
        if (!this.lone) {
            const dark = this.tint && this._luma(this.tint) < 0.6;
            this._tagStyle = `background-color: ${this.tint}; color: ${dark ? 'white' : 'black'};`;
            this.tag = new St.Label({text: this.label, style_class: 'claude-pet-tag'});
            this.setTagWidth(s.slot - 4);
            this.tag.clutter_text.ellipsize = 3;   // Pango.EllipsizeMode.END
            this.actor.add_child(this.tag);
            this.tag.connect('notify::width', () => this._placeTag());
        }

        this.actor.connect('destroy', () => {
            this.gone = true;   // with the popup (or the whole shell)
            this.timers.stopAll();
        });
        this.actor.connect('button-press-event', (a, event) => {
            this._clickCount = event.get_click_count();
            return Clutter.EVENT_STOP;
        });
        this.actor.connect('button-release-event', () => {
            if (this._clickCount === 2 && this.lone)
                this.dance();
            else
                this.clicked();
            return Clutter.EVENT_STOP;
        });
        if (!this.lone) {
            stage.ctx.tips.add(this.actor, () => this.lastChat
                ? [(this.host ? `${this.host}: ` : '') + this.lastChat.name,
                    `${L.stateText(this.lastChat, stage.ctx.now)}\nClick to open this chat`] : '');
        }
    }

    _luma(hex) {
        const n = parseInt(hex.slice(1), 16);
        return (((n >> 16) & 255) * 0.299 + ((n >> 8) & 255) * 0.587 + (n & 255) * 0.114) / 255;
    }

    // The sheets that need it are drawn (at the view's size), then the view
    // shows the one in front or, while a pose fades into the next, both mixed:
    // (1 - mix) × front + mix × next, added up (ADD), so where both cover the
    // background never shows through
    _paint(area) {
        const cr = area.get_context();
        const [width, height] = area.get_surface_size();
        const scale = area.get_resource_scale();
        const pictures = this.pictures;
        const size = `${width}x${height}@${scale}`;
        if (size !== this._sheetSize) {
            this._sheetSize = size;
            this.sheets = [];
            pictures.reset();
            pictures.front.paint = true;   // (the one shown, right away)
        }
        for (const s of pictures.sheets) {
            if (!s.paint)
                continue;
            s.paint = false;
            if (!this.sheets[s.index]) {
                this.sheets[s.index] = new Cairo.ImageSurface(Cairo.Format.ARGB32, Math.ceil(width * scale), Math.ceil(height * scale));
                this.sheets[s.index].setDeviceScale(scale, scale);
            }
            const sheet = new Cairo.Context(this.sheets[s.index]);
            sheet.setOperator(Cairo.Operator.CLEAR);
            sheet.paint();
            sheet.setOperator(Cairo.Operator.OVER);
            const ctx = new CairoCanvas(sheet);
            const boxPx = width / 1.6;
            ctx.translate(boxPx * 0.3, boxPx * 0.45);
            ctx.scale(boxPx / 64, boxPx / 64);
            pictures.paint(s, ctx);
            sheet.$dispose();
        }
        const front = this.sheets[pictures.front.index];
        const coming = pictures.coming ? this.sheets[pictures.coming.index] : null;
        if (front) {
            cr.setSourceSurface(front, 0, 0);
            cr.paintWithAlpha(coming ? 1 - pictures.mix : 1);
        }
        if (coming) {
            cr.setOperator(Cairo.Operator.ADD);
            cr.setSourceSurface(coming, 0, 0);
            cr.paintWithAlpha(pictures.mix);
        }
        cr.$dispose();
    }

    // The name tag fits the room between pets
    setTagWidth(width) {
        width = Math.round(width);
        if (!this.tag || width === this._tagWidth)
            return;
        this._tagWidth = width;
        this.tag.style = `${this._tagStyle} max-width: ${width}px;`;
    }

    _placeTag() {
        const s = this.stage.size;
        this.tag.set_position(Math.round((s.slot - this.tag.width) / 2), Math.round(s.floorY + s.box * 6 / 64));
    }

    get px() {
        return this.actor.x + this.stage.size.slot / 2;
    }

    set px(x) {
        this.actor.x = Math.round(x - this.stage.size.slot / 2);
    }

    get live() {
        return this.stage.live;
    }

    // Talpy's moods: idle working agents needs done failed limit (error loading for the hero)
    get mood() {
        if (this.lone)
            return this.stage.ctxMood;
        const c = this.chat;
        if (!c)
            return 'idle';
        if (c.state === 'waiting')
            return 'needs';
        if (c.state === 'working')
            return c.agents && c.agents.running > 0 ? 'agents' : 'working';
        if (c.stopped && !c.stopped.over)
            return 'limit';                               // a usage limit (or the login) stopped it
        if (c.state === 'idle')
            return 'idle';                                // ready for your next message
        return c.reason === 'failed' ? 'failed' : 'done';   // done: results to look at
    }

    // Shows its mood (and wakes up for work)
    sync() {
        if (this.gone)
            return;
        const mood = this.mood;
        if (mood !== this.lastMood) {
            this.talpy.setMood(mood);
            if (this.lastMood === 'done' && mood !== 'done' && !this.leaving)
                this.react('yawn');   // woken up by work
            this.lastMood = mood;
        }
    }

    setChat(chat, label) {
        this.chat = chat;
        if (chat)
            this.lastChat = chat;
        if (this.tag && label !== undefined && label !== this.label) {
            this.label = label;
            this.tag.text = label;
        }
        this.sync();
    }

    // ------------------------------------------------------------ actions

    react(name, done) {
        this.talpy.react(name, done || null);
    }

    clampX(x) {
        const s = this.stage.size, reach = s.box * 27 / 64 + 4;
        // the burrow stays on the stage; the hero walks anywhere on it, over the headline too
        const max = Math.max(reach, this.stage.width - reach);
        return Math.max(reach, Math.min(max, x));
    }

    // Digs over to x (it dives in, tunnels across, pops up there); quick: its
    // spot moved (a new chat makes room), so it hurries
    digTo(x, quick) {
        if (this.leaving || this.arriving)
            return;
        this.travelTo = this.clampX(x);
        if (Math.abs(this.travelTo - this.px) < this.stage.size.body * 0.3) {
            this.travelTo = -1;
            return;
        }
        this.react(quick ? 'scoot' : 'dig');
    }

    // It dug in: tunnel across to the spot within ms
    _travel(ms) {
        let to = this.travelTo;
        this.travelTo = -1;
        if (to < 0) {
            const cursor = this.stage.cursorX, s = this.stage.size;
            to = cursor >= 0 ? cursor + (Math.random() - 0.5) * s.body : Math.random() * this.stage.width;
        }
        to = this.clampX(to);
        this.talpy.facingLeft = to < this.px;
        this.actor.remove_transition('x');
        this.actor.ease({
            x: Math.round(to - this.stage.size.slot / 2),
            duration: Math.max(200, ms - 100),
            mode: Clutter.AnimationMode.EASE_IN_OUT_SINE,
        });
    }

    say(text) {
        this.stage.say(this, text);
    }

    // Clicked: the hero gets petted, a chat's pet opens its chat
    clicked() {
        if (this.lone) {
            this.petIt();
            return;
        }
        const c = this.lastChat;
        if (!c)
            return;
        if (this.host)
            this.stage.ctx.remoteShow(this.host, c);
        else
            this.stage.ctx.jumpTo(c.sessionId, c.profileDir);
    }

    petIt() {
        this.clicks += 1;
        this.timers.after('tickle', 1500, () => {
            this.clicks = 0;
        });
        if (this.mood === 'done') {
            if (this.clicks >= 3) {
                this.clicks = 0;
                this.react('angry');
                this.say('I said let me SLEEP!');
            } else {
                this.react('grumpy');
                this.say('Zzz… let me sleep.');
            }
            return;
        }
        if (this.clicks >= 4) {
            this.clicks = 0;
            this.react('laugh');
            this.say('Hehe, that tickles!');
        } else if (this.clicks === 3) {
            this.react('shy');
            this.say('Aww, stop it…');
        } else {
            this.react('pet');
            this.say(this.petLine());
        }
    }

    dance() {
        if (this.mood === 'done') {
            this.react('yawn');
            this.say('…five more minutes.');
            return;
        }
        this.react('dance');
        this.say('♪ ♫');
    }

    petLine() {
        const ctx = this.stage.ctx, mood = this.mood;
        if (mood === 'needs')
            return L.fmt('%1 needs you!', L.firstWaitingName(ctx.allGroups));
        if (mood === 'agents') {
            const n = L.agentsRunning(ctx.allGroups);
            return L.fmt(n === 1 ? 'Juggling %1 agent!' : 'Juggling %1 agents!', n);
        }
        if (mood === 'working')
            return 'Busy coding… thanks!';
        return pick(['Hi!', '♥', 'Ship it!', 'All quiet here.', 'Pet me more!'], '');
    }

    // Something happened to its chat (or, for the hero, to an account)
    event(kind, text) {
        if (this.leaving)
            return; // (a reaction now would stop it digging away)
        const action = {done: 'finished', failed: 'failed', stopped: 'shrug', limit: 'battery', oops: 'confused', reset: 'charged'}[kind];
        this.react(action || 'alert');
        this.say(text);
    }

    // Shown or hidden with the popup
    setLive(live) {
        if (this.gone)
            return;
        this.timers.stopAll();
        if (!live)
            return;
        this.sync();
        this.talpy.setTheme(this.stage.pets.theme);
        this.pictures.reset();   // (the theme may have changed)
        // its clock, and its picture: the hero's as often as that shows
        // something new (talpy.frameMs: 25 times a second for quick moves,
        // down to 5 at rest), a chat's pet's when what it shows changes
        // (pictures: a sheet to draw, or another one to show)
        this.timers.every('frame', 40, () => {
            const now = Date.now();
            this.talpy.tick(now);
            if (this.gone)
                return;   // (it dug away in that tick: removed)
            if (this.pictures.tick(now) || this.pictures.sheets.some(s => s.paint))
                this.view.queue_repaint();
        });
        // the hero turns towards the mouse while it hovers the stage
        if (this.lone) {
            this.timers.every('face', 350, () => {
                const cursor = this.stage.cursorX;
                if (cursor >= 0 && Math.abs(cursor - this.px) > this.stage.size.body * 0.4 && this.mood !== 'done')
                    this.talpy.facingLeft = cursor < this.px;
            });
        }
        // a working chat whose context is nearly full, or a limit close by
        this.timers.every('worries', 25000, () => this._worry());
        this.timers.after('firstWorry', 2500, () => this._worry());
    }

    _worry() {
        if (this.leaving || this.talpy.busy)
            return;
        const ctx = this.stage.ctx, mood = this.mood;
        const contextFull = !this.lone
            ? this.chat && this.chat.state === 'working' && this.chat.context !== null && this.chat.context >= 85
                ? L.fmt('%1: context %2% full', this.label, Math.round(this.chat.context)) : ''
            : L.contextFullText(ctx.allGroups, ctx.petColors);
        if (contextFull && (mood === 'working' || mood === 'agents')) {
            this.react('contextFull');
            this.say(contextFull);
            return;
        }
        const high = this.lone ? L.highUsageText(ctx.allGroups) : '';
        if (high && mood !== 'done') {
            this.react(L.maxFiveHour(ctx.allGroups) >= 100 ? 'battery' : 'mindblown');
            this.say(high);
        }
    }

    // A new chat: it digs up out of the ground
    arrive() {
        this.arriving = true;
        this.react('arrive', () => {
            this.arriving = false;
        });
    }

    // Its chat left the list: it waves and digs away
    leave() {
        this.leaving = true;
        if (!this.live) {
            this.stage.removePet(this.key);
            return;
        }
        this.react('leave', ok => {
            if (ok && this.leaving && !this.gone)
                this.stage.removePet(this.key);
        });
    }

    comeBack() {
        this.leaving = false;
        this.arrive();
    }

    destroy() {
        this.timers.stopAll();
        this.actor.destroy();
    }
}

// ---------------------------------------------------------------- a stage

class Stage {
    constructor(pets, key, hero) {
        this.pets = pets;
        this.ctx = pets.ctx;
        this.key = key;
        this.hero = hero;
        this.live = false;
        this.cursorX = -1;
        this.chats = [];
        this.order = [];      // the shown chats' keys, in the list's order
        this.list = new Map();   // pet key -> Pet
        this.colors = {};     // pet key -> palette index
        this.timers = new Timers();
        this.firstShown = false;

        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        const gu = 16 * scale;
        // Talpy's 64-unit box, its canvas (room around it for what it throws and
        // holds up), where the floor is on the canvas, and its body's size
        const boxPx = (hero ? 5.6 : 3.8) * gu;
        this.size = {
            gu, scale, box: boxPx, canvasW: Math.round(boxPx * 1.6), canvasH: Math.round(boxPx * 1.5),
            floorY: boxPx * 0.45 + boxPx * 57 / 64, body: boxPx * 38 / 64, bodyH: boxPx * 31 / 64,
            tag: gu * 1.1, slot: Math.round(hero ? boxPx * 1.6 : Math.max(boxPx * 1.6, gu * 7)),
        };
        this.actor = new St.Widget({
            style_class: hero ? 'claude-hero' : 'claude-stage', reactive: true, track_hover: true,
            x_expand: true, height: Math.round((hero ? 6 : 4.5) * gu), clip_to_allocation: true,
        });
        this._width = 0;   // as last allocated
        this._toSay = null;   // [pet, text] said before it could be placed
        this.actor.connect('notify::width', () => {
            this._width = this.actor.get_allocation_box().get_width();
            this.layout();
        });
        this.actor.connect('destroy', () => {
            this.gone = true;
            this.timers.stopAll();
        });
        this.actor.connect('motion-event', (a, event) => {
            const [x, y] = event.get_coords();
            const [ok, lx] = this.actor.transform_stage_point(x, y);
            this.cursorX = ok ? lx : -1;
            return Clutter.EVENT_PROPAGATE;
        });
        this.actor.connect('leave-event', () => {
            this.cursorX = -1;
            return Clutter.EVENT_PROPAGATE;
        });

        if (hero) {
            this.glow = new St.Widget({style_class: 'claude-hero-glow', x_expand: true, y_expand: true});
            this.actor.add_child(this.glow);
            this.stars = [[0.55, 0.14], [0.64, 0.36], [0.71, 0.10], [0.80, 0.30], [0.88, 0.12], [0.94, 0.40],
                [0.60, 0.56], [0.97, 0.66], [0.50, 0.42]].map(([x, y], i) => {
                const star = new St.Label({text: i % 3 === 0 ? '✦' : '·',
                    style_class: `claude-star${i % 3 === 0 ? '' : ' claude-star-dot'}`, opacity: 128});
                star._spot = [x, y];
                this.actor.add_child(star);
                return star;
            });
            // the headline (what needs you, what works) and the counts
            this.info = new St.BoxLayout({style_class: 'claude-hero-info', orientation: Clutter.Orientation.VERTICAL});
            this.headline = link('', () => this._openCalling(), 'claude-headline');
            this.ctx.tips.add(this.headline, () => {
                const c = this._calling();
                return c ? [L.fmt('Open %1', c.session.name),
                    (c.host ? `${c.host} · ` : '') + L.stateText(c.session, this.ctx.now)] : '';
            });
            this.chips = box('claude-chips');
            this.info.add_child(this.headline);
            this.info.add_child(this.chips);
            this.actor.add_child(this.info);
        } else {
            this.floor = new St.Widget({style_class: 'claude-stage-floor', height: 1});
            this.actor.add_child(this.floor);
            this.more = new St.Label({style_class: 'claude-small claude-dim claude-stage-more', visible: false});
            this.actor.add_child(this.more);
            this.ctx.tips.add(this.more, () => [L.fmt('%1 more chats', this.hidden),
                L.fmt('Up to %1 pets per account, the chats that need you or work first; the list shows them all.',
                    this.pets.maxPets)]);
        }
        this.bubble = new St.Label({style_class: 'claude-bubble', visible: false});
        this.bubble.clutter_text.ellipsize = 3;
        this.actor.add_child(this.bubble);
    }

    get width() {
        return this._width;
    }

    get ctxMood() {
        return this.pets.mood;
    }

    get petCount() {
        return this.list.size;
    }

    // Where a pet stands: the hero on the right of his stage (under the
    // stars), a chat's pet on its spot in the row
    slotX(key) {
        if (key === '')
            return this.width * 0.76;
        const keys = this.order;
        const at = keys.indexOf(key);
        return at >= 0 ? this.size.body * 0.8 + (at + 0.5) * this.spacing : this.list.get(key)?.px ?? this.width / 2;
    }

    // Room per pet in the row
    get spacing() {
        const margin = this.size.body * 0.8;
        return Math.max(0, Math.min(this.size.gu * 7.5, (this.width - 2 * margin) / Math.max(1, this.order.length)));
    }

    // A color for a chat: its own (from its key) unless another pet wears it,
    // here or, while there are colors left, on another account's stage
    _freeColor(key) {
        const h = colorHash(key);
        const here = new Set(Object.values(this.colors));
        const anywhere = new Set(Object.values(this.pets.colors).map(c => PALETTE.indexOf(c)));
        for (const used of [new Set([...here, ...anywhere]), here]) {
            let c = h % PALETTE.length;
            for (let n = 0; n < PALETTE.length; n++, c = (c + 1) % PALETTE.length) {
                if (!used.has(c))
                    return c;
            }
        }
        return h % PALETTE.length;
    }

    // An account's chats as [{key, session, host, order}] (order: in the list), the ones that get a pet first
    setChats(chats) {
        const shown = chats.slice(0, this.pets.maxPets);
        this.hidden = chats.length - shown.length;
        const byKey = new Map(shown.map(c => [c.key, c]));
        for (const [key, pet] of this.list) {
            const c = byKey.get(key);
            if (!c && !pet.leaving) {
                pet.setChat(null);
                pet.leave();
            } else if (c && pet.leaving) {
                pet.comeBack();
            }
            if (c)
                pet.setChat(c.session, (c.session.name || '').trim());
        }
        // spots: in the order of the chats in the list, left to right
        this.order = shown.slice().sort((a, b) => a.order - b.order).map(c => c.key);
        for (const c of shown) {
            if (this.list.has(c.key))
                continue;
            this.colors[c.key] = this._freeColor(c.key);
            const pet = new Pet(this, c.key, {tint: PALETTE[this.colors[c.key]], label: (c.session.name || '').trim(),
                host: c.host});
            this.list.set(c.key, pet);
            this.actor.insert_child_below(pet.actor, this.bubble);
            pet.setChat(c.session);
            this._enter(pet);
        }
        if (this.more) {
            this.more.text = L.fmt('+%1', this.hidden);
            this.more.visible = this.hidden > 0;
        }
        this.layout();
    }

    _enter(pet) {
        pet.px = this.slotX(pet.key);
        pet.placed = this.width > 0;
        pet.setLive(this.live);
        // the first time the popup opens they're just there; later a new chat's pet digs up
        if (this.firstShown && this.live && this.width > 0)
            pet.arrive();
    }

    removePet(key) {
        const pet = this.list.get(key);
        if (!pet)
            return;
        this.list.delete(key);
        delete this.colors[key];
        pet.destroy();
        if (!this.hero && this.list.size === 0 && this.chats.length === 0)
            this.pets.ctx.rerender();   // the stage folds away
    }

    get colorsByPet() {
        const out = {};
        for (const [key, pet] of this.list) {
            if (!pet.leaving && key in this.colors)
                out[key] = PALETTE[this.colors[key]];
        }
        return out;
    }

    // Places what isn't animated: the floor, stars, headline, standing pets
    layout() {
        // (not while detached, as while the list is rebuilt: even reading its
        // height then asks St for a size it can't give)
        if (this.gone || !this.actor.get_stage())
            return;
        const w = this.width, h = this.actor.height, s = this.size;
        if (w <= 0)
            return;
        // (a chat's name tag goes under its burrow's mound)
        const ground = this.hero ? h - s.gu * 0.55 : h - s.tag - s.box * 6 / 64 - 4;
        const tagWidth = Math.max(s.gu * 3.5, this.spacing - 8);
        for (const pet of this.list.values()) {
            pet.setTagWidth(tagWidth);
            pet.actor.y = Math.round(ground - s.floorY);
            if (pet.leaving)
                continue;
            const home = this.slotX(pet.key);
            if (!this.live || !this.firstShown || !pet.placed) {
                pet.px = home;   // not seen yet: it's just there
                pet.placed = true;
            } else if (!pet.lone && Math.abs(pet.px - home) > s.body * 0.3) {
                pet.digTo(home, true);   // its spot moved: it digs over
            } else if (pet.lone && pet.clampX(pet.px) !== pet.px) {
                pet.digTo(pet.clampX(pet.px), true);
            }
        }
        if (this.hero) {
            this.glow.set_size(w, h);
            for (const star of this.stars)
                star.set_position(Math.round(w * star._spot[0]), Math.round(h * star._spot[1]));
            this.info.set_position(Math.round(s.gu * 0.8), Math.round(s.gu * 0.55));
            this.info.width = Math.round(Math.max(s.gu * 8, this.slotX('') - s.body / 2 - s.gu - s.gu * 0.8));
        } else {
            this.floor.set_position(Math.round(s.gu * 0.6), Math.round(ground));
            this.floor.width = Math.round(w - s.gu * 1.2);
            this.more.set_position(Math.round(w - this.more.width - 6), 4);
        }
        if (this._toSay) {
            const [pet, text] = this._toSay;
            this._toSay = null;
            if (!pet.gone)
                this.say(pet, text);
        }
    }

    // ------------------------------------------------------------ the hero

    _calling() {
        for (const g of this.ctx.allGroups) {
            for (const s of g.sessions) {
                if (s.state === 'waiting')
                    return {session: s, host: g.host || ''};
            }
        }
        return null;
    }

    _openCalling() {
        const c = this._calling();
        if (c && c.host)
            this.ctx.remoteShow(c.host, c.session);
        else if (c)
            this.ctx.jumpTo(c.session.sessionId, c.session.profileDir);
    }

    updateHero(headline, counts, status) {
        if (this.gone)
            return;
        const mood = this.pets.mood;
        this.headline.child.text = headline;
        if (mood === 'needs')
            this.headline.add_style_class_name('claude-fg-waiting');
        else
            this.headline.remove_style_class_name('claude-fg-waiting');
        this.chips.destroy_all_children();
        if (status) {
            const chips = [['waiting', counts.waiting, counts.waiting === 1 ? '%1 needs input' : '%1 need input'],
                ['working', counts.working, '%1 working'], ['ok', counts.idle, '%1 idle'], ['ok', counts.done, '%1 done']]
                .filter(c => c[1] > 0);
            for (const [cls, n, text] of chips) {
                const chip = box('claude-chip');
                chip.add_child(dot(cls, 'claude-dot claude-dot-small'));
                chip.add_child(label(L.fmt(text, n), 'claude-small'));
                this.chips.add_child(chip);
            }
            if (!chips.length)
                this.chips.add_child(label('No sessions running', 'claude-small claude-dim'));
        }
        // the light: what the whole dashboard is up to
        const [r, g, b] = mood === 'working' || mood === 'agents' ? this.pets.accentRgb : MOOD_COLORS[mood] || NIGHT;
        this.actor.style = `background-gradient-direction: vertical; background-gradient-start: rgba(${r},${g},${b},0.22);` +
            ` background-gradient-end: rgba(${r},${g},${b},0.05); border-color: rgba(${r},${g},${b},0.35);`;
        this.glow.style = `background-color: rgba(${r},${g},${b},0.12);`;
        const night = mood === 'done';
        for (const star of this.stars)
            star.visible = night;
        if (mood !== this._heroMood) {
            this._heroMood = mood;
            this._animateLight();
        }
        for (const pet of this.list.values())
            pet.sync();
    }

    // pulsing while a chat needs you, twinkling stars at night
    _animateLight() {
        if (!this.hero)
            return;
        this.glow.remove_all_transitions();
        this.glow.opacity = 0;
        for (const star of this.stars) {
            star.remove_all_transitions();
            star.opacity = 128;
        }
        if (!this.live)
            return;
        if (this._heroMood === 'needs') {
            this.glow.ease({opacity: 255, duration: 900, mode: Clutter.AnimationMode.EASE_IN_OUT_SINE,
                repeatCount: -1, autoReverse: true});
        } else if (this._heroMood === 'done') {
            this.stars.forEach((star, i) => star.ease({opacity: 230, duration: 900 + 260 * i,
                mode: Clutter.AnimationMode.EASE_IN_OUT_SINE, repeatCount: -1, autoReverse: true}));
        }
    }

    // ------------------------------------------------------------ shared by the pets

    say(pet, text) {
        if (!this.live || !text || this.gone)
            return;
        if (this.width <= 0 || !this.actor.get_stage()) {
            this._toSay = [pet, text];   // once it's laid out (layout()), where it can be placed
            return;
        }
        this._toSay = null;
        const s = this.size;
        this.bubble.text = text;
        this.bubble.set_width(-1);   // measure the new text, not the last width
        this.bubble.show();
        const [, natWidth] = this.bubble.get_preferred_width(-1);
        const width = Math.min(natWidth, this.width - 8);
        this.bubble.width = width;
        const headTop = pet.actor.y + s.floorY - s.bodyH;
        const above = headTop - this.bubble.height - 4 >= 0;
        let x = above ? pet.px - width / 2
            : pet.px + s.body / 2 + width + 4 <= this.width ? pet.px + s.body / 2 + 4 : pet.px - s.body / 2 - width - 4;
        x = Math.max(0, Math.min(this.width - width, x));
        this.bubble.set_position(Math.round(x), Math.round(above ? headTop - this.bubble.height - 4 : Math.max(0, headTop)));
        this.actor.set_child_above_sibling(this.bubble, null);
        this.timers.after('bubble', 4500, () => this.bubble.hide());
    }

    // Events go to the chat's own pet; the hero takes the ones about
    // everything (and the ones for a chat that has no pet)
    event(kind, text, key) {
        const pet = this.hero ? (!key || !(key in this.pets.colors) ? this.list.get('') : null)
            : key ? this.list.get(key) : null;
        if (pet && this.live)
            pet.event(kind, text);
    }

    setLive(live) {
        if (this.gone)
            return;
        this.live = live;
        if (!live) {
            this.timers.stopAll();
            this.bubble.hide();
            this._toSay = null;
        } else {
            this.pets.updateTheme(this.actor);
        }
        // shown and laid out: from now on a new chat's pet digs up
        if (live && !this.firstShown)
            this.timers.after('firstShown', 500, () => {
                this.firstShown = true;
            });
        for (const [key, pet] of this.list) {
            if (pet.leaving && !live) {
                this.removePet(key);
                continue;
            }
            pet.setLive(live);
        }
        this.layout();
        if (this.hero) {
            this._animateLight();
            if (live)
                this._greet();
        }
    }

    // Opening the popup: the hero says hi now and then (or happy holidays)
    _greet() {
        const hero = this.list.get('');
        const mood = this.pets.mood;
        if (!hero || mood === 'done' || mood === 'loading')
            return;
        const text = holidayGreeting();
        if (text) {
            hero.react('celebrate');
            hero.say(text);
        } else if (Math.random() < 0.6) {
            hero.react('wave');
            hero.say('Hi!');
        }
    }

    destroy() {
        this.timers.stopAll();
        for (const pet of this.list.values())
            pet.timers.stopAll();
        this.list.clear();
        this.actor.destroy();
    }
}

// ---------------------------------------------------------------- the director

export class Pets {
    constructor(ctx) {
        this.ctx = ctx;
        this._stages = new Map();   // group key -> Stage
        this.theme = {fx: 'rgba(255,255,255,0.55)', text: '#ffffff'};   // the popup's text color (updateTheme)
        this.mood = 'loading';
        this.accentRgb = [53, 132, 228];   // "working" blue (stylesheet.css)
        this.hero = new Stage(this, 'hero', true);
        const talpy = new Pet(this.hero, '', {});
        this.hero.list.set('', talpy);
        this.hero.actor.insert_child_below(talpy.actor, this.hero.bubble);
        talpy.sync();
        this._heroShown = null;
    }

    get settings() {
        return this.ctx._settings;
    }

    get maxPets() {
        return Math.max(0, this.settings.get_int('chat-pets'));
    }

    get heroShown() {
        return this.settings.get_boolean('show-pet');
    }

    // Talpy's words and particles take the popup's text color
    updateTheme(actor) {
        if (!actor.get_stage())
            return;
        const c = actor.get_theme_node().get_foreground_color();
        this.theme = {fx: `rgba(${c.red},${c.green},${c.blue},0.55)`, text: `rgba(${c.red},${c.green},${c.blue},1)`};
    }

    // An account's stage with its chats' pets, or null when it has none
    stageFor(groupKey, chats) {
        if (!this.heroShown || this.maxPets === 0)
            return null;
        let stage = this._stages.get(groupKey);
        if (!stage && chats.length === 0)
            return null;
        if (!stage) {
            stage = new Stage(this, groupKey, false);
            this._stages.set(groupKey, stage);
            stage.setLive(this.ctx.menu.isOpen);
        }
        stage.chats = chats;
        stage.setChats(chats);
        stage.used = true;
        if (chats.length === 0 && stage.petCount === 0)
            return null;
        return stage.actor;
    }

    // Before the list is rebuilt: keep the stages (their pets live on)
    detachStages() {
        for (const stage of this._stages.values()) {
            stage.used = false;
            stage.actor.get_parent()?.remove_child(stage.actor);
        }
    }

    // After: stages of accounts that are gone go too
    pruneStages() {
        for (const [key, stage] of this._stages) {
            if (!stage.used) {
                stage.destroy();
                this._stages.delete(key);
            }
        }
    }

    // Each chat pet's color by pet key (the bar next to its chat in the list)
    get colors() {
        const all = {};
        for (const stage of this._stages.values())
            Object.assign(all, stage.colorsByPet);
        return all;
    }

    // Every poll: the hero's mood and headline
    update() {
        const ctx = this.ctx;
        const groups = ctx.allGroups;
        const counts = L.counts(groups);
        this.mood = L.petMood(ctx._status, ctx._errorText, L.overall(groups, counts), L.agentsRunning(groups));
        const shown = this.heroShown;
        if (shown !== this._heroShown) {
            this._heroShown = shown;
            ctx._heroBin.child = shown ? this.hero.actor : null;
        }
        if (shown)
            this.hero.updateHero(L.headline(ctx._status, ctx._errorText, counts), counts, ctx._status);
    }

    event({kind, text, key}) {
        this.hero.event(kind, text, key);
        for (const stage of this._stages.values())
            stage.event(kind, text, key);
    }

    setActive(open) {
        this.hero.setLive(open);
        for (const stage of this._stages.values())
            stage.setLive(open);
    }

    destroy() {
        for (const stage of this._stages.values())
            stage.destroy();
        this._stages.clear();
        this.ctx._heroBin.child = null;
        this.hero.destroy();
    }
}

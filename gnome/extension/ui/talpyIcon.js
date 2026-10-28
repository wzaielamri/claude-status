// The panel icon: Talpy peeking up through the panel's edge (talpy/glyph.js,
// the same as the Plasma widget's), in the color of its style class
// (claude-fg-*). It pops up when a chat needs you, glances around while Claude
// works, smiles when it's your turn and sleeps when nothing runs.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {CairoCanvas} from './cairoCanvas.js';
import {drawGlyph, glyphMoves} from './talpy/glyph.js';

export const TalpyIcon = GObject.registerClass(
class ClaudeTalpyIcon extends St.DrawingArea {
    _init(styleClass = 'claude-spark') {
        super._init({style_class: styleClass, y_align: Clutter.ActorAlign.CENTER});
        this._timer = 0;
        this._colorClass = '';
        this._mode = 'none';
        this._moving = true;
        this.connect('destroy', () => this._stop());
    }

    // false: holds still (the popup's own icon while the popup is closed)
    setMoving(moving) {
        this._moving = moving;
        this._sync();
        this.queue_repaint();
    }

    // colorClass: claude-fg-<colorClass>; mode: the dashboard's state (waiting working idle none)
    setState(colorClass, mode) {
        if (colorClass !== this._colorClass) {
            if (this._colorClass)
                this.remove_style_class_name(`claude-fg-${this._colorClass}`);
            this._colorClass = colorClass;
            this.add_style_class_name(`claude-fg-${colorClass}`);
        }
        this._mode = mode;
        this._sync();
        this.queue_repaint();
    }

    // a few frames a second, so an icon that moves for hours stays cheap
    _sync() {
        const moves = this._moving && glyphMoves(this._mode);
        if (moves && !this._timer) {
            this._timer = GLib.timeout_add(GLib.PRIORITY_LOW, 80, () => {
                this.queue_repaint();
                return GLib.SOURCE_CONTINUE;
            });
        } else if (!moves) {
            this._stop();
        }
    }

    _stop() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
        }
    }

    vfunc_repaint() {
        const cr = this.get_context();
        const [width, height] = this.get_surface_size();
        const size = Math.min(width, height);
        const c = this.get_theme_node().get_foreground_color();
        const ctx = new CairoCanvas(cr);
        ctx.translate((width - size) / 2, (height - size) / 2);
        ctx.scale(size / 24, size / 24);
        drawGlyph(ctx, this._mode, `rgba(${c.red},${c.green},${c.blue},${c.alpha / 255})`, Date.now());
        cr.$dispose();
    }
});

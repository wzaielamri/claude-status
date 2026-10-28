// A 2D canvas context over Cairo: the calls Talpy (talpy/talpy.js) and the
// panel icon (talpy/glyph.js) make, so GNOME Shell draws them with the same
// code as the Plasma widget and the VS Code extension.

import Cairo from 'cairo';

const colors = new Map();

// '#rrggbb', '#rgb', 'rgb(…)', 'rgba(…)' → [r, g, b, a] (0…1)
function parseColor(c) {
    let rgba = colors.get(c);
    if (rgba)
        return rgba;
    let m;
    if ((m = /^#([0-9a-f]{6})$/i.exec(c))) {
        const n = parseInt(m[1], 16);
        rgba = [(n >> 16 & 255) / 255, (n >> 8 & 255) / 255, (n & 255) / 255, 1];
    } else if ((m = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/i.exec(c))) {
        rgba = [m[1], m[2], m[3]].map(h => parseInt(h + h, 16) / 255).concat([1]);
    } else if ((m = /^rgba?\(([^)]*)\)$/.exec(c))) {
        const p = m[1].split(',').map(v => parseFloat(v));
        rgba = [p[0] / 255, p[1] / 255, p[2] / 255, p.length > 3 ? p[3] : 1];
    } else {
        rgba = [0, 0, 0, 1];
    }
    colors.set(c, rgba);
    return rgba;
}

export class CairoCanvas {
    constructor(cr) {
        this.cr = cr;
        this.s = {fillStyle: '#000', strokeStyle: '#000', lineWidth: 1, lineCap: 'butt', lineJoin: 'miter',
            globalAlpha: 1, font: '10px sans-serif', textAlign: 'start', textBaseline: 'alphabetic',
            globalCompositeOperation: 'source-over'};
        this.stack = [];
    }

    get fillStyle() { return this.s.fillStyle; }
    set fillStyle(v) { this.s.fillStyle = v; }
    get strokeStyle() { return this.s.strokeStyle; }
    set strokeStyle(v) { this.s.strokeStyle = v; }
    get lineWidth() { return this.s.lineWidth; }
    set lineWidth(v) { this.s.lineWidth = v; }
    get lineCap() { return this.s.lineCap; }
    set lineCap(v) { this.s.lineCap = v; }
    get lineJoin() { return this.s.lineJoin; }
    set lineJoin(v) { this.s.lineJoin = v; }
    get globalAlpha() { return this.s.globalAlpha; }
    set globalAlpha(v) { this.s.globalAlpha = v; }
    get font() { return this.s.font; }
    set font(v) { this.s.font = v; }
    get textAlign() { return this.s.textAlign; }
    set textAlign(v) { this.s.textAlign = v; }
    get textBaseline() { return this.s.textBaseline; }
    set textBaseline(v) { this.s.textBaseline = v; }
    get globalCompositeOperation() { return this.s.globalCompositeOperation; }
    set globalCompositeOperation(v) { this.s.globalCompositeOperation = v; }

    save() {
        this.cr.save();
        this.stack.push(Object.assign({}, this.s));
    }

    restore() {
        this.cr.restore();
        if (this.stack.length)
            this.s = this.stack.pop();
    }

    translate(x, y) { this.cr.translate(x, y); }
    // (a canvas draws nothing at a scale of 0, where Cairo's matrix can't be
    // inverted and the frame's drawing stops: a bulb's first frame)
    scale(x, y) { this.cr.scale(x || 1e-4, y || 1e-4); }
    rotate(r) { this.cr.rotate(r); }
    beginPath() { this.cr.newPath(); }
    moveTo(x, y) { this.cr.moveTo(x, y); }
    lineTo(x, y) { this.cr.lineTo(x, y); }
    bezierCurveTo(a, b, c, d, e, f) { this.cr.curveTo(a, b, c, d, e, f); }
    closePath() { this.cr.closePath(); }
    rect(x, y, w, h) { this.cr.rectangle(x, y, w, h); }

    clip() {
        this.cr.clip();
    }

    createLinearGradient(x0, y0, x1, y1) {
        const pattern = new Cairo.LinearGradient(x0, y0, x1, y1);
        return {
            pattern,
            addColorStop: (offset, color) => {
                const c = parseColor(color);
                pattern.addColorStopRGBA(offset, c[0], c[1], c[2], c[3]);
            },
        };
    }

    _source(style) {
        this.cr.setOperator(this.s.globalCompositeOperation === 'destination-out' ? Cairo.Operator.DEST_OUT : Cairo.Operator.OVER);
        if (typeof style === 'object' && style.pattern) {
            this.cr.setSource(style.pattern);
            return;
        }
        const c = parseColor(style);
        this.cr.setSourceRGBA(c[0], c[1], c[2], c[3] * this.s.globalAlpha);
    }

    fill() {
        this._source(this.s.fillStyle);
        this.cr.fillPreserve();
    }

    stroke() {
        this._source(this.s.strokeStyle);
        this.cr.setLineWidth(this.s.lineWidth);
        this.cr.setLineCap(this.s.lineCap === 'round' ? Cairo.LineCap.ROUND : this.s.lineCap === 'square'
            ? Cairo.LineCap.SQUARE : Cairo.LineCap.BUTT);
        this.cr.setLineJoin(this.s.lineJoin === 'round' ? Cairo.LineJoin.ROUND : this.s.lineJoin === 'bevel'
            ? Cairo.LineJoin.BEVEL : Cairo.LineJoin.MITER);
        this.cr.strokePreserve();
    }

    fillText(text, x, y) {
        const m = /(bold)?.*?([\d.]+)px/.exec(this.s.font);
        this.cr.selectFontFace('Sans', Cairo.FontSlant.NORMAL, m && m[1] ? Cairo.FontWeight.BOLD : Cairo.FontWeight.NORMAL);
        this.cr.setFontSize(m ? parseFloat(m[2]) : 10);
        const e = this.cr.textExtents(text);
        if (this.s.textAlign === 'center')
            x -= e.xBearing + e.width / 2;
        else if (this.s.textAlign === 'right' || this.s.textAlign === 'end')
            x -= e.xAdvance;
        if (this.s.textBaseline === 'middle')
            y -= e.yBearing + e.height / 2;
        this._source(this.s.fillStyle);
        this.cr.newPath();
        this.cr.moveTo(x, y);
        this.cr.showText(text);
        this.cr.newPath();
    }
}

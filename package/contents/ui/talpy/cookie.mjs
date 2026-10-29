// A cookie for the big Talpy (talpy.mjs), on its stage. Double-click the
// stage a little away from it and a cookie pops up there. Talpy sees it,
// jumps out of its burrow and goes after it on its feet; drag the cookie
// about and it follows, hold it up out of reach and it hops and stretches
// for it all the same (lower it a little as it jumps: it has it), within
// reach it jumps for it and takes it out of your hand. Once it has it, it
// eats it, or, stuffed, takes it down a new burrow for later, and digs in
// where it is. Kept away too long, it gets cross for a moment. The host
// draws the cookie (drawCookie in talpy.mjs) where `cookie` says, moves
// Talpy where this says, and keeps the tally (how many it ate, saved).
//
// Nothing here runs without a cookie: the host ticks it only while `on`.
//
//   const game = new CookieGame(talpy, host);
//   double-click at (x, y), stage pixels: game.place(x, y) (false: too close to it, or it's eating)
//   the cookie pressed, moved, let go: game.grab(x, y), game.drag(x, y), game.drop()
//   every tick while game.on: game.tick(now), after talpy.tick(now)
//   you picked Talpy up: game.picked(); it has landed and dug in: game.landed()
//   the stage shows again: game.surprise() (true: it digs up one it saved)
//
// host: {
//   stage(): { width, ground, unit (px a box unit), bodyWidth, bodyHeight, minX, maxX },
//   px(): where Talpy is (its centre); moveTo(x): it's there now (and digs nowhere else);
//   face(left): it turns;
//   say(what, n): its words for 'spot' 'wake' 'full' 'gimme' 'cross' 'aww', and once it has it
//     'first' 'milestone' 'yum' 'burp' (n: how many it has eaten), 'saved', 'found';
//   leaveHole(open): it left its burrow (that open, as setHeld): draw that hole where it was,
//     until fillHole();
//   tally(): { eaten, saved }; setTally(eaten, saved): kept for good;
//   changed(): what shows changed (on, chasing, the cookie);
//   instant(): no running about (less motion): it just has it }
//
// Plain ES2017 (see paths.mjs).

const R = 7;                 // the cookie's radius (box units)
const REACH = 26;            // how high its middle may be (box units over the floor) to take it standing,
const LEAP = 46;             // or jumping
const FULL = 5;              // cookies within FULL_MS that fill it up
const FULL_MS = 10 * 60000;
const CROSS_MS = 9000;       // after it that long (and you keep moving it): cross for a moment
export const MILESTONES = [10, 25, 50, 100, 250, 500, 1000];

const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const outBack = p => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
};

// What eating its n-th cookie is: 'first', 'milestone', 'full' (this one
// filled it up) or ''
export function cookieNews(n, full) {
    if (n === 1)
        return 'first';
    if (MILESTONES.indexOf(n) >= 0 || (n > 1000 && n % 1000 === 0))
        return 'milestone';
    return full ? 'full' : '';
}

// How many it ate, short enough for a corner: 999, then 1.2k, 12k (the
// tooltip says it in full)
export function cookieCount(n) {
    return n < 1000 ? String(n) : n < 10000 ? Math.floor(n / 100) / 10 + 'k' : Math.floor(n / 1000) + 'k';
}

export class CookieGame {
    constructor(talpy, host) {
        this.talpy = talpy;
        this.host = host;
        this.cookie = null;      // { x, y (its middle, stage px), r, scale, angle (deg), held }; null: none
        this.state = '';         // spot chase leap cross held eat, '' (nothing going on)
        this.on = false;         // something goes on: the host ticks it
        this.chasing = false;    // Talpy is on its feet after it (a host draws it live)
        this.ate = [];           // when it ate its last ones (Date.now(): it fills up)
        this.now = 0;
        this.last = 0;
        this.v = 0;              // how fast it runs (px/s, + to the right)
        this.since = 0;          // when the state began
        this.chaseAt = 0;        // when it set off (cross after a while)
        this.standAt = 0;        // when it stood still under it
        this.leapAt = -1e9;      // when it last jumped for it
        this.tries = 0;          // jumps in a row for one out of reach
        this.movedAt = -1e9;     // when you last moved the cookie
        this.saidAt = {};        // when it last said what (not over and over)
        this.grip = null;        // where you hold it, from its middle
        this.dragV = 0;          // how fast you move it (px/s), for its swing
        this.dragAt = 0;
        this.holeLeft = false;   // a hole it left shows: filled once it digs in again
    }

    // It ate FULL in the last FULL_MS
    get stuffed() {
        const now = Date.now();
        return this.ate.filter(t => now - t < FULL_MS).length >= FULL;
    }

    // Where a cookie can be: over the floor, on the stage, never where Talpy
    // can't get under it
    fit(x, y) {
        const g = this.host.stage(), r = R * g.unit, reach = g.bodyWidth * 0.4;
        return { x: clamp(x, Math.max(r, g.minX - reach), Math.min(g.width - r, g.maxX + reach)), y: clamp(y, r, g.ground - r) };
    }

    // Where the cookie is from Talpy's eyes: ahead, and up (-) or down
    look() {
        const c = this.cookie, g = this.host.stage();
        if (!c)
            return [0, 0];
        const ahead = (c.x - this.host.px()) * (this.talpy.facingLeft ? -1 : 1) / g.bodyWidth;
        return [clamp(ahead * 2, -1.8, 1.8), clamp((22 - (g.ground - c.y) / g.unit) / 12, -2, 1.4)];
    }

    say(what, n, every) {
        if (every && this.now - (this.saidAt[what] || -1e9) < every)
            return;
        this.saidAt[what] = this.now;
        this.host.say(what, n || 0);
    }

    // ------------------------------------------------------------ you

    // A double-click at (x, y): a cookie there (one already out moves there)
    place(x, y) {
        const t = this.talpy, g = this.host.stage();
        if (t.held || this.state === 'eat')
            return false;
        // (on it or right beside it: that's petting it)
        if (Math.abs(x - this.host.px()) < g.bodyWidth * 0.75 && y > g.ground - g.bodyHeight * 1.4)
            return false;
        const at = this.fit(x, y);
        const was = this.cookie;
        this.cookie = { x: at.x, y: at.y, r: R * g.unit, scale: 0, angle: 0, held: false, at: this.now };
        this.grip = null;
        this.on = true;
        if (was) {
            this.movedAt = this.now;
            this.host.changed();
            return true;
        }
        this.host.face(at.x < this.host.px());
        this.say(this.stuffed ? 'full' : t.mood === 'done' ? 'wake' : 'spot');
        if (this.host.instant()) {
            this.host.moveTo(clamp(at.x, g.minX, g.maxX));
            this.caught(false);
            return true;
        }
        this.state = 'spot';
        t.seeCookie(this.look(), ok => {
            if (ok && this.state === 'spot')
                this.go();
        });
        this.host.changed();
        return true;
    }

    // You took the cookie at (x, y): false if there's none to take
    grab(x, y) {
        const c = this.cookie;
        if (!c)
            return false;
        this.grip = { x: c.x - x, y: c.y - y };
        this.dragAt = Date.now();
        c.held = true;
        return true;
    }

    drag(x, y) {
        const c = this.cookie;
        if (!c || !this.grip)
            return;
        const at = this.fit(x + this.grip.x, y + this.grip.y), now = Date.now();
        this.dragV = 0.5 * this.dragV + 0.5 * (at.x - c.x) * 1000 / Math.max(16, now - this.dragAt);
        this.dragAt = now;
        c.x = at.x;
        c.y = at.y;
        this.movedAt = this.now;
        this.host.changed();
    }

    drop() {
        if (this.cookie)
            this.cookie.held = false;
        this.grip = null;
    }

    // You picked Talpy up (talpy.setHeld): it goes after it again once down
    picked() {
        if (!this.on)
            return;
        this.chasing = false;
        this.v = 0;
        this.holeLeft = false;   // (the host fills it as it lands)
        this.state = this.cookie ? 'held' : '';
        this.on = this.cookie !== null;
        this.host.changed();
    }

    // Down again and dug in
    landed() {
        if (this.state !== 'held' || !this.cookie)
            return;
        this.state = 'spot';
        this.host.face(this.cookie.x < this.host.px());
        this.talpy.seeCookie(this.look(), ok => {
            if (ok && this.state === 'spot')
                this.go();
        });
        this.host.changed();
    }

    // The stage shows again: now and then it digs up one it saved
    surprise() {
        const tally = this.host.tally(), t = this.talpy;
        if (this.on || tally.saved <= 0 || this.stuffed || t.held || t.mood === 'done' || Math.random() > 0.4)
            return false;
        this.host.setTally(tally.eaten + 1, tally.saved - 1);
        this.ate.push(Date.now());
        this.state = 'eat';
        this.on = true;
        t.digUp(() => this.ended());
        this.say('found');
        this.host.changed();
        return true;
    }

    // ------------------------------------------------------------ Talpy

    // Out of its burrow and after it
    go() {
        const left = this.talpy.chase();
        if (left > 0) {
            this.host.leaveHole(left);
            this.holeLeft = true;
        }
        this.state = 'chase';
        this.chasing = true;
        this.since = this.chaseAt = this.standAt = this.now;
        this.v = 0;
        this.host.changed();
    }

    tick(now) {
        const dt = this.last ? clamp(now - this.last, 0, 100) / 1000 : 0;
        this.last = this.now = now;
        const c = this.cookie;
        if (c) {
            // it pops up, and swings as you move it
            const p = clamp((now - c.at) / 300, 0, 1);
            c.scale = p >= 1 ? 1 : outBack(p);
            if (Date.now() - this.dragAt > 60)
                this.dragV *= Math.exp(-dt / 0.12);
            const swing = clamp(this.dragV / this.host.stage().unit * 0.12, -35, 35);
            c.angle += (swing - c.angle) * (1 - Math.exp(-dt / 0.08));
        }
        // it digs in again: the hole it left is filled
        if (this.state === 'eat' && this.holeLeft && this.talpy.holeOpen) {
            this.holeLeft = false;
            this.host.fillHole();
        }
        if (this.chasing && c)
            this.follow(dt, c);
        this.host.changed();
    }

    follow(dt, c) {
        const t = this.talpy, g = this.host.stage(), now = this.now;
        const up = (g.ground - c.y) / g.unit;   // box units over the floor
        let px = this.host.px();
        if (this.state === 'chase' && now - this.since < 450) {
            t.chaseAs('out', this.look());   // (out of its burrow first)
            return;
        }
        if (this.state === 'leap') {
            const ms = now - this.since;
            if (ms > 200 && ms < 560 && Math.abs(c.x - px) < g.bodyWidth * 0.6 && up <= LEAP + 4) {
                this.caught(true);
                return;
            }
            if (ms < 800) {
                // (drifts its way in the air)
                const d = clamp(c.x, g.minX, g.maxX) - px;
                this.host.moveTo(px + clamp(d, -g.bodyWidth * 2 * dt, g.bodyWidth * 2 * dt));
                t.chaseAs(this.tries > 0 ? 'reach' : 'leap', this.look());
                return;
            }
            this.state = 'chase';
            this.standAt = now;
            if (this.tries > 0 && this.tries % 4 === 0) {
                this.state = 'cross';
                this.since = now;
                t.chaseAs('pout');
                this.say('cross', 0, 4000);
                return;
            }
            this.say('aww', 0, 4000);
        }
        if (this.state === 'cross') {
            if (now - this.since < 1400) {
                t.chaseAs('pout');
                return;
            }
            this.state = 'chase';
            this.chaseAt = this.standAt = now;
        }
        // Running there: quicker the further it is, turning round when it's behind
        const max = g.bodyWidth * 4.2, acc = g.bodyWidth * 16;
        const d = clamp(c.x, g.minX, g.maxX) - px;
        this.v += clamp(clamp(d * 5, -max, max) - this.v, -acc * dt, acc * dt);
        px = clamp(px + this.v * dt, g.minX, g.maxX);
        this.host.moveTo(px);
        const running = Math.abs(this.v) > g.bodyWidth * 0.6;
        const left = Math.abs(this.v) > g.bodyWidth * 0.25 ? this.v < 0
                   : Math.abs(c.x - px) > g.bodyWidth * 0.1 ? c.x < px : t.facingLeft;
        if (left !== t.facingLeft)
            this.host.face(left);
        const close = Math.abs(c.x - px) < g.bodyWidth * 0.55;
        if (close && up <= REACH) {
            this.caught(false);
            return;
        }
        if (running || !close)
            this.standAt = now;
        // under it: it jumps for it; out of reach it tries all the same, now
        // and then, begging in between (and gets cross after a few)
        const high = up > LEAP;
        if (close && !running && now - this.standAt > 250 && now - this.leapAt > (high ? 900 : 0)) {
            this.state = 'leap';
            this.since = this.leapAt = now;
            this.v = 0;
            this.tries = high ? this.tries + 1 : 0;
            t.chaseAs(high ? 'reach' : 'leap', this.look());
            if (high && this.tries === 1)
                this.say('gimme', 0, 6000);
            return;
        }
        if (close && !running && high) {
            t.chaseAs('beg', this.look());
        } else {
            t.chaseAs(running ? 'run' : 'stand', this.look());
        }
        // kept away too long, you moving it about all the while
        if (now - this.chaseAt > CROSS_MS && now - this.movedAt < 1500) {
            this.state = 'cross';
            this.since = now;
            this.v = 0;
            t.chaseAs('pout');
            this.say('cross');
        }
    }

    // It has it (inAir: out of the air, or out of your hand)
    caught(inAir) {
        const t = this.talpy, tally = this.host.tally();
        this.cookie = null;
        this.grip = null;
        this.chasing = false;
        this.v = 0;
        this.state = 'eat';
        if (this.stuffed) {
            this.host.setTally(tally.eaten, tally.saved + 1);
            t.stash(() => this.ended());
            this.say('saved');
        } else {
            this.ate.push(Date.now());
            const n = tally.eaten + 1, news = cookieNews(n, this.stuffed);
            this.host.setTally(n, tally.saved);
            t.eat(news, inAir, () => this.ended());
            this.say(news === 'first' ? 'first' : news === 'milestone' ? 'milestone' : news === 'full' ? 'burp' : 'yum', n);
        }
        this.host.changed();
    }

    // (eaten or saved, or you picked it up meanwhile)
    ended() {
        if (this.state !== 'eat')
            return;
        this.state = '';
        this.on = this.cookie !== null;
        if (this.holeLeft && !this.talpy.held)
            this.host.fillHole();   // (it didn't dig in; held, it's filled as it lands)
        this.holeLeft = false;
        this.host.changed();
    }
}

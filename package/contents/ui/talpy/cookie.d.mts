// Types for cookie.mjs, for the VS Code extension's webview (TypeScript)

import type { Talpy } from "./talpy.mjs";

export const MILESTONES: number[];
export function cookieNews(n: number, full: boolean): "first" | "milestone" | "full" | "";
export function cookieCount(n: number): string;   // 999, then 1.2k, 12k

export interface CookieStage {
    width: number;
    ground: number;      // the floor, from the stage's top
    unit: number;        // px a box unit
    bodyWidth: number;
    bodyHeight: number;
    minX: number;        // where Talpy may be (its centre)
    maxX: number;
}

export type CookieWords = "spot" | "wake" | "full" | "gimme" | "cross" | "aww" | "first" | "milestone" | "yum" | "burp" | "saved" | "found";

export interface CookieHost {
    stage(): CookieStage;
    px(): number;
    moveTo(x: number): void;
    face(left: boolean): void;
    say(what: CookieWords, n: number): void;
    leaveHole(open: number): void;
    fillHole(): void;
    tally(): { eaten: number; saved: number };
    setTally(eaten: number, saved: number): void;
    changed(): void;
    instant(): boolean;
}

export interface Cookie {
    x: number;        // its middle, stage px
    y: number;
    r: number;        // its radius, px
    scale: number;    // popping up: 0 to 1 (a little over on the way)
    angle: number;    // degrees, as it swings
    held: boolean;    // in your hand
}

export class CookieGame {
    constructor(talpy: Talpy, host: CookieHost);
    readonly cookie: Cookie | null;
    readonly on: boolean;        // something goes on: tick it
    readonly chasing: boolean;   // Talpy is on its feet after it: draw it live
    readonly stuffed: boolean;
    place(x: number, y: number): boolean;
    grab(x: number, y: number): boolean;
    drag(x: number, y: number): void;
    drop(): void;
    picked(): void;
    landed(): void;
    surprise(): boolean;
    tick(now: number): void;
}

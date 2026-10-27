// A reaction that fails (a pet, a notification) must not stop the dashboard
// from taking in new status: the widget froze at every plan-limit reset when
// its reset reaction threw before the status was stored.

import assert from "node:assert/strict";
import { mock, test } from "node:test";
import type * as vscode from "vscode";
import type { Backend } from "../src/backend";
import { Dashboard } from "../src/dashboard";
import type { Notifier } from "../src/notify";
import { demoState } from "../src/shared/demo";
import type { Status } from "../src/shared/types";

const NOW = 1_800_000_000_000;

function withFiveHour(pct: number): Status {
  const status = structuredClone(demoState(NOW).status!);
  const windows = status.groups[0].limits!.windows;
  windows[0] = { ...windows[0], pct };
  return status;
}

test("the status keeps updating after a reaction to a limit reset throws", async () => {
  let next = withFiveHour(80);
  const backend = { status: async () => ({ status: next }) } as unknown as Backend;
  const notifier = { handle() {}, isLeader: () => true } as unknown as Notifier;
  const errors: string[] = [];
  const log = { warn() {}, info() {}, error: (m: string) => errors.push(m) } as unknown as vscode.LogOutputChannel;
  const dash = new Dashboard(backend, notifier, log);
  const resets: string[] = [];
  dash.onPetEvent((e) => {
    resets.push(e.kind);
    throw new Error("a pet fell over");
  });
  const fiveHour = () => dash.state().status!.groups[0].limits!.windows[0].pct;

  await dash.refresh();
  assert.equal(fiveHour(), 80);
  next = withFiveHour(2); // the 5-hour limit resets: the pets celebrate, and one throws
  await dash.refresh();
  assert.deepEqual(resets, ["reset"]);
  assert.equal(fiveHour(), 2, "the reset's status is stored");
  assert.equal(errors.length, 1, "the failure is logged");
  next = withFiveHour(3);
  await dash.refresh();
  assert.equal(fiveHour(), 3, "later polls still update");
  dash.dispose();
});

test("opening the view doesn't cancel the next try of a Python that didn't work", async () => {
  mock.timers.enable({ apis: ["setTimeout"] });
  try {
    let checks = 0;
    const backend = {
      checkPython: async () => (++checks === 1 ? "python3 doesn't work" : ""),
      status: async () => ({ status: demoState(NOW).status! }),
    } as unknown as Backend;
    const log = { warn() {}, info() {}, error() {} } as unknown as vscode.LogOutputChannel;
    const dash = new Dashboard(backend, { handle() {}, isLeader: () => true } as unknown as Notifier, log);
    await dash.start();
    dash.setVisible(true); // polls right away (its timer used to be the retry's too)
    mock.timers.tick(30000);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(checks, 2, "Python is checked again");
    dash.dispose();
  } finally {
    mock.timers.reset();
  }
});

test("a slow pollInterval isn't made faster while the view is hidden", async () => {
  mock.timers.enable({ apis: ["setTimeout"] });
  const { overrides } = await import("./vscode-stub");
  overrides.set("pollInterval", 30000);
  try {
    let polls = 0;
    const backend = {
      checkPython: async () => "",
      status: async () => (polls++, { status: demoState(NOW).status! }),
    } as unknown as Backend;
    const log = { warn() {}, info() {}, error() {} } as unknown as vscode.LogOutputChannel;
    const dash = new Dashboard(backend, { handle() {}, isLeader: () => true } as unknown as Notifier, log);
    await dash.start();
    mock.timers.tick(0);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(polls, 1);
    mock.timers.tick(10000); // hidden: not sooner than the setting
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(polls, 1, "no poll after 10 s");
    mock.timers.tick(20000);
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(polls, 2);
    dash.dispose();
  } finally {
    overrides.clear();
    mock.timers.reset();
  }
});

test("a host listed twice in the settings is one host", async () => {
  const { overrides } = await import("./vscode-stub");
  const { settings } = await import("../src/config");
  overrides.set("sshHosts", ["a", " b ", "a", ""]);
  try {
    assert.deepEqual(settings.sshHosts(), ["a", "b"]);
  } finally {
    overrides.clear();
  }
});

test("the Claude Code extension starting after this one is found without a reload", async () => {
  mock.timers.enable({ apis: ["setTimeout", "Date"] });
  const stub = await import("./vscode-stub");
  const getCommands = stub.commands.getCommands;
  let registered: string[] = []; // both start on onStartupFinished, in no set order
  stub.commands.getCommands = async () => registered;
  const settle = async () => {
    for (let i = 0; i < 5; i++) await new Promise((resolve) => setImmediate(resolve));
  };
  try {
    const backend = { checkPython: async () => "", status: async () => ({ status: demoState(NOW).status! }) } as unknown as Backend;
    const log = { warn() {}, info() {}, error() {} } as unknown as vscode.LogOutputChannel;
    const dash = new Dashboard(backend, { handle() {}, isLeader: () => true } as unknown as Notifier, log);
    dash.setVisible(true);
    await dash.start();
    await settle();
    assert.equal(dash.claudeCodeInfo().available, false);
    registered = ["claude-vscode.editor.open"]; // its activate ran a moment later
    for (let s = 0; s < 10; s++) {
      mock.timers.tick(2000);
      await settle();
    }
    assert.equal(dash.claudeCodeInfo().available, true, "a Claude Code tab can reopen chats");
    dash.dispose();
  } finally {
    stub.commands.getCommands = getCommands;
    mock.timers.reset();
  }
});

test("a setting checks again only what it changes: the chat tab's text size or a sound just redraws", async () => {
  const { changeSettings, overrides } = await import("./vscode-stub");
  const backend = { status: async () => ({ status: demoState(NOW).status! }), hostStatus: async () => ({ ok: false, error: "x" }) } as unknown as Backend;
  const log = { warn() {}, info() {}, error() {} } as unknown as vscode.LogOutputChannel;
  const dash = new Dashboard(backend, { handle() {}, isLeader: () => true } as unknown as Notifier, log);
  const checks: string[] = [];
  const d = dash as unknown as { scheduleLocal(delay?: number): void; scheduleHosts(delay?: number): void };
  d.scheduleLocal = (delay?: number) => void checks.push(`here ${delay ?? "at its pace"}`);
  d.scheduleHosts = (delay?: number) => void checks.push(`hosts ${delay ?? "at their pace"}`);
  let redraws = 0;
  dash.onState(() => redraws++);
  const change = (key: string, value: unknown) => {
    overrides.set(key, value);
    changeSettings(`talpyDen.${key}`);
    const done = checks.splice(0);
    return done;
  };
  try {
    for (const [key, value] of [["chatTextScale", 1.5], ["diffSideBySide", false], ["soundVolume", 20], ["showPet", false], ["notifyDone", false], ["sshUsage", "all"]] as const)
      assert.deepEqual(change(key, value), [], key);
    assert.equal(redraws, 6, "the view and the status bar take the new settings");
    assert.deepEqual(change("keepDoneHours", 48), ["here 0", "hosts 0"]);
    assert.deepEqual(change("showTokens", false), ["here 0", "hosts 0"]);
    assert.deepEqual(change("usageCap", 80), ["here 0"]);
    assert.deepEqual(change("extraConfigDirs", ["/srv/claude-team"]), ["here 0"]);
    assert.deepEqual(change("sshHosts", ["lab"]), ["hosts 0"]);
    assert.deepEqual(change("includeCurrentRemote", false), [], "(no window host here)");
    assert.deepEqual(change("pollInterval", 5000), ["here at its pace"]);
    assert.deepEqual(change("remotePollSeconds", 60), ["hosts at their pace"]);
    assert.deepEqual(change("pythonPath", "/usr/bin/python3.12"), ["here 0", "hosts 0"]);
    assert.deepEqual(change("pythonPath", "/usr/bin/python3.12"), [], "set again as it was");
  } finally {
    overrides.clear();
    dash.dispose();
  }
});

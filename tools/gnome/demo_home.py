#!/usr/bin/env python3
"""Fill a home folder with made-up Claude Code profiles and sessions, for
trying the GNOME extension in tools/gnome/shell.sh (it runs this inside the
container). Each "running" session is a sleeping process, so the status
script sees it alive. Nothing here is real data.

    python3 demo_home.py HOME
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

home = Path(sys.argv[1])
now = time.time()
day = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now - 3600)) + ".000Z"


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data if isinstance(data, str) else json.dumps(data))


def alive(profile):
    """(pid, procStart) of a new process that sleeps for good, on profile (its
    CLAUDE_CONFIG_DIR, as a claude started there has)."""
    env = dict(os.environ, CLAUDE_CONFIG_DIR=str(home / profile))
    p = subprocess.Popen(["sleep", "infinity"], start_new_session=True, env=env)
    stat = Path(f"/proc/{p.pid}/stat").read_text()
    return p.pid, stat[stat.rfind(")") + 2:].split()[19]


def session(profile, sid, name, folder, status, minutes_ago, more=(), **extra):
    pid, start = alive(profile)
    cwd = str(home / folder)
    os.makedirs(cwd, exist_ok=True)
    write(home / profile / "sessions" / f"{pid}.json", {
        "pid": pid, "procStart": start, "sessionId": sid, "cwd": cwd, "name": name,
        "kind": "interactive", "status": status, "startedAt": int((now - 3600) * 1000),
        "statusUpdatedAt": int((now - minutes_ago * 60) * 1000), **extra})
    transcript(profile, sid, folder, name, minutes_ago, more=more)
    return sid


def transcript(profile, sid, folder, title, minutes_ago, tokens=4000, more=()):
    cwd = str(home / folder)
    os.makedirs(cwd, exist_ok=True)
    project = home / profile / "projects" / cwd.replace("/", "-")
    lines = [{"type": "ai-title", "aiTitle": title},
             {"type": "user", "cwd": cwd, "timestamp": day, "message": {"content": title}},
             {"type": "assistant", "cwd": cwd, "timestamp": day, "requestId": f"req-{sid}",
              "message": {"id": f"msg-{sid}", "model": "claude-opus-5-5",
                          "usage": {"input_tokens": 1200, "output_tokens": tokens,
                                    "cache_read_input_tokens": tokens * 30, "cache_creation_input_tokens": 900}}},
             *more]
    path = project / f"{sid}.jsonl"
    write(path, "\n".join(json.dumps(line, separators=(",", ":")) for line in lines) + "\n")
    os.utime(path, (now - minutes_ago * 60, now - minutes_ago * 60))


def account(profile, label, uuid, org, display):
    write(home / profile / ".profile-name", label)
    write(home / profile / ".claude.json", {"oauthAccount": {"accountUuid": uuid, "organizationType": org,
                                                              "displayName": display}})


def history(profile, folders):
    lines = [json.dumps({"project": str(home / f), "timestamp": int((now - i * 600) * 1000)})
             for i, f in enumerate(folders)]
    write(home / profile / "history.jsonl", "\n".join(lines) + "\n")


def limits(profile, sid, five, week, context, model="Opus 5.5"):
    write(home / ".cache/talpy-den/statusline" / profile / f"{sid}.json", {
        "session_id": sid,
        "rate_limits": {"five_hour": {"used_percentage": five, "resets_at": int(now + 2 * 3600 + 900)},
                        "seven_day": {"used_percentage": week, "resets_at": int(now + 4 * 86400)}},
        "context_window": {"used_percentage": context},
        "model": {"display_name": model}})


# What the chats said last, what they're doing, their tasks and the files they changed
prompt = lambda text: {"type": "user", "timestamp": day, "message": {"role": "user", "content": text}}
said = lambda mid, blocks, stop=None: {"type": "assistant", "timestamp": day,
                                       "message": {"id": mid, "role": "assistant", "content": blocks, "stop_reason": stop}}
text = lambda t: {"type": "text", "text": t}
use = lambda name, inp: {"type": "tool_use", "id": "toolu_" + name, "name": name, "input": inp}
parser_work = [prompt("The parser crashes on an empty file. Fix it and add a test."),
               {"type": "file-history-snapshot", "messageId": "p1", "isSnapshotUpdate": False,
                "snapshot": {"messageId": "p1", "trackedFileBackups": {}}},
               said("m1", [text("Found it: `parse()` reads the first token before checking for one. Fixing that, then the tests.")]),
               said("m1", [use("Edit", {"file_path": str(home / "repos/parser/parser.py")})]),
               {"type": "file-history-delta", "snapshotMessageId": "p1", "trackingPath": "parser.py",
                "backup": {"backupFileName": "pp@v1", "version": 1, "realParentDir": str(home / "repos/parser")}},
               {"type": "file-history-delta", "snapshotMessageId": "p1", "trackingPath": "tests/test_empty.py",
                "backup": {"backupFileName": None, "version": 1, "realParentDir": str(home / "repos/parser/tests")}},
               {"type": "assistant", "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now - 240)) + ".000Z",
                "message": {"id": "m2", "role": "assistant", "model": "claude-opus-5-5",
                            "content": [use("Bash", {"command": "pytest -x tests/"})],
                            "usage": {"input_tokens": 300, "output_tokens": 2400, "cache_read_input_tokens": 180000,
                                      "cache_creation_input_tokens": 4000}}}]
release_wait = [prompt("Write the release notes for 2.4 from the merged PRs."),
                said("m1", [text("Here's a draft. I'll put it in CHANGELOG.md.")]),
                said("m1", [use("Write", {"file_path": str(home / "repos/site/CHANGELOG.md")})])]
api_done = [prompt("Why do the API tests time out on CI?"),
            said("m1", [text("All 42 API tests pass now. The client waited 30 s for a server that never started on CI: "
                             "the fixture now starts it and waits until it answers.\n\nWant me to open a PR?")], "end_turn")]
blog_done = [prompt("Tighten the intro of the garden post."),
             said("m1", [text("Done: the intro is two sentences now, and the photo caption moved under the photo.")], "end_turn")]

account(".claude-work", "work", "acct-work", "claude_team", "Sam")
account(".claude-personal", "personal", "acct-pro", "claude_max", "Sam")

fix = session(".claude-work", "9a1c7e2b-0000-4000-8000-000000000001", "fix parser", "repos/parser", "busy", 4,
              more=parser_work)
rel = session(".claude-work", "9a1c7e2b-0000-4000-8000-000000000002", "release notes", "repos/site", "waiting", 1,
              waitingFor="permission", more=release_wait)
session(".claude-work", "9a1c7e2b-0000-4000-8000-000000000003", "api tests", "repos/api", "idle", 12, more=api_done)
blog = session(".claude-personal", "9a1c7e2b-0000-4000-8000-000000000004", "blog draft", "notes/blog", "idle", 25,
               entrypoint="claude-vscode", more=blog_done)
write(home / ".claude-work/file-history" / fix / "pp@v1", "def parse(tokens):\n    first = tokens[0]\n")
write(home / "repos/parser/parser.py", "def parse(tokens):\n    if not tokens:\n        return None\n    first = tokens[0]\n")
write(home / "repos/parser/tests/test_empty.py", "def test_empty():\n    assert parse([]) is None\n")
for n, subject, status, active in ((1, "Find where the parser fails", "completed", ""),
                                   (2, "Fix the empty-file case", "completed", ""),
                                   (3, "Add a test for empty files", "in_progress", "Running the parser tests"),
                                   (4, "Check the other entry points", "pending", "")):
    write(home / ".claude-work/tasks" / fix / f"{n}.json", {"id": str(n), "subject": subject, "status": status,
                                                            "activeForm": active, "blocks": [], "blockedBy": []})
transcript(".claude-personal", "9a1c7e2b-0000-4000-8000-000000000005", "notes/garden", "garden planner", 300)
transcript(".claude-personal", "9a1c7e2b-0000-4000-8000-000000000006", "notes/trip", "trip to Lisbon", 1500)
transcript(".claude-work", "9a1c7e2b-0000-4000-8000-000000000007", "repos/site", "landing page copy", 2900)

# A background job working with two subagents, and one that failed
deploy = session(".claude-work", "9a1c7e2b-0000-4000-8000-000000000008", "deploy docs", "repos/site", "busy", 2,
                 kind="bg", jobId="job-deploy")
write(home / ".claude-work/jobs/job-deploy/state.json", {"state": "working", "sessionId": deploy,
                                                         "cwd": str(home / "repos/site")})
agents = home / ".claude-work/projects" / str(home / "repos/site").replace("/", "-") / deploy / "subagents"
iso = lambda t: time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(t)) + ".000Z"


def step(kind, content, minutes_ago, stop=None):
    """One entry of a subagent's transcript; its replies carry a model and usage."""
    message = {"role": kind, "content": content, "stop_reason": stop}
    if kind == "assistant":
        message.update(model="claude-haiku-5-5", id=f"msg-{minutes_ago}",
                       usage={"input_tokens": 300, "output_tokens": 400, "cache_read_input_tokens": 9000,
                              "cache_creation_input_tokens": 200})
    return {"type": kind, "timestamp": iso(now - minutes_ago * 60), "isSidechain": True, "message": message}


def call(n, name, inp, minutes_ago):
    return step("assistant", [{"type": "tool_use", "id": f"toolu_{n}", "name": name, "input": inp}], minutes_ago, "tool_use")


def result(n, text, minutes_ago):
    return step("user", [{"type": "tool_result", "tool_use_id": f"toolu_{n}", "content": text}], minutes_ago)


for agent_id, kind, description, lines in [
        ("a1", "Explore", "Check the links", [
            step("user", "Check every link in the built docs (build/): internal ones must point to a page that "
                         "exists, external ones must answer. Report the broken ones with the page they're on.", 9),
            call(1, "Bash", {"command": "npx linkinator ./build --recurse --format json > /tmp/links.json",
                             "description": "Crawl the built site"}, 9),
            result(1, "214 links scanned", 7),
            call(2, "Read", {"file_path": str(home / "repos/site/docs/install.md")}, 7),
            result(2, "# Install\n...", 7),
            call(3, "Grep", {"pattern": "](/guide/", "path": str(home / "repos/site/docs")}, 6),
            result(3, "docs/index.md:12", 6),
            call(4, "SubagentHandback", {"message": "All 214 links work.\n\n- 198 internal links point to pages "
                                                    "that exist\n- 16 external links answered 200\n\nNothing to fix."}, 5),
            result(4, "ok", 5)]),
        ("a2", "general-purpose", "Build the site", [
            step("user", "Build the docs site for production (npm ci, then npm run build) and tell me about any "
                         "warning the build prints.", 4),
            call(5, "Bash", {"command": "npm ci", "description": "Install the dependencies"}, 4),
            result(5, "added 412 packages in 9s", 3),
            call(6, "Read", {"file_path": str(home / "repos/site/package.json")}, 3),
            result(6, "{ \"name\": \"site\" }", 3),
            call(7, "Bash", {"command": "npm run build", "description": "Build the site"}, 2)])]:
    write(agents / f"agent-{agent_id}.meta.json", {"agentType": kind, "description": description,
                                                    "spawnDepth": 1, "toolUseId": "toolu_" + agent_id,
                                                    "requestShape": "background"})
    write(agents / f"agent-{agent_id}.jsonl", "\n".join(json.dumps(line, separators=(",", ":")) for line in lines) + "\n")
write(home / ".claude-work/jobs/job-lint/state.json", {
    "state": "failed", "tempo": "idle", "name": "lint everything", "cwd": str(home / "repos/api"),
    "sessionId": "9a1c7e2b-0000-4000-8000-000000000009", "detail": "eslint: 3 errors in src/routes.ts",
    "createdAt": iso(now - 1800), "updatedAt": iso(now - 600)})

history(".claude-work", ["repos/parser", "repos/site", "repos/api"])
history(".claude-personal", ["notes/blog", "notes/garden"])


# The last days, for the stats: earlier chats' replies (with their usage) and
# your prompts, spread over two weeks
def past_work(profile, folder, sid, days, title, asks=(), limit=False):
    """A finished chat in folder with a reply on each of days (days ago: output tokens); on
    the last, asks: [(tool, input, seconds you took to allow it)]; limit: one stopped the day before."""
    cwd = str(home / folder)
    os.makedirs(cwd + "/.git", exist_ok=True)
    lines = [{"type": "ai-title", "aiTitle": title, "sessionId": sid}]
    for n, (ago, output) in enumerate(days):
        t = now - ago * 86400 - 3600
        start = t - 600 - output % 7 * 300  # your prompt, then Claude's turn (for the Week tab)
        lines.append({"type": "user", "cwd": cwd, "timestamp": iso(start), "uuid": f"u-{sid}-{n}",
                      "origin": {"kind": "human"}, "message": {"role": "user", "content": "Go on with the next step"}})
        lines.append({"type": "assistant", "cwd": cwd, "timestamp": iso(t), "message": {
            "id": f"msg-{sid}-{n}", "model": "claude-haiku-5-5" if n % 5 == 4 else "claude-opus-5-5",
            "usage": {"input_tokens": 900, "output_tokens": output, "cache_read_input_tokens": output * 40,
                      "cache_creation_input_tokens": 700}}})
        # (for the Recap tab: permission prompts you answered, and a usage limit)
        for k, (tool, inp, waited) in enumerate(asks if n == len(days) - 1 else ()):
            at = start + 30 + k * 200
            lines.append({"type": "assistant", "cwd": cwd, "timestamp": iso(at), "message": {
                "id": f"msg-{sid}-{n}-ask{k}", "model": "claude-opus-5-5", "content": [
                    {"type": "tool_use", "id": f"t-{sid}-{k}", "name": tool, "input": inp}],
                "usage": {"input_tokens": 10, "output_tokens": 50, "cache_read_input_tokens": 4000}}})
            lines.append({"type": "user", "cwd": cwd, "timestamp": iso(at + waited), "uuid": f"u-{sid}-{n}-ask{k}",
                          "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": f"t-{sid}-{k}",
                                                                    "content": "ok"}]},
                          "permissionDecision": {"decision": "accept", "source": "user_temporary"}})
        if limit and n == len(days) - 2:
            lines.append({"type": "assistant", "cwd": cwd, "timestamp": iso(t - 120), "isApiErrorMessage": True, "message": {
                "id": f"msg-{sid}-{n}-limit", "model": "<synthetic>", "role": "assistant",
                "content": [{"type": "text", "text": "You've hit your session limit · resets 7pm"}],
                "usage": {"input_tokens": 0, "output_tokens": 0}}})
        lines.append({"type": "system", "subtype": "turn_duration", "cwd": cwd, "timestamp": iso(t + 20),
                      "durationMs": int((t + 20 - start) * 1000)})
    path = home / profile / "projects" / cwd.replace("/", "-") / f"{sid}.jsonl"
    write(path, "\n".join(json.dumps(line, separators=(",", ":")) for line in lines) + "\n")


past_work(".claude-work", "repos/parser", "9a1c7e2b-0000-4000-8000-000000000011",
          [(13, 9000), (12, 30000), (9, 21000), (8, 52000), (6, 18000), (2, 41000), (1, 26000)], "Parser rewrite",
          [("Read", {"file_path": str(home / "repos/site/src/grammar.ts")}, 140),
           ("Read", {"file_path": str(home / "repos/site/README.md")}, 40),
           ("Bash", {"command": "git status --short"}, 25)], limit=True)
past_work(".claude-work", "repos/site", "9a1c7e2b-0000-4000-8000-000000000012",
          [(12, 8000), (7, 15000), (5, 12000), (2, 9000)], "Site redesign",
          [("Edit", {"file_path": str(home / "repos/site/index.html"), "old_string": "a", "new_string": "b"}, 60)])
past_work(".claude-work", "repos/api", "9a1c7e2b-0000-4000-8000-000000000013", [(9, 6000), (3, 22000), (1, 14000)],
          "API pagination")
past_work(".claude-personal", "notes/garden", "9a1c7e2b-0000-4000-8000-000000000014", [(10, 5000), (4, 3000)],
          "Garden notes")
with open(home / ".claude-work/history.jsonl", "a") as f:
    for ago, folder, n in ((13, "repos/parser", 3), (12, "repos/parser", 8), (12, "repos/site", 2), (9, "repos/api", 2),
                           (8, "repos/parser", 11), (7, "repos/site", 4), (6, "repos/parser", 5), (5, "repos/site", 3),
                           (3, "repos/api", 6), (2, "repos/parser", 9), (1, "repos/api", 4), (1, "repos/parser", 7)):
        for i in range(n):
            f.write(json.dumps({"project": str(home / folder), "timestamp": int((now - ago * 86400 - i * 300) * 1000)}) + "\n")
limits(".claude-work", fix, 64, 31, 42)
limits(".claude-work", rel, 64, 31, 88)
limits(".claude-personal", blog, 12, 7, 23, "Sonnet 5.5")
write(home / ".ssh/config", "Host lab\n  HostName lab.example.com\n  User sam\n\nHost gpu\n  ProxyJump lab\n")
print("demo home ready:", home)

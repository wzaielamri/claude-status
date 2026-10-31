"""A chat's tasks in its chat window (Plasma's ChatPane.qml) and its tab
(VS Code's chat.tsx): a strip under the header, a progress bar and
"3/7 · what it's on", folded; unfolded, the tasks and the subagents with what
each does now. Hidden without a task list; the list is made only when
unfolded, so the window opens as quickly."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = (ROOT / "package/contents/ui/ChatPane.qml").read_text()
CHAT = (ROOT / "vscode/webview/chat.tsx").read_text()


class PlasmaStripTests(unittest.TestCase):
    def strip(self):
        start = PANE.index("// Its tasks, when it has a task list")
        return PANE[start:PANE.index("// Chat | Steps | Review", start)]

    def test_it_shows_only_with_a_task_list_and_folds_shut_for_each_chat(self):
        self.assertIn("readonly property var tasks: row && row.tasks && row.tasks.total > 0 ? row.tasks : null", PANE)
        self.assertIn("visible: pane.tasks !== null", self.strip())
        reset = PANE[PANE.index("function reset() {"):PANE.index("}", PANE.index("function reset() {"))]
        self.assertIn("tasksOpen = false", reset)

    def test_its_list_is_made_only_when_unfolded(self):
        strip = self.strip()
        loader = strip[strip.index("Loader {"):]
        self.assertIn("active: pane.tasksOpen && pane.tasks !== null", loader)
        self.assertIn("pane.tasks.items", loader)          # the tasks
        self.assertIn("pane.taskAgents", loader)           # and the subagents
        self.assertNotIn("Repeater", strip[:strip.index("Loader {")])
        # (the subagents are sorted only when unfolded)
        self.assertRegex(PANE, r"taskAgents: !tasksOpen \|\| !row \|\| !row\.agents \? \[\]")

    def test_its_line_says_how_far_and_what_its_on(self):
        strip = self.strip()
        self.assertIn('"%1/%2 · %3", pane.tasks.done, pane.tasks.total', strip)
        self.assertIn("pane.tasks.current", strip)
        self.assertIn("Icons.plasma.unfolded : Icons.plasma.folded", strip)   # (the folds' arrows, A1)
        self.assertIn("activeFocusOnTab: true", strip)                        # (and the keyboard's)


class VsCodeStripTests(unittest.TestCase):
    def test_the_tab_gets_the_rows_tasks(self):
        pane_ts = (ROOT / "vscode/src/chatPane.ts").read_text()
        self.assertIn("tasks: session?.tasks && session.tasks.total > 0 ? session.tasks : null", pane_ts)
        self.assertIn('tasks: Session["tasks"];', (ROOT / "vscode/src/shared/pane.ts").read_text())

    def test_it_shows_only_with_a_task_list_and_lists_only_when_unfolded(self):
        self.assertIn("{chat?.tasks ? <TaskStrip key={chat.chatId}", CHAT)   # (a new chat: folded again)
        strip = CHAT[CHAT.index("function TaskStrip("):CHAT.index("function gapOf(")]
        self.assertIn("useState(false)", strip)
        self.assertRegex(strip, r"const tree = open && agents \?")
        self.assertRegex(strip, re.compile(r"\{open \? \(\s*<ul class=\"pane-tasks-list\">", re.S))
        self.assertIn("{tasks.done}/{tasks.total} · {now}", strip)
        self.assertIn("I.folded", strip)


if __name__ == "__main__":
    unittest.main()

"""A row's buttons (HoverButtons.qml) show on hover, and also for the
keyboard and a finger, which can't hover: while the line's name or one of its
buttons has the keyboard's focus (Tab), and after a press and hold
(TouchHold.qml). A mouse does what it did."""
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from test_pets import NEEDS_PLASMA_QML

UI = Path(__file__).resolve().parent.parent / "package/contents/ui"

LINE = """import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import "%s"
Item {
    id: root
    width: 400; height: 100
    property bool dashboardShown: true
    property string log: ""
    function note(s) { log = log + s + " " }
    ColumnLayout {
        width: 400
        RowLayout {
            Layout.fillWidth: true
            HoverHandler { id: lineHover }
            TouchHold { buttons: lineButtons }
            PlasmaComponents3.Label {
                id: name
                text: "a chat"
                Layout.preferredWidth: 150
                activeFocusOnTab: true
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!lineButtons.holding) root.note("click")
                    TouchHold { buttons: lineButtons }
                }
            }
            Item { Layout.fillWidth: true; implicitHeight: 20 }
            HoverButtons {
                id: lineButtons
                lineHeight: 20
                shown: lineHover.hovered || name.activeFocus || lineButtons.focused || lineButtons.held
                onShownChanged: root.note(shown ? "shown" : "hidden")
                PlasmaComponents3.ToolButton { text: "1"; Layout.preferredWidth: 30; onActiveFocusChanged: if (activeFocus) root.note("b1") }
                PlasmaComponents3.ToolButton { text: "2"; Layout.preferredWidth: 30; onActiveFocusChanged: if (activeFocus) root.note("b2") }
            }
        }
        PlasmaComponents3.Label { text: "after"; activeFocusOnTab: true; onActiveFocusChanged: if (activeFocus) root.note("after") }
    }
}
"""

SCRIPT = """import sys
from PySide6.QtCore import QUrl, QPoint, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
app = QGuiApplication(sys.argv)
view = QQuickView(); view.setSource(QUrl.fromLocalFile(sys.argv[1]))
if view.status() != QQuickView.Ready:
    sys.exit(str([e.toString() for e in view.errors()]))
view.show(); QTest.qWaitForWindowExposed(view); view.requestActivate(); QTest.qWait(100)
r = view.rootObject()
QTest.mouseMove(view, QPoint(390, 90)); QTest.qWait(100)
touch = QTest.createTouchDevice()
name, beside = QPoint(20, 10), QPoint(250, 10)
def hold(at, ms):
    QTest.touchEvent(view, touch).press(0, at, view).commit(); QTest.qWait(ms)
    QTest.touchEvent(view, touch).release(0, at, view).commit()
def mouse_hold(at, ms):
    QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, at); QTest.qWait(ms)
    QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, at)
steps = [lambda: QTest.keyClick(view, Qt.Key_Tab)] * 4 + [
    lambda: hold(name, 1200), lambda: hold(beside, 1200), lambda: hold(beside, 1200),
    lambda: r.setProperty("dashboardShown", False), lambda: mouse_hold(name, 1200)]
for step in steps:
    r.setProperty("log", ""); step(); QTest.qWait(300); print(repr(r.property("log").strip()))
"""


@NEEDS_PLASMA_QML
class RowButtonsTests(unittest.TestCase):
    def test_the_keyboard_and_a_finger_get_a_rows_buttons_too(self):
        with tempfile.TemporaryDirectory() as tmp:
            qml = Path(tmp) / "line.qml"
            qml.write_text(LINE % UI.as_uri())
            out = subprocess.run(["python3", "-c", SCRIPT, str(qml)], capture_output=True, text=True, timeout=60,
                                 env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
        steps = [eval(line) for line in out.stdout.split("\n") if line]
        self.assertEqual(steps, [
            "shown",          # Tab: on the name
            "b1", "b2",       # then on its buttons, which stay
            "hidden after",   # and past them
            "shown",          # a finger holds the name: no click, and they stay
            "hidden", "shown",  # held again, beside it: gone; and back
            "hidden",         # the popup hides
            "shown click",    # a mouse on the name shows them (hover) and, held, still clicks
        ], out.stderr[-2000:])

    def test_every_line_with_buttons_shows_them_for_the_keyboard_and_a_finger(self):
        # a chat's row, a recent chat's, a plan's and a memory's line
        rows = (UI / "SessionRow.qml").read_text() + (UI / "GroupSection.qml").read_text()
        for name, buttons, mouse in (("nameLabel", "rowButtons", "nameMouse"), ("recentName", "recentButtons", "recentMouse"),
                                     ("planName", "planButtons", "planMouse"), ("memoryName", "memoryButtons", "memoryMouse")):
            with self.subTest(buttons):
                self.assertRegex(rows, r"%s\.activeFocus \|\| %s\.focused \|\| %s\.held" % (name, buttons, buttons))
                self.assertEqual(len(re.findall(r"TouchHold \{\s+buttons: %s\s+\}" % buttons, rows)), 2)
                self.assertIn("if (!%s.holding)" % buttons, rows)
                label = rows[rows.index("id: %s\n" % name):rows.index("id: %s\n" % mouse)]
                self.assertIn("activeFocusOnTab: true", label)
                self.assertIn("Keys.onReturnPressed", label)


if __name__ == "__main__":
    unittest.main()

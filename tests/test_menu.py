"""A right-click on the dashboard on the desktop opens the widget's menu
(MenuCatcher.qml): the dashboard is a Page (PlasmaExtras.Representation) and
its lists ScrollViews, which take every mouse button, so Plasma's desktop
never got the right press. The catcher lies over it all and takes the right
button only: a left click, the wheel and a right click in a text field go to
what's under it, as before."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from test_pets import NEEDS_PLASMA_QML

UI = Path(__file__).resolve().parent.parent / "package/contents/ui"

PAGE = """import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import "%s"
Item {
    id: root
    width: 400; height: 300
    property string log: ""
    function note(s) { log = log + s + " " }
    // the desktop under the widget: it would open the widget's menu on a right press
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: root.note("desktop")
    }
    PlasmaExtras.Representation {
        id: full
        anchors.fill: parent
        header: PlasmaExtras.PlasmoidHeading {
            PlasmaComponents3.TextField { id: field; width: 200; placeholderText: "search" }
        }
        PlasmaComponents3.ScrollView {
            anchors.fill: parent
            ListView {
                model: 20
                delegate: MouseArea {
                    width: 380; height: 20
                    onClicked: root.note("row" + index)
                    onWheel: wheel => { root.note("wheel"); wheel.accepted = false }
                    PlasmaComponents3.Label { text: "row " + index }
                }
            }
        }
        Loader {
            parent: full
            anchors.fill: parent
            z: 1000
            sourceComponent: MenuCatcher {
                covers: full
                onMenu: at => root.note("menu")
            }
        }
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
r = view.rootObject()
view.show(); QTest.qWaitForWindowExposed(view); QTest.qWait(200)
row, field, empty = QPoint(100, 80), QPoint(60, 20), QPoint(300, 20)
steps = [
    lambda: QTest.mouseClick(view, Qt.RightButton, Qt.NoModifier, row),     # on a list's line
    lambda: QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, row),      # a left click
    lambda: QTest.mouseClick(view, Qt.RightButton, Qt.NoModifier, empty),   # on the heading, beside the field
    lambda: QTest.mouseClick(view, Qt.RightButton, Qt.NoModifier, field),   # in the text field
]
for step in steps:
    r.setProperty("log", ""); step(); QTest.qWait(200); print(repr(r.property("log").strip()))
"""


@NEEDS_PLASMA_QML
class MenuCatcherTests(unittest.TestCase):
    def test_a_right_click_anywhere_but_in_a_text_field_opens_the_menu(self):
        with tempfile.TemporaryDirectory() as tmp:
            qml = Path(tmp) / "page.qml"
            qml.write_text(PAGE % UI.as_uri())
            out = subprocess.run(["python3", "-c", SCRIPT, str(qml)], capture_output=True, text=True, timeout=60,
                                 env=dict(os.environ, QT_QPA_PLATFORM="offscreen"))
        steps = [eval(line) for line in out.stdout.split("\n") if line]
        self.assertRegex(steps[1] if len(steps) > 1 else "", r"^row\d+$")   # a left click goes to the line, as before
        steps[1:2] = ["row"]
        self.assertEqual(steps, [
            "menu",   # a right click on a list's line: the menu
            "row",
            "menu",   # on the heading too
            "",       # in the text field: its own menu (not the widget's, nor the desktop's)
        ], out.stderr[-2000:])

    def test_the_dashboard_has_it_on_the_desktop_only(self):
        full = (UI / "FullRepresentation.qml").read_text()
        catcher = full[full.index("sourceComponent: MenuCatcher {") - 200:]
        self.assertIn("parent: full", catcher)          # (over the heading too, not only the page's content)
        self.assertIn("active: root.onDesktop", catcher)  # (in the panel's popup Plasma has none either)
        self.assertIn("z: 1000", catcher)
        main = (UI / "main.qml").read_text()
        menu = main[main.index("function openWidgetMenu("):main.index("function openHostsMenu(")]
        self.assertIn("Plasmoid.contextualActions", menu)
        self.assertIn('Plasmoid.internalAction("configure")', menu)
        self.assertIn("action.visible", menu)


if __name__ == "__main__":
    unittest.main()

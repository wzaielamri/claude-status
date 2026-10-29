import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A row's buttons, shown on hover over the right end of its line, as in the
// VS Code extension: they take no room, so what stands at the end (a chat's
// state; a folder and how long ago: a CoveredEnd) stays there, its end
// covered while they show. Where they reach past it, over a name or tags,
// the popup's ground is under them, so they don't sit on the words. Put it
// last in the line's RowLayout.
Item {
    id: hover

    property bool shown: false
    property Item under: null               // what stands at the line's end
    default property alias buttons: row.data
    // how much of the line's end they cover now (CoveredEnd.covered)
    readonly property real covering: shown ? row.width + Kirigami.Units.smallSpacing : 0

    Layout.alignment: Qt.AlignTop
    Layout.preferredWidth: 0
    Layout.leftMargin: parent && parent.spacing !== undefined ? -parent.spacing : 0
    implicitHeight: row.implicitHeight
    z: 1

    Rectangle {
        anchors.left: row.left
        anchors.top: row.top
        anchors.bottom: row.bottom
        anchors.leftMargin: -Kirigami.Units.smallSpacing
        width: Math.max(0, row.width - (hover.under ? hover.under.width : 0) + Kirigami.Units.smallSpacing)
        visible: row.visible && width > Kirigami.Units.smallSpacing
        opacity: row.opacity
        color: Kirigami.Theme.backgroundColor
    }
    RowLayout {
        id: row
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Kirigami.Units.smallSpacing
        opacity: hover.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }
}

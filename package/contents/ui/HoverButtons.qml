import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A row's buttons, shown on hover over the right end of its line, as in the
// VS Code extension: they take no room, so what stands at the end (a chat's
// state; a folder and how long ago: a CoveredEnd) stays there, its end
// covered while they show, and nothing is drawn behind them (over a popup
// that shows the desktop through, a ground of their own was a dark box).
// Where they reach past it, the row cuts what's under them (beyond). Put it
// last in the line's RowLayout; its buttons take buttonSize.
Item {
    id: hover

    property bool shown: false
    property Item under: null               // what stands at the line's end
    property real lineHeight: 0             // the line's (the buttons are centered on it, a little taller)
    default property alias buttons: row.data
    readonly property real buttonSize: Math.round(Kirigami.Units.iconSizes.small * 1.375)   // (22 px high, 16 px icons: as in VS Code)
    readonly property real buttonWidth: Kirigami.Units.iconSizes.small + 4                  // (packed close: 2 px each side)
    // how much of the line's end they cover now (CoveredEnd.covered), and how
    // far past what stands there
    readonly property real covering: shown ? row.width : 0   // (cut where the first one starts)
    readonly property real beyond: Math.max(0, covering - (under ? under.width : 0))

    Layout.alignment: Qt.AlignTop
    Layout.preferredWidth: 0
    Layout.leftMargin: parent && parent.spacing !== undefined ? -parent.spacing : 0
    implicitHeight: lineHeight > 0 ? lineHeight : row.implicitHeight
    z: 1

    RowLayout {
        id: row
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        opacity: hover.shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }
}

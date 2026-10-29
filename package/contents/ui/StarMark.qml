import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore

// The ★ after a starred chat's or plan's name, as in the VS Code extension
// (a click unstars it; its row's hover buttons star one that isn't)
PlasmaComponents3.Label {
    id: mark

    property string tooltip
    signal clicked()

    textFormat: Text.PlainText
    text: "★"
    color: "#e0a800"
    opacity: markMouse.containsMouse ? 0.7 : 1

    PlasmaCore.ToolTipArea {
        textFormat: Text.PlainText
        anchors.fill: parent
        mainText: i18n("Starred")
        subText: mark.tooltip

        MouseArea {
            id: markMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mark.clicked()
        }
    }
}

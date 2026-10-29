import QtQuick
import QtQuick.Window
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// A tooltip over what it fills, for what shows both in the popup and in the
// chat pane: Plasma's in the popup; in the chat pane, a window of its own
// that Plasma's would show at the screen's edge, one drawn in that window,
// beside what you hover. Children (a MouseArea) as in PlasmaCore.ToolTipArea.
Item {
    id: tip

    property string mainText
    property string subText
    property bool active: true
    property int textFormat: Text.PlainText
    readonly property bool inPane: Window.window !== null && Window.window.objectName === "talpyDenChatPane"

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: tip.active && !tip.inPane
        textFormat: tip.textFormat
        mainText: tip.mainText
        subText: tip.subText
    }
    HoverHandler {
        id: hover
        enabled: tip.inPane
    }
    PlasmaComponents3.ToolTip {
        visible: tip.inPane && tip.active && hover.hovered && (tip.mainText !== "" || tip.subText !== "")
        delay: Kirigami.Units.toolTipDelay
        text: tip.subText ? tip.mainText + "\n" + tip.subText : tip.mainText
    }
}

import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Small outlined label, e.g. the profile or "VS Code" next to a session name.
Rectangle {
    id: tag

    property alias text: label.text
    property string tooltip
    property string tooltipTitle: label.text
    property bool active: false     // outlined in the highlight colour
    property bool warning: false    // outlined and written in the negative colour
    property bool clickable: false
    signal clicked()

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: label.implicitHeight
    radius: Kirigami.Units.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: warning ? Kirigami.Theme.negativeTextColor : active ? Kirigami.Theme.focusColor
                  : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        color: tag.warning ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        opacity: tag.warning ? 1 : 0.8
    }

    TipArea {
        textFormat: Text.PlainText
        anchors.fill: parent
        active: tag.tooltip !== ""
        mainText: tag.tooltipTitle
        subText: tag.tooltip

        MouseArea {
            anchors.fill: parent
            enabled: tag.clickable
            cursorShape: tag.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tag.clicked()
        }
    }
}

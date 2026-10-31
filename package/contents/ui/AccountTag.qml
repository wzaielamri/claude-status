import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// The account a line is on, in a project that's on several (ProjectsView.qml):
// drawn as a Tag, without its tooltip (one on every line made a project slow
// to open; its name says it)
Rectangle {
    property alias text: label.text

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: label.implicitHeight
    radius: Kirigami.Units.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3)

    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }
}

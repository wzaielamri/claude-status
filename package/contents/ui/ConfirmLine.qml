import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// "Do this?" with a button that does it and one that doesn't.
RowLayout {
    id: confirm

    property alias text: question.text
    property string confirmText: i18n("Yes")
    property string cancelText: i18n("Cancel")
    signal confirmed()
    signal cancelled()

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Label {
        id: question
        textFormat: Text.PlainText
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Kirigami.Theme.neutralTextColor
    }
    PlasmaComponents3.Button {
        text: confirm.confirmText
        onClicked: confirm.confirmed()
    }
    PlasmaComponents3.Button {
        text: confirm.cancelText
        onClicked: confirm.cancelled()
    }
}

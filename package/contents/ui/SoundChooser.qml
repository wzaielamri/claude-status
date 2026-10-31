import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import "icons.mjs" as Icons

// Picks a notification sound: one of the sound theme's sounds, none, or a
// file. value is what notify_sound.py takes (theme names, comma separated
// alternatives, or a path).
RowLayout {
    id: chooser

    property string value: ""
    signal preview(string sound)

    readonly property var presets: [
        { text: i18n("Message"), value: "message-new-instant" },
        { text: i18n("Success"), value: "outcome-success,complete" },
        { text: i18n("Complete"), value: "complete" },
        { text: i18n("Bell"), value: "bell" },
        { text: i18n("Attention"), value: "window-attention" },
        { text: i18n("Question"), value: "dialog-question,dialog-information" },
        { text: i18n("Information"), value: "dialog-information" },
        { text: i18n("Warning"), value: "dialog-warning" },
        { text: i18n("Error"), value: "dialog-error" },
        { text: i18n("No sound"), value: "" },
        { text: i18n("Sound file…"), value: "<file>" }
    ]
    readonly property int presetIndex: presets.findIndex(p => p.value === value)
    readonly property bool isFile: presetIndex < 0

    function syncCombo() {
        combo.currentIndex = Qt.binding(() => chooser.isFile ? chooser.presets.length - 1 : chooser.presetIndex)
    }

    spacing: Kirigami.Units.smallSpacing

    QQC2.ComboBox {
        id: combo
        model: chooser.presets
        textRole: "text"
        currentIndex: chooser.isFile ? chooser.presets.length - 1 : chooser.presetIndex
        onActivated: index => {
            const v = chooser.presets[index].value
            if (v === "<file>")
                fileDialog.open()
            else
                chooser.value = v
            chooser.syncCombo()
        }
    }
    QQC2.Label {
        visible: chooser.isFile
        text: chooser.value.split("/").pop()
        elide: Text.ElideMiddle
        Layout.maximumWidth: Kirigami.Units.gridUnit * 8
    }
    QQC2.ToolButton {
        icon.name: Icons.plasma.startNow
        enabled: chooser.value !== ""
        display: QQC2.AbstractButton.IconOnly
        text: i18n("Play this sound")
        onClicked: chooser.preview(chooser.value)
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
    }
    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a sound file")
        nameFilters: [i18n("Sound files (*.oga *.ogg *.wav *.flac *.mp3)"), i18n("All files (*)")]
        onAccepted: {
            chooser.value = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            chooser.syncCombo()
        }
        onRejected: chooser.syncCombo()
    }
}

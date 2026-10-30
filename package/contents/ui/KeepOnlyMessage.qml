import QtQuick
import org.kde.kirigami as Kirigami

// Asks before a shared chat is kept on one account only (the others lose it).
// Made only while it's asked (shown): one under every line made a list slow
// to open. Made hidden, then shown, so it fades in as an InlineMessage does.
Loader {
    id: keep

    property bool shown: false

    active: shown
    visible: shown
    onLoaded: item.visible = Qt.binding(() => keep.shown)

    sourceComponent: Kirigami.InlineMessage {
        visible: false
        type: Kirigami.MessageType.Warning
        // rich text (an InlineMessage always guesses), so the names are escaped
        text: "<span>" + i18n("Keep “%1” only on %2? It leaves the chat lists of %3; the conversation stays on %2. It can't be open in Claude meanwhile.",
                              root.escapeHtml(root.shareConfirm.name), root.escapeHtml(root.shareConfirm.account),
                              root.escapeHtml(root.shareConfirm.others)) + "</span>"
        actions: [
            Kirigami.Action {
                text: i18n("Keep only on %1", root.shareConfirm.account)
                onTriggered: root.confirmKeepOnly()
            },
            Kirigami.Action {
                text: i18n("Cancel")
                onTriggered: root.shareConfirm = root.noShareConfirm
            }
        ]
    }
}

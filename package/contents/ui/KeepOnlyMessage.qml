import QtQuick
import org.kde.kirigami as Kirigami

// Asks before a shared chat is kept on one account only (the others lose it)
Kirigami.InlineMessage {
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

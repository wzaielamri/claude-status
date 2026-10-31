import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// "Show N more" under a list that shows a page at a time (Recent chats,
// ★ Starred chats and plans, a project's chats): the next page of it
// (main.qml: showMore). Folded again, the list shows its first page.
PlasmaComponents3.ToolButton {
    id: moreButton

    property bool open: false          // (the list is unfolded)
    property string listKey: ""        // the list's key in root.morePages
    property int shown: 0              // how many of it show
    property int count: 0              // of how many
    readonly property int next: Math.min(root.pageSize, count - shown)
    signal paged(int pages)            // (Show N more: now this many pages show)

    visible: open && shown < count
    Layout.leftMargin: Kirigami.Units.gridUnit
    flat: true
    icon.name: "go-down-skip"
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
    text: i18np("Show %1 more", "Show %1 more", next)
    font: Kirigami.Theme.smallFont
    onClicked: moreButton.paged(root.showMore(listKey))

    PlasmaCore.ToolTipArea {
        textFormat: Text.PlainText
        anchors.fill: parent
        mainText: i18np("Show %1 more", "Show %1 more", moreButton.next)
        subText: i18n("%1 of %2 show. Folded again, the list shows its first ones again.", moreButton.shown, moreButton.count)
    }
}

import QtQuick

// The model of a list that grows a page at a time (Recent chats, ★ Starred
// chats and plans, a project's chats): size rows, a Repeater's lines made
// only for the rows added ("Show N more"). (A Repeater given a number makes
// all its lines anew whenever the number changes.) Taking rows away while a
// Repeater shows them is slow (a fifth of a second for a few lines): a
// folded list's Repeater gets 0 instead (model: open ? rows : 0), and its
// rows go back to its first page meanwhile.
ListModel {
    id: rows

    property int size: 0

    function fit() {
        if (size <= 0)
            clear()
        else if (count > size)
            remove(size, count - size)
        while (count < size)
            append({ row: count })
    }
    onSizeChanged: fit()
    Component.onCompleted: fit()
}

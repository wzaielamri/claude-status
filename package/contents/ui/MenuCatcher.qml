import QtQuick

// A right-click on the dashboard where it stands on the desktop: the
// widget's menu, as on the panel icon. On the desktop Plasma opens a widget's
// menu for a right press the widget doesn't take, but the dashboard is a
// Page (PlasmaExtras.Representation) and its lists are ScrollViews, which take
// every mouse button, so it never got one. This lies over all of it (z on
// top) and takes the right button only: left clicks, the wheel, fingers and
// the keyboard go to what's under it as before. Over a text field it lets the
// press through, so the task box keeps its Cut/Copy/Paste menu.
MouseArea {
    id: catcher

    property Item covers: parent   // (what it lies over: where it looks for a text field)
    signal menu(point at)          // (where, in its own coordinates)

    acceptedButtons: Qt.RightButton
    onPressed: mouse => {
        mouse.accepted = !textAt(mouse.x, mouse.y)
    }
    onClicked: mouse => catcher.menu(Qt.point(mouse.x, mouse.y))

    // A text field or text box at that point, under it: the deepest item
    // there, its topmost child at each level (itself and its Loader left out)
    function textAt(x, y) {
        let item = covers
        let p = mapToItem(covers, x, y)
        for (let depth = 0; item && depth < 64; depth++) {
            if (typeof item.cursorPosition === "number" && typeof item.selectByMouse === "boolean")
                return !item.readOnly || item.selectByMouse   // (a field you can type in or select from)
            const kids = item.children
            let next = null
            let nextZ = -Infinity
            for (let i = 0; i < kids.length; i++) {
                const k = kids[i]
                if (k === catcher || k === catcher.parent || !k.visible || k.z < nextZ)   // (itself, or its Loader)
                    continue
                const q = item.mapToItem(k, p.x, p.y)
                if (q.x >= 0 && q.y >= 0 && q.x < k.width && q.y < k.height) {
                    next = k
                    nextZ = k.z
                }
            }
            if (!next)
                return false
            p = item.mapToItem(next, p.x, p.y)
            item = next
        }
        return false
    }
}

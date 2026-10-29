import QtQuick

// What stands at a line's end (a chat's state; a folder and how long ago):
// the row's HoverButtons cover its end while they show, so it's cut there,
// in place. Its child takes the whole width (width: <this>.width).
Item {
    id: end

    property real covered: 0                // HoverButtons.covering
    default property alias content: window.data

    Item {
        id: window
        width: Math.max(0, end.width - end.covered)
        height: end.height
        clip: true
    }
}

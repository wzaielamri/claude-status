import QtQuick

// A finger can't hover: pressing and holding a row's line shows its buttons
// (HoverButtons.held), and again hides them. Put one in the line and one in
// each MouseArea of it (a MouseArea keeps the touch from the line's own);
// that MouseArea skips the click that ends the hold (buttons.holding). A
// mouse isn't taken: it does what it did.
TapHandler {
    property Item buttons: null   // the line's HoverButtons

    acceptedDevices: PointerDevice.TouchScreen
    onLongPressed: {
        buttons.held = !buttons.held
        buttons.holding = true
    }
    // (let go: after the MouseArea had its release, which comes after this)
    onPressedChanged: if (!pressed && buttons && buttons.holding) Qt.callLater(() => { if (buttons) buttons.holding = false })
}

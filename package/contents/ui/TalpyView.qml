import QtQuick
import org.kde.kirigami as Kirigami
import "talpy/talpy.mjs" as T
import "talpy/films.mjs" as F

// Talpy on a canvas: talpy/talpy.mjs is the creature (looks, moods, actions);
// this ticks its clock with the widget's (main.qml: petFrame) while it can be
// seen, and shows it as a film (talpy/films.mjs): each picture of a quick move
// is painted once on a sheet of its own and shown again as the move goes
// round (only one sheet shows at a time, so a new picture costs nothing but
// the window), a new pose moves there through pictures in between (a chat's
// pet) or is drawn live until it has settled (the big Talpy), and a big move
// (a jump, popping out of its burrow) is drawn live. What flies about (dirt,
// hearts, z's) has a canvas of its own over it, painted only while there is
// any. The open hole is painted once on hidden sheets (half of what a picture
// costs) and copied in.
// The canvas has room around the creature's box for what it throws and holds up.
Item {
    id: view

    property real box: 100                 // the creature's 64-unit box, in pixels
    property bool playing: true            // seen: it moves
    property bool travels: false           // may dig over to another spot by itself
    property color tint: "transparent"     // a chat's color (calmed down); none: Talpy's own lilac
    property bool facingLeft: false
    property bool live: false              // drawn live, not from pictures (a pet you hold)
    // The film (see films.mjs): pictures at least frameMs apart, at most
    // maxFrames a move, kept on `sheets` canvases; tweenMs 0: a new pose is
    // drawn live until it has settled, restMs: at rest it's drawn live that
    // often; smooth: a move too slow for a picture every frame is drawn live
    property int sheets: 16
    property real frameMs: 33
    property int maxFrames: 12
    property int tweenMs: 200
    property int restMs: 0
    property bool smooth: false
    readonly property real boxX: box * 0.3
    readonly property real boxY: box * 0.45
    readonly property real floorY: boxY + box * T.FLOOR / T.BOX   // the floor, from the canvas top
    property var talpy: null
    property var film: null
    property int shownSheet: 0
    property int wantedSheet: 0            // the film's front: it shows once its picture is painted
    signal travel(int ms)                  // it dug in: move it to its new spot within ms
    signal travelStop()                    // (cut short on the way: it stops where it is)
    signal ready()                         // talpy exists

    width: box * 1.6
    height: box * 1.5

    function cssColor(c, alpha) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (alpha === undefined ? c.a : alpha) + ")"
    }
    function colors() {
        return tint.a > 0 ? T.calmColors(tint.toString().slice(-6)) : T.LILAC
    }
    function theme() {
        return { fx: cssColor(Kirigami.Theme.textColor, 0.5), text: cssColor(Kirigami.Theme.textColor, 1) }
    }

    Component.onCompleted: {
        // the few words it says, in your language
        const words = {
            "achoo!": i18nc("Talpy sneezes", "achoo!"), "hic!": i18nc("Talpy has the hiccups", "hic!"),
            "pop!": i18nc("a balloon pops", "pop!"), "ta-da!": i18nc("Talpy pops out of hiding", "ta-da!"),
            "boo!": i18nc("Talpy plays peekaboo", "boo!"), "a bug!": i18nc("Talpy spots a bug", "a bug!"),
            "got it!": i18nc("Talpy caught a bug", "got it!"), "sigh": i18nc("Talpy is sad", "sigh"),
            "haha": i18nc("Talpy laughs", "haha"), "hihi": i18nc("Talpy giggles", "hihi"),
            "cheese!": i18nc("Talpy takes a selfie", "cheese!"), "yum!": i18nc("Talpy eats a cookie", "yum!"),
            "wheee!": i18nc("Talpy slides or swings", "wheee!"), "yay!": i18nc("Talpy cheers", "yay!"),
            "mmm…": i18nc("Talpy smells a flower", "mmm…"), "a star!": i18nc("Talpy sees a shooting star", "a star!"),
            "sniff sniff": i18nc("Talpy smells a cookie in its sleep", "sniff sniff")
        }
        talpy = new T.Talpy({ colors: colors(), theme: theme(), travels: travels, words: s => words[s] || s })
        talpy.facingLeft = facingLeft
        talpy.onTravel = ms => view.travel(ms)
        talpy.onTravelStop = () => view.travelStop()
        talpy.tick(Date.now())
        // (pictures in between a frame apart)
        film = new F.Films(talpy, { sheets: sheets, frameMs: frameMs, maxFrames: maxFrames, tweenMs: tweenMs,
                                    tweens: Math.max(3, Math.round(tweenMs / frameMs) - 1), restMs: restMs, smooth: smooth,
                                    clockMs: root.petFrameMs })
        paintHoles()
        ready()
        frame(Date.now())
    }
    // (new colors, size or rate: the pictures are painted again)
    onTintChanged: if (talpy) { talpy.setColors(colors()); film.reset() }
    onFacingLeftChanged: if (talpy) talpy.facingLeft = facingLeft
    onTravelsChanged: if (talpy) talpy.travels = travels
    onBoxChanged: if (talpy) { paintHoles(); film.reset() }
    onFrameMsChanged: if (film) { film.frameMs = frameMs; film.reset() }

    Connections {
        target: Kirigami.Theme
        function onTextColorChanged() {
            if (view.talpy) {
                view.talpy.setTheme(view.theme())
                view.film.reset()
            }
        }
    }

    Connections {
        target: root
        enabled: view.playing && view.visible && view.talpy !== null
        function onPetFrame(now) {
            view.frame(now)
        }
    }

    function frame(now) {
        talpy.tick(now)
        film.on = !live
        film.tick(now)
        for (const s of film.sheets) {
            const item = sheetItems.itemAt(s.index)
            if (s.paint && item) {
                item.ready = false
                item.requestPaint()
            }
        }
        wantedSheet = film.front.index
        showWanted()
        if (film.fx.paint)
            flying.requestPaint()
        flying.visible = film.fx.on
    }

    // Only the sheet in front shows, once its picture is painted: a Canvas
    // shows what it had until its new picture is ready (a frame later), so a
    // sheet put in front while it was painted showed its old picture, or
    // nothing, for a frame (pets blinking out and jumping between poses)
    function showWanted() {
        const item = sheetItems.itemAt(wantedSheet)
        if (!item || (!item.ready && wantedSheet !== shownSheet))
            return
        if (wantedSheet !== shownSheet) {
            const was = sheetItems.itemAt(shownSheet)
            if (was)
                was.opacity = 0
            shownSheet = wantedSheet
        }
        item.opacity = 1
    }

    function begin(ctx) {
        ctx.reset()
        ctx.translate(boxX, boxY)
        ctx.scale(box / T.BOX, box / T.BOX)
    }

    function paint(sheet, index) {
        const ctx = sheet.getContext("2d")
        begin(ctx)
        if (film)
            film.paint(film.sheets[index], ctx)
    }

    // The open hole's back and front, turned right and left: painted once
    // here (they aren't shown), copied into each picture pixel for pixel
    function paintHoles() {
        talpy.holeImage = null
        for (let i = 0; i < holes.count; i++) {
            const c = holes.itemAt(i)
            if (!c || !c.available)
                return   // (Talpy draws its hole itself meanwhile)
            const ctx = c.getContext("2d")
            begin(ctx)
            T.drawHoleSide(ctx, i % 2 ? "front" : "back", i >= 2)
        }
        talpy.holeImage = (part, left) => holes.itemAt((left ? 2 : 0) + (part === "front" ? 1 : 0))
    }

    Repeater {
        id: holes
        model: 4
        delegate: Canvas {
            width: view.width
            height: view.height
            visible: false
            renderStrategy: Canvas.Cooperative
            onAvailableChanged: if (available && view.talpy) { view.paintHoles(); view.film.reset() }
        }
    }

    Repeater {
        id: sheetItems
        model: view.sheets
        delegate: Canvas {
            required property int index
            property bool ready: false     // its picture is the film's (see showWanted)
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            opacity: index === 0 ? 1 : 0
            onPaint: view.paint(this, index)
            onPainted: {
                ready = true
                if (index === view.wantedSheet)
                    view.showWanted()
            }
        }
    }

    // What flies about, over it
    Canvas {
        id: flying
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        visible: false
        z: 1
        onPaint: {
            const ctx = getContext("2d")
            view.begin(ctx)
            if (view.film)
                view.film.paintFx(ctx)
        }
    }
}

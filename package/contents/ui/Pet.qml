import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "talpy/talpy.mjs" as T

// One Talpy on the pet strip (PetStrip.qml). The creature itself (looks,
// moods, what it does) is talpy/talpy.mjs, drawn by TalpyView.qml; this is
// where it lives on the stage and what it does with you.
//
// The lone Talpy (petKey "") mirrors all your sessions and has a life of its
// own: it digs over to wherever your mouse is, has hobbies, naps and reacts to
// you. Click to pet it (many quick clicks tickle), double-click to make it
// dance, drag it out of its burrow and drop it.
//
// A chat's pet stands for one chat in the sessions list: it acts that chat out
// (works, calls you, rests while it's idle, sleeps once it's done, looks sad if
// it failed), wears its name and a calm version of its color, pops up out of
// the ground when the chat shows up and digs away when it leaves the list, and
// opens the chat when clicked (drag it for fun: it digs back to its spot).
Item {
    id: pet

    required property Item strip
    property string petKey: ""          // the chat's key ("" for the lone Talpy)
    readonly property bool lone: petKey === ""
    property var chat: null             // the chat's session row, null once it's done
    property var lastChat: null         // the last one seen (opened when clicked)
    property string host: ""            // SSH host of the chat, if any
    property string label: ""           // short name on its tag
    property color tint: "transparent"  // the chat's color
    property real homeX: strip.width / 2
    property bool leaving: false
    property bool isMain: false         // shows the account-wide things (usage limits)
    signal gone()

    onChatChanged: if (chat) lastChat = chat

    // Talpy's moods: idle working agents needs done failed limit (error loading for the lone one)
    readonly property string mood: lone ? root.petMood
                                 : !chat ? "idle"
                                 : chat.state === "waiting" ? "needs"
                                 : chat.state === "working" ? (chat.agents && chat.agents.running > 0 ? "agents" : "working")
                                 : chat.stopped && !chat.stopped.over ? "limit"   // a usage limit (or the login) stopped it
                                 : chat.state === "idle" ? "idle"                // ready for your next message
                                 : chat.reason === "failed" ? "failed"
                                 : "done"                                        // done: results to look at

    readonly property real gu: strip.gu
    readonly property real box: strip.boxSize
    readonly property real unit: box / 64
    readonly property real bodyWidth: strip.bodyWidth
    readonly property real bodyHeight: strip.bodyHeight
    readonly property real ground: lone ? strip.loneGround : strip.chatGround
    // Where it can be: anywhere on the stage, its burrow (wider than its body)
    // staying on it; the lone Talpy walks over the headline
    readonly property real reach: box * 27 / 64 + Kirigami.Units.smallSpacing
    readonly property real minX: reach
    readonly property real maxX: Math.max(minX, strip.width - reach)
    readonly property bool live: strip.live
    readonly property bool playing: strip.playing   // not under a window: it moves

    // Where it is: px = horizontal centre, lift = how high you hold it (its
    // spot moves it by digging over there: no binding to homeX)
    property real px: 0
    Component.onCompleted: px = homeX
    property real lift: 0
    // Where it's drawn: there, but while you hold it it trails your hand on a
    // spring and swings with how fast you move it (and wobbles back after)
    property real shownX: px
    Behavior on shownX {
        enabled: pet.held
        SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.2 }
    }
    readonly property real swing: held ? Math.max(-30, Math.min(30, (px - shownX) * 1.8 / unit)) : 0
    property bool held: false
    property bool landing: false        // picked up, until it has landed and dug in: drawn live
    property bool arriving: false
    property bool departed: false   // dug away: only waiting to be removed
    property real travelTo: -1      // where the next dig takes it (-1: it picks)
    property int quickClicks: 0
    property int sleepyClicks: 0
    property string lastMood: ""
    property var missed: null       // {kind, text, at}: what happened while it couldn't be seen
    property real actedOutAt: 0     // when it last acted that out
    readonly property var talpy: view.talpy

    anchors.fill: parent

    function clampX(x) {
        return Math.max(minX, Math.min(maxX, x))
    }

    function react(name, done) {
        if (talpy)
            talpy.react(name, done || null)
    }

    // Digs over to x (it dives in, tunnels across, pops up there); quick: its
    // spot moved (a new chat makes room), so it hurries
    function digTo(x, quick) {
        if (held || leaving || arriving || !talpy)
            return
        travelTo = clampX(x)
        if (Math.abs(travelTo - px) < bodyWidth * 0.3) {
            travelTo = -1
            return
        }
        react(quick ? "scoot" : "dig")
    }

    function say(text) {
        strip.say(pet, text)
    }

    // Seasons (northern hemisphere, by month) and a few days of the year
    function holidayGreeting() {
        const d = new Date(), m = d.getMonth() + 1, day = d.getDate()
        if ((m === 12 && day === 31) || (m === 1 && day === 1))
            return i18n("Happy New Year!")
        if (m === 12 && day >= 24 && day <= 26)
            return i18n("Merry Christmas!")
        if (m === 10 && day === 31)
            return i18n("Boo! Happy Halloween!")
        if (m === 2 && day === 14)
            return i18n("Happy Valentine's Day!")
        return ""
    }

    function start() {
        talpy.setMood(mood)
        lastMood = mood
        if (lone && !strip.firstShown)
            return            // the first time the popup opens it's just there
        arriving = true       // a new chat: it digs up out of the ground
        react("arrive", () => { pet.arriving = false })
    }

    onMoodChanged: {
        if (!talpy)
            return
        talpy.setMood(mood)
        if (lastMood === "done" && mood !== "done" && !leaving)
            react("yawn")     // woken up by work
        lastMood = mood
    }
    onHomeXChanged: {
        if (held || leaving)
            return       // in your hand (put down, it digs back), or on its way out
        if (!strip.firstShown || arriving)
            px = homeX   // not seen yet, or still underground: it's just there
        else
            digTo(homeX, true)
    }
    // The strip got narrower: back inside it
    onMaxXChanged: if (!held && px > maxX) digTo(maxX, true)
    onLeavingChanged: {
        if (leaving && !held)
            goAway()
        else if (!leaving && !held) {
            departed = false   // its chat came back (also while it dug away): it pops up again
            arriving = true
            react("arrive", () => { pet.arriving = false })
        }
    }
    onLiveChanged: {
        if (!live || !lone || !talpy || mood === "done" || mood === "loading" || fresh(missed) || Date.now() - actedOutAt < 1000)
            return   // (what it missed meanwhile comes instead, see onPlayingChanged)
        const holiday = holidayGreeting()
        if (holiday) {
            react("celebrate")
            say(holiday)
        } else if (Math.random() < 0.6) {
            react("wave")
            say(i18n("Hi!"))
        }
    }

    // Seen again: it acts out what happened meanwhile, if it's from the last
    // minute (older news is dropped)
    onPlayingChanged: {
        if (!playing || !missed)
            return
        const m = missed
        missed = null
        if (fresh(m)) {
            actedOutAt = Date.now()
            event(m.kind, m.text)
        }
    }
    function fresh(m) {
        return m !== null && Date.now() - m.at < 60000
    }

    // (Removed once its frame is over: the leave ends in Talpy's tick, inside
    // its view's frame, and removing it there destroyed the view under it:
    // "attempted to evaluate a function in an invalid context")
    function goAway() {
        react("leave", ok => {
            if (ok && pet.leaving) {
                pet.departed = true
                Qt.callLater(pet.gone)
            }
        })
    }

    // Clicked: the lone Talpy gets petted, a chat's pet opens its chat
    function clicked() {
        if (lone) {
            petIt()
            return
        }
        const c = lastChat
        if (!c)
            return
        if (host)
            root.remoteShow(host, c)
        else
            root.jumpTo(c.sessionId, c.profileDir)
    }

    function petIt() {
        if (mood === "done") {
            sleepyClicks += 1
            tickleTimer.restart()
            if (sleepyClicks >= 3) {
                sleepyClicks = 0
                react("angry")
                say(i18n("I said let me SLEEP!"))
            } else {
                react("grumpy")
                say(i18n("Zzz… let me sleep."))
            }
            return
        }
        quickClicks += 1
        tickleTimer.restart()
        if (quickClicks >= 4) {
            quickClicks = 0
            react("laugh")
            say(i18n("Hehe, that tickles!"))
        } else if (quickClicks === 3) {
            react("shy")
            say(i18n("Aww, stop it…"))
        } else {
            const r = Math.random()
            react(r < 0.2 ? "love" : r < 0.35 ? "wink" : r < 0.45 ? "blowkiss" : "pet")
            say(petLine())
        }
    }

    function dance() {
        if (mood === "done") {
            react("yawn")
            say(i18n("…five more minutes."))
            return
        }
        react(Math.random() < 0.4 ? "boogie" : "dance")
        say("♪ ♫")
    }

    function pickUp() {
        held = true
        landing = true
        fall.stop()   // grabbed again while falling
        stride.stop()
        if (talpy) {
            // (its hole doesn't come along: it stays where it was, until it has landed)
            const open = talpy.setHeld(true)
            if (open > 0)
                leaveHole(open)
        }
        say(i18n("Whoa!"))
    }

    function leaveHole(open) {
        closeHole.stop()
        leftHole.at = px
        leftHole.flip = view.facingLeft
        leftHole.open = open
        leftHole.shown = true
    }

    function drop() {
        fall.duration = Math.max(160, Math.sqrt(lift / gu) * 230)
        fall.restart()
    }

    // On the floor again: dizzy if it fell from high up, then it digs in where it landed
    function landed(fromHeight) {
        held = false
        if (leftHole.shown)
            closeHole.restart()   // (the one it left is filled in; it digs a new one where it is)
        if (!talpy) {
            landing = false
            return
        }
        const feel = talpy.land(fromHeight / unit, () => {
            pet.landing = false
            if (pet.leaving)
                pet.goAway()      // its chat left while you held it: now it goes
            else if (!pet.lone && Math.abs(pet.px - pet.homeX) > pet.bodyWidth * 0.5)
                pet.digTo(pet.homeX)
        })
        // (in the words for how it looks)
        if (feel === "sick")
            say(i18n("Ugh… I don't feel so good."))
        else if (feel === "dizzy")
            say(i18n("Ouch… the room is spinning."))
    }

    function petLine() {
        if (mood === "needs")
            return i18n("%1 needs you!", root.waitingName)
        if (mood === "agents")
            return i18np("Juggling %1 agent!", "Juggling %1 agents!", root.agentsRunning)
        if (mood === "working")
            return i18n("Busy coding… thanks!")
        const lines = [i18n("Hi!"), "♥", i18n("Ship it!"), i18n("All quiet here."), i18n("Pet me more!")]
        return lines[Math.floor(Math.random() * lines.length)]
    }

    // Something happened to its chat (or, for the main pet, to an account)
    function event(kind, text) {
        if (held || leaving)
            return   // (a reaction now would stop it digging away)
        if (!playing) {
            missed = { kind: kind, text: text, at: Date.now() }   // (acted out when it can be seen)
            return
        }
        const action = { done: Math.random() < 0.4 ? "yay" : "finished", failed: "failed", stopped: "shrug", limit: "battery", oops: "confused", reset: "charged" }[kind]
        react(action || "alert")
        say(text)
    }

    // ------------------------------------------------------------ timers

    Timer {
        id: tickleTimer
        interval: 1500
        onTriggered: {
            pet.quickClicks = 0
            pet.sleepyClicks = 0
        }
    }

    // The lone Talpy turns towards the mouse while it hovers the stage
    Timer {
        interval: 350
        repeat: true
        running: pet.playing && pet.lone && pet.strip.cursorX >= 0 && !pet.held && pet.mood !== "done"
        onTriggered: {
            if (Math.abs(pet.strip.cursorX - pet.px) > pet.bodyWidth * 0.4)
                view.facingLeft = pet.strip.cursorX < pet.px
        }
    }

    // A working session's context window is nearly full: point it out now and
    // then (a chat's pet for its own chat, the hero for chats without a pet)
    readonly property string contextFullText: !lone ? (chat && chat.state === "working" && chat.context !== null && chat.context >= 85
                                                       ? i18n("%1: context %2% full", label, Math.round(chat.context)) : "")
                                                    : root.contextFullText
    Timer {
        interval: 40000
        repeat: true
        running: pet.playing && pet.contextFullText !== "" && (pet.mood === "working" || pet.mood === "agents") && !pet.leaving
        triggeredOnStart: true
        onTriggered: {
            if (!pet.held && pet.talpy && !pet.talpy.run) {
                pet.react("contextFull")
                pet.say(pet.contextFullText)
            }
        }
    }

    // Close to a usage limit: mind-blown now and then; at the limit out of steam
    Timer {
        interval: 25000
        repeat: true
        running: pet.playing && pet.isMain && root.highUsageText !== "" && pet.mood !== "done" && !pet.leaving
        triggeredOnStart: true
        onTriggered: {
            if (pet.held || !pet.talpy || pet.talpy.run)
                return
            pet.react(root.maxFiveHour >= 100 ? "battery" : "mindblown")
            pet.say(root.highUsageText)
        }
    }

    // ------------------------------------------------------------ motion

    // Tunnelling across while it digs to a new spot
    NumberAnimation {
        id: stride
        target: pet
        property: "px"
        easing.type: Easing.InOutSine
    }

    NumberAnimation {
        id: fall
        target: pet
        property: "lift"
        to: 0
        easing.type: Easing.InQuad
        property real fromHeight: 0
        onStarted: fromHeight = pet.lift
        onFinished: pet.landed(fromHeight)
    }

    // ------------------------------------------------------------ drawing

    // The hole it was pulled out of, empty where it was while you hold it
    // (under it, so it's drawn first)
    Canvas {
        id: leftHole
        property bool shown: false
        property real at: 0             // its horizontal centre
        property real open: 1           // 0 closed, 1 open
        property bool flip: false       // (the burrow isn't quite the same on both sides)
        visible: shown && !pet.departed
        width: view.width
        height: view.height
        x: at - view.boxX - pet.box / 2
        y: pet.ground - view.floorY
        renderStrategy: Canvas.Cooperative
        onOpenChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.translate(view.boxX, view.boxY)
            ctx.scale(pet.box / T.BOX, pet.box / T.BOX)
            if (flip) {
                ctx.translate(T.BOX, 0)
                ctx.scale(-1, 1)
            }
            T.drawHole(ctx, open)
        }
    }

    NumberAnimation {
        id: closeHole
        target: leftHole
        property: "open"
        to: 0
        duration: 350
        onFinished: leftHole.shown = false
    }

    TalpyView {
        id: view
        visible: !pet.departed   // (dug away: not even back up for the moment before it's removed)
        box: pet.box
        x: pet.shownX - boxX - pet.box / 2
        y: pet.ground - pet.lift - floorY
        transform: Rotation {
            origin.x: view.boxX + pet.box / 2
            origin.y: view.boxY + pet.box * 30 / 64   // (where you hold it)
            angle: pet.swing
            Behavior on angle {
                SpringAnimation { spring: 3; damping: 0.16; epsilon: 0.3 }
            }
        }
        playing: pet.playing
        travels: pet.lone
        tint: pet.lone ? "transparent" : pet.tint
        // Both are films (TalpyView.qml), drawn live while you hold them and
        // until they've landed, and for a move too slow for a picture every
        // tick (it would step). The big Talpy: a picture every frame of the
        // clock, live until a new pose has settled, breathing at rest. A
        // chat's pet: smaller, so a picture every other tick (30 a second in
        // the popup, 15 on the desktop: even steps, each picture as long),
        // pictures in between poses, still at rest.
        live: pet.landing
        sheets: pet.lone ? 36 : 32
        frameMs: pet.lone ? root.petFrameMs : 2 * root.petFrameMs
        maxFrames: 32
        tweenMs: pet.lone ? 0 : 200
        restMs: pet.lone ? 200 : 0
        smooth: true
        onReady: pet.start()
        onTravel: ms => {
            let to = pet.travelTo
            pet.travelTo = -1
            if (to < 0) {
                // its own idea: towards the mouse if it hovers the stage, else anywhere
                const cursor = pet.strip.cursorX
                to = cursor >= 0 ? cursor + (Math.random() - 0.5) * pet.bodyWidth
                                 : pet.minX + Math.random() * (pet.maxX - pet.minX)
            }
            to = pet.clampX(to)
            view.facingLeft = to < pet.px
            stride.to = to
            stride.duration = Math.max(200, ms - 100)
            stride.restart()
        }
    }

    // Name tag under it, in the chat's color
    Rectangle {
        id: tag
        visible: !pet.lone && pet.label !== "" && !pet.departed
        readonly property bool darkTint: (pet.tint.r * 0.299 + pet.tint.g * 0.587 + pet.tint.b * 0.114) < 0.6
        width: Math.min(tagText.implicitWidth + Kirigami.Units.smallSpacing * 2, pet.strip.tagWidth)
        height: tagText.implicitHeight + 2
        radius: height / 2
        x: pet.px - width / 2   // follows it, also while it tunnels
        y: pet.ground + pet.unit * 6
        color: pet.tint

        PlasmaComponents3.Label {
            id: tagText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pet.strip.tagWidth - Kirigami.Units.smallSpacing * 2)
            text: pet.label
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.95
            color: tag.darkTint ? "white" : "black"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pet.clicked()
        }
    }

    // ------------------------------------------------------------ input

    // Grab area around its body (in strip coordinates, so flipping doesn't move it)
    MouseArea {
        id: grab
        property point pressedAt
        property bool dragging: false
        x: pet.px - width / 2
        y: pet.ground - pet.lift - height
        width: pet.bodyWidth + Kirigami.Units.largeSpacing
        height: pet.bodyHeight + Kirigami.Units.largeSpacing
        visible: !pet.departed
        cursorShape: pet.held ? Qt.ClosedHandCursor : pet.lone ? Qt.OpenHandCursor : Qt.PointingHandCursor
        preventStealing: true
        hoverEnabled: !pet.lone

        onPressed: mouse => {
            pressedAt = mapToItem(pet, mouse.x, mouse.y)
            dragging = false
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return
            const p = mapToItem(pet, mouse.x, mouse.y)
            if (!dragging && Math.hypot(p.x - pressedAt.x, p.y - pressedAt.y) > pet.gu * 0.5) {
                dragging = true
                pet.pickUp()
            }
            if (dragging) {
                pet.px = pet.clampX(p.x)
                pet.lift = Math.max(0, Math.min(pet.ground - pet.bodyHeight, pet.ground - p.y - pet.bodyHeight / 2))
            }
        }
        onReleased: {
            if (dragging)
                pet.drop()
        }
        // (a press that ends without a release: the popup closed or the stage folded away under the mouse)
        onCanceled: {
            if (dragging && pet.held)
                pet.drop()
        }
        onClicked: {
            if (!dragging)
                pet.clicked()
        }
        onDoubleClicked: {
            if (!dragging && pet.lone)
                pet.dance()
        }

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            active: !pet.lone && !pet.held && pet.lastChat !== null
            mainText: pet.lastChat ? (pet.host ? pet.host + ": " : "") + pet.lastChat.name : ""
            subText: pet.lastChat ? root.stateText(pet.lastChat) + "\n" + i18n("Click to open this chat") : ""
        }
    }
}

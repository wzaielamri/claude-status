import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "hub"
import "markdown.mjs" as Md
import "codehtml.mjs" as Code

// A chat beside the popup (main.qml: openPane): its conversation, updating
// while it works, drawn the way Claude's terminal draws it (a dot before each
// reply and tool call, a tool call's outcome under it, your prompts set off),
// with each tool call folded into one line; a box to reply
// (pane.py --send: typed into tmux, put in its VS Code tab's input, or it
// goes on in the background); what it asks while it waits for a permission,
// with Allow once / Always allow / Deny, or Claude's questions to answer;
// and its review: the files it
// changed, against how they were before the chat, with Undo, Commit and
// Mark reviewed. One window, for the chat root.paneChat.
Window {
    id: pane

    readonly property var chat: root.paneChat || ({})
    readonly property var row: root.paneRow   // its row in the status now (null: not listed)
    readonly property string host: chat.host || ""
    readonly property string chatId: chat.chatId || ""
    readonly property string profileDir: row && row.profileDir ? row.profileDir : (chat.profileDir || "")
    readonly property string sessionId: row && row.sessionId ? row.sessionId : (chat.sessionId || "")
    readonly property string chatName: row && row.name ? row.name : (chat.name || "")
    readonly property string chatState: row ? row.state : "done"
    readonly property bool busy: chatState === "working" || chatState === "waiting"
    readonly property string route: row && row.reply ? row.reply : "background"
    readonly property var permission: row && row.permission && chatState === "waiting" ? row.permission : null
    readonly property var queued: root.queuedMessage(chatId, host)
    readonly property bool reviewPending: row ? root.reviewPending(row, host) : false
    property string tab: "chat"

    title: i18nc("window title: a chat's name", "%1 — Claude chat", chatName || chatId.slice(0, 8))
    width: Kirigami.Units.gridUnit * 38
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 18
    color: Kirigami.Theme.backgroundColor
    onClosing: {
        cancelDictation()
        root.closePane()
    }

    // ---------------------------------------------------------------- how it looks

    // Text size: the desktop's font size times paneTextPercent (A− / A+, Ctrl+wheel, Ctrl+= / Ctrl+-)
    readonly property var scales: [90, 100, 115, 130, 150, 175, 200]
    readonly property int textPercent: Math.max(80, Math.min(200, Plasmoid.configuration.paneTextPercent || 115))
    readonly property real pt: surface.Kirigami.Theme.defaultFont.pointSize * textPercent / 100
    function zoom(step) {
        let i = scales.findIndex(v => v >= textPercent)
        i = i < 0 ? scales.length - 1 : i
        Plasmoid.configuration.paneTextPercent = step === 0 ? 115 : scales[Math.max(0, Math.min(scales.length - 1, i + step))]
    }

    // Colors: Claude's own orange for its dots, headings and the working
    // line; the theme's accent for you; inline code in the blue Claude's
    // terminal uses. (From the window's surface: a Window's own Kirigami.Theme
    // isn't the desktop's colors.)
    function hex(c) {
        return Qt.rgba(c.r, c.g, c.b, 1).toString()
    }
    function mix(c, a) {   // the text color, a of it over the background
        return Qt.tint(surface.Kirigami.Theme.backgroundColor, Qt.rgba(c.r, c.g, c.b, a))
    }
    readonly property color textColor: surface.Kirigami.Theme.textColor
    readonly property bool dark: surface.Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property color claudeColor: dark ? "#d97757" : "#c15f3c"
    readonly property color codeColor: dark ? "#b1b9f9" : "#5769f7"
    readonly property color mutedColor: mix(textColor, 0.62)
    readonly property color borderColor: mix(textColor, 0.16)
    readonly property color youColor: surface.Kirigami.Theme.focusColor
    readonly property var mdStyle: ({
        pt: pt, mono: monoFamily, text: hex(textColor), muted: hex(mutedColor),
        accent: hex(claudeColor), heading: hex(claudeColor), code: hex(codeColor), codeBg: hex(mix(textColor, 0.09)),
        blockBg: hex(dark ? Qt.tint(surface.Kirigami.Theme.backgroundColor, Qt.rgba(0, 0, 0, 0.28)) : mix(textColor, 0.04)),
        border: hex(borderColor), link: hex(surface.Kirigami.Theme.linkColor)
    })
    // Code and changes (codehtml.mjs): a tool call's details
    readonly property var codeStyle: Code.palette(dark, hex(textColor), mdStyle.blockBg, monoFamily, pt)

    FontMetrics {
        id: fm
        font.pointSize: pane.pt
    }
    // Code in a fixed-width font: the desktop's, if it is one (it can be set to any font), else monospace
    FontMetrics {
        id: fixedFm
        font.family: surface.Kirigami.Theme.fixedWidthFont.family
    }
    readonly property string monoFamily: Math.abs(fixedFm.advanceWidth("iiii") - fixedFm.advanceWidth("WWWW")) < 0.5
                                         ? surface.Kirigami.Theme.fixedWidthFont.family : "monospace"
    readonly property real gutter: Math.round(fm.height * 1.3)   // where the dots go

    // ● before a reply or a tool call, on its first line (blinking: still going)
    component Dot: Item {
        id: dotItem
        property color color
        property bool blinking: false
        property real gutter: 0
        property real lineHeight: 0
        Layout.preferredWidth: gutter
        Layout.preferredHeight: lineHeight
        Layout.alignment: Qt.AlignTop

        Rectangle {
            id: dot
            width: Math.round(dotItem.lineHeight * 0.42)
            height: width
            radius: width / 2
            x: Math.round((dotItem.gutter - width) * 0.4)
            anchors.verticalCenter: parent.verticalCenter
            color: dotItem.color

            SequentialAnimation on opacity {
                running: dotItem.blinking
                loops: Animation.Infinite
                onRunningChanged: if (!running) dot.opacity = 1
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.ZoomIn, "Ctrl+="]
        onActivated: pane.zoom(1)
    }
    Shortcut {
        sequences: [StandardKey.ZoomOut]
        onActivated: pane.zoom(-1)
    }
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: pane.zoom(0)
    }

    // A code block's Copy
    TextEdit {
        id: clipboard
        visible: false
    }
    function copyText(text) {
        clipboard.text = text
        clipboard.selectAll()
        clipboard.copy()
        clipboard.text = ""
        info = i18n("Copied")
        infoBad = false
        infoTimer.restart()
    }

    // ---------------------------------------------------------------- the conversation

    property string stamp: ""
    property int limit: 120
    property bool more: false
    property bool loaded: false
    property string loadError: ""
    property var openTools: ({})   // key -> unfolded
    property string info: ""
    property bool infoBad: false

    ListModel {
        id: items
    }

    function reset() {
        offers = null
        offersAt = 0
        suggestions = []
        historyAt = -1
        items.clear()
        stamp = ""
        limit = 120
        more = false
        loaded = false
        loadError = ""
        openTools = {}
        info = ""
        review = null
        reviewFor = ""
        reviewLoading = false
        commitOpen = false
        commitText.text = ""   // (the chat before's message: this one's comes with its review)
        commitEdited = false
        undoAsk = ""
        replyBox.text = ""
        askHow = false
        answering = 0
        answerStale.stop()
        outputText = ""
        outputHtml = ""
        outputError = ""
        // (what's still on its way for the chat before is left out when it
        // comes, handle(): this one's is read now)
        loading = false
        loadAgain = false
        const wasTab = tab
        tab = chat.tab || "chat"
        Qt.callLater(load)
        if (tab === "review" && wasTab === "review")
            Qt.callLater(loadReview)   // (the tab stays: onTabChanged doesn't read this one's)
    }
    property bool ready: false   // (nothing runs while the window is being made)
    onChatIdChanged: if (ready) reset()
    Component.onCompleted: {
        ready = true
        reset()
    }
    Connections {
        target: root
        function onPaneDraftChanged() {   // (a reply from a notification, for a terminal that takes no text)
            if (root.paneDraft) {
                replyBox.text = root.paneDraft
                replyBox.cursorPosition = replyBox.text.length
                pane.askHow = true
                root.paneDraft = ""
            }
        }
        function onImagePasted(path, target) {   // (Ctrl+V: a picture, saved; an SSH host's copied there)
            if (target !== "pane")
                return
            const at = replyBox.cursorPosition
            replyBox.insert(at, (at > 0 && replyBox.text.charAt(at - 1).trim() !== "" ? " " : "") + "[Image: " + path + "] ")
            replyBox.forceActiveFocus()
        }
        function onFileAttached(path, target) {   // (a file dropped on the pane: named, as Claude's @ does)
            if (target !== "pane")
                return
            const at = replyBox.cursorPosition
            const named = /\s/.test(path) ? "@\"" + path + "\"" : "@" + path
            replyBox.insert(at, (at > 0 && replyBox.text.charAt(at - 1).trim() !== "" ? " " : "") + named + " ")
            replyBox.forceActiveFocus()
        }
        function onPaneNote(message) {
            pane.info = message
            pane.infoBad = true
            infoTimer.restart()
        }
        function onPaneDenyingChanged() {   // (Deny with a note, from a notification)
            if (root.paneDenying) {
                askColumn.denyWithNote()
                root.paneDenying = false
            }
        }
        function onPaneTypingChanged() {   // (Other…, from a question's notification)
            if (root.paneTyping) {
                askColumn.typeAnswer()
                root.paneTyping = false
            }
        }
        function onPaneChatChanged() {
            if (root.paneChat && root.paneChat.tab)
                pane.tab = root.paneChat.tab
            pane.raise()
            pane.requestActivate()
        }
    }

    function grow(fromLeft, fromY) {
        growBox.origin.x = fromLeft ? 0 : surface.width
        growBox.origin.y = Math.max(0, Math.min(surface.height, fromY))
        growing.restart()
    }
    // (shown at once if the popup never says where it is)
    Timer {
        interval: 1500
        running: true
        onTriggered: if (surface.opacity === 0 && !growing.running) surface.opacity = 1
    }

    function paneArgs() {
        return (profileDir ? " --profile " + root.shellQuote(profileDir) : "")
               + (host ? " --host " + root.shellQuote(host) : "") + root.configDirArgs
    }

    // (the time makes a click run its command again; the conversation, read
    // every 1.5 s, goes without, so its name repeats while nothing changes:
    // every executable DataSource in plasmashell keeps each name, hub/Exec.qml)
    function run(kind, args) {
        const cmd = "python3 -I " + root.shellQuote(root.codeDir + "pane.py") + " " + args
                    + (kind === "conversation" || kind === "logs" ? "" : " # " + Date.now())   // (read again and again: one name)
        runs[cmd] = { kind: kind, chat: chatId, host: host, target: row || chat }
        runner.connectSource(cmd)
    }
    property var runs: ({})   // command -> {kind, chat: the chat it's for, host, target: its row (openRow)}
    // A command whose answer never came (plasmashell lost it) is given up
    // after this, and a read runs again (hub/Exec.qml; a host's goes over ssh)
    readonly property int staleMs: 120000
    property bool loading: false
    property real loadingSince: 0
    property bool loadAgain: false   // (something changed while it was read: read it again then)

    function load() {
        if (!chatId)
            return
        if (loading && Date.now() - loadingSince < staleMs) {
            loadAgain = true
            return
        }
        loading = true
        loadingSince = Date.now()
        run("conversation", "--conversation " + root.shellQuote(chatId) + " --limit " + limit
            + (stamp ? " --if-changed " + root.shellQuote(stamp) : "") + paneArgs())
    }

    // Live (hub/Hub.qml): with the live hook, the conversation is read the
    // moment the chat does a step or changes state, and the timer is only
    // there for what comes without one (a long reply being written)
    readonly property bool followsLive: !host && root.watching && root.liveHook
    Timer {
        interval: pane.host || pane.followsLive ? 5000 : 1500
        running: pane.visible && pane.chatId !== ""
        repeat: true
        onTriggered: pane.load()
    }
    Connections {
        target: Hub
        function onLive(views) {
            if (pane.visible && !pane.host && pane.sessionId && views.some(v => v.sessionId === pane.sessionId))
                pane.load()
        }
    }

    // The items in place (by key): rows keep their state, the list its position
    function merge(list) {
        const wanted = {}
        list.forEach(i => wanted[i.key] = true)
        for (let i = items.count - 1; i >= 0; i--) {
            if (!wanted[items.get(i).key])
                items.remove(i)
        }
        for (let i = 0; i < list.length; i++) {
            const it = list[i]
            const flat = { kind: it.kind, key: String(it.key), text: it.text || "", line: it.line || "",
                           name: it.name || "", status: it.status || "", input: it.input || "", output: it.output || "",
                           summary: it.summary || "", at: it.at || 0, bad: !!it.error, prev: i > 0 ? list[i - 1].kind : "",
                           diff: (it.diff || []).join("\n") }
            if (i < items.count && items.get(i).key === flat.key) {
                const old = items.get(i)
                if (old.text !== flat.text || old.status !== flat.status || old.output !== flat.output
                        || old.input !== flat.input || old.summary !== flat.summary || old.prev !== flat.prev || old.diff !== flat.diff)
                    items.set(i, flat)
            } else if (i < items.count) {
                items.insert(i, flat)
            } else {
                items.append(flat)
            }
        }
        while (items.count > list.length)
            items.remove(items.count - 1)
    }

    // The end of the conversation in view, with its working line, when you
    // were at the end (scrolled up, it stays where you are). Rich text rows
    // take a moment to get their height: it keeps the end in view while they do.
    function nearEnd() {
        return list.originY + list.contentHeight - list.contentY - list.height < Kirigami.Units.gridUnit * 2
    }
    function followEnd() {
        list.contentY = Math.max(list.originY, list.originY + list.contentHeight - list.height)
    }
    Timer {
        id: settle
        property int left: 0
        interval: 80
        repeat: true
        onTriggered: {
            pane.followEnd()
            if (--left <= 0)
                stop()
        }
    }
    function keepEnd() {
        followEnd()
        settle.left = 10
        settle.restart()
    }
    onChatStateChanged: {
        if (visible)
            load()   // (its turn began or ended, it asks something: the conversation now)
        if (loaded && nearEnd())
            keepEnd()   // (the working line comes or goes)
    }

    // ---------------------------------------------------------------- what the box offers
    //
    // As you type (pane.py --complete, read once a chat, again after a minute):
    // / at the start: Claude's commands, yours and the project's, and skills; @:
    // the project's files; ↑ / ↓ in an empty box (or on its first / last line):
    // your past prompts in its folder. Tab or Enter takes the one marked, Esc
    // closes the list.
    property var offers: null          // {commands, files, history}
    property real offersAt: 0
    property var suggestions: []       // [{text, about, insert}]
    property int suggestion: 0
    property int tokenStart: -1
    property string dismissed: ""      // (the word Esc closed the list for)
    property int historyAt: -1
    property string historyDraft: ""

    function loadOffers() {
        if (!chatId || Date.now() - offersAt < 60000)
            return
        offersAt = Date.now()
        run("complete", "--complete " + root.shellQuote(chatId) + paneArgs())
    }

    function suggest() {
        const before = replyBox.text.slice(0, replyBox.cursorPosition)
        const command = /^\/([^\s]*)$/.exec(before)
        const file = /(^|\s)@("?)([^\s"]*)$/.exec(before)
        const token = command ? before : file ? before.slice(before.length - file[0].length + file[1].length) : ""
        if (!token || token === dismissed || !offers) {
            if (token && !offers)
                loadOffers()
            suggestions = []
            return
        }
        loadOffers()
        const q = (command ? command[1] : file[3]).toLowerCase()
        let found
        if (command) {
            found = offers.commands.filter(c => c.name.toLowerCase().indexOf(q) >= 0)
                .sort((a, b) => (a.name.toLowerCase().startsWith("/" + q) ? 0 : 1) - (b.name.toLowerCase().startsWith("/" + q) ? 0 : 1))
                .map(c => ({ text: c.name, about: c.about + (c.kind === "Claude" ? "" : " · " + c.kind), insert: c.name + " " }))
        } else {
            const rank = f => {
                const base = f.slice(f.lastIndexOf("/") + 1).toLowerCase()
                return base.startsWith(q) ? 0 : base.indexOf(q) >= 0 ? 1 : 2
            }
            found = offers.files.filter(f => f.toLowerCase().indexOf(q) >= 0).slice(0, 400)
                .sort((a, b) => rank(a) - rank(b) || a.length - b.length)
                .map(f => ({ text: "@" + f, about: "", insert: (/\s/.test(f) ? "@\"" + f + "\"" : "@" + f) + " " }))
        }
        tokenStart = before.length - token.length
        suggestions = found.slice(0, 8)
        suggestion = 0
    }

    function takeSuggestion(i) {
        const s = suggestions[i]
        if (!s)
            return
        const at = replyBox.cursorPosition
        replyBox.remove(tokenStart, at)
        replyBox.insert(tokenStart, s.insert)
        suggestions = []
    }

    // ↑ / ↓: your past prompts there, newest first (what you were typing comes back after the last)
    function historyStep(step) {
        const list = offers ? offers.history : []
        if (!list.length)
            return false
        if (historyAt < 0)
            historyDraft = replyBox.text
        const next = Math.max(-1, Math.min(list.length - 1, historyAt + step))
        if (next === historyAt)
            return true
        historyAt = next
        replyBox.text = next < 0 ? historyDraft : list[next]
        replyBox.cursorPosition = replyBox.text.length
        return true
    }

    // asked: the run it answers ({kind, chat, host, target}: run())
    function handle(kind, result, asked) {
        // An answer for the chat shown before (another one was opened since,
        // reset()): none of it goes into this one's conversation, review, box
        // or buttons. A message sent there still goes where it was going.
        if (asked.chat !== chatId) {
            if (kind === "send" || kind === "later") {
                if (result.ok && result.how === "vscode" && result.link)
                    Qt.openUrlExternally(result.link)
                else if (result.ok && result.how === "copy" && result.copied)
                    root.openRow(asked.target, asked.host)
                else if (!result.ok || result.how === "ask" || result.how === "copy") {
                    // (it didn't go, and the box it was in is this chat's now: said here)
                    info = i18n("Your message to %1 didn't go: %2", asked.target && asked.target.name ? asked.target.name : i18n("the chat before"),
                                result.message || i18n("its terminal takes no text"))
                    infoBad = true
                    infoTimer.restart()
                }
            }
            if (kind !== "conversation" && kind !== "review" && kind !== "complete" && kind !== "logs") {
                root.refresh()   // (what was done there shows in the popup)
                if (asked.host)
                    root.pollHost(asked.host)
            }
            return
        }
        if (kind === "complete") {
            if (result.ok)
                offers = { commands: result.commands || [], files: result.files || [], history: result.history || [] }
            Qt.callLater(suggest)
            return
        }
        if (kind === "conversation") {
            loading = false
            if (loadAgain) {
                loadAgain = false
                Qt.callLater(load)
            }
            if (!result.ok) {
                loadError = result.message || i18n("Can't read this chat")
                return
            }
            loadError = ""
            if (result.unchanged)
                return
            const following = !loaded || nearEnd()
            stamp = result.stamp || ""
            more = !!result.more
            merge(result.items || [])
            loaded = true
            if (following)
                keepEnd()
            return
        }
        if (kind === "logs") {
            outputError = result.ok ? "" : (result.message || i18n("Its output can't be read now"))
            const text = result.ok ? (result.lines || []).join("\n") : ""
            if (result.ok && text !== outputText) {   // (made again only when the screen changed)
                const following = outputText === "" || outputAtEnd()
                outputText = text
                outputHtml = Code.termHtml(result.runs || (result.lines || []).map(l => [[l, 0]]), result.styles || [{}], termStyle)
                if (following)
                    Qt.callLater(outputToEnd)
            }
            return
        }
        if (kind === "review") {
            reviewLoading = false
            review = result.ok ? result : null
            reviewFor = result.ok ? asked.chat : ""
            reviewError = result.ok ? "" : (result.message || "")
            if (result.ok && !commitEdited)
                commitText.text = result.message || ""
            return
        }
        info = result.message || (result.ok ? "" : i18n("That didn't work"))
        infoBad = !result.ok
        infoTimer.restart()
        if (kind === "send" && result.ok) {
            if (result.how === "ask") {
                askHow = true
                info = ""
                return
            }
            if (result.how === "vscode" && result.link)
                Qt.openUrlExternally(result.link)
            if (result.how === "copy") {
                if (!result.copied) {   // (your message stays in the box)
                    infoBad = true
                    return
                }
                root.openRow(row || chat, host)
            }
            replyBox.text = ""
            askHow = false
        }
        if (kind === "deny" || kind === "answer")
            answering = Math.max(0, answering - 1)
        if (kind === "commit" && result.ok) {
            commitOpen = false
            commitEdited = false
        }
        if (kind === "undo" || kind === "commit" || kind === "reviewed")
            loadReview()
        root.refresh()
        if (host)
            root.pollHost(host)
        stamp = ""   // (read it again now)
        load()
    }

    Exec {
        id: runner
        staleMs: pane.staleMs - 30000   // (less: the read load() gives up on runs again, not taken for one still running)
        onNewData: (source, data) => {
            disconnectSource(source)
            const asked = pane.runs[source] || { kind: "", chat: "", host: "", target: null }
            delete pane.runs[source]
            pane.handle(asked.kind, root.helperResult(data), asked)
        }
    }

    Timer {
        id: infoTimer
        interval: 12000
        onTriggered: pane.info = ""
    }

    // ---------------------------------------------------------------- dictating
    //
    // The microphone button: record, then whisper (whisper.cpp, or the
    // faster-whisper the widget sets up) writes it down here (dictate.py;
    // nothing leaves the computer) and it goes in at the cursor
    property string dictating: ""        // "", "recording", "writing", "model" (a model being downloaded), "setup"
    property string dictateId: ""
    property real dictateSince: 0
    property var dictateState: null      // dictate.py --status
    property bool offerModel: false      // (asks before it downloads one)
    property bool offerSetup: false      // (asks before it sets dictation up)

    function dictateRun(args) {
        dictateExec.connectSource("python3 -I " + root.shellQuote(root.codeDir + "dictate.py") + " " + args + " # " + Date.now())
    }
    function dictate() {
        if (dictating === "recording") {
            dictating = "writing"
            dictateRun("--stop " + dictateId + " --language " + root.shellQuote(Plasmoid.configuration.dictateLanguage || "auto"))
        } else if (dictating === "") {
            dictateRun("--status")
        }
    }
    function cancelDictation() {
        if (dictating === "recording")
            dictateRun("--cancel " + dictateId)
        dictating = ""
    }
    function noteDictation(message, bad) {
        pane.info = message
        pane.infoBad = bad
        infoTimer.restart()
    }
    Exec {
        id: dictateExec
        onNewData: (source, data) => {
            disconnectSource(source)
            const result = root.helperResult(data)
            if (source.indexOf(" --status") >= 0) {
                pane.dictateState = result
                if (result.ok) {
                    pane.dictateId = "r" + Date.now()
                    pane.dictating = "recording"
                    pane.dictateSince = Date.now()
                    pane.recordedMs = 0
                    pane.dictateRun("--start " + pane.dictateId)
                } else if (result.recorder && result.canSetup) {
                    pane.offerSetup = true
                } else if (result.recorder && result.tool && !result.model) {
                    pane.offerModel = true
                } else {
                    pane.noteDictation(i18n("To dictate, install %1.", (result.missing || []).join(i18n(" and "))), true)
                }
            } else if (source.indexOf(" --start ") >= 0) {
                if (!result.ok) {
                    pane.dictating = ""
                    pane.noteDictation(result.message, true)
                }
            } else if (source.indexOf(" --stop ") >= 0) {
                pane.dictating = ""
                if (result.ok && result.text) {
                    const at = replyBox.cursorPosition
                    replyBox.insert(at, (at > 0 && replyBox.text.charAt(at - 1).trim() !== "" ? " " : "") + result.text + " ")
                    replyBox.forceActiveFocus()
                } else {
                    pane.noteDictation(result.message, true)
                }
            } else if (source.indexOf(" --get-model ") >= 0 || source.indexOf(" --setup") >= 0) {
                pane.dictating = ""
                pane.noteDictation(result.message, !result.ok)
            }
        }
    }
    property real recordedMs: 0          // (the time on the button while it records)
    Timer {
        interval: 1000
        repeat: true
        running: pane.dictating === "recording"
        onTriggered: pane.recordedMs = Date.now() - pane.dictateSince
    }

    // ---------------------------------------------------------------- replying

    property bool askHow: false   // its terminal takes no text: background or copy?

    function send(how, afterTurn) {
        const text = replyBox.text.trim()
        if (!text)
            return
        run(afterTurn ? "later" : "send", "--send " + root.shellQuote(chatId) + " --text " + root.shellQuote(text)
            + (sessionId ? " --session " + root.shellQuote(sessionId) : "") + " --how " + (how || "auto")
            + (afterTurn ? " --after-turn --name " + root.shellQuote(chatName) : "") + paneArgs())
        if (afterTurn)
            replyBox.text = ""
    }

    readonly property string routeHint: {
        const where = host ? " " + i18n("(on %1)", host) : ""
        if (route === "tmux")
            return i18n("Typed into its tmux pane.") + where
        if (route === "vscode")
            return i18n("Goes into the chat's input in VS Code: press Enter there.") + where
        if (route === "terminal")
            return i18n("Its terminal takes no text from outside: Enter copies your message and opens its tab, to paste it there. Send, go on in the background: Claude there quits and the chat goes on in the background.") + where
        if (row && row.pid && row.kind === "bg")
            return i18n("Its background session stops, then goes on with your message.") + where
        return i18n("The chat goes on in the background with your message.") + where
    }

    // ---------------------------------------------------------------- permission prompt

    property int answering: 0   // answers on their way

    // (answers that never come back: the buttons work again after a while)
    Timer {
        id: answerStale
        interval: pane.staleMs
        onTriggered: pane.answering = 0
    }

    // answers: a question's, {question: [labels or text]} (decision "answer").
    // It answers what the pane shows only: the hook's request, or in tmux
    // the tool call it asks about (--expect: if it asks something else now,
    // nothing is pressed, and the pane says so)
    function answer(decision, note, answers) {
        const p = permission
        if (!p || (p.answer !== "hook" && p.answer !== "keys"))
            return
        answering += 1
        answerStale.restart()
        if (p.answer === "hook")
            run(decision === "deny" ? "deny" : "answer", "--answer " + root.shellQuote(p.request) + " --decision " + decision
                + (note ? " --note " + root.shellQuote(note) : "")
                + (answers ? " --answers " + root.shellQuote(JSON.stringify(answers)) : "")
                + (host ? " --host " + root.shellQuote(host) : "") + root.configDirArgs)
        else if (p.answer === "keys")
            run(decision === "deny" ? "deny" : "answer", "--keys " + root.shellQuote(sessionId) + " --decision " + decision
                + (note ? " --note " + root.shellQuote(note) : "")
                + (p.toolUse ? " --expect " + root.shellQuote(p.toolUse) : "") + paneArgs())
    }

    // ---------------------------------------------------------------- review

    property var review: null
    property string reviewFor: ""   // the chat that review is of: Undo and Commit act on that one only
    readonly property bool reviewIsThis: review !== null && reviewFor !== "" && reviewFor === chatId
    property bool reviewLoading: false
    property string reviewError: ""
    property var openFiles: ({})
    property bool commitOpen: false
    property bool commitEdited: false
    property string undoAsk: ""   // "*": all, else a file's path, asked to confirm

    function loadReview() {
        if (!chatId)
            return
        reviewLoading = true
        run("review", "--review " + root.shellQuote(chatId) + paneArgs())
    }
    onTabChanged: {
        if (tab === "review" && review === null)
            loadReview()
        if (tab === "output")
            loadOutput()
    }

    // A background session's screen (the Output tab): its terminal as Claude
    // draws it, in its colors on a terminal's dark ground (a light theme too)
    readonly property string jobId: row && row.kind === "bg" && row.jobId && row.pid ? row.jobId : ""
    property string outputText: ""
    property string outputHtml: ""
    property string outputError: ""
    readonly property var termStyle: ({ mono: monoFamily, pt: pt, fg: "#e3e3e3", bg: "#1f2124" })
    function outputAtEnd() {
        const f = outputView.contentItem
        return !f || f.contentY >= f.contentHeight - f.height - Kirigami.Units.gridUnit
    }
    function outputToEnd() {
        const f = outputView.contentItem
        if (f)
            f.contentY = Math.max(0, f.contentHeight - f.height)
    }
    function loadOutput() {
        if (jobId)
            run("logs", "--logs " + root.shellQuote(jobId) + paneArgs())
    }
    Timer {
        interval: 2000
        repeat: true
        running: pane.tab === "output" && pane.visible && pane.visibility !== Window.Minimized && pane.jobId !== ""
        onTriggered: pane.loadOutput()
    }
    onJobIdChanged: if (!jobId && tab === "output") tab = "chat"
    readonly property real editedAt: row && row.review ? row.review.editedAt || 0 : 0
    onEditedAtChanged: if (tab === "review") loadReview()

    function undo(path) {
        undoAsk = ""
        if (!reviewIsThis)
            return   // (the files shown aren't this chat's: its own review comes first)
        run("undo", "--undo " + root.shellQuote(chatId) + (path !== "*" ? " --file " + root.shellQuote(path) : "") + paneArgs())
    }

    function totals(files) {
        let added = 0, removed = 0
        for (const f of files || []) {
            added += f.added || 0
            removed += f.removed || 0
        }
        return [added, removed]
    }

    // ---------------------------------------------------------------- what's shown

    Rectangle {
        id: surface
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        // Files and pictures dropped on the pane go in your reply (a picture as
        // a pasted one, a file named with @), while the Chat tab shows
        DropArea {
            id: dropArea
            anchors.fill: parent
            z: 10
            enabled: pane.tab === "chat"
            keys: ["text/uri-list"]
            onDropped: drop => {
                const paths = (drop.urls || []).map(u => String(u)).filter(u => u.startsWith("file://"))
                                               .map(u => decodeURIComponent(u.slice(7)))
                if (paths.length) {
                    root.attachFiles(paths, pane.host, "pane")
                    drop.acceptProposedAction()
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                visible: dropArea.containsDrag
                radius: Kirigami.Units.cornerRadius * 2
                color: Qt.rgba(Kirigami.Theme.focusColor.r, Kirigami.Theme.focusColor.g, Kirigami.Theme.focusColor.b, 0.12)
                border.width: 2
                border.color: Kirigami.Theme.focusColor

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: pane.host ? i18n("Drop a picture: it's copied to %1 for your reply", pane.host)
                                    : i18n("Drop to add it to your reply")
                    font.pointSize: pane.pt * 1.2
                }
            }
        }

        // It grows out of the chat's row in the popup (main.qml: placePane):
        // from the popup's side, at the row's height
        opacity: 0
        transform: Scale { id: growBox; xScale: 1; yScale: 1 }
        ParallelAnimation {
            id: growing
            NumberAnimation { target: growBox; properties: "xScale,yScale"; from: 0.88; to: 1; duration: Kirigami.Units.longDuration * 1.6; easing.type: Easing.OutCubic }
            NumberAnimation { target: surface; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.longDuration * 1.2; easing.type: Easing.OutQuad }
            onStopped: { growBox.xScale = 1; growBox.yScale = 1; surface.opacity = 1 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            // Its name, where it runs and what it's doing
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.preferredWidth: Math.round(fm.height * 0.5)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: root.stateColor(pane.chatState)
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    text: pane.chatName
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    font.pointSize: pane.pt * 1.25
                    font.weight: Font.Bold
                }
                Tag {
                    visible: pane.host !== ""
                    text: pane.host
                    tooltip: i18n("This chat runs on the SSH host %1.", pane.host)
                }
                // what it's doing, in its state's color
                Rectangle {
                    readonly property color tone: pane.row ? root.stateColor(pane.chatState) : pane.mutedColor
                    implicitWidth: stateLabel.implicitWidth + Kirigami.Units.largeSpacing * 1.5
                    implicitHeight: stateLabel.implicitHeight + Kirigami.Units.smallSpacing
                    radius: height / 2
                    color: Qt.rgba(tone.r, tone.g, tone.b, 0.16)

                    PlasmaComponents3.Label {
                        id: stateLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: pane.row ? root.stateText(pane.row) : i18n("not running")
                        color: pane.chatState === "waiting" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                        font.weight: pane.chatState === "waiting" ? Font.Bold : Font.Normal
                    }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "zoom-out"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Smaller text")
                    enabled: pane.textPercent > pane.scales[0]
                    onClicked: pane.zoom(-1)
                    PlasmaComponents3.ToolTip.text: i18n("Smaller text (Ctrl+-, Ctrl+wheel)")
                    PlasmaComponents3.ToolTip.visible: hovered
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "zoom-in"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Larger text")
                    enabled: pane.textPercent < pane.scales[pane.scales.length - 1]
                    onClicked: pane.zoom(1)
                    PlasmaComponents3.ToolTip.text: i18n("Larger text (Ctrl+=, Ctrl+wheel; Ctrl+0: as it was)")
                    PlasmaComponents3.ToolTip.visible: hovered
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "window"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Open its window")
                    onClicked: root.openRow(pane.row || pane.chat, pane.host)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Open its window")
                        subText: i18n("The terminal or VS Code tab the chat runs in; a chat that isn't open reopens in a terminal.")
                    }
                }
            }
            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.leftMargin: Math.round(fm.height * 0.5) + Kirigami.Units.smallSpacing
                text: (pane.host ? pane.host + ":" : "") + (pane.row ? pane.row.cwdShort || pane.row.cwd || "" : pane.chat.cwd || "")
                font.family: pane.monoFamily
                font.pointSize: pane.pt * 0.85
                color: pane.mutedColor
                elide: Text.ElideMiddle
            }

            // Chat | Review, underlined in Claude's color
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: 0

                Repeater {
                    model: [
                        { tab: "chat", text: i18n("Chat") }].concat(pane.jobId ? [{ tab: "output", text: i18n("Output") }] : []).concat([
                        { tab: "review", text: pane.row && pane.row.changes
                              ? (pane.reviewPending ? i18nc("tab: the files a chat changed, not reviewed yet", "Review ±%1 •", pane.row.changes.count)
                                                    : i18nc("tab: the files a chat changed", "Review ±%1", pane.row.changes.count))
                              : i18n("Review") }
                    ])
                    delegate: MouseArea {
                        id: tabButton
                        required property var modelData
                        readonly property bool on: pane.tab === modelData.tab
                        implicitWidth: tabText.implicitWidth + Kirigami.Units.gridUnit * 1.5
                        implicitHeight: tabText.implicitHeight + Kirigami.Units.largeSpacing * 1.5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.tab = modelData.tab
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.text

                        PlasmaComponents3.Label {
                            id: tabText
                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: tabButton.modelData.text
                            font.pointSize: pane.pt
                            font.weight: tabButton.on ? Font.Bold : Font.Normal
                            color: tabButton.on || tabButton.containsMouse ? Kirigami.Theme.textColor : pane.mutedColor
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            radius: 1
                            visible: tabButton.on
                            color: pane.claudeColor
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: -Kirigami.Units.smallSpacing
                implicitHeight: 1
                color: pane.borderColor
            }

            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: pane.info !== ""
                text: pane.info
                wrapMode: Text.Wrap
                color: pane.infoBad ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
            }

            // ---------------------------------------------------------------- Chat
            PlasmaComponents3.ScrollView {
                id: scroll
                visible: pane.tab === "chat"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                ListView {
                    id: list
                    model: items
                    spacing: 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    // every item made and laid out once (not as it scrolls in), so the
                    // list doesn't jump while you scroll
                    cacheBuffer: 100000

                    // Ctrl+wheel: the text size
                    WheelHandler {
                        acceptedModifiers: Qt.ControlModifier
                        onWheel: event => pane.zoom(event.angleDelta.y > 0 ? 1 : -1)
                    }

                    header: Item {
                        width: list.width
                        implicitHeight: headerColumn.implicitHeight + Kirigami.Units.largeSpacing

                        ColumnLayout {
                            id: headerColumn
                            width: parent.width

                            PlasmaComponents3.Button {
                                visible: pane.more
                                Layout.alignment: Qt.AlignHCenter
                                icon.name: "go-up"
                                text: i18n("Show earlier")
                                onClicked: {
                                    pane.limit = Math.min(2000, pane.limit * 2)
                                    pane.stamp = ""
                                    pane.load()
                                }
                            }
                            PlasmaComponents3.Label {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                visible: !pane.loaded || pane.loadError !== ""
                                horizontalAlignment: Text.AlignHCenter
                                text: pane.loadError || i18n("Reading the chat…")
                                color: pane.loadError ? Kirigami.Theme.negativeTextColor : pane.mutedColor
                                font.pointSize: pane.pt
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    // While it works: ✻ what it's doing, in Claude's color
                    footer: Item {
                        width: list.width
                        implicitHeight: pane.chatState === "working" ? workingLine.implicitHeight + Kirigami.Units.gridUnit : 0
                        visible: pane.chatState === "working"

                        RowLayout {
                            id: workingLine
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            spacing: 0

                            PlasmaComponents3.Label {
                                id: spinner
                                property int step: 0
                                readonly property var glyphs: ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
                                Layout.preferredWidth: pane.gutter
                                textFormat: Text.PlainText
                                text: glyphs[step % glyphs.length]
                                color: pane.claudeColor
                                font.pointSize: pane.pt
                                font.weight: Font.Bold

                                Timer {
                                    interval: 120
                                    repeat: true
                                    running: workingLine.visible && pane.visible && pane.tab === "chat"
                                    onTriggered: spinner.step += 1
                                }
                            }
                            PlasmaComponents3.Label {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                // (what it's doing, unless that's the tool call just above)
                                readonly property bool toolAbove: items.count > 0 && items.get(items.count - 1).status === "open"
                                readonly property string activity: pane.row ? root.doingText(pane.row, pane.host).replace(/[….\s]+$/, "") : ""
                                text: (activity && !toolAbove ? activity : i18n("Working")) + "…"
                                elide: Text.ElideRight
                                color: pane.claudeColor
                                font.pointSize: pane.pt
                            }
                        }
                    }

                    delegate: Item {
                        id: entry
                        required property int index
                        required property string kind
                        required property string key
                        required property string text
                        required property string line
                        required property string name
                        required property string status
                        required property string input
                        required property string output
                        required property string summary
                        required property string prev
                        required property bool bad
                        required property string diff
                        readonly property bool unfolded: pane.openTools[key] === true
                        // more room before your prompt (a new turn) than between steps
                        readonly property real gap: index === 0 ? 0
                            : kind === "you" ? Kirigami.Units.gridUnit * 1.6
                            : kind === "tool" && prev === "tool" ? Kirigami.Units.smallSpacing * 1.5
                            : Kirigami.Units.gridUnit * 0.8
                        width: list.width
                        implicitHeight: gap + body.implicitHeight
                        height: implicitHeight

                        Loader {
                            id: body
                            y: entry.gap
                            width: parent.width
                            sourceComponent: entry.kind === "you" ? youItem : entry.kind === "claude" ? claudeItem
                                           : entry.kind === "tool" ? toolItem : noteItem
                        }

                        // Yours: a band in your accent color, after a ›
                        Component {
                            id: youItem

                            Rectangle {
                                implicitHeight: youRow.implicitHeight + Kirigami.Units.largeSpacing * 1.5
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(pane.youColor.r, pane.youColor.g, pane.youColor.b, 0.13))

                                Rectangle {
                                    width: 3
                                    height: parent.height
                                    radius: 1.5
                                    color: pane.youColor
                                }
                                RowLayout {
                                    id: youRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: Kirigami.Units.largeSpacing
                                    spacing: 0

                                    PlasmaComponents3.Label {
                                        Layout.preferredWidth: pane.gutter
                                        Layout.alignment: Qt.AlignTop
                                        horizontalAlignment: Text.AlignHCenter
                                        textFormat: Text.PlainText
                                        text: "›"
                                        color: pane.youColor
                                        font.pointSize: pane.pt
                                        font.weight: Font.Bold
                                    }
                                    TextEdit {
                                        Layout.fillWidth: true
                                        text: entry.text
                                        textFormat: TextEdit.PlainText
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: TextEdit.Wrap
                                        color: Kirigami.Theme.textColor
                                        selectionColor: Kirigami.Theme.focusColor
                                        selectedTextColor: Kirigami.Theme.highlightedTextColor
                                        font.family: Kirigami.Theme.defaultFont.family
                                        font.pointSize: pane.pt
                                    }
                                }
                            }
                        }

                        // Claude's reply: ● and its Markdown, rendered
                        Component {
                            id: claudeItem

                            RowLayout {
                                spacing: 0

                                Dot {
                                    color: pane.claudeColor
                                    gutter: pane.gutter
                                    lineHeight: fm.height
                                }
                                TextEdit {
                                    Layout.fillWidth: true
                                    text: Md.toHtml(entry.text, pane.mdStyle)
                                    textFormat: TextEdit.RichText
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    color: Kirigami.Theme.textColor
                                    selectionColor: Kirigami.Theme.focusColor
                                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                                    font.family: Kirigami.Theme.defaultFont.family
                                    font.pointSize: pane.pt
                                    onLinkActivated: link => {
                                        if (link.indexOf("copy:") === 0)
                                            pane.copyText(Md.codeBlocks(entry.text)[Number(link.slice(5))] || "")
                                        else
                                            Qt.openUrlExternally(link)
                                    }

                                    HoverHandler {
                                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                                    }
                                }
                            }
                        }

                        // A tool call: ● Bash(pytest) in green, red or (still going) blinking,
                        // and under it ⎿ what came of it; click for what it ran and got
                        Component {
                            id: toolItem

                            ColumnLayout {
                                id: toolBox
                                spacing: Kirigami.Units.smallSpacing
                                readonly property bool asking: !!pane.permission && entry.status === "open" && entry.index === items.count - 1
                                readonly property bool going: entry.status === "open" && pane.busy
                                readonly property string args: entry.line.indexOf(entry.name + ": ") === 0 ? entry.line.slice(entry.name.length + 2) : ""

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: toolRow.implicitHeight + Kirigami.Units.smallSpacing
                                    radius: Kirigami.Units.cornerRadius
                                    color: toolHover.hovered ? pane.mix(pane.textColor, 0.06) : "transparent"

                                    RowLayout {
                                        id: toolRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        Dot {
                                            Layout.alignment: Qt.AlignTop
                                            color: entry.status === "ok" ? Kirigami.Theme.positiveTextColor
                                                 : entry.status === "error" ? Kirigami.Theme.negativeTextColor
                                                 : toolBox.asking ? Kirigami.Theme.neutralTextColor : pane.mutedColor
                                            blinking: toolBox.going && pane.visible
                                            gutter: pane.gutter
                                            lineHeight: fm.height
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            // Bash  git status: the tool, then what it got, set apart in code's font
                                            PlasmaComponents3.Label {
                                                Layout.fillWidth: true
                                                textFormat: Text.StyledText
                                                text: toolBox.args ? "<b>" + Md.escape(entry.name) + "</b>&nbsp;&nbsp;<font face=\"" + pane.monoFamily
                                                                     + "\" color=\"" + pane.hex(pane.codeColor) + "\">" + Md.escape(toolBox.args) + "</font>"
                                                                   : "<b>" + Md.escape(entry.line) + "</b>"
                                                wrapMode: Text.Wrap
                                                maximumLineCount: entry.unfolded ? 20 : 2
                                                elide: Text.ElideRight
                                                font.pointSize: pane.pt
                                            }
                                            PlasmaComponents3.Label {
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                                textFormat: Text.PlainText
                                                text: entry.summary ? "⎿  " + entry.summary
                                                    : toolBox.asking ? "⎿  " + i18n("Waiting for your answer")
                                                    : ""
                                                elide: Text.ElideRight
                                                font.pointSize: pane.pt * 0.92
                                                color: entry.status === "error" ? Kirigami.Theme.negativeTextColor
                                                     : toolBox.asking ? Kirigami.Theme.neutralTextColor : pane.mutedColor
                                            }
                                            // An edit's change, right under it (its first lines; unfolded, all
                                            // of it). Made only for an edit: the pane opens as quickly as before
                                            Loader {
                                                active: entry.diff !== ""
                                                visible: active
                                                Layout.fillWidth: true
                                                Layout.topMargin: active ? Kirigami.Units.smallSpacing : 0
                                                sourceComponent: DiffView {
                                                    lines: entry.diff.split("\n")
                                                    path: toolBox.args
                                                    maxRows: entry.unfolded ? 0 : 6
                                                    canSplit: entry.unfolded
                                                    pt: pane.pt
                                                    mono: pane.monoFamily
                                                    base: pane.mdStyle.blockBg
                                                }
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: toolHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: {
                                            const next = Object.assign({}, pane.openTools)
                                            next[entry.key] = !entry.unfolded
                                            pane.openTools = next
                                        }
                                    }
                                }
                                // Unfolded: the command and what it printed, the lines it read
                                // (numbered, in the file's colors), or what it was asked and got
                                // (codehtml.mjs; an edit's change is above, its error here)
                                Loader {
                                    active: entry.unfolded && (entry.input !== "" || entry.output !== "")
                                            && (entry.diff === "" || entry.status === "error")
                                    visible: active
                                    Layout.fillWidth: true
                                    Layout.leftMargin: pane.gutter
                                    sourceComponent: Rectangle {
                                        implicitHeight: detail.implicitHeight + Kirigami.Units.largeSpacing * 1.5
                                        radius: Kirigami.Units.cornerRadius
                                        color: pane.mdStyle.blockBg
                                        border.width: 1
                                        border.color: pane.borderColor

                                        TextEdit {
                                            id: detail
                                            anchors.fill: parent
                                            anchors.margins: Kirigami.Units.largeSpacing * 0.75
                                            text: Code.toolHtml({ name: entry.name, input: entry.input, output: entry.output, status: entry.status },
                                                                toolBox.args, pane.codeStyle)
                                            textFormat: TextEdit.RichText
                                            readOnly: true
                                            selectByMouse: true
                                            wrapMode: TextEdit.Wrap
                                            color: Kirigami.Theme.textColor
                                            selectionColor: Kirigami.Theme.focusColor
                                            selectedTextColor: Kirigami.Theme.highlightedTextColor
                                        }
                                    }
                                }
                            }
                        }

                        // A note: interrupted, a usage limit, compacted (── Interrupted ──)
                        Component {
                            id: noteItem

                            RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: entry.bad ? Kirigami.Theme.negativeTextColor : pane.borderColor
                                }
                                PlasmaComponents3.Label {
                                    Layout.maximumWidth: list.width * 0.75
                                    textFormat: Text.PlainText
                                    text: entry.text
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    font.italic: true
                                    font.pointSize: pane.pt * 0.9
                                    color: entry.bad ? Kirigami.Theme.negativeTextColor : pane.mutedColor
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 1
                                    color: entry.bad ? Kirigami.Theme.negativeTextColor : pane.borderColor
                                }
                            }
                        }
                    }
                }
            }

            // What it asks while it waits: Allow once / Always allow / Deny, or its questions
            // (at most half the pane, scrolling, so the conversation stays in sight)
            Rectangle {
                visible: pane.tab === "chat" && pane.permission !== null
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(askColumn.implicitHeight + Kirigami.Units.largeSpacing * 2, pane.height / 2)
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(Kirigami.Theme.neutralTextColor.r, Kirigami.Theme.neutralTextColor.g, Kirigami.Theme.neutralTextColor.b, 0.08)
                border.width: 1
                border.color: Kirigami.Theme.neutralTextColor

                PlasmaComponents3.ScrollView {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    contentWidth: availableWidth
                    PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                    PermissionAsk {
                        id: askColumn
                        width: parent.width
                        permission: pane.permission
                        busy: pane.answering > 0
                        diffLines: 12
                        planHeight: Kirigami.Units.gridUnit * 1000   // (the box scrolls)
                        onAnswered: (decision, note, answers) => pane.answer(decision, note, answers)
                    }
                }
            }

            // Your reply
            ColumnLayout {
                visible: pane.tab === "chat"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    visible: pane.queued !== null
                    Layout.fillWidth: true

                    PlasmaComponents3.Label {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: pane.queued ? i18n("Sent when this turn ends: %1", pane.queued.prompt) : ""
                        elide: Text.ElideRight
                        color: Kirigami.Theme.focusColor
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "edit-delete-remove"
                        text: i18n("Cancel")
                        onClicked: root.unqueue(pane.queued)
                    }
                }
                // What it offers for what you're typing (/ commands, @ files)
                Rectangle {
                    visible: pane.suggestions.length > 0 && replyBox.activeFocus
                    Layout.fillWidth: true
                    Layout.leftMargin: pane.gutter
                    implicitHeight: offerList.implicitHeight + 2
                    radius: Kirigami.Units.cornerRadius
                    color: pane.mix(pane.textColor, 0.06)
                    border.width: 1
                    border.color: pane.borderColor

                    Column {
                        id: offerList
                        x: 1
                        y: 1
                        width: parent.width - 2
                        Repeater {
                            model: pane.suggestions.length
                            delegate: Rectangle {
                                required property int index
                                readonly property var offer: pane.suggestions[index] || { text: "", about: "" }
                                width: offerList.width
                                height: offerRow.implicitHeight + Kirigami.Units.smallSpacing
                                radius: Kirigami.Units.cornerRadius
                                color: index === pane.suggestion ? Qt.rgba(pane.youColor.r, pane.youColor.g, pane.youColor.b, 0.22) : "transparent"
                                RowLayout {
                                    id: offerRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Kirigami.Units.smallSpacing
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    PlasmaComponents3.Label {
                                        textFormat: Text.PlainText
                                        text: offer.text
                                        font.family: pane.monoFamily
                                        font.pointSize: pane.pt * 0.95
                                        color: index === pane.suggestion ? pane.youColor : pane.textColor
                                        elide: Text.ElideMiddle
                                        Layout.maximumWidth: offerList.width * 0.6
                                    }
                                    PlasmaComponents3.Label {
                                        textFormat: Text.PlainText
                                        Layout.fillWidth: true
                                        text: offer.about
                                        color: pane.mutedColor
                                        font.pointSize: pane.pt * 0.85
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        pane.takeSuggestion(index)
                                        replyBox.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }
                // a box like Claude's prompt: › and what you type, framed (your accent while you type)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(fm.height * 9, Math.max(fm.height * 3.2, replyBox.implicitHeight + Kirigami.Units.smallSpacing * 2))
                    radius: Kirigami.Units.cornerRadius * 1.5
                    color: pane.mix(pane.textColor, 0.035)
                    border.width: replyBox.activeFocus ? 2 : 1
                    border.color: replyBox.activeFocus ? pane.youColor : pane.borderColor
                    opacity: replyBox.enabled ? 1 : 0.6

                    PlasmaComponents3.Label {
                        x: 0
                        y: Kirigami.Units.smallSpacing + replyBox.topPadding
                        width: pane.gutter
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: "›"
                        color: replyBox.activeFocus ? pane.youColor : pane.mutedColor
                        font.pointSize: pane.pt
                        font.weight: Font.Bold
                    }
                    PlasmaComponents3.ScrollView {
                        anchors.fill: parent
                        anchors.leftMargin: pane.gutter - replyBox.leftPadding
                        anchors.topMargin: Kirigami.Units.smallSpacing
                        anchors.bottomMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing

                        PlasmaComponents3.TextArea {
                            id: replyBox
                            background: null
                            placeholderText: pane.permission ? i18n("It's asking you something: answer that first")
                                                             : i18n("Reply to Claude… (Enter sends, Shift+Enter: new line; Ctrl+V or drop: a picture or a file too)")
                            wrapMode: TextEdit.Wrap
                            font.pointSize: pane.pt
                            enabled: !(pane.permission && pane.route === "tmux")
                            // Enter sends, as in Claude's own prompt (Shift+Enter: a new line). For a
                            // terminal that takes no text from outside, Enter copies it and opens its
                            // tab (pane.py how enter): Claude there never quits on an Enter.
                            // Ctrl+V with no text on the clipboard: its picture (an SSH host's
                            // chat asks to copy it there).
                            onTextChanged: {
                                if (pane.historyAt >= 0 && text !== (pane.offers ? pane.offers.history[pane.historyAt] : ""))
                                    pane.historyAt = -1   // (typed into a past prompt: it's yours now)
                                pane.suggest()
                            }
                            onCursorPositionChanged: pane.suggest()
                            onActiveFocusChanged: if (activeFocus) pane.loadOffers()
                            Keys.onPressed: event => {
                                if (pane.suggestions.length) {
                                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                                        const n = pane.suggestions.length
                                        pane.suggestion = (pane.suggestion + (event.key === Qt.Key_Down ? 1 : n - 1)) % n
                                        event.accepted = true
                                        return
                                    }
                                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        pane.takeSuggestion(pane.suggestion)
                                        event.accepted = true
                                        return
                                    }
                                    if (event.key === Qt.Key_Escape) {
                                        pane.dismissed = text.slice(pane.tokenStart, cursorPosition)
                                        pane.suggestions = []
                                        event.accepted = true
                                        return
                                    }
                                }
                                if ((event.key === Qt.Key_Up && text.lastIndexOf("\n", cursorPosition - 1) < 0)
                                        || (event.key === Qt.Key_Down && pane.historyAt >= 0 && text.indexOf("\n", cursorPosition) < 0)) {
                                    if (event.modifiers === Qt.NoModifier && (text === "" || pane.historyAt >= 0 || event.key === Qt.Key_Down)
                                            && pane.historyStep(event.key === Qt.Key_Up ? 1 : -1)) {
                                        event.accepted = true
                                        return
                                    }
                                }
                                if (event.matches(StandardKey.Paste) && !canPaste) {
                                    event.accepted = true
                                    root.pasteImage(pane.host, "pane")
                                    return
                                }
                                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                                    return
                                if (event.modifiers & Qt.ShiftModifier) {
                                    if (selectedText)
                                        remove(selectionStart, selectionEnd)
                                    insert(cursorPosition, "\n")
                                } else if (preeditText === "") {   // (not while an input method composes)
                                    pane.send("enter", false)
                                } else {
                                    return
                                }
                                event.accepted = true
                            }
                        }
                    }
                }
                // The pictures your reply names, small (× takes one out)
                PictureStrip {
                    id: replyPictures
                    Layout.fillWidth: true
                    Layout.leftMargin: pane.gutter
                    pictures: named(replyBox.text)
                    host: pane.host
                    removeText: i18n("Take it out of your reply")
                    onRemoveRequested: path => replyBox.text = without(replyBox.text, path)
                }
                // A picture for an SSH host's chat: copied there once you say so
                RowLayout {
                    Layout.fillWidth: true
                    visible: !!pane.host && !!root.pictureOffer && root.pictureOffer.host === pane.host
                             && root.pictureOffer.target === "pane"
                    spacing: Kirigami.Units.smallSpacing

                    Image {
                        source: root.pictureOffer ? "file://" + encodeURI(root.pictureOffer.path) : ""
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        sourceSize.height: Kirigami.Units.gridUnit * 2 * Screen.devicePixelRatio
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    ConfirmLine {
                        Layout.fillWidth: true
                        text: i18n("Copy this picture to %1? Claude there can only open it there.", pane.host)
                        confirmText: i18n("Copy")
                        onConfirmed: root.copyPicture()
                        onCancelled: root.pictureOffer = null
                    }
                }
                PlasmaComponents3.Label {
                    visible: !!pane.host && root.pictureCopyingTo === pane.host && root.pictureCopyTarget === "pane"
                    textFormat: Text.PlainText
                    text: i18n("Copying the picture to %1…", pane.host)
                    color: pane.mutedColor
                }
                // Nothing to write it down with: dictation is set up once you say so
                ConfirmLine {
                    Layout.fillWidth: true
                    visible: pane.offerSetup
                    text: i18n("Set up dictation? It installs faster-whisper, speech to text that runs on this computer, and its base speech model: about %1 MB from pypi.org and huggingface.co into ~/.local/share/talpy-den/whisper, no sudo needed; a few minutes. What you say never leaves the computer. Other models: in the settings.",
                               pane.dictateState ? pane.dictateState.setupMb : 612)
                    confirmText: i18n("Set up")
                    onConfirmed: {
                        pane.offerSetup = false
                        pane.dictating = "setup"
                        pane.dictateRun("--setup")
                    }
                    onCancelled: pane.offerSetup = false
                }
                // whisper is there but no speech model: one is downloaded once you say so
                ConfirmLine {
                    Layout.fillWidth: true
                    visible: pane.offerModel
                    text: i18n("To dictate, %1 needs a speech model: download its base model (142 MB) from huggingface.co? It's kept in ~/.local/share/talpy-den/whisper; what you say never leaves the computer. Other models: in the settings.",
                               pane.dictateState && pane.dictateState.engine ? pane.dictateState.engine : "whisper")
                    confirmText: i18n("Download")
                    onConfirmed: {
                        pane.offerModel = false
                        pane.dictating = "model"
                        pane.dictateRun("--get-model base")
                    }
                    onCancelled: pane.offerModel = false
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: pane.routeHint
                    wrapMode: Text.Wrap
                    font.pointSize: pane.pt * 0.85
                    color: pane.mutedColor
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.ToolButton {
                        icon.name: pane.dictating === "recording" ? "media-playback-stop" : "audio-input-microphone"
                        icon.color: pane.dictating === "recording" ? Kirigami.Theme.negativeTextColor : "transparent"
                        enabled: pane.dictating === "" || pane.dictating === "recording"
                        text: pane.dictating === "recording" ? i18n("Stop: write it down") + " · " + root.duration(Math.max(1000, pane.recordedMs))
                              : pane.dictating === "writing" ? i18n("Writing it down…")
                              : pane.dictating === "model" ? i18n("Downloading the speech model…")
                              : pane.dictating === "setup" ? i18n("Setting up dictation (a few minutes)…") : i18n("Dictate")
                        display: pane.dictating === "" ? PlasmaComponents3.AbstractButton.IconOnly : PlasmaComponents3.AbstractButton.TextBesideIcon
                        onClicked: pane.dictate()

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("Dictate")
                            subText: i18n("Say your reply: click again to stop, and it's written down where you're typing. On this computer only (whisper): what you say doesn't leave it. The speech model: in the settings.")
                        }
                    }
                    PlasmaComponents3.ToolButton {
                        visible: pane.dictating === "recording"
                        icon.name: "dialog-cancel"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: i18n("Stop, don't write it down")
                        onClicked: pane.cancelDictation()
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "list-add"
                        text: i18n("Attach files…")
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        onClicked: root.pickFiles(pane.host, "pane", pane.row ? pane.row.cwd || "" : pane.chat.cwd || "")

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("Attach files…")
                            subText: pane.host ? i18n("Pick pictures for your reply (copied to %1 once you say so).", pane.host)
                                               : i18n("Pick files for your reply: a picture goes in as one, another file is named for Claude to read. You can drop them on the pane too.")
                        }
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "spectacle"
                        text: i18n("Screenshot…")
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        onClicked: root.takeScreenshot(pane.host, "pane")

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("Screenshot…")
                            subText: i18n("Pick a region of the screen: its picture goes in your reply. Files and pictures can be dropped on the pane too.")
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    PlasmaComponents3.Button {
                        visible: pane.route === "terminal" || pane.askHow
                        enabled: replyBox.text.trim() !== ""
                        icon.name: "edit-copy"
                        text: i18n("Copy and open its tab")
                        onClicked: pane.send("copy", false)
                    }
                    PlasmaComponents3.Button {
                        visible: pane.busy
                        enabled: replyBox.text.trim() !== ""
                        icon.name: "chronometer"
                        text: i18n("Send when this turn ends")
                        onClicked: pane.send(pane.route === "terminal" ? "background" : "auto", true)

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("Send when this turn ends")
                            subText: i18n("The widget keeps it and sends it once Claude's turn is over (also with the popup closed).")
                        }
                    }
                    PlasmaComponents3.Button {
                        enabled: replyBox.text.trim() !== "" && !(pane.route === "terminal" && pane.busy)
                                 && !(pane.permission && pane.route === "tmux")
                        icon.name: "document-send"
                        text: pane.route === "terminal" || pane.askHow ? i18n("Send, go on in the background") : i18n("Send")
                        onClicked: pane.send(pane.route === "terminal" || pane.askHow ? "background" : "auto", false)
                    }
                }
            }

            // ---------------------------------------------------------------- Output
            // A background session's screen now (pane.py --logs: claude logs),
            // its tool calls, diffs and spinner as its terminal shows them, in
            // their colors, read again every 2 s while shown; it stays at the
            // end as it changes, unless you scrolled up
            ColumnLayout {
                visible: pane.tab === "output"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing

                    Rectangle {
                        implicitWidth: Kirigami.Units.smallSpacing * 1.5
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: pane.outputError ? pane.mutedColor : Kirigami.Theme.positiveTextColor
                    }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: pane.outputError || i18n("Its terminal right now, as Claude draws it in the background")
                        color: pane.outputError ? Kirigami.Theme.neutralTextColor : pane.mutedColor
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                    }
                    PlasmaComponents3.ToolButton {
                        icon.name: "go-bottom"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: i18n("To the end")
                        onClicked: pane.outputToEnd()
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Kirigami.Units.cornerRadius
                    color: pane.termStyle.bg
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    PlasmaComponents3.ScrollView {
                        id: outputView
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing * 0.75
                        PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AsNeeded

                        TextEdit {
                            text: pane.outputHtml
                            textFormat: TextEdit.RichText
                            readOnly: true
                            selectByMouse: true
                            color: pane.termStyle.fg
                            selectionColor: Kirigami.Theme.focusColor
                            selectedTextColor: Kirigami.Theme.highlightedTextColor
                        }
                    }
                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        visible: pane.outputHtml === ""
                        textFormat: Text.PlainText
                        text: pane.outputError ? "" : i18n("Reading its screen…")
                        color: "#9a9a9a"
                    }
                }
            }

            // ---------------------------------------------------------------- Review
            PlasmaComponents3.ScrollView {
                visible: pane.tab === "review"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        visible: pane.review === null
                        text: pane.reviewLoading ? i18n("Comparing its files with how they were before the chat…")
                                                 : pane.reviewError || i18n("Nothing to review yet")
                        color: pane.reviewError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: 0.7
                        wrapMode: Text.Wrap
                    }
                    PlasmaComponents3.Label {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        visible: pane.review !== null && pane.review.files.length === 0
                        text: i18n("No changed files: they're as they were before this chat.")
                        opacity: 0.7
                        wrapMode: Text.Wrap
                    }

                    // the files, +/- lines, their diffs
                    RowLayout {
                        visible: pane.review !== null && pane.review.files.length > 0
                        Layout.fillWidth: true

                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            readonly property var sums: pane.totals(pane.review ? pane.review.files : [])
                            text: pane.review ? i18np("%1 file changed since the chat started", "%1 files changed since the chat started",
                                                     pane.review.files.length) + "  +" + sums[0] + " −" + sums[1] : ""
                            font.bold: true
                        }
                        TestsBadge {
                            review: pane.row ? pane.row.review : (pane.review ? { tests: pane.review.tests } : null)
                        }
                        PlasmaComponents3.ToolButton {
                            icon.name: "view-split-left-right"
                            checkable: true
                            checked: Plasmoid.configuration.diffSideBySide
                            display: PlasmaComponents3.AbstractButton.IconOnly
                            text: i18n("Side by side")
                            onToggled: Plasmoid.configuration.diffSideBySide = checked

                            PlasmaCore.ToolTipArea {
                                textFormat: Text.PlainText
                                anchors.fill: parent
                                mainText: i18n("Side by side")
                                subText: i18n("Each change as before | after, where the pane is wide enough; else removed and added lines one after the other.")
                            }
                        }
                    }
                    Repeater {
                        model: pane.review ? pane.review.files.length : 0
                        delegate: ColumnLayout {
                            id: fileItem
                            required property int index
                            readonly property var file: pane.review && pane.review.files[index] ? pane.review.files[index] : ({ label: "", path: "", diff: [] })
                            readonly property bool unfolded: pane.openFiles[file.path] === true
                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents3.Label {
                                    textFormat: Text.PlainText
                                    text: fileItem.unfolded ? "▾" : "▸"
                                    opacity: 0.6
                                }
                                PlasmaComponents3.Label {
                                    textFormat: Text.PlainText
                                    Layout.fillWidth: true
                                    text: fileItem.file.label + (fileItem.file.created ? "  " + i18nc("a file the chat made", "(new)") : "")
                                          + (fileItem.file.deleted ? "  " + i18nc("a file the chat removed", "(removed)") : "")
                                    elide: Text.ElideMiddle
                                    font.family: "monospace"

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const next = Object.assign({}, pane.openFiles)
                                            next[fileItem.file.path] = !fileItem.unfolded
                                            pane.openFiles = next
                                        }
                                    }
                                }
                                PlasmaComponents3.Label {
                                    textFormat: Text.PlainText
                                    visible: fileItem.file.added !== null && fileItem.file.added !== undefined
                                    text: "+" + fileItem.file.added
                                    color: Kirigami.Theme.positiveTextColor
                                    font.family: "monospace"
                                }
                                PlasmaComponents3.Label {
                                    textFormat: Text.PlainText
                                    visible: fileItem.file.removed !== null && fileItem.file.removed !== undefined
                                    text: "−" + fileItem.file.removed
                                    color: Kirigami.Theme.negativeTextColor
                                    font.family: "monospace"
                                }
                                PlasmaComponents3.Label {
                                    textFormat: Text.PlainText
                                    visible: !!fileItem.file.binary || !!fileItem.file.unknown
                                    text: fileItem.file.binary ? i18n("binary") : i18n("no earlier version kept")
                                    opacity: 0.6
                                    font: Kirigami.Theme.smallFont
                                }
                                PlasmaComponents3.ToolButton {
                                    visible: !fileItem.file.unknown
                                    icon.name: "edit-undo"
                                    display: PlasmaComponents3.AbstractButton.IconOnly
                                    text: i18n("Undo this file")
                                    onClicked: pane.undoAsk = fileItem.file.path

                                    PlasmaCore.ToolTipArea {
                                        textFormat: Text.PlainText
                                        anchors.fill: parent
                                        mainText: i18n("Undo this file")
                                        subText: i18n("Asks first. Puts it back as it was before this chat.")
                                    }
                                }
                            }
                            ConfirmLine {
                                visible: pane.undoAsk === fileItem.file.path
                                Layout.fillWidth: true
                                text: fileItem.file.created ? i18n("Remove %1? The chat made it.", fileItem.file.label)
                                                            : i18n("Put %1 back as it was before this chat? Later changes to it are lost too.", fileItem.file.label)
                                confirmText: i18n("Undo")
                                onConfirmed: pane.undo(fileItem.file.path)
                                onCancelled: pane.undoAsk = ""
                            }
                            PlasmaComponents3.Label {
                                visible: fileItem.unfolded && !!fileItem.file.unknown && !!fileItem.file.now && fileItem.file.now.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.gridUnit
                                textFormat: Text.PlainText
                                text: i18n("No earlier version was kept, so this is how it is now:")
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                wrapMode: Text.Wrap
                            }
                            Loader {
                                active: fileItem.unfolded && ((fileItem.file.diff || []).length > 0 || (fileItem.file.now || []).length > 0)
                                visible: active
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.gridUnit
                                sourceComponent: DiffView {
                                    lines: fileItem.file.diff || []
                                    now: fileItem.file.unknown ? fileItem.file.now || [] : []
                                    path: fileItem.file.path
                                    pt: pane.pt
                                    mono: pane.monoFamily
                                    base: pane.mdStyle.blockBg
                                }
                            }
                        }
                    }

                    // Commit only these files, with a message from its name and recap
                    ColumnLayout {
                        visible: pane.commitOpen && pane.review !== null
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.largeSpacing

                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: pane.review && pane.review.repos.length
                                  ? i18n("Commit only these files in %1 (yours that aren't this chat's stay as they are):", pane.review.repos.join(", "))
                                  : i18n("None of these files is in a git repository.")
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents3.TextArea {
                            id: commitText
                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                            wrapMode: TextEdit.Wrap
                            font.family: "monospace"
                            onTextChanged: if (activeFocus) pane.commitEdited = true
                        }
                        RowLayout {
                            Item {
                                Layout.fillWidth: true
                            }
                            PlasmaComponents3.Button {
                                text: i18n("Cancel")
                                onClicked: pane.commitOpen = false
                            }
                            PlasmaComponents3.Button {
                                enabled: commitText.text.trim() !== "" && pane.reviewIsThis && pane.review.repos.length > 0
                                icon.name: "vcs-commit"
                                text: i18n("Commit")
                                onClicked: pane.run("commit", "--commit " + root.shellQuote(pane.chatId) + " --message "
                                                    + root.shellQuote(commitText.text) + pane.paneArgs())
                            }
                        }
                    }
                    ConfirmLine {
                        visible: pane.undoAsk === "*"
                        Layout.fillWidth: true
                        text: i18n("Put all of them back as they were before this chat? Files it made are removed; later changes to them are lost too.")
                        confirmText: i18n("Undo all")
                        onConfirmed: pane.undo("*")
                        onCancelled: pane.undoAsk = ""
                    }
                }
            }
            RowLayout {
                visible: pane.tab === "review"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Compare again")
                    onClicked: pane.loadReview()
                }
                Item {
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Button {
                    enabled: pane.reviewIsThis && pane.review.files.length > 0
                    icon.name: "edit-undo"
                    text: i18n("Undo all…")
                    onClicked: pane.undoAsk = "*"
                }
                PlasmaComponents3.Button {
                    enabled: pane.reviewIsThis && pane.review.files.length > 0 && pane.review.repos.length > 0
                    icon.name: "vcs-commit"
                    text: i18n("Commit these files…")
                    onClicked: pane.commitOpen = !pane.commitOpen
                }
                PlasmaComponents3.Button {
                    readonly property bool marked: !!pane.row && !pane.reviewPending && !!pane.row.review
                    icon.name: marked ? "checkmark" : "view-task"
                    text: marked ? i18n("Reviewed") : i18n("Mark reviewed")
                    checkable: false
                    onClicked: pane.run("reviewed", "--reviewed " + root.shellQuote(pane.chatId) + (marked ? " --off" : "")
                                        + (pane.host ? " --host " + root.shellQuote(pane.host) : "") + root.configDirArgs)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: parent.marked ? i18n("Reviewed") : i18n("Mark reviewed")
                        subText: parent.marked ? i18n("Click to mark it not reviewed.")
                                               : i18n("Its row stops saying \"to review\", until it changes files again.")
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// One Claude account: plan limits, token totals, its sessions (which may
// come from several config dirs logged into that account) and recent chats.
// With remoteHost set, the account is on that SSH host: its actions run there.
ColumnLayout {
    id: section

    property var group
    property bool last: false
    property string remoteHost: ""
    property int accounts: 1          // how many accounts its machine has (the default one is marked)

    readonly property string groupKey: (remoteHost ? remoteHost + "/" : "") + group.id
    readonly property var recent: group.recent || []
    readonly property bool recentOpen: !!root.expandedRecent[groupKey]
    readonly property var plans: group.plans || []
    readonly property var queued: root.queuedFor(group, remoteHost)
    readonly property bool plansOpen: !!root.expandedPlans[groupKey]
    // the chats and plans you starred, however old (listed first while unfolded)
    readonly property var starred: group.starred || []
    readonly property var starredPlans: group.starredPlans || []
    readonly property bool starredOpen: !!root.expandedStarred[groupKey + "|chats"]
    readonly property bool starredPlansOpen: !!root.expandedStarred[groupKey + "|plans"]
    readonly property var starredShown: starredOpen ? starred : []
    readonly property var starredPlansShown: starredPlansOpen ? starredPlans : []
    readonly property var memories: group.memories || []
    readonly property bool memoriesOpen: !!root.expandedMemories[groupKey]

    readonly property var tokens: group.tokens
    readonly property bool hasTokens: tokens !== null && tokens !== undefined
    readonly property bool hasStats: !!group.stats
    readonly property bool statsOpen: hasStats && root.expandedStats[groupKey] === true
    readonly property bool multiProfile: group.profiles.length > 1

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            id: heading
            textFormat: Text.PlainText
            level: 2   // (as the Recap tab's section titles)
            font.weight: Font.Bold
            text: section.group.title
            elide: Text.ElideRight
            Layout.maximumWidth: section.width - newChatButton.width - (defaultTag.visible ? defaultTag.width : 0) - Kirigami.Units.gridUnit * 6
        }
        // The default account: listed first, VS Code's Claude and plain claude run on it
        Tag {
            id: defaultTag
            visible: !!section.group.defaultHere && section.accounts > 1
            text: i18n("default")
            tooltipTitle: section.remoteHost ? i18n("The default account on %1", section.remoteHost) : i18n("The default account")
            tooltip: (section.remoteHost
                      ? i18n("Listed first; VS Code's Claude on %1 (its VS Code server) and plain claude there run on it.", section.remoteHost)
                      : i18n("Listed first, its 5-hour usage is next to the panel icon, and VS Code's Claude and plain claude run on it."))
                     + " " + i18n("Change it in the widget's settings: Accounts, Make Default.")
        }
        PlasmaComponents3.ToolButton {
            id: newChatButton
            icon.name: "list-add"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: i18n("New chat")
            Layout.preferredHeight: heading.implicitHeight
            Layout.preferredWidth: Layout.preferredHeight
            checked: root.newChatGroup === section.groupKey
            onClicked: root.toggleNewChat(section.groupKey)

            PlasmaCore.ToolTipArea {
                textFormat: Text.PlainText
                anchors.fill: parent
                mainText: i18n("New chat on %1", section.group.title)
                subText: (section.remoteHost
                          ? i18n("Lists this account's folders on %1: start a new Claude chat in one, in a terminal (over ssh) or in VS Code.", section.remoteHost)
                          : i18n("Lists this account's recent folders: start a new Claude chat in one, in a terminal or in VS Code."))
                         + " " + i18n("Write a task first and the chat starts with it, also in the background.")
            }
        }
        Item {
            Layout.fillWidth: true
        }
        PlasmaComponents3.Label {
            textFormat: Text.PlainText
            visible: section.multiProfile
            text: section.group.profiles.join(" + ")
            opacity: 0.6
            font: Kirigami.Theme.smallFont
        }
    }

    // New chat (the + above): what Claude should do (optional) and the
    // account's folders (NewChatBox.qml)
    NewChatBox {
        visible: root.newChatGroup === section.groupKey
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        group: section.group
        remoteHost: section.remoteHost
    }

    // This account's chats as pets (PetStrip.qml), the ones that need you or
    // work first. It slides open when the account has a chat in the list.
    PetStrip {
        id: stage
        readonly property bool wanted: Plasmoid.configuration.showPet && Plasmoid.configuration.chatPets > 0
                                       && (stage.chats.length > 0 || stage.petCount > 0)
        property real shownHeight: wanted ? implicitHeight : 0
        Behavior on shownHeight {
            NumberAnimation { duration: 260; easing.type: Easing.InOutQuad }
        }
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        Layout.preferredHeight: shownHeight
        visible: shownHeight > 0
        stageKey: section.groupKey
        chats: {
            const rank = { waiting: 0, working: 1, idle: 2, done: 3 }
            const out = [], seen = {}
            for (const s of section.group.sessions) {
                const key = root.petKeyOf(s, section.remoteHost)
                if (key in seen)
                    continue
                seen[key] = true
                out.push({ key: key, session: s, host: section.remoteHost, order: out.length })
            }
            return out.sort((a, b) => (rank[a.session.state] - rank[b.session.state]) || (a.order - b.order))
        }
    }

    // Not logged in to an account (a new one, or logged out): Claude's own
    // login, in a terminal (over ssh for a host's)
    RowLayout {
        visible: !!section.group.loggedOut
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: "im-user-offline"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
        }
        PlasmaComponents3.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: i18n("Not logged in")
            opacity: 0.8
        }
        PlasmaComponents3.Button {
            text: i18n("Log in…")
            icon.name: "go-next"
            enabled: !section.remoteHost || !!section.group.loginCommand

            PlasmaCore.ToolTipArea {
                textFormat: Text.PlainText
                anchors.fill: parent
                mainText: i18n("Log in to %1", section.group.title)
                subText: section.remoteHost
                         ? i18n("Opens a terminal with Claude's own login on %1 (over ssh): open the address it shows in your browser, sign in, and paste the code you get back.", section.remoteHost)
                         : i18n("Opens a terminal with Claude's own login (claude auth login): sign in in your browser with the account for this folder. The widget never sees the login.")
            }
            onClicked: root.logIn(section.group, section.remoteHost)
        }
    }

    // Plan limits (from the status line); not where they show elsewhere (root.withUsage)
    ColumnLayout {
        visible: !section.group.limitsHidden && !section.group.loggedOut
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing / 2

        Repeater {
            // a count, not the array: a new array every poll would make the
            // bars anew (and close the forecast's tooltip under the mouse)
            model: section.group.limits ? section.group.limits.windows.length : 0
            delegate: UsageBar {
                required property int index
                readonly property var window: (section.group.limits ? section.group.limits.windows[index] : null)
                                              || ({ label: "", pct: 0, forecast: null, resetsAt: 0 })
                Layout.fillWidth: true
                label: window.label
                pct: window.pct
                detail: root.resetText(window)
                forecast: window.forecast || null
                resetsAt: window.resetsAt || 0
            }
        }

        PlasmaComponents3.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: !section.group.limits ? i18n("No plan usage yet: shows after this account's next reply")
                  : section.group.limitsFrom
                    ? (root.now - section.group.limits.updatedAt < 60000 ? i18n("Plan usage updated just now, on %1", section.group.limitsFrom)
                       : i18n("Plan usage as of %1 ago, on %2", root.duration(root.now - section.group.limits.updatedAt), section.group.limitsFrom))
                  : root.now - section.group.limits.updatedAt < 60000 ? i18n("Plan usage updated just now")
                  : i18n("Plan usage as of %1 ago", root.duration(root.now - section.group.limits.updatedAt))

            PlasmaCore.ToolTipArea {
                textFormat: Text.PlainText
                anchors.fill: parent
                active: !section.group.limits
                mainText: i18n("No plan usage yet")
                subText: i18n("Plan limits come from the Claude Code status line (statusline-snippet.sh). They update whenever a session of this account gets a reply.")
            }
        }
    }

    // Token totals (from local transcripts); click for the last days
    RowLayout {
        visible: section.hasTokens
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            id: tokenLabel
            textFormat: Text.PlainText
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: section.hasTokens
                  ? i18n("Tokens today %1 (%2 out) · 7 days %3 (%4 out)",
                         root.formatTokens(section.tokens.today.total), root.formatTokens(section.tokens.today.output),
                         root.formatTokens(section.tokens.week.total), root.formatTokens(section.tokens.week.output))
                  : ""

            PlasmaCore.ToolTipArea {
                textFormat: Text.PlainText
                anchors.fill: parent
                active: section.hasTokens
                mainText: i18n("Tokens (this machine's transcripts only)")
                subText: {
                    if (!section.hasTokens)
                        return ""
                    const t = section.tokens
                    const fmt = b => i18n("input %1 · output %2 · cache read %3 · cache write %4 · %5 replies",
                                          root.formatTokens(b.input), root.formatTokens(b.output),
                                          root.formatTokens(b.cacheRead), root.formatTokens(b.cacheWrite), b.messages)
                    const models = t.models.map(m => m.model.replace(/^claude-/, "") + ": " + root.formatTokens(m.total))
                    return i18n("Today: %1", fmt(t.today)) + "\n" + i18n("Last 7 days: %1", fmt(t.week))
                           + (models.length ? "\n" + i18n("By model (7 days): %1", models.join(", ")) : "")
                           + (t.week.shared > 0
                              ? "\n" + i18n("Includes %1 today (%2 in 7 days) from chats shared with another profile. A transcript doesn't say which account paid, so shared chats count on both.",
                                             root.formatTokens(t.today.shared), root.formatTokens(t.week.shared))
                              : "")
                           + (section.hasStats ? "\n\n" + (section.statsOpen ? i18n("Click to fold the last days up again.")
                                                                             : i18n("Click for the last days: tokens per day, your busiest folders and models.")) : "")
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: section.hasStats
                    cursorShape: section.hasStats ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.toggleStats(section.groupKey)
                }
            }
        }
        Kirigami.Icon {
            visible: section.hasStats
            source: section.statsOpen ? "arrow-up" : "arrow-down"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            opacity: 0.5

            TapHandler {
                onTapped: root.toggleStats(section.groupKey)
            }
        }
    }

    // The last days, unfolded from the token line
    StatsPanel {
        visible: section.statsOpen
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        stats: section.hasStats ? section.group.stats : null
    }

    // Sessions
    Repeater {
        model: section.group.sessions.length
        delegate: SessionRow {
            required property int index
            Layout.fillWidth: true
            session: section.group.sessions[index] || root.emptySession
            showProfile: section.multiProfile
            remoteHost: section.remoteHost
            account: section.group.title
        }
    }

    PlasmaComponents3.Label {
        textFormat: Text.PlainText
        visible: section.group.sessions.length === 0
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        text: i18n("No running chats")
        opacity: 0.6
    }

    // Tasks waiting for this account's usage limit to reset, or for the time you picked (main.qml: the queue)
    Repeater {
        model: section.queued.length
        delegate: ColumnLayout {
            id: queuedLine

            required property int index
            readonly property var task: section.queued[index]
                                        || ({ id: "", prompt: "", planTitle: "", folder: "", folderShort: "", startAt: 0, error: "", due: false,
                                              chat: null, name: "" })
            readonly property string what: root.queuedWhat(task)
            readonly property string folder: (task.host ? task.host + ":" : "") + (task.folder || "~")

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: queuedLine.task.error ? "dialog-warning" : "chronometer"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                }
                PlasmaComponents3.Label {
                    id: queuedName
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: queuedLine.what.split("\n")[0]
                    elide: Text.ElideRight

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: queuedLine.task.scheduled ? i18n("Starts later") : queuedLine.task.chat ? i18n("Goes on after the usage limit")
                                                            : i18n("Waits for the usage limit")
                        subText: queuedLine.what + "\n\n"
                                 + (queuedLine.task.chat
                                    ? i18n("The chat goes on in the background in %1, at %2, telling Claude that the limit has reset. A session that still has it open (in a terminal, or in the background) ends first; if it went on before then, nothing happens.",
                                           queuedLine.folder, root.startText(queuedLine.task.startAt))
                                    : i18n("Starts in the background in %1, at %2.", queuedLine.folder, root.startText(queuedLine.task.startAt)))
                    }
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    text: queuedLine.task.error ? i18n("didn't start")
                          : queuedLine.task.due || queuedLine.task.startAt <= root.now ? i18n("starting…")
                          : queuedLine.task.startAt - root.now > 12 * 3600000
                          ? i18nc("queued task: folder, when it starts", "%1 · starts %2", queuedLine.task.folderShort || "~",
                                  root.startText(queuedLine.task.startAt))
                          : i18nc("queued task: folder, when it starts", "%1 · starts in %2", queuedLine.task.folderShort || "~",
                                  root.duration(queuedLine.task.startAt - root.now))
                    color: queuedLine.task.error ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    opacity: queuedLine.task.error ? 1 : 0.6
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideLeft
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "media-playback-start"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Start it now")
                    enabled: !root.isStarting(queuedLine.task.id)
                    Layout.preferredHeight: queuedName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.startQueued(queuedLine.task)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Start it now")
                        subText: queuedLine.task.scheduled ? i18n("In the background, without waiting for its time.")
                                 : i18n("In the background, without waiting for the limit to reset. While the limit lasts, Claude stops again at once.")
                    }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "edit-delete-remove"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Cancel it")
                    Layout.preferredHeight: queuedName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.unqueue(queuedLine.task)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Cancel it")
                        subText: i18n("It doesn't start.")
                    }
                }
            }
            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                visible: queuedLine.task.error !== ""
                text: queuedLine.task.error
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
            }
        }
    }

    // Chats shared with this account that are in use on another one (they're
    // listed there, once): a line pointing to them
    Repeater {
        model: (section.group.sharedHere || []).length
        delegate: RowLayout {
            id: sharedLine

            required property int index
            readonly property var chat: section.group.sharedHere[index]
                                        || ({ sessionId: "", profileDir: "", name: "", profile: "", state: "idle",
                                              reason: "", since: null, stoppedHere: false, copy: false, openCommand: "" })

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                text: "⇄"
                color: root.stateColor(sharedLine.chat.state)
            }
            PlasmaComponents3.Label {
                id: sharedName
                textFormat: Text.PlainText
                text: sharedLine.chat.name
                opacity: 0.8
                font.underline: sharedMouse.containsMouse
                elide: Text.ElideRight
                Layout.fillWidth: true

                PlasmaCore.ToolTipArea {
                    textFormat: Text.PlainText
                    width: sharedName.contentWidth
                    height: parent.height
                    mainText: sharedLine.chat.copy ? i18n("Shared chat, continued on %1 as a copy", sharedLine.chat.profile)
                              : sharedLine.chat.state === "done" ? i18n("Shared chat, last used on %1", sharedLine.chat.profile)
                              : i18n("Shared chat, open on %1", sharedLine.chat.profile)
                    subText: (sharedLine.chat.copy
                              ? i18n("This chat is shared with this account too, but it continued on %1 in a copy Claude forked from it. New messages are only in that copy. Click to go to it.", sharedLine.chat.profile)
                              : i18n("This chat is shared with this account too. It's listed once, under the account it's used on. Click to go to it."))
                             + (sharedLine.chat.stoppedHere ? "\n" + i18n("Its background session on this account was stopped.") : "")

                    MouseArea {
                        id: sharedMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // as a click on the chat's own name (its row, under the account it's used on)
                        onClicked: {
                            const row = root.listedRow(sharedLine.chat.sessionId, sharedLine.chat.profileDir, section.remoteHost)
                            if (row)
                                root.clickChat(row, section.remoteHost)
                            else if (section.remoteHost)
                                root.remoteOpen(section.remoteHost, sharedLine.chat.openCommand)
                            else
                                root.jumpTo(sharedLine.chat.sessionId, sharedLine.chat.profileDir)
                        }
                    }
                }
            }
            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                text: sharedLine.chat.copy
                      ? i18nc("shared chat continued in a copy: where, its state", "copy on %1 · %2", sharedLine.chat.profile, root.stateText(sharedLine.chat))
                      : i18nc("shared chat: where it is, its state", "on %1 · %2", sharedLine.chat.profile, root.stateText(sharedLine.chat))
                opacity: 0.6
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            }
        }
    }

    // Recent chats: this account's latest other chats, to pick one up again
    PlasmaComponents3.ToolButton {
        visible: section.recent.length > 0 || section.starred.length > 0
        Layout.leftMargin: Kirigami.Units.smallSpacing
        flat: true
        icon.name: section.recentOpen ? "arrow-down" : "arrow-right"
        text: i18n("Recent chats (%1)", section.recent.length)
        font: Kirigami.Theme.smallFont
        onClicked: root.toggleRecent(section.groupKey, section.recentOpen)

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            mainText: i18n("Recent chats")
            subText: i18n("This account's latest chats that aren't listed above, and the ones you starred. Click one to reopen it, in a terminal or in VS Code (the switch at the top of the list).")
        }
    }

    // Where they reopen: the same Terminal | VS Code choice as for new chats
    OpenInSwitch {
        id: recentOpenIn
        visible: section.recentOpen && (section.recent.length > 0 || section.starred.length > 0)
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.smallSpacing
        group: section.group
        remoteHost: section.remoteHost
        resuming: true
    }

    // the chats you starred: unfolded, they come first (a step further in)
    PlasmaComponents3.ToolButton {
        visible: section.recentOpen && section.starred.length > 0
        Layout.leftMargin: Kirigami.Units.gridUnit
        flat: true
        icon.name: section.starredOpen ? "arrow-down" : "arrow-right"
        text: i18nc("starred chats, how many", "★ Starred (%1)", section.starred.length)
        font: Kirigami.Theme.smallFont
        onClicked: root.toggleStarred(section.groupKey + "|chats", section.starredOpen)

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            mainText: i18n("Starred chats")
            subText: i18n("The chats of this account you starred (☆ next to a chat), newest first, however old they are; not the ones listed above. Click a chat's ★ to unstar it.")
        }
    }

    Repeater {
        model: section.recentOpen ? section.starredShown.length + section.recent.length : 0
        delegate: ColumnLayout {
            id: recentLine

            required property int index
            readonly property bool inStarred: index < section.starredShown.length
            readonly property var chat: (inStarred ? section.starredShown[index] : section.recent[index - section.starredShown.length])
                                        || ({ key: "", sessionId: "", name: "", cwd: "", cwdShort: "", lastActive: 0, profileDir: "",
                                              profile: "", shared: false, openCommand: "", starred: false })
            readonly property string rowKey: (section.remoteHost ? section.remoteHost + "|" : "") + chat.key
            readonly property bool canOpen: recentOpenIn.inVscode
                                            || (recentOpenIn.terminalHere && (!section.remoteHost || !!chat.openCommand))

            function open() {
                if (section.remoteHost && recentOpenIn.inVscode)
                    root.remoteResumeVscode(section.remoteHost, chat.sessionId, chat.cwd)
                else if (section.remoteHost)
                    root.remoteOpen(section.remoteHost, chat.openCommand)
                else if (recentOpenIn.inVscode)
                    root.resumeInVscode(chat.sessionId, chat.profileDir)
                else
                    root.jumpTo(chat.sessionId, chat.profileDir)
            }

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit * (inStarred ? 2 : 1)
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: 0

            HoverHandler {
                id: recentHover
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    id: recentName
                    textFormat: Text.PlainText
                    text: recentLine.chat.name
                    font.underline: recentMouse.containsMouse
                    opacity: recentLine.canOpen ? 1 : 0.6
                    elide: Text.ElideRight
                    Layout.fillWidth: true

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        width: recentName.contentWidth
                        height: parent.height
                        mainText: recentLine.chat.name
                        subText: (recentLine.canOpen ? (recentOpenIn.inVscode ? root.vscodeHint(section.group, section.remoteHost, true)
                                                                              : root.terminalHint(section.remoteHost, true))
                                                     : root.terminalHint(section.remoteHost, true) + "\n" + root.vscodeHint(section.group, section.remoteHost, true))
                                 + (recentLine.chat.cwd ? "\n" + i18n("Folder: %1", (section.remoteHost ? section.remoteHost + ":" : "") + recentLine.chat.cwd) : "")
                                 + (recentLine.chat.shared ? "\n" + i18n("Shared between accounts; last used on %1.", recentLine.chat.profile) : "")
                                 + (recentLine.chat.stopped ? "\n\n" + root.stopText(recentLine.chat.stopped) : "")
                                 + (recentLine.chat.recap ? "\n\n" + i18n("Recap: %1", recentLine.chat.recap.text) : "")

                        MouseArea {
                            id: recentMouse
                            anchors.fill: parent
                            enabled: recentLine.canOpen || Plasmoid.configuration.clickOpensPane
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Plasmoid.configuration.clickOpensPane
                                       ? root.openPane(recentLine.chat, section.remoteHost, "chat") : recentLine.open()
                        }
                    }
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    visible: recentLine.chat.shared
                    text: "⇄"
                    opacity: 0.6
                }
                // a usage limit stopped it (talpy_den.py: limit_stop): until it resets;
                // click: it goes on by itself then (queued; again: cancelled)
                Tag {
                    readonly property real goOnAt: root.goOnAt(recentLine.chat)
                    readonly property var goingOn: root.queuedChat(recentLine.chat.sessionId, section.remoteHost)
                    visible: goingOn !== null
                             || (!!recentLine.chat.stopped && recentLine.chat.stopped.kind === "limit" && !recentLine.chat.stopped.over)
                    text: goingOn ? i18nc("a chat that goes on by itself at this time", "⏱ %1", root.startText(goingOn.startAt))
                                  : i18n("limit")
                    warning: goingOn === null
                    active: goingOn !== null
                    clickable: goingOn !== null || goOnAt > 0
                    tooltipTitle: goingOn ? i18n("Goes on by itself at %1", root.startText(goingOn.startAt))
                                          : i18n("A usage limit stopped it")
                    tooltip: (goingOn ? i18n("In the background, in the permission mode it had, telling Claude that the limit has reset (if it didn't go on before then).")
                              : (recentLine.chat.stopped ? recentLine.chat.stopped.text : "")
                                + (goOnAt > 0 ? "\n\n" + i18n("Click to have it go on by itself in the background at %1, a minute after the limit resets, once.", root.startText(goOnAt))
                                                + (section.remoteHost ? "" : " " + i18n("↻ beside it: after later limits too, until it's done.")) : ""))
                             + (goingOn ? "\n\n" + i18n("Click to cancel it.") : "")
                    onClicked: {
                        if (goingOn)
                            root.unqueue(goingOn)
                        else
                            root.queueContinue(recentLine.chat, section.remoteHost, section.group.title, false)
                    }
                }
                // it keeps going (click: not any more), or a limit stopped it and it can (click: it does)
                Tag {
                    readonly property var kept: section.remoteHost ? null : root.keptChat(recentLine.chat.sessionId)
                    readonly property bool canKeep: kept === null && !section.remoteHost && root.goOnAt(recentLine.chat) > 0
                                                    && root.queuedChat(recentLine.chat.sessionId, section.remoteHost) === null
                    visible: kept !== null || canKeep
                    text: i18nc("a chat that goes on by itself after usage limits", "↻")
                    active: kept !== null && !kept.error
                    warning: kept !== null && (!!kept.error || !!kept.note)
                    clickable: true
                    tooltipTitle: kept ? i18n("Keeps going until it's done") : i18n("Keep going until it's done")
                    tooltip: kept ? root.keptText(kept)
                                  : i18n("Click to have it go on by itself in the background at %1, a minute after the limit resets, in the permission mode it had, and again after each later limit that stops it, until a turn of it ends by itself.",
                                         root.startText(root.goOnAt(recentLine.chat)))
                    onClicked: {
                        if (kept)
                            root.keepGoing(recentLine.chat, false)
                        else
                            root.queueContinue(recentLine.chat, section.remoteHost, section.group.title, true)
                    }
                }
                // it changed files: to review until you mark it reviewed (ChatPane.qml)
                Tag {
                    visible: root.reviewPending(recentLine.chat, section.remoteHost)
                    text: i18nc("a finished chat's changes, not reviewed yet", "to review")
                    active: true
                    clickable: true
                    onClicked: root.openPane(recentLine.chat, section.remoteHost, "review")
                    tooltipTitle: i18n("Not reviewed yet")
                    tooltip: i18n("It changed files. Click to see what it changed, against how the files were before the chat: undo it, commit only its files, or mark it reviewed.")
                }
                TestsBadge {
                    review: root.reviewPending(recentLine.chat, section.remoteHost) ? recentLine.chat.review : null
                }
                PlasmaComponents3.ToolButton {
                    // with clicks opening the pane: reopen the chat itself
                    visible: Plasmoid.configuration.clickOpensPane && recentLine.canOpen
                    opacity: recentHover.hovered ? 1 : 0
                    icon.name: "window"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Reopen this chat")
                    Layout.preferredHeight: recentName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: recentLine.open()

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Reopen this chat")
                        subText: recentOpenIn.inVscode ? root.vscodeHint(section.group, section.remoteHost, true)
                                                       : root.terminalHint(section.remoteHost, true)
                    }
                }
                PlasmaComponents3.Label {
                    id: recentFolder
                    textFormat: Text.PlainText
                    text: i18nc("recent chat: folder · how long ago", "%1 · %2", recentLine.chat.cwdShort || "~",
                                root.ago(root.now - recentLine.chat.lastActive))
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideLeft
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 12

                    PlasmaCore.ToolTipArea {   // (the whole folder: the line may be cut short)
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        active: !!recentLine.chat.cwd
                        mainText: i18n("Folder")
                        subText: (section.remoteHost ? section.remoteHost + ":" : "") + recentLine.chat.cwd
                    }
                }
                PlasmaComponents3.ToolButton {
                    // star it (it stays listed under Starred) or unstar it
                    opacity: recentLine.chat.starred || recentHover.hovered ? 1 : 0
                    icon.name: recentLine.chat.starred ? "starred-symbolic" : "non-starred-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: recentLine.chat.starred ? i18n("Unstar") : i18n("Star")
                    Layout.preferredHeight: recentName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.setStar("chats", recentLine.chat.sessionId, section.remoteHost, !recentLine.chat.starred)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: recentLine.chat.starred ? i18n("Starred") : i18n("Star this chat")
                        subText: root.starHint("chats", !!recentLine.chat.starred)
                    }
                }
                PlasmaComponents3.ToolButton {
                    id: recentShare
                    visible: root.shareAccountsOf(section.remoteHost).length >= 2
                    opacity: recentHover.hovered ? 1 : 0
                    icon.name: "document-share"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Share or continue on another account…")
                    Layout.preferredHeight: recentName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.openShareMenu(recentShare, {
                        chatId: recentLine.chat.sessionId, name: recentLine.chat.name,
                        profileDir: recentLine.chat.profileDir, shared: recentLine.chat.shared, host: section.remoteHost
                    }, recentLine.rowKey)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Continue on another account")
                        subText: root.shareHint(section.remoteHost)
                    }
                }
            }

            KeepOnlyMessage {
                Layout.fillWidth: true
                visible: root.shareConfirm.key === recentLine.rowKey
            }
        }
    }

    // Plans: what this account's chats in plan mode wrote (<config>/plans):
    // open one, carry it out in a new chat, continue the chat that made it,
    // or share it with your other accounts
    PlasmaComponents3.ToolButton {
        visible: section.plans.length > 0 || section.starredPlans.length > 0
        Layout.leftMargin: Kirigami.Units.smallSpacing
        flat: true
        icon.name: section.plansOpen ? "arrow-down" : "arrow-right"
        text: i18n("Plans (%1)", section.plans.length)
        font: Kirigami.Theme.smallFont
        onClicked: root.togglePlans(section.groupKey, section.plansOpen)

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            mainText: i18n("Plans")
            subText: i18n("The plans this account's chats wrote in plan mode, newest first, and the ones you starred. Click one to open it; carry it out in a new chat, go back to the chat that made it, or share it with your other accounts.")
        }
    }

    // the plans you starred: unfolded, they come first (a step further in)
    PlasmaComponents3.ToolButton {
        visible: section.plansOpen && section.starredPlans.length > 0
        Layout.leftMargin: Kirigami.Units.gridUnit
        flat: true
        icon.name: section.starredPlansOpen ? "arrow-down" : "arrow-right"
        text: i18nc("starred plans, how many", "★ Starred (%1)", section.starredPlans.length)
        font: Kirigami.Theme.smallFont
        onClicked: root.toggleStarred(section.groupKey + "|plans", section.starredPlansOpen)

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            mainText: i18n("Starred plans")
            subText: i18n("The plans of this account you starred (☆ next to a plan), newest first, however old they are. Click a plan's ★ to unstar it.")
        }
    }

    Repeater {
        model: section.plansOpen ? section.starredPlansShown.length + section.plans.length : 0
        delegate: ColumnLayout {
            id: planLine

            required property int index
            readonly property bool inStarred: index < section.starredPlansShown.length
            readonly property var plan: (inStarred ? section.starredPlansShown[index] : section.plans[index - section.starredPlansShown.length])
                                        || root.emptyPlan
            readonly property string composerKey: (section.remoteHost ? section.remoteHost + "|" : "") + plan.key

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit * (inStarred ? 2 : 1)
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing / 2

            HoverHandler {
                id: planHover
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "view-task"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    opacity: 0.7
                }
                PlasmaComponents3.Label {
                    id: planName
                    textFormat: Text.PlainText
                    text: planLine.plan.title
                    font.underline: planMouse.containsMouse
                    elide: Text.ElideRight
                    Layout.fillWidth: true

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        width: planName.contentWidth
                        height: parent.height
                        mainText: planLine.plan.title
                        subText: (section.remoteHost ? i18n("Click to read it: a copy, fetched from %1.", section.remoteHost)
                                                     : i18n("Click to read it, rendered."))
                                 + (!section.remoteHost || root.vscodeInstalled ? " " + i18n("To change it, the edit button next to it opens its file.") : "")
                                 + (planLine.plan.cwd ? "\n" + i18n("Folder: %1", (section.remoteHost ? section.remoteHost + ":" : "") + planLine.plan.cwd) : "")
                                 + (planLine.plan.shared ? "\n" + i18n("Shared with your other accounts.") : "")
                                 + (planLine.plan.chatId ? "" : "\n" + i18n("The chat that made it isn't here any more."))

                        MouseArea {
                            id: planMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPlan(planLine.plan.slug, planLine.plan.profileDir, section.remoteHost)
                        }
                    }
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    visible: planLine.plan.shared
                    text: "⇄"
                    opacity: 0.6
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    text: planLine.plan.cwdShort
                          ? i18nc("plan: folder · how long ago", "%1 · %2", planLine.plan.cwdShort, root.ago(root.now - planLine.plan.updatedAt))
                          : root.ago(root.now - planLine.plan.updatedAt)
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideLeft
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 10

                    PlasmaCore.ToolTipArea {   // (the whole folder: the line may be cut short)
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        active: !!planLine.plan.cwd
                        mainText: i18n("Folder")
                        subText: (section.remoteHost ? section.remoteHost + ":" : "") + planLine.plan.cwd
                    }
                }
                PlasmaComponents3.ToolButton {
                    // star it (it stays listed under Starred) or unstar it
                    opacity: planLine.plan.starred || planHover.hovered ? 1 : 0
                    icon.name: planLine.plan.starred ? "starred-symbolic" : "non-starred-symbolic"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: planLine.plan.starred ? i18n("Unstar") : i18n("Star")
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.setStar("plans", planLine.plan.slug, section.remoteHost, !planLine.plan.starred)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: planLine.plan.starred ? i18n("Starred") : i18n("Star this plan")
                        subText: root.starHint("plans", !!planLine.plan.starred)
                    }
                }
                // the plan's Markdown file itself, to change it (an SSH host's: in VS Code, over Remote-SSH)
                PlasmaComponents3.ToolButton {
                    visible: !section.remoteHost || root.vscodeInstalled
                    icon.name: "document-edit"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Edit the plan")
                    opacity: planHover.hovered ? 1 : 0
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.editPlan(planLine.plan, section.remoteHost)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Edit the plan")
                        subText: section.remoteHost
                                 ? i18n("Opens its Markdown file on %1 in VS Code (Remote - SSH). What you change there is the plan.", section.remoteHost)
                                 : i18n("Opens its Markdown file in your text editor (VS Code, if the settings open plans there). What you change there is the plan.")
                    }
                }
                // what you changed in it, to the chat that made it (main.qml: sendPlanFeedback)
                // (a plan whose chat is gone keeps this button's place, greyed out, so every line's buttons and time stay in the same columns)
                PlasmaComponents3.ToolButton {
                    visible: !section.remoteHost
                    enabled: !!planLine.plan.chatId
                    icon.name: "mail-send"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Send your changes to Claude")
                    opacity: planHover.hovered || (enabled && planLine.plan.edited) ? 1 : 0
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.sendPlanFeedback(planLine.plan.slug, planLine.plan.profileDir, planLine.plan.chatId)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Send your changes to Claude")
                        subText: (planLine.plan.edited ? i18n("You changed this plan since Claude wrote it.") + " " : "")
                                 + i18n("Sends what you changed in it (and notes you wrote into it) to the chat that made it: Claude revises the plan, in plan mode. In tmux it's typed in for you; else it goes to the clipboard and the chat comes up, to paste it there. A chat that isn't open reopens in plan mode with it.")
                    }
                }
                PlasmaComponents3.ToolButton {
                    id: planGo
                    icon.name: "media-playback-start"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Carry it out…")
                    opacity: planHover.hovered || root.planComposer === planLine.composerKey ? 1 : 0
                    checked: root.planComposer === planLine.composerKey
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.togglePlanComposer(planLine.composerKey)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Carry it out in a new chat")
                        subText: i18n("A new chat starts with the plan as its first message: in a terminal, in VS Code or in the background, in the plan's folder or another one.")
                    }
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "go-previous"
                    enabled: !!planLine.plan.chatId
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Continue the chat that made it")
                    opacity: planHover.hovered ? 1 : 0
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.continuePlanChat(planLine.plan, section.group, section.remoteHost)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Continue the chat that made it")
                        subText: i18n("To change the plan with Claude: its chat comes up, or reopens (in a terminal or VS Code, as the switch of Recent chats says).")
                    }
                }
                PlasmaComponents3.ToolButton {
                    id: planShare
                    visible: root.shareAccountsOf(section.remoteHost).length >= 2
                    icon.name: "document-share"
                    display: PlasmaComponents3.AbstractButton.IconOnly
                    text: i18n("Share it with another account…")
                    opacity: planHover.hovered ? 1 : 0
                    Layout.preferredHeight: planName.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                    onClicked: root.openPlanMenu(planShare, planLine.plan, section.remoteHost)

                    PlasmaCore.ToolTipArea {
                        textFormat: Text.PlainText
                        anchors.fill: parent
                        mainText: i18n("Share this plan")
                        subText: i18n("A shared plan is one file on each account: a change shows on all of them. Sharing a chat shares its plan too.")
                    }
                }
            }

            NewChatBox {
                visible: root.planComposer === planLine.composerKey
                Layout.fillWidth: true
                group: section.group
                remoteHost: section.remoteHost
                plan: planLine.plan
            }
        }
    }

    // Memories: what Claude keeps about you and your projects on this account
    // (<config>/projects/<folder>/memory): read one, or change it
    PlasmaComponents3.ToolButton {
        visible: section.memories.length > 0
        Layout.leftMargin: Kirigami.Units.smallSpacing
        flat: true
        icon.name: section.memoriesOpen ? "arrow-down" : "arrow-right"
        text: i18n("Memories (%1)", section.memories.length)
        font: Kirigami.Theme.smallFont
        onClicked: root.toggleMemories(section.groupKey, section.memoriesOpen)

        PlasmaCore.ToolTipArea {
            textFormat: Text.PlainText
            anchors.fill: parent
            mainText: i18n("Memories")
            subText: i18n("What Claude keeps about you and your projects on this account, newest first: one note each, for the folder it was learned in. Claude reads them in new chats there. Click one to read it; the edit button changes it.")
        }
    }

    Repeater {
        model: section.memoriesOpen ? section.memories.length : 0
        delegate: RowLayout {
            id: memoryLine

            required property int index
            readonly property var memory: section.memories[index]
                                          || ({ key: "", name: "", description: "", type: "", path: "", folder: "", folderShort: "", updatedAt: 0 })
            // an SSH host's opens in VS Code (Remote-SSH), to change it
            readonly property bool canOpen: !section.remoteHost || root.vscodeInstalled

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            Layout.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            HoverHandler {
                id: memoryHover
            }

            Kirigami.Icon {
                source: root.memoryIcon(memoryLine.memory.type)
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                opacity: 0.7
            }
            PlasmaComponents3.Label {
                id: memoryName
                textFormat: Text.PlainText
                text: memoryLine.memory.description || memoryLine.memory.name
                font.underline: memoryMouse.containsMouse
                opacity: memoryLine.canOpen ? 1 : 0.7
                elide: Text.ElideRight
                Layout.fillWidth: true

                PlasmaCore.ToolTipArea {
                    textFormat: Text.PlainText
                    width: memoryName.contentWidth
                    height: parent.height
                    mainText: memoryLine.memory.name
                    subText: (memoryLine.memory.description ? memoryLine.memory.description + "\n\n" : "")
                             + (memoryLine.memory.type ? i18n("Kind: %1", memoryLine.memory.type) + "\n" : "")
                             + (memoryLine.memory.folder ? i18n("Folder: %1", (section.remoteHost ? section.remoteHost + ":" : "") + memoryLine.memory.folder) + "\n" : "")
                             + (section.remoteHost ? (memoryLine.canOpen ? i18n("Click to open it on %1 in VS Code (Remote - SSH).", section.remoteHost) : "")
                                                   : i18n("Click to read it, rendered."))

                    MouseArea {
                        id: memoryMouse
                        anchors.fill: parent
                        enabled: memoryLine.canOpen
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openMemory(memoryLine.memory, section.remoteHost, false)
                    }
                }
            }
            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                text: memoryLine.memory.folderShort || memoryLine.memory.type === "account"
                      ? i18nc("memory: folder · how long ago", "%1 · %2", memoryLine.memory.folderShort || i18n("every folder"),
                              root.ago(root.now - memoryLine.memory.updatedAt))
                      : root.ago(root.now - memoryLine.memory.updatedAt)
                opacity: 0.6
                font: Kirigami.Theme.smallFont
                elide: Text.ElideLeft
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
            }
            PlasmaComponents3.ToolButton {
                visible: !section.remoteHost
                icon.name: "document-edit"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: i18n("Edit this memory")
                opacity: memoryHover.hovered ? 1 : 0
                Layout.preferredHeight: memoryName.implicitHeight
                Layout.preferredWidth: Layout.preferredHeight
                onClicked: root.openMemory(memoryLine.memory, section.remoteHost, true)

                PlasmaCore.ToolTipArea {
                    textFormat: Text.PlainText
                    anchors.fill: parent
                    mainText: i18n("Edit this memory")
                    subText: i18n("Opens its file in your text editor (VS Code, if the settings open plans there). What you change there is what Claude remembers; Claude reads it in new chats in that folder.")
                }
            }
        }
    }

    Kirigami.Separator {
        visible: !section.last
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
}

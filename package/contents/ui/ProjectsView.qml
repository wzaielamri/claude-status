import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// The Projects tab: each project (a chat's git repository, else its folder),
// newest first, with what goes on there now (its open chats), Claude's last
// recap of it, how long Claude worked on it and what that cost (the last 7
// days and everything kept), its chats, plans and memories, and a button for
// a new chat there. The numbers come from week.py --projects (main.qml:
// loadProjects), what goes on now from the status.
PlasmaComponents3.ScrollView {
    id: view

    readonly property var projects: root.projectsData ? root.projectsData.projects || [] : []
    readonly property real gu: Kirigami.Units.gridUnit
    property var open: ({})        // project path -> unfolded (all folded at first)
    contentWidth: availableWidth
    PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

    function under(folder, path) {
        return !!folder && (folder === path || folder.startsWith(path + "/"))
    }
    // What the status has about a project now: its open chats, plans, memories, the last recap
    function now(project) {
        const sessions = [], plans = [], memories = [], recents = []
        for (const g of root.groups) {
            for (const s of g.sessions)
                if (under(s.cwd, project.path))
                    sessions.push({ key: root.petKeyOf(s, ""), session: s, host: "", account: g.title })
            for (const p of g.plans || [])
                if (under(p.cwd, project.path))
                    plans.push(p)
            for (const m of g.memories || [])
                if (m.folder && under(m.folder, project.path))
                    memories.push(m)
            for (const r of g.recent || [])
                if (under(r.cwd, project.path) && r.recap && r.recap.text)
                    recents.push(r)
        }
        recents.sort((a, b) => (b.lastActive || 0) - (a.lastActive || 0))
        plans.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0))
        memories.sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0))
        return { sessions: sessions, plans: plans, memories: memories, recap: recents.length ? recents[0].recap.text : "" }
    }
    function isOpen(project, index) {
        return project.path in open ? open[project.path] : false
    }
    // (as the Recap shows money: its currency, symbol and rounding)
    readonly property var currency: root.projectsData && root.projectsData.currency ? root.projectsData.currency : ({ code: "USD", rate: 1 })
    readonly property var symbols: ({ USD: "$", EUR: "€", GBP: "£", JPY: "¥", CNY: "¥", INR: "₹", KRW: "₩", ILS: "₪", TRY: "₺", PHP: "₱", THB: "฿" })
    function money(usd) {
        const amount = (usd || 0) * (currency.rate || 1)
        const symbol = symbols[currency.code]
        const put = text => symbol ? symbol + text : text + " " + currency.code
        if (!amount)
            return put("0")
        const whole = amount >= 100 || ["JPY", "KRW", "HUF", "ISK", "IDR"].indexOf(currency.code) >= 0
        if (amount < (whole ? 1 : 0.01))
            return "<" + put(whole ? "1" : Number(0.01).toLocaleString(Qt.locale(), "f", 2))
        return put(Number(amount).toLocaleString(Qt.locale(), "f", whole ? 0 : 2))
    }
    // (as the Recap shows worked time: 26h 5m, 45m)
    function hours(ms) {
        const m = Math.round(Math.max(0, ms) / 60000)
        return m < 60 ? i18nc("duration in minutes", "%1m", m)
                      : i18nc("duration in hours and minutes", "%1h %2m", Math.floor(m / 60), m % 60)
    }

    // A plan's or a memory's button, its title as it is (one with <tags> in it isn't drawn as markup)
    component Chip: PlasmaComponents3.ToolButton {
        id: chip
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: chip.icon.name
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            Text {
                Layout.fillWidth: true
                text: chip.text
                textFormat: Text.PlainText
                font: chip.font
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        width: view.availableWidth
        spacing: Kirigami.Units.largeSpacing

        PlasmaComponents3.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.projectsBusy && view.projects.length === 0
            text: i18n("Reading your chats by project…")
            opacity: 0.7
        }
        PlasmaComponents3.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.projectsError !== ""
            text: root.projectsError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
        }
        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            visible: !root.projectsBusy && root.projectsData !== null && view.projects.length === 0
            iconName: "folder-open"
            text: i18n("No projects yet")
            explanation: i18n("A project is a folder (or the git repository it's in) where you chatted with Claude.")
        }

        Repeater {
            model: view.projects.length
            delegate: ColumnLayout {
                id: card
                required property int index
                readonly property var project: view.projects[index] || ({ name: "", path: "", short: "", chats: [], chatCount: 0 })
                readonly property bool unfolded: view.isOpen(project, index)
                readonly property var here: unfolded ? view.now(project) : ({ sessions: [], plans: [], memories: [], recap: "" })
                // its hide button: on hover, while the keyboard is on its line
                // (Tab), or after a press and hold with a finger (TouchHold.qml)
                readonly property bool buttonsShown: cardHover.hovered || projectName.activeFocus || newHere.visualFocus
                                                     || hideHere.visualFocus || held
                property bool held: false
                property bool holding: false
                Connections {
                    target: root
                    enabled: card.held
                    function onDashboardShownChanged() {
                        card.held = false
                    }
                }
                function fold() {
                    view.open = Object.assign({}, view.open, { [project.path]: !unfolded })
                }
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: card.index > 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    HoverHandler {
                        id: cardHover
                    }
                    TouchHold {
                        buttons: card
                    }
                    Kirigami.Icon {
                        source: card.unfolded ? "go-down" : "go-next"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        // (on the name's line)
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Math.max(0, (projectName.implicitHeight - Layout.preferredHeight) / 2)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Kirigami.Heading {
                            id: projectName
                            level: 4
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: card.project.name
                            elide: Text.ElideRight
                            // (Tab: its hide button shows; Enter: folds it open or shut, as a click)
                            activeFocusOnTab: true
                            font.underline: activeFocus
                            Keys.onReturnPressed: card.fold()
                            Keys.onEnterPressed: card.fold()
                        }
                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: card.project.short + " · " + i18n("last at work %1 ago", root.duration(Math.max(60000, root.now - card.project.lastAt)))
                            font: Kirigami.Theme.smallFont
                            opacity: 0.65
                            elide: Text.ElideMiddle
                        }
                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: i18n("7 days: %1", view.hours(card.project.weekMs)) + " · " + i18n("all: %1 · %2", view.hours(card.project.workedMs), view.money(card.project.cost))
                            font: Kirigami.Theme.smallFont
                            opacity: 0.65
                            elide: Text.ElideRight
                        }
                    }
                    PlasmaComponents3.ToolButton {
                        id: newHere
                        Layout.alignment: Qt.AlignTop
                        icon.source: root.iconDir + "chat-new-symbolic.svg"   // (as an account's: at 16 px)
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: i18n("New chat here")
                        onClicked: root.newChatInProject(card.project)

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("New chat here")
                            subText: card.project.short
                        }
                    }
                    // on hover: hide it here (nothing is deleted; its chats, plans and memories stay in their lists)
                    PlasmaComponents3.ToolButton {
                        id: hideHere
                        Layout.alignment: Qt.AlignTop
                        opacity: card.buttonsShown ? 1 : 0
                        enabled: card.buttonsShown
                        icon.name: "window-close"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: i18n("Hide this project")
                        onClicked: root.hideItem("projects", card.project.path, "")

                        PlasmaCore.ToolTipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: i18n("Hide this project")
                            subText: root.hideHint("projects", "")
                        }
                    }
                    TapHandler {
                        onTapped: card.fold()
                    }
                }

                // What goes on there now
                Repeater {
                    model: card.here.sessions.length
                    delegate: FocusLine {
                        required property int index
                        Layout.fillWidth: true
                        item: card.here.sessions[index] || null
                    }
                }
                // Claude's last recap of it (its own, in the chat)
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    visible: card.unfolded && card.here.recap !== ""
                    text: "“" + card.here.recap + "”"
                    font.italic: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    opacity: 0.8
                }
                // Its chats, newest first (click: brings it up)
                Repeater {
                    model: card.unfolded ? Math.min(5, card.project.chats.length) : 0
                    delegate: WeekChatLine {
                        required property int index
                        readonly property var c: card.project.chats[index] || ({ id: "", name: "", profileDir: "", cwd: "", lastAt: 0, workedMs: 0, cost: 0 })
                        chat: ({ name: c.name, chatId: c.id, host: "", profileDir: c.profileDir, folder: "", cwd: c.cwd })
                        where: i18n("%1 ago", root.duration(Math.max(60000, root.now - c.lastAt)))
                        numbers: view.hours(c.workedMs) + " · " + view.money(c.cost)
                        indent: Kirigami.Units.iconSizes.small
                    }
                }
                PlasmaComponents3.Label {
                    textFormat: Text.PlainText
                    Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                    visible: card.unfolded && card.project.chatCount > 5
                    text: i18np("and %1 more chat", "and %1 more chats", card.project.chatCount - 5)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
                // Its plans and memories
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    visible: card.unfolded && (card.here.plans.length + card.here.memories.length) > 0
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: Math.min(4, card.here.plans.length)
                        delegate: Chip {
                            required property int index
                            readonly property var plan: card.here.plans[index]
                            icon.name: "view-task"
                            text: plan ? plan.title : ""
                            onClicked: if (plan) root.openPlan(plan.slug, plan.profileDir, "")
                        }
                    }
                    Repeater {
                        model: Math.min(4, card.here.memories.length)
                        delegate: Chip {
                            required property int index
                            readonly property var memory: card.here.memories[index]
                            icon.name: root.memoryIcon(memory ? memory.type : "")   // (as under its account)
                            text: memory ? memory.name : ""
                            onClicked: if (memory) root.openMemory(memory, "", false)
                        }
                    }
                    PlasmaComponents3.Label {
                        textFormat: Text.PlainText
                        visible: card.here.plans.length > 4 || card.here.memories.length > 4
                        height: implicitHeight * 2
                        verticalAlignment: Text.AlignVCenter
                        text: [card.here.plans.length > 4 ? i18np("%1 more plan", "%1 more plans", card.here.plans.length - 4) : "",
                               card.here.memories.length > 4 ? i18np("%1 more memory", "%1 more memories", card.here.memories.length - 4) : ""]
                              .filter(t => t).join(" · ") + " " + i18n("(under its account in Chats)")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }
            }
        }

        Item {
            implicitHeight: Kirigami.Units.smallSpacing
        }
    }
}

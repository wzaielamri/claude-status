import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Claude's multiple-choice questions (its AskUserQuestion tool; talpy_den.py:
// question_view): each question with its options, one to choose (or several,
// for a multiSelect one), and a field to answer in your own words instead
// (as "Type something." in Claude's dialog). PermissionAsk.qml sends them.
ColumnLayout {
    id: form

    property var questions: []
    property string requestKey: ""   // a new request starts over
    property bool compact: false     // (in a row: descriptions in tooltips)
    property real pt: Kirigami.Theme.defaultFont.pointSize   // (the pane's text size there)
    readonly property real smallPt: Kirigami.Theme.smallFont.pointSize * pt / Kirigami.Theme.defaultFont.pointSize
    // index -> {labels: {label: true}, text}; kept here, as the rows come again each poll
    property var chosen: ({})

    spacing: Kirigami.Units.largeSpacing
    onRequestKeyChanged: chosen = {}

    function stateOf(i) {
        return chosen[i] || { labels: {}, text: "" }
    }
    function isChosen(i, label) {
        return !!stateOf(i).labels[label]
    }
    // A click on an option: the one answer (instead of what you typed), or one more of several
    function choose(i, label) {
        const q = questions[i]
        const was = stateOf(i)
        const labels = q.multiSelect ? Object.assign({}, was.labels) : {}
        if (q.multiSelect && labels[label])
            delete labels[label]
        else
            labels[label] = true
        const next = Object.assign({}, chosen)
        next[i] = { labels: labels, text: q.multiSelect ? was.text : "" }
        chosen = next
    }
    // What you typed: the answer instead of an option (or one more of several)
    function setText(i, text) {
        const q = questions[i]
        const was = stateOf(i)
        const next = Object.assign({}, chosen)
        next[i] = { labels: q.multiSelect || text.trim() === "" ? was.labels : {}, text: text }
        chosen = next
    }
    // {question: [the labels chosen (in the options' order), then what you typed]}
    function answers() {
        const out = {}
        questions.forEach((q, i) => {
            const s = stateOf(i)
            const values = q.options.map(o => o.label).filter(l => s.labels[l])
            if (s.text.trim() !== "")
                values.push(s.text.trim())
            if (values.length)
                out[q.question] = values
        })
        return out
    }
    readonly property bool complete: questions.length > 0 && questions.every((q, i) => {
        const s = stateOf(i)
        return s.text.trim() !== "" || Object.keys(s.labels).length > 0
    })

    // "Other…" from a notification: the first question's own-words field, ready to type in
    function typeAnswer() {
        const first = questionList.itemAt(0)
        if (first)
            first.typeAnswer()
    }

    Repeater {
        id: questionList
        model: form.questions.length

        ColumnLayout {
            id: questionItem
            required property int index
            readonly property var question: form.questions[index] || { question: "", header: "", multiSelect: false, options: [] }
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            function typeAnswer() {
                ownWords.forceActiveFocus()
            }

            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                visible: questionItem.question.header !== "" && form.questions.length > 1
                text: questionItem.question.header
                font.pointSize: form.smallPt
                opacity: 0.7
            }
            PlasmaComponents3.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: questionItem.question.question + (questionItem.question.multiSelect ? " " + i18n("(choose any)") : "")
                wrapMode: Text.Wrap
                font.bold: true
                font.pointSize: form.pt
            }
            Repeater {
                model: questionItem.question.options.length

                RowLayout {
                    id: optionItem
                    required property int index
                    readonly property var option: questionItem.question.options[index] || { label: "", description: "" }
                    readonly property bool picked: form.isChosen(questionItem.index, option.label)
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.RadioButton {
                        visible: !questionItem.question.multiSelect
                        Layout.alignment: Qt.AlignTop
                        checked: optionItem.picked
                        autoExclusive: false
                        onToggled: {
                            form.choose(questionItem.index, optionItem.option.label)
                            checked = Qt.binding(() => optionItem.picked)
                        }
                    }
                    PlasmaComponents3.CheckBox {
                        visible: questionItem.question.multiSelect
                        Layout.alignment: Qt.AlignTop
                        checked: optionItem.picked
                        onToggled: {
                            form.choose(questionItem.index, optionItem.option.label)
                            checked = Qt.binding(() => optionItem.picked)
                        }
                    }
                    // Its words (a click on them chooses it too)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        TapHandler {
                            enabled: form.enabled
                            onTapped: form.choose(questionItem.index, optionItem.option.label)
                        }
                        HoverHandler {
                            cursorShape: form.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            text: optionItem.option.label
                            wrapMode: Text.Wrap
                            font.pointSize: form.pt
                        }
                        PlasmaComponents3.Label {
                            textFormat: Text.PlainText
                            visible: !form.compact && optionItem.option.description !== ""
                            Layout.fillWidth: true
                            text: optionItem.option.description
                            wrapMode: Text.Wrap
                            font.pointSize: form.smallPt
                            opacity: 0.7
                        }
                    }
                    Kirigami.Icon {
                        visible: form.compact && optionItem.option.description !== ""
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        Layout.alignment: Qt.AlignTop
                        source: "help-about"
                        opacity: 0.6

                        TipArea {
                            textFormat: Text.PlainText
                            anchors.fill: parent
                            mainText: optionItem.option.label
                            subText: optionItem.option.description
                        }
                    }
                }
            }
            PlasmaComponents3.TextField {
                id: ownWords
                Layout.fillWidth: true
                placeholderText: i18n("Or answer in your own words…")
                font.pointSize: form.pt
                onTextEdited: form.setText(questionItem.index, text)

                Connections {   // (an option chosen instead, or a new request: the field follows)
                    target: form
                    function onChosenChanged() {
                        const kept = form.stateOf(questionItem.index).text
                        if (ownWords.text !== kept)
                            ownWords.text = kept
                    }
                }
            }
        }
    }
}

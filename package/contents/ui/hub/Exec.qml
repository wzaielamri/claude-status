import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs commands as an "executable" DataSource does: connectSource(command),
// then newData(command, data) with data's stdout, stderr and "exit code".
// But each command gets a DataSource of its own, gone with its answer.
//
// Plasma tells every executable DataSource in plasmashell about each command
// that ends, the ones that never ran it too, and each one keeps a property
// named after that command for good: a new name rebuilds its whole list of
// them. With ~30 DataSources kept in each copy of the widget and commands
// named " # <time>" to make them run again, that cost grew all day: after a
// few hours each command took plasmashell a second, so the panel, the
// desktop and the chat pane froze now and then. A DataSource that lives for
// one command only ever sees a few.
//
// A command whose answer never comes (plasmashell lost it) must not block
// that command for good: with staleMs, one that has run longer than that is
// given up and run again. And QML refuses a new DataSource while another one
// of this copy is still being made (it logs "Cannot create new component
// instance before completing the previous" and gives none): the command is
// tried again a moment later, not dropped.
//
// A command's DataSource can also be gone with no answer (destroyed: QML
// shows it without methods, so calling one throws "Property 'destroy' of
// object … is not a function"). That command doesn't run any more: it's run
// again at once. Its stale DataSource was destroyed on the next try, which
// threw there, before the new one replaced it, on every try after: the
// widget showed what it saw last until plasmashell restarted (2026-10-27).
//
// And a command run again right after it answered isn't run: Plasma keeps
// what a command said until the event loop comes round again (its 10 ms
// check that no DataSource holds it), and a DataSource that connects to it
// meanwhile gets that at once, as it connects. Each check run again from
// inside an answer (Hub's "again") got the old answer back, and live.py's
// watcher, started again the moment it answers, got its own answer ~90
// times in a row, each a check of the status for all copies. That answer is
// dropped: the command runs a moment later (with the retry), and then takes
// whatever comes, should something else still hold it.
QtObject {
    id: exec

    signal newData(string source, var data)

    property int staleMs: 0      // 0: a command that doesn't answer is waited for
    property var running: ({})   // command -> {source, at}
    property var waiting: []     // commands whose DataSource couldn't be made yet
    property string connecting: ""   // the command a new DataSource connects to right now
    property var anyAnswer: ({})     // command -> true: run again after a kept answer, it takes what comes

    function gone(source) {
        return !!source && typeof source.connectSource !== "function"
    }

    // Whether a command still runs (or waits for its DataSource): its answer can come
    function has(command) {
        const old = running[command]
        return !!old && !gone(old.source)
    }

    function connectSource(command) {
        const old = running[command]
        if (old) {
            if (!gone(old.source) && (!staleMs || Date.now() - old.at < staleMs))
                return   // still running: not run twice (as with a DataSource)
            delete running[command]
            if (old.source && !gone(old.source)) {
                old.source.destroy()
                console.warn("Talpy Den: no answer to a command in " + staleMs + " ms, running it again")
            }
        }
        const source = runner.createObject(exec)
        if (!source) {
            running[command] = { source: null, at: Date.now() }
            if (waiting.indexOf(command) < 0)
                waiting.push(command)
            retry.restart()
            return
        }
        running[command] = { source: source, at: Date.now() }
        const was = connecting
        connecting = anyAnswer[command] ? "" : command
        delete anyAnswer[command]
        source.connectSource(command)
        connecting = was
    }

    // (each command's DataSource lets go of it by itself; the onNewData
    // handlers still call this, as they did on a DataSource)
    function disconnectSource(command) {
    }

    property Timer retry: Timer {
        interval: 50
        onTriggered: {
            const commands = exec.waiting
            exec.waiting = []
            for (const command of commands) {
                const old = exec.running[command]
                if (old && old.source && !exec.gone(old.source))
                    continue   // (it runs: given up meanwhile and run again)
                delete exec.running[command]
                exec.connectSource(command)
            }
        }
    }

    property Component runner: Component {
        P5Support.DataSource {
            engine: "executable"
            connectedSources: []
            onNewData: (source, data) => {
                disconnectSource(source)
                destroy()
                if (source === exec.connecting) {
                    // (an answer while it connects is the one Plasma kept)
                    exec.running[source] = { source: null, at: Date.now() }
                    exec.anyAnswer[source] = true
                    if (exec.waiting.indexOf(source) < 0)
                        exec.waiting.push(source)
                    exec.retry.restart()
                    return
                }
                delete exec.running[source]
                exec.newData(source, data)
            }
        }
    }
}

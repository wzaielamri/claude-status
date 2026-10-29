import QtQuick
import org.kde.kirigami as Kirigami

// Whether tests ran after a chat's last edit and how they went (its row's
// review: talpy_den.py, TestsCache.review).
Tag {
    id: badge

    property var review: null
    readonly property var run: review ? review.tests || null : null

    visible: review !== null
    text: run === null ? i18nc("a chat ran no tests after its last edit", "Not tested")
        : run.ok ? i18nc("tests passed after a chat's last edit", "Tests ✓") : i18nc("tests failed after a chat's last edit", "Tests ✗")
    warning: run !== null && !run.ok
    active: run !== null && run.ok
    tooltipTitle: run === null ? i18n("No tests since its last edit")
                : run.ok ? i18n("Tests passed after its last edit") : i18n("Tests failed after its last edit")
    tooltip: run === null ? i18n("Claude ran no test command (pytest, npm test, cargo test, …) after it last changed a file.")
           : i18n("The last test run: %1", run.command)
}

// One icon per meaning, the same in every front end. This table is the
// reference: Plasma (Breeze names; a name ending in .svg is one of this
// package's icons/), VS Code (the view's own line icons, webview/util/icons.tsx,
// drawn after the codicon of that meaning; null: VS Code has no such button)
// and GNOME (Adwaita symbolic names; null: GNOME has no such thing). Code asks
// for a meaning (Icons.plasma.cancel in QML, I.cancel in the webview,
// Icons.gnome.cancel in GJS), never for an icon by its name.
//
// The rule: icons are plain, in the theme's text color. Only warning, error
// and failed are colored (they say something is wrong). Breeze colors some
// names (edit-delete, list-remove: red; checkmark: green, as an emblem;
// view-calendar-week: green at 16 px), so none of those stand here:
// tests/test_icons.py checks every Plasma name at the sizes it's drawn.
// Cancel is the ×, and the trash can is only Delete… (to the Trash).
//
// ES2017, no `?.` or `??`: QML (Qt V4), GJS and browsers import it as it is.

const TABLE = {
    //               Plasma (Breeze)                   VS Code      GNOME (Adwaita)
    // ---- what you do to something
    cancel:          ['window-close',                  'close',     'window-close-symbolic'],            // a queued task, a picture, dictation, a question; Revoke a permission
    close:           ['window-close',                  'close',     'window-close-symbolic'],            // a summary, a window's part
    hide:            ['view-hidden',                   'eyeClosed', 'view-conceal-symbolic'],            // a chat, plan, memory, project, SSH host: listed no more, nothing deleted
    showHidden:      ['view-visible',                  'eye',       'view-reveal-symbolic'],
    delete:          ['user-trash',                    'trash',     'user-trash-symbolic'],              // Delete… to the Trash (a chat, plan, memory, an account's folder)
    erase:           ['draw-eraser',                   null,        'edit-clear-all-symbolic'],          // deleted for good: a dictation model, saved history
    startNow:        ['media-playback-start',          'play',      'media-playback-start-symbolic'],    // a queued task, a plan carried out, a sound tried
    stop:            ['media-playback-stop',           'stop',      'media-playback-stop-symbolic'],
    interrupt:       ['media-playback-pause',          null,        'media-playback-pause-symbolic'],
    goOnAt:          ['chronometer',                   'clock',     'alarm-symbolic'],                   // go on once the limit resets; pressed: it goes on then
    later:           ['chronometer',                   'clock',     'alarm-symbolic'],                   // send when this turn ends
    keepGoing:       ['media-playlist-repeat',         'repeat',    'media-playlist-repeat-symbolic'],
    star:            ['non-starred-symbolic',          'star',      'non-starred-symbolic'],
    starred:         ['starred-symbolic',              'starFull',  'starred-symbolic'],
    share:           ['document-share',                'share',     'emblem-shared-symbolic'],           // share or continue on another account
    continueOn:      ['system-switch-user',            'move',      'system-switch-user-symbolic'],      // continue on the account with room left
    moveTo:          ['go-next',                       'move',      'go-next-symbolic'],                 // keep only on, move a chat to Claude Code
    edit:            ['document-edit',                 'edit',      'document-edit-symbolic'],
    send:            ['document-send',                 'send',      'document-send-symbolic'],
    copy:            ['edit-copy',                     null,        'edit-copy-symbolic'],
    save:            ['document-save',                 null,        'document-save-symbolic'],
    undo:            ['edit-undo',                     null,        'edit-undo-symbolic'],
    refresh:         ['view-refresh',                  'refresh',   'view-refresh-symbolic'],
    openWindow:      ['window',                        'external',  'window-new-symbolic'],              // its window, terminal or tab; reopen a recent chat
    openPane:        ['dialog-messages',               'chat',      'chat-bubbles-symbolic'],            // the chat pane
    openRun:         ['document-preview',              'external',  'document-open-symbolic'],           // a subagent's whole run
    newChat:         ['chat-new-symbolic.svg',         'newChat',   'chat-new-symbolic'],
    allow:           ['dialog-ok',                     null,        'object-select-symbolic'],
    always:          ['dialog-ok-apply',               null,        'object-select-symbolic'],
    deny:            ['dialog-cancel',                 null,        'action-unavailable-symbolic'],
    reviewed:        ['dialog-ok',                     null,        'object-select-symbolic'],
    markReviewed:    ['view-task',                     null,        'view-list-bullet-symbolic'],
    commit:          ['vcs-commit',                    null,        'emblem-ok-symbolic'],
    signIn:          ['go-next',                       null,        'go-next-symbolic'],
    signOut:         ['system-log-out',                'logout',    'system-log-out-symbolic'],          // an account, an SSH host's connection
    addAccount:      ['list-add-user',                 'user',      'contact-new-symbolic'],
    download:        ['download',                      null,        'folder-download-symbolic'],
    dictate:         ['audio-input-microphone',        'mic',       'audio-input-microphone-symbolic'],
    attach:          ['mail-attachment',               'attach',    'mail-attachment-symbolic'],
    screenshot:      ['camera-photo',                  'camera',    'camera-photo-symbolic'],
    chooseFolder:    ['folder-open',                   'folder',    'folder-open-symbolic'],
    previous:        ['go-previous',                   'chevron',   'go-previous-symbolic'],
    next:            ['go-next',                       'chevron',   'go-next-symbolic'],
    goTo:            ['go-next',                       'chevron',   'go-next-symbolic'],                 // the chat that needs you, a project in its tab
    more:            ['go-down-skip',                  'more',      'go-bottom-symbolic'],               // Show N more
    earlier:         ['go-up',                         null,        'go-up-symbolic'],                   // Show earlier
    folded:          ['arrow-right',                   'chevron',   'pan-end-symbolic'],                 // a fold, closed
    unfolded:        ['arrow-down',                    'chevron',   'pan-down-symbolic'],                // (VS Code turns its chevron)
    expandAll:       ['expand-all',                    null,        'pan-down-symbolic'],
    collapseAll:     ['collapse-all',                  null,        'pan-up-symbolic'],
    peekOpen:        ['arrow-up',                      'chevron',   'pan-up-symbolic'],                  // what's under a line, shown
    peekClosed:      ['arrow-down',                    'chevron',   'pan-down-symbolic'],
    zoomIn:          ['zoom-in',                       null,        'zoom-in-symbolic'],
    zoomOut:         ['zoom-out',                      null,        'zoom-out-symbolic'],
    sideBySide:      ['view-split-left-right',         null,        'view-dual-symbolic'],
    aboveBelow:      ['view-split-top-bottom',         null,        'view-paged-symbolic'],
    focus:           ['view-filter',                   'filter',    'view-filter-symbolic'],             // Focus view
    showAll:         ['view-list-details',             'filter',    'view-list-symbolic'],               // out of Focus view
    search:          ['edit-find',                     'search',    'edit-find-symbolic'],
    settings:        ['configure',                     'gear',      'emblem-system-symbolic'],
    password:        ['dialog-password',               null,        'dialog-password-symbolic'],
    web:             ['globe',                         'external',  'web-browser-symbolic'],
    play:            ['media-playback-start',          'play',      'media-playback-start-symbolic'],    // Play with Talpy
    origin:          ['go-previous',                   'back',      'go-previous-symbolic'],             // the chat that made a plan
    playful:         ['games-config-options',          'play',      'applications-games-symbolic'],      // Playful Talpy (a toggle)
    ticked:          ['dialog-ok',                     null,        'object-select-symbolic'],           // a menu's ticked item (GNOME)
    accounts:        ['system-users',                  'user',      'system-users-symbolic'],
    chooseFile:      ['document-open',                 null,        'document-open-symbolic'],
    vscodeApp:       ['vscode',                        null,        'text-editor-symbolic'],             // VS Code's own icon (GNOME: if it has none)
    // ---- things
    chats:           ['dialog-messages',               'chat',      'chat-bubbles-symbolic'],            // the Talpy Den tab
    account:         ['user-identity',                 'user',      'avatar-default-symbolic'],
    accountOut:      ['im-user-offline',               'user',      'avatar-default-symbolic'],          // not signed in
    host:            ['network-server',                'server',    'network-server-symbolic'],
    computer:        ['computer',                      'server',    'computer-symbolic'],
    plan:            ['view-task',                     'task',      'view-list-bullet-symbolic'],
    project:         ['folder',                        'folder',    'folder-symbolic'],
    folder:          ['folder',                        'folder',    'folder-symbolic'],
    home:            ['user-home',                     'folder',    'user-home-symbolic'],
    terminal:        ['utilities-terminal',            null,        'utilities-terminal-symbolic'],
    phone:           ['smartphone',                    null,        'phone-symbolic'],
    recap:           ['view-statistics',               'chart',     'org.gnome.Settings-usage-symbolic'],
    permissions:     ['object-locked',                 'shield',    'security-medium-symbolic'],
    away:            ['view-history',                  'clock',     'document-open-recent-symbolic'],    // while you were away
    info:            ['help-about',                    null,        'help-about-symbolic'],
    question:        ['help-about',                    null,        'dialog-question-symbolic'],
    memoryUser:      ['user-identity',                 'user',      'avatar-default-symbolic'],
    memoryFeedback:  ['dialog-messages',               'chat',      'chat-bubbles-symbolic'],
    memoryProject:   ['folder-documents',              'folder',    'folder-documents-symbolic'],
    memoryReference: ['bookmarks',                     'bookmark',  'user-bookmarks-symbolic'],
    memoryAccount:   ['configure',                     'gear',      'emblem-system-symbolic'],           // the account's CLAUDE.md
    memoryNote:      ['note',                          'note',      'text-x-generic-symbolic'],
    trusted:         ['folder-locked',                 'shield',    'folder-symbolic'],                  // permissions: a trusted folder
    mcp:             ['network-connect',               'server',    'network-transmit-receive-symbolic'], // an MCP server
    webAccess:       ['globe',                         'external',  'web-browser-symbolic'],             // fetching from the web
    allowed:         ['dialog-ok',                     null,        'object-select-symbolic'],           // a command you allowed
    // ---- states: the only colored ones
    warning:         ['dialog-warning',                'warning',   'dialog-warning-symbolic'],
    error:           ['dialog-error',                  'error',     'dialog-error-symbolic'],
    failed:          ['dialog-error',                  'error',     'dialog-error-symbolic'],
    done:            ['dialog-ok',                     null,        'emblem-ok-symbolic']
};

// The meanings whose icons may be colored (they say something is wrong)
export const COLORED = ['warning', 'error', 'failed'];

function column(n) {
    const out = {};
    for (const key of Object.keys(TABLE))
        out[key] = TABLE[key][n];
    return out;
}

export const plasma = column(0);
export const vscode = column(1);
export const gnome = column(2);
export const meanings = Object.keys(TABLE);

// A memory's icon by its kind (a note about you, feedback, a project, a
// reference, the account's CLAUDE.md, else a note): the meaning's name
export function memoryMeaning(type) {
    return ({ user: 'memoryUser', feedback: 'memoryFeedback', project: 'memoryProject', reference: 'memoryReference',
              account: 'memoryAccount' })[type] || 'memoryNote';
}

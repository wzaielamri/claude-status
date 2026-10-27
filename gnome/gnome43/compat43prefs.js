// Stand-ins for the settings window on GNOME 43/44 (libadwaita 1.2, GTK
// 4.8): the ExtensionPreferences base class, Adw.SpinRow and Adw.SwitchRow
// (libadwaita 1.4), Adw.AlertDialog (libadwaita 1.5) and Gtk.FileDialog
// (GTK 4.10), each with just the parts prefs.js uses. Legacy imports, like
// compat43.js.

const {Adw, GObject, Gtk} = imports.gi;
const ExtensionUtils = imports.misc.extensionUtils;

var ExtensionPreferences = class ExtensionPreferences {
    constructor() {
        const me = ExtensionUtils.getCurrentExtension();
        this.metadata = me.metadata;
        this.uuid = me.uuid;
        this.path = me.path;
        this.dir = me.dir;
    }

    getSettings(schema) {
        return ExtensionUtils.getSettings(schema);
    }
};

// A row with a spin button; its value property is the button's
var SpinRow = GObject.registerClass({
    GTypeName: 'TalpyDenSpinRow',
    Properties: {
        value: GObject.ParamSpec.double('value', 'Value', 'The spin button value',
            GObject.ParamFlags.READWRITE, -Number.MAX_VALUE, Number.MAX_VALUE, 0),
    },
}, class TalpyDenSpinRow extends Adw.ActionRow {
    _init(props = {}) {
        super._init(props);
        this._spin = new Gtk.SpinButton({valign: Gtk.Align.CENTER});
        this._spin.connect('notify::value', () => this.notify('value'));
        this.add_suffix(this._spin);
        this.activatable_widget = this._spin;
    }

    static new_with_range(min, max, step) {
        const row = new this();
        row._spin.set_range(min, max);
        row._spin.set_increments(step, step * 10);
        // wide enough for the longest value (GTK 4.8 sizes it for fewer
        // digits: 10000 showed as 1000)
        row._spin.width_chars = Math.max(String(Math.trunc(min)).length, String(Math.trunc(max)).length);
        return row;
    }

    // Adw.SpinRow's row.set({title, subtitle})
    set(props) {
        Object.assign(this, props);
    }

    get value() {
        return this._spin ? this._spin.value : 0;
    }

    set value(v) {
        if (this._spin && this._spin.value !== v)
            this._spin.value = v;
    }
});

// A row with a switch; its active property is the switch's
var SwitchRow = GObject.registerClass({
    GTypeName: 'TalpyDenSwitchRow',
    Properties: {
        active: GObject.ParamSpec.boolean('active', 'Active', 'Whether the switch is on',
            GObject.ParamFlags.READWRITE, false),
    },
}, class TalpyDenSwitchRow extends Adw.ActionRow {
    _init(props = {}) {
        super._init(props);
        this._switch = new Gtk.Switch({valign: Gtk.Align.CENTER});
        this._switch.connect('notify::active', () => this.notify('active'));
        this.add_suffix(this._switch);
        this.activatable_widget = this._switch;
    }

    get active() {
        return this._switch ? this._switch.active : false;
    }

    set active(v) {
        if (this._switch && this._switch.active !== v)
            this._switch.active = v;
    }
});

// Gtk.FileDialog's open()/open_finish(), on Gtk.FileChooserNative
const openDialogs = new Set();   // kept alive while open

var FileDialog = class FileDialog {
    constructor({title = '', default_filter: filter = null} = {}) {
        this._title = title;
        this._filter = filter;
        this._file = null;
    }

    open(parent, cancellable, callback) {
        const native = new Gtk.FileChooserNative({title: this._title, transient_for: parent, modal: true,
            action: Gtk.FileChooserAction.OPEN});
        if (this._filter)
            native.add_filter(this._filter);
        openDialogs.add(native);
        native.connect('response', (d, response) => {
            this._file = response === Gtk.ResponseType.ACCEPT ? d.get_file() : null;
            openDialogs.delete(native);
            d.destroy();
            callback(this, null);
        });
        native.show();
    }

    open_finish() {
        if (!this._file)
            throw new Error('Dismissed by user');
        return this._file;
    }
};

// Adw.AlertDialog's add_response(), set_response_appearance() and
// choose()/choose_finish(), on Adw.MessageDialog (libadwaita 1.2 has no
// choose() yet: its response signal says which button closed it)
var AlertDialog = class AlertDialog {
    constructor({heading = '', body = ''} = {}) {
        this._heading = heading;
        this._body = body;
        this._responses = [];     // [id, label]
        this._appearances = [];   // [id, Adw.ResponseAppearance]
        this._response = 'close';
    }

    add_response(id, label) {
        this._responses.push([id, label]);
    }

    set_response_appearance(id, appearance) {
        this._appearances.push([id, appearance]);
    }

    choose(parent, cancellable, callback) {
        const dialog = new Adw.MessageDialog({heading: this._heading, body: this._body,
            transient_for: parent, modal: true});
        for (const [id, label] of this._responses)
            dialog.add_response(id, label);
        for (const [id, appearance] of this._appearances)
            dialog.set_response_appearance(id, appearance);
        openDialogs.add(dialog);
        dialog.connect('response', (d, response) => {
            this._response = response;
            openDialogs.delete(dialog);
            callback(this, null);
        });
        dialog.present();
    }

    choose_finish() {
        return this._response;
    }
};

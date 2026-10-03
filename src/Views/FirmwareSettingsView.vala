/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class About.FirmwareSettingsView : Adw.NavigationPage {
    private Fwupd.Client client = new Fwupd.Client ();
    private Gtk.Box settings_box;
    private Gtk.Label status_label;
    private Gtk.Label reboot_label;
    private Gtk.Button refresh_button;
    private bool busy;

    construct {
        title = _("Firmware Settings");

        var back_button = new Granite.BackButton (_("All Updates")) {
            action_name = "navigation.pop",
            halign = START
        };

        refresh_button = new Gtk.Button.with_label (_("Refresh"));
        var header_bar = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label (title)
        };
        header_bar.pack_start (back_button);
        header_bar.pack_end (refresh_button);

        status_label = new Gtk.Label ("") {
            wrap = true,
            xalign = 0
        };
        reboot_label = new Gtk.Label (_("Restart required to apply firmware settings.")) {
            wrap = true,
            xalign = 0,
            visible = false
        };
        settings_box = new Gtk.Box (VERTICAL, 12);

        var content = new Gtk.Box (VERTICAL, 12) {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };
        content.append (status_label);
        content.append (reboot_label);
        content.append (settings_box);

        var toolbarview = new Adw.ToolbarView () {
            content = new Gtk.ScrolledWindow () { child = content },
            top_bar_style = RAISED_BORDER
        };
        toolbarview.add_top_bar (header_bar);
        child = toolbarview;

        refresh_button.clicked.connect (() => load.begin ());
    }

    public async void load () {
        if (busy) {
            return;
        }

        set_busy (true);
        yield read_settings ();
        set_busy (false);
    }

    private void set_busy (bool value) {
        busy = value;
        settings_box.sensitive = !value;
        refresh_button.sensitive = !value;
    }

    private async void read_settings () {
        while (settings_box.get_first_child () != null) {
            settings_box.remove (settings_box.get_first_child ());
        }

        status_label.label = _("Loading firmware settings…");
        reboot_label.visible = false;

        try {
            yield client.connect_async (null);
            yield client.set_feature_flags_async (Fwupd.FeatureFlags.ALLOW_AUTHENTICATION, null);
            var settings = yield client.get_bios_settings_async (null);
            foreach (var setting in settings) {
                // fwupd exposes this status even when other values are hidden.
                if (setting.get_name () == "pending_reboot") {
                    reboot_label.visible |= setting.get_current_value () == "1";
                    continue;
                }

                add_setting (setting);
            }

            status_label.label = settings_box.get_first_child () == null
                ? _("Firmware settings are not available on this device.")
                : _("Authentication may be required to change firmware settings.");
        } catch (Error e) {
            status_label.label = _("Unable to load firmware settings: %s").printf (e.message);
        }
    }

    private void add_setting (Fwupd.BiosSetting setting) {
        var current = setting.get_current_value ();
        var editable = !setting.get_read_only () && current != null && setting.get_id () != null;
        var box = new Gtk.Box (VERTICAL, 6);
        var name_label = new Gtk.Label (setting.get_name () ?? setting.get_id ()) {
            xalign = 0,
            wrap = true
        };
        box.append (name_label);
        if (setting.get_description () != null) {
            box.append (new Gtk.Label (setting.get_description ()) {
                xalign = 0,
                wrap = true
            });
        }

        var controls = new Gtk.Box (HORIZONTAL, 6);
        Gtk.Entry? entry = null;
        Gtk.DropDown? dropdown = null;

        if (editable && setting.get_kind () == Fwupd.BiosSettingKind.ENUMERATION) {
            var values = new Gtk.StringList (null);
            uint selected = Gtk.INVALID_LIST_POSITION;
            var possible = setting.get_possible_values ();
            for (uint i = 0; i < possible.length; i++) {
                values.append (possible[i]);
                if (possible[i] == current) {
                    selected = i;
                }
            }
            dropdown = new Gtk.DropDown (values, null) {
                selected = selected,
                hexpand = true
            };
            dropdown.update_relation (Gtk.AccessibleRelation.LABELLED_BY, name_label, null, -1);
            controls.append (dropdown);
        } else if (editable && (setting.get_kind () == Fwupd.BiosSettingKind.INTEGER ||
                               setting.get_kind () == Fwupd.BiosSettingKind.STRING)) {
            entry = new Gtk.Entry () {
                text = current,
                hexpand = true
            };
            entry.update_relation (Gtk.AccessibleRelation.LABELLED_BY, name_label, null, -1);
            controls.append (entry);
            var constraints = setting.get_kind () == Fwupd.BiosSettingKind.INTEGER
                ? _("Range: %s–%s; increment: %s").printf (
                    setting.get_lower_bound ().to_string (), setting.get_upper_bound ().to_string (),
                    setting.get_scalar_increment ().to_string ())
                : _("Length: %s–%s bytes").printf (
                    setting.get_lower_bound ().to_string (), setting.get_upper_bound ().to_string ());
            box.append (new Gtk.Label (constraints) { xalign = 0, wrap = true });
        } else {
            controls.append (new Gtk.Label (current ?? _("Unavailable")) {
                xalign = 0,
                wrap = true,
                selectable = true
            });
            box.append (new Gtk.Label (_("Not Editable")) { xalign = 0 });
        }

        if (entry != null || dropdown != null) {
            var apply_button = new Gtk.Button.with_label (_("Apply")) { sensitive = false };
            apply_button.update_property (Gtk.AccessibleProperty.LABEL, _("Apply %s").printf (name_label.label), -1);
            controls.append (apply_button);
            if (entry != null) {
                entry.changed.connect (() => {
                    apply_button.sensitive = entry.text != current && valid_value (setting, entry.text);
                });
            } else {
                dropdown.notify["selected"].connect (() => {
                    var item = dropdown.selected_item as Gtk.StringObject;
                    apply_button.sensitive = item != null && item.string != current;
                });
            }

            apply_button.clicked.connect (() => {
                var value = entry != null ? entry.text : ((Gtk.StringObject) dropdown.selected_item).string;
                if (setting.get_kind () == Fwupd.BiosSettingKind.INTEGER) {
                    value = uint64.parse (value, 10).to_string ();
                }
                save.begin (setting.get_id (), value);
            });
        }

        box.append (controls);
        settings_box.append (box);
    }

    private bool valid_value (Fwupd.BiosSetting setting, string value) {
        var lower = setting.get_lower_bound ();
        var upper = setting.get_upper_bound ();
        if (setting.get_kind () == Fwupd.BiosSettingKind.STRING) {
            return value.length >= lower && value.length <= upper;
        }

        // Avoid floating point widgets: firmware integers can span all of uint64.
        uint64 number;
        if (value.length == 0) {
            return false;
        }
        for (int i = 0; i < value.length; i++) {
            if (!value[i].isdigit ()) {
                return false;
            }
        }
        if (!uint64.try_parse (value, out number, null, 10) || number < lower || number > upper) {
            return false;
        }
        var increment = setting.get_scalar_increment ();
        return increment == 0 || (number - lower) % increment == 0;
    }

    private async void save (string id, string value) {
        if (busy) {
            return;
        }

        set_busy (true);
        status_label.label = _("Applying firmware setting…");
        try {
            var changes = new HashTable<string, string> (str_hash, str_equal);
            changes.insert (id, value);
            yield client.modify_bios_setting_async ((owned) changes, null);
        } catch (Error e) {
            var window = get_root () as Gtk.Window;
            if (window != null && window.visible) {
                var dialog = new Granite.MessageDialog (
                    _("Unable to change firmware setting"),
                    e.message,
                    new ThemedIcon ("dialog-error"),
                    Gtk.ButtonsType.CLOSE
                ) {
                    transient_for = window
                };
                dialog.response.connect (dialog.destroy);
                dialog.present ();
            }
        }

        // Re-fetch the daemon's cached settings, including after a failed write.
        yield read_settings ();
        set_busy (false);
    }
}

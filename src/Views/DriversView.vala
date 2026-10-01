/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class About.DriversView : Switchboard.SettingsPage {
    private Gtk.Stack stack;
    private Gtk.ListBox devices_list;
    private Granite.Placeholder progress_placeholder;
    private Granite.Placeholder error_placeholder;
    private Drivers? driver_proxy;
    private string error_message = "";

    public DriversView () {
        Object (
            icon: new ThemedIcon ("application-x-firmware"),
            title: _("Drivers"),
            description: _("Broadcom® Wi-Fi adapters, NVIDIA® graphics, and some virtual machines may not function properly without additional drivers.")
        );
    }

    construct {
        var none_placeholder = new Granite.Placeholder (_("No drivers available")) {
            description = _("This device doesn't need any additional drivers."),
            icon = new ThemedIcon ("emblem-default")
        };

        var checking_placeholder = new Granite.Placeholder (_("Checking for Drivers")) {
            description = _("Connecting to the driver service and searching for drivers."),
            icon = new ThemedIcon ("sync-synchronizing")
        };

        devices_list = new Gtk.ListBox () {
            vexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        devices_list.set_placeholder (checking_placeholder);
        devices_list.set_header_func (header_func);
        devices_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);

        var scrolled = new Gtk.ScrolledWindow () {
            child = devices_list
        };

        progress_placeholder = new Granite.Placeholder ("") {
            icon = new ThemedIcon ("emblem-synchronized")
        };

        error_placeholder = new Granite.Placeholder (_("Failed to install driver")) {
            description = _("Manually refreshing driver information may resolve the issue"),
            icon = new ThemedIcon ("dialog-error")
        };
        var refresh_button = error_placeholder.append_button (new ThemedIcon ("sync-synchronizing"), _("Refresh"), _("Refresh driver information"));
        var more_button = error_placeholder.append_button (new ThemedIcon ("go-next"), _("Learn More…"), "");

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        };
        stack.add_named (none_placeholder, "none");
        stack.add_named (scrolled, "scrolled");
        stack.add_named (progress_placeholder, "progress");
        stack.add_named (error_placeholder, "error");

        var frame = new Gtk.Frame (null) {
            child = stack
        };

        child = frame;
        if (!Plug.is_sysupdate ()) {
            Bus.get_proxy.begin<Drivers> (SESSION, "io.elementary.settings-daemon", "/io/elementary/settings_daemon", 0, null, (obj, res) => {
                try {
                    driver_proxy = Bus.get_proxy.end (res);

                    driver_proxy.state_changed.connect (update_state);
                    update_state.begin ();
                } catch (Error e) {
                    critical ("Failed to get driver proxy: %s", e.message);
                }
            });
        }

        refresh_button.clicked.connect (() => {
            if (driver_proxy != null) {
                driver_proxy.check_for_drivers.begin (false);
            }
        });

        more_button.clicked.connect (() => {
            var message_dialog = new Granite.MessageDialog (
                _("Failed to install"),
                _("This may have been caused by sideloaded or manually compiled software, a third-party software source, or a package manager error. Manually refreshing may resolve the issue."),
                new ThemedIcon ("dialog-error")
            ) {
                transient_for = (Gtk.Window) get_root (),
                modal = true
            };

            message_dialog.show_error_details (error_message);

            message_dialog.response.connect (message_dialog.destroy);
            message_dialog.present ();
        });
    }

    private async void update_state () {
        if (driver_proxy == null) {
            return;
        }

        Drivers.CurrentState current_state;
        try {
            current_state = yield driver_proxy.get_current_state ();
        } catch (Error e) {
            critical ("Failed to get current state from Updates Backend: %s", e.message);
            return;
        }

        switch (current_state.state) {
            case UP_TO_DATE:
                stack.visible_child_name = "none";
                break;

            case CHECKING:
                stack.visible_child_name = "scrolled";
                //FIXME: Replace with remove_all
                while (devices_list.get_row_at_index (0) != null) {
                    devices_list.remove (devices_list.get_row_at_index (0));
                }

                break;

            case AVAILABLE:
                stack.visible_child_name = "scrolled";
                //FIXME: Replace with remove_all
                while (devices_list.get_row_at_index (0) != null) {
                    devices_list.remove (devices_list.get_row_at_index (0));
                }

                try {
                    var drivers = yield driver_proxy.get_available_drivers ();
                    foreach (var device in drivers.get_keys ()) {
                        DriverRow? last_row = null;
                        foreach (var driver in drivers[device].get_keys ()) {
                            var row = new DriverRow (device, driver, drivers[device][driver]);
                            devices_list.append (row);

                            if (last_row != null) {
                                last_row.install_button.group = row.install_button;
                            }

                            last_row = row;

                            row.install.connect (() => {
                                driver_proxy.install.begin (row.driver_name);
                                progress_placeholder.title = _("Installing %s…").printf (row.driver_name);
                            });
                        }
                    }
                } catch (Error e) {
                    warning ("Failed to get driver list from backend: %s", e.message);
                }

                break;

            case DOWNLOADING:
                stack.visible_child_name = "progress";
                progress_placeholder.description = current_state.message;
                break;

            case ERROR:
                stack.visible_child_name = "error";
                error_message = current_state.message;
                break;

            default:
                break;
        }
    }

    private void header_func (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        var driver1 = (DriverRow) row;

        bool same = false;
        if (before != null) {
            var driver2 = (DriverRow) before;
            same = driver1.device == driver2.device;
        }

        if (!same) {
            var header = new Granite.HeaderLabel (driver1.device);
            driver1.set_header (header);
        }
    }
}

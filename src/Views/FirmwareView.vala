/*
* Copyright 2020-2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
*/

public class About.FirmwareView : Switchboard.SettingsPage {
    private Gtk.Stack stack;
    private Adw.NavigationView navigation_view;
    private FirmwareReleaseView firmware_release_view;
    private Granite.Placeholder progress_alert_view;
    private Granite.Placeholder placeholder_alert_view;
    private Gtk.ListBox update_list;
    private uint num_updates = 0;
    private Fwupd.Client fwupd_client;

    public FirmwareView () {
        Object (
            icon: new ThemedIcon ("application-x-firmware"),
            title: _("Firmware"),
            description: _("Firmware updates provided by device manufacturers can improve performance and fix critical security issues.")
        );
    }

    construct {
        progress_alert_view = new Granite.Placeholder ("") {
            description = _("Do not unplug the device during the update."),
            icon = new ThemedIcon ("emblem-synchronized")
        };

        placeholder_alert_view = new Granite.Placeholder (_("Checking for Updates")) {
            description = _("Connecting to the firmware service and searching for updates."),
            icon = new ThemedIcon ("sync-synchronizing")
        };

        update_list = new Gtk.ListBox () {
            vexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        update_list.set_sort_func ((Gtk.ListBoxSortFunc) compare_rows);
        update_list.set_header_func ((Gtk.ListBoxUpdateHeaderFunc) header_rows);
        update_list.set_placeholder (placeholder_alert_view);

        var update_scrolled = new Gtk.ScrolledWindow () {
            child = update_list
        };

        var update_page = new Adw.NavigationPage (update_scrolled, _("All Updates"));

        firmware_release_view = new FirmwareReleaseView ();

        navigation_view = new Adw.NavigationView ();
        navigation_view.add (update_page);
        navigation_view.add_css_class (Granite.STYLE_CLASS_VIEW);

        stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        };
        stack.add_child (navigation_view);
        stack.add_child (progress_alert_view);

        var frame = new Gtk.Frame (null) {
            child = stack
        };

        child = frame;

        if (LoginManager.get_instance ().can_reboot_to_firmware_setup ()) {
            var reboot_to_firmware_setup_button = add_button (_("Restart to Firmware Setup…"));
            reboot_to_firmware_setup_button.clicked.connect (reboot_to_firmware_setup_clicked);
        }

        fwupd_client = new Fwupd.Client ();
        fwupd_client.device_added.connect (on_device_added);
        fwupd_client.device_removed.connect (on_device_removed);

        update_list_view.begin ();

        update_list.row_activated.connect (show_release);

        firmware_release_view.update.connect ((device, release) => {
            update.begin (device, release);
        });
    }

    private async void update_list_view () {
        while (update_list.get_row_at_index (0) != null) {
            update_list.remove (update_list.get_row_at_index (0));
        }

        num_updates = 0;

        try {
            var devices = yield FirmwareClient.get_devices (fwupd_client);
            for (int i = 0; i < devices.length; i++) {
                add_device (devices[i]);
            }

            placeholder_alert_view.title = _("Firmware Updates Are Not Available");
            placeholder_alert_view.description = _("Firmware updates are not supported on this or any connected devices.");
        } catch (Error e) {
            placeholder_alert_view.title = _("The Firmware Service Is Not Available");
            placeholder_alert_view.description = _("Please make sure “fwupd” is installed and enabled.");
        }

        stack.visible_child = navigation_view;
    }

    private void add_device (Fwupd.Device device) {
#if HAS_FWUPD_2_0
        if (device.has_flag (Fwupd.DeviceFlags.UPDATABLE)) {
#else
        if (device.has_flag (Fwupd.DEVICE_FLAG_UPDATABLE)) {
#endif
            FirmwareClient.get_upgrades.begin (fwupd_client, device.get_id (), (obj, res) => {
                Fwupd.Release? release = null;

                try {
                    var upgrades = FirmwareClient.get_upgrades.end (res);
                    if (upgrades != null) {
                        release = upgrades[0];
                    }
                } catch (Error e) {
                    debug (e.message);
                }

                var row = new Widgets.FirmwareUpdateRow (device, release);

                if (row.is_updatable) {
                    num_updates++;
                }

                update_list.append (row);
                update_list.invalidate_sort ();

                row.update.connect ((device, release) => {
                    update.begin (device, release);
                });
            });
        }
    }

    private void show_release (Gtk.ListBoxRow widget) {
        if (widget is Widgets.FirmwareUpdateRow) {
            var row = (Widgets.FirmwareUpdateRow) widget;
            firmware_release_view.update_view (row.device, row.release);
            navigation_view.push (firmware_release_view);
        }
    }

    private void on_device_added (Fwupd.Client client, Fwupd.Device device) {
        debug ("Added device: %s", device.get_name ());

        add_device (device);

        stack.visible_child = navigation_view;
    }

    private void on_device_removed (Fwupd.Client client, Fwupd.Device device) {
        debug ("Removed device: %s", device.get_name ());

        unowned var child = update_list.get_first_child ();
        while (child != null) {
            Widgets.FirmwareUpdateRow row = null;
            if (child is Widgets.FirmwareUpdateRow) {
                row = (Widgets.FirmwareUpdateRow) child;
            }

            child = child.get_next_sibling ();

            if (row != null) {
                if (row.device.get_id () == device.get_id ()) {
                    if (row.is_updatable) {
                        num_updates--;
                    }

                    update_list.remove (row);
                }
            }
        }

        update_list.invalidate_sort ();
    }

    [CCode (instance_pos = -1)]
    private int compare_rows (Widgets.FirmwareUpdateRow row1, Widgets.FirmwareUpdateRow row2) {
        if (row1.is_updatable && !row2.is_updatable) {
            return -1;
        }

        if (!row1.is_updatable && row2.is_updatable) {
            return 1;
        }

        return row1.device.get_name ().collate (row2.device.get_name ());
    }

    [CCode (instance_pos = -1)]
    private void header_rows (Widgets.FirmwareUpdateRow row1, Widgets.FirmwareUpdateRow? row2) {
        if (row2 == null && row1.is_updatable) {
            var header = new Granite.HeaderLabel (
                dngettext (GETTEXT_PACKAGE, "%u Update Available", "%u Updates Available", num_updates).printf (num_updates)
            );
            row1.set_header (header);
        } else if (row2 == null || row1.is_updatable != row2.is_updatable) {
            var header = new Granite.HeaderLabel (_("Up to Date"));
            row1.set_header (header);
        } else {
            row1.set_header (null);
        }
    }

    private async void update (Fwupd.Device device, Fwupd.Release release) {
        progress_alert_view.title = _("“%s” is being updated").printf (device.get_name ());
        stack.visible_child = progress_alert_view;

        unowned var detach_caption = release.get_detach_caption ();
        if (detach_caption != null) {
            var detach_image = release.get_detach_image ();

            if (detach_image != null) {
                detach_image = yield download_file (device, detach_image);
            }

            var details_dialog = show_details_dialog (device, detach_caption, detach_image);
            details_dialog.response.connect ((response) => {
                details_dialog.destroy ();
                if (response == Gtk.ResponseType.ACCEPT) {
                    continue_update.begin (device, release);
                } else {
                    stack.visible_child = navigation_view;
                    return;
                }
            });

            details_dialog.present ();
        } else {
            continue_update.begin (device, release);
        }
    }

    private async void continue_update (Fwupd.Device device, Fwupd.Release release) {
#if HAS_FWUPD_2_0
        var locations = release.get_locations ();
        // Typically the first URI will be the main HTTP mirror,
        // it's unlikely that we'll be using IPFS/IPNS URLs anyway.
        var path = yield download_file (device, locations.length > 0 ? locations[0] : "");
#else
        var path = yield download_file (device, release.get_uri ());
#endif

        try {
            var install_flags = Fwupd.InstallFlags.NONE;
#if !HAS_FWUPD_2_0
            if (device.has_flag (Fwupd.DEVICE_FLAG_ONLY_OFFLINE)) {
                install_flags = Fwupd.InstallFlags.OFFLINE;
            }
#endif

            if (yield FirmwareClient.install (fwupd_client, device.get_id (), path, install_flags)) {
#if HAS_FWUPD_2_0
                if (device.has_flag (Fwupd.DeviceFlags.NEEDS_REBOOT)) {
#else
                if (device.has_flag (Fwupd.DEVICE_FLAG_NEEDS_REBOOT)) {
#endif
                    show_reboot_dialog ();
#if HAS_FWUPD_2_0
                } else if (device.has_flag (Fwupd.DeviceFlags.NEEDS_SHUTDOWN)) {
#else
                } else if (device.has_flag (Fwupd.DEVICE_FLAG_NEEDS_SHUTDOWN)) {
#endif
                    show_shutdown_dialog ();
                }
            }
        } catch (Error e) {
            show_error_dialog (device, e.message);
        }

        stack.visible_child = navigation_view;
        update_list_view.begin ();
    }

    private async string? download_file (Fwupd.Device device, string uri) {
        var server_file = File.new_for_uri (uri);
        var path = Path.build_filename (Environment.get_tmp_dir (), server_file.get_basename ());
        var local_file = File.new_for_path (path);

        bool result;
        try {
            result = yield server_file.copy_async (local_file, FileCopyFlags.OVERWRITE, Priority.DEFAULT, null, (current_num_bytes, total_num_bytes) => {
            // TODO: provide useful information for user
            });
        } catch (Error e) {
            show_error_dialog (device, "Could not download file: %s".printf (e.message));
            return null;
        }

        if (!result) {
            show_error_dialog (device, "Download of %s was not successful".printf (uri));
            return null;
        }

        return path;
    }

    private void show_error_dialog (Fwupd.Device device, string secondary_text) {
        var gicon = new ThemedIcon ("application-x-firmware");
        var icons = device.get_icons ();
        if (icons.data != null) {
            gicon = new GLib.ThemedIcon.from_names (icons.data);
        }

        var message_dialog = new Granite.MessageDialog (
            _("Failed to install firmware release"),
            secondary_text,
            gicon,
            Gtk.ButtonsType.CLOSE
        ) {
            badge_icon = new ThemedIcon ("dialog-error"),
            transient_for = (Gtk.Window) get_root ()
        };

        message_dialog.response.connect (message_dialog.destroy);
        message_dialog.present ();
    }

    private Granite.MessageDialog show_details_dialog (Fwupd.Device device, string detach_caption, string? detach_image) {
        var gicon = new ThemedIcon ("application-x-firmware");
        var icons = device.get_icons ();
        if (icons.data != null) {
            gicon = new GLib.ThemedIcon.from_names (icons.data);
        }

        var message_dialog = new Granite.MessageDialog (
            _("“%s” needs to manually be put in update mode").printf (device.get_name ()),
            detach_caption,
            gicon,
            Gtk.ButtonsType.CANCEL
        ) {
            badge_icon = new ThemedIcon ("dialog-information"),
            transient_for = (Gtk.Window) get_root ()
        };

        var suggested_button = (Gtk.Button) message_dialog.add_button (_("Continue"), Gtk.ResponseType.ACCEPT);
        suggested_button.add_css_class (Granite.CssClass.SUGGESTED);

        if (detach_image != null) {
            var custom_widget = new Gtk.Image.from_file (detach_image);
            message_dialog.custom_bin.append (custom_widget);
        }

        return message_dialog;
    }

    private void show_reboot_dialog () {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("An update requires the system to restart to complete"),
            _("This will close all open applications and restart this device."),
            "application-x-firmware",
            Gtk.ButtonsType.CANCEL
        ) {
            badge_icon = new ThemedIcon ("system-reboot"),
            transient_for = (Gtk.Window) get_root ()
        };

        var suggested_button = (Gtk.Button) message_dialog.add_button (_("Restart"), Gtk.ResponseType.ACCEPT);
        suggested_button.add_css_class (Granite.CssClass.SUGGESTED);

        message_dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                LoginManager.get_instance ().reboot ();
            }
            message_dialog.destroy ();
        });

        message_dialog.present ();
    }

    private void show_shutdown_dialog () {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("An update requires the system to shut down to complete"),
            _("This will close all open applications and turn off this device."),
            "application-x-firmware",
            Gtk.ButtonsType.CANCEL
        ) {
            badge_icon = new ThemedIcon ("system-shutdown"),
            transient_for = (Gtk.Window) get_root ()
        };

        var suggested_button = (Gtk.Button) message_dialog.add_button (_("Shut Down"), Gtk.ResponseType.ACCEPT);
        suggested_button.add_css_class (Granite.CssClass.DESTRUCTIVE);

        message_dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                LoginManager.get_instance ().shutdown ();
            }
            message_dialog.destroy ();
        });

        message_dialog.present ();
    }

    private void reboot_to_firmware_setup_clicked () {
        var dialog = new Granite.MessageDialog (
            _("Restart to firmware setup"),
            _("This will close all open applications, restart this device, and open the firmware setup screen."),
            new ThemedIcon ("system-reboot"),
            Gtk.ButtonsType.CANCEL
        ) {
            badge_icon = new ThemedIcon ("application-x-firmware"),
            modal = true,
            transient_for = (Gtk.Window) get_root ()
        };

        var continue_button = dialog.add_button (_("Restart"), Gtk.ResponseType.ACCEPT);
        continue_button.add_css_class (Granite.CssClass.DESTRUCTIVE);

        dialog.response.connect ((result) => {
            dialog.destroy ();

            if (result != Gtk.ResponseType.ACCEPT) {
                return;
            }

            var login_manager = LoginManager.get_instance ();
            var error = login_manager.set_reboot_to_firmware_setup ();

            if (error != null) {
                var message_dialog = new Granite.MessageDialog (
                    _("Unable to restart to firmware setup"),
                    _("A system error prevented automatically restarting into firmware setup."),
                    new ThemedIcon ("system-reboot"),
                    Gtk.ButtonsType.CLOSE
                ) {
                    badge_icon = new ThemedIcon ("dialog-error"),
                    modal = true,
                    transient_for = (Gtk.Window) get_root ()
                };
                message_dialog.show_error_details (error.message);
                message_dialog.present ();
                message_dialog.response.connect (message_dialog.destroy);

                return;
            }

            login_manager.reboot ();
        });

        dialog.present ();
    }
}

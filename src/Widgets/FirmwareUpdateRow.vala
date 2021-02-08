/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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

public class About.Widgets.FirmwareUpdateRow : Gtk.ListBoxRow {
    public FwupdManager fwupd { get; construct set; }
    public Fwupd.Device device { get; construct set; }

    public signal void on_update_start ();
    public signal void on_update_end ();

    public FirmwareUpdateRow (FwupdManager fwupd, Fwupd.Device device) {
        Object (
            fwupd: fwupd,
            device: device
        );
    }

    construct {
        var icon = new Gtk.Image.from_icon_name (device.icon, Gtk.IconSize.DND) {
            pixel_size = 32
        };

        var device_name_label = new Gtk.Label (device.name) {
            halign = Gtk.Align.START,
            hexpand = true
        };
        device_name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var version_label = new Gtk.Label (device.latest_release.version) {
            wrap = true,
            xalign = 0
        };

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            margin = 6
        };
        grid.attach (icon, 0, 0, 1, 2);
        grid.attach (device_name_label, 1, 0);
        grid.attach (version_label, 1, 1);

        switch (device.latest_release.flag) {
            case Fwupd.ReleaseFlag.IS_UPGRADE:
                if (device.latest_release.version == device.version) {
                    break;
                }

                var update_button = new Gtk.Button.with_label (_("Update")) {
                    valign = Gtk.Align.CENTER
                };
                update_button.clicked.connect (() => {
                    on_update_start ();

                    update.begin (device, device.latest_release, (obj, res) => {
                        update.end (res);
                        on_update_end ();
                    });
                });
                grid.attach (update_button, 2, 0, 1, 2);
                break;
        }

        add (grid);
    }

    private async void update (Fwupd.Device device, Fwupd.Release release) {
        var path = yield fwupd.download_file (device, release.uri);

        var details = yield fwupd.get_release_details (device, path);

        if (details.caption != null) {
            if (show_details_dialog (details) == false) {
                return;
            }
        }

        if ((yield fwupd.install (device, path)) == true) {
            if (device.has_flag (Fwupd.DeviceFlag.NEEDS_REBOOT)) {
                show_reboot_dialog ();
            } else if (device.has_flag (Fwupd.DeviceFlag.NEEDS_SHUTDOWN)) {
                show_shutdown_dialog ();
            }
        }
    }

    private bool show_details_dialog (Fwupd.Details details) {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("“%s” needs to manually be put in update mode").printf (device.name),
            details.caption,
            device.icon,
            Gtk.ButtonsType.CANCEL
        );
        message_dialog.transient_for = (Gtk.Window) get_toplevel ();

        var suggested_button = new Gtk.Button.with_label (_("Continue"));
        suggested_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        message_dialog.add_action_widget (suggested_button, Gtk.ResponseType.ACCEPT);

        if (details.image != null) {
            var custom_widget = new Gtk.Image.from_file (details.image);
            message_dialog.custom_bin.add (custom_widget);
        }

        message_dialog.badge_icon = new ThemedIcon ("dialog-information");
        message_dialog.show_all ();
        bool should_continue = message_dialog.run () == Gtk.ResponseType.ACCEPT;

        message_dialog.destroy ();

        return should_continue;
    }

    private void show_reboot_dialog () {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("An update requires the system to restart to complete"),
            _("This will close all open applications and restart this device."),
            "application-x-firmware",
            Gtk.ButtonsType.CANCEL
        );
        message_dialog.transient_for = (Gtk.Window) get_toplevel ();

        var suggested_button = new Gtk.Button.with_label (_("Restart"));
        suggested_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        message_dialog.add_action_widget (suggested_button, Gtk.ResponseType.ACCEPT);

        message_dialog.badge_icon = new ThemedIcon ("system-reboot");
        message_dialog.show_all ();
        if (message_dialog.run () == Gtk.ResponseType.ACCEPT) {
            LoginManager.get_instance ().reboot ();
        }

        message_dialog.destroy ();
    }

    private void show_shutdown_dialog () {
        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("An update requires the system to shut down to complete"),
            _("This will close all open applications and turn off this device."),
            "application-x-firmware",
            Gtk.ButtonsType.CANCEL
        );
        message_dialog.transient_for = (Gtk.Window) get_toplevel ();

        var suggested_button = new Gtk.Button.with_label (_("Shut Down"));
        suggested_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        message_dialog.add_action_widget (suggested_button, Gtk.ResponseType.ACCEPT);

        message_dialog.badge_icon = new ThemedIcon ("system-shutdown");
        message_dialog.show_all ();
        if (message_dialog.run () == Gtk.ResponseType.ACCEPT) {
            LoginManager.get_instance ().shutdown ();
        }

        message_dialog.destroy ();
    }
}

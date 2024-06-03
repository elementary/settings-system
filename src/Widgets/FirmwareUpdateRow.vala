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
    public signal void update (Fwupd.Device device, Fwupd.Release release);

    public Fwupd.Device device { get; construct; }
    public Fwupd.Release? release { get; construct; }
    public bool is_updatable { get; private set; }

    public FirmwareUpdateRow (Fwupd.Device device, Fwupd.Release? release) {
        Object (
            device: device,
            release: release
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("application-x-firmware") {
            pixel_size = 32
        };

        var device_name_label = new Gtk.Label (device.get_name ()) {
            halign = Gtk.Align.START,
            hexpand = true
        };
        device_name_label.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var version_label = new Gtk.Label (device.get_version ()) {
            wrap = true,
            xalign = 0
        };

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (device_name_label, 1, 0);
        grid.attach (version_label, 1, 1);

        var icons = device.get_icons ();
        if (icons.data != null) {
            image.gicon = new GLib.ThemedIcon.from_names (icons.data);
        }

        if (release != null && device.get_version () != release.get_version ()) {
            is_updatable = true;

            version_label.label = "%s → %s".printf (device.get_version (), release.get_version ());

            var update_button = new Gtk.Button.with_label (_("Update")) {
                valign = Gtk.Align.CENTER
            };

            update_button.clicked.connect (() => {
                update (device, release);
            });

            grid.attach (update_button, 2, 0, 1, 2);
        }

        child = grid;
    }
}

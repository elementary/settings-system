/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class About.DriverRow : Gtk.ListBoxRow {
    public signal void install ();

    public string device { get; construct; }
    public string driver_name { get; construct; }
    public bool installed { get; construct; }

    public Gtk.CheckButton install_button { get; construct; }

    public DriverRow (string device, string driver_name, bool installed) {
        Object (device: device, driver_name: driver_name, installed: installed);
    }

    construct {
        var icon = new Gtk.Image.from_icon_name ("application-x-firmware") {
            pixel_size = 32
        };

        var label = new Gtk.Label (driver_name) {
            hexpand = true,
            xalign = 0
        };

        install_button = new Gtk.CheckButton () {
            active = installed,
            valign = CENTER
        };

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.append (icon);
        box.append (label);
        box.append (install_button);

        child = box;

        install_button.toggled.connect (() => {
            if (install_button.active) {
                install ();
            }
        });
    }
}

/*
* Copyright (c) 2017 elementary LLC. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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
*/

public class RestoreDialog : Gtk.Dialog {
    public RestoreDialog () {
        Object (resizable: false, deletable: false, skip_taskbar_hint: true);
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
        image.valign = Gtk.Align.START;

        var primary_label = new Gtk.Label (_("System Settings Will Be Restored to The Factory Defaults"));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.max_width_chars = 50;
        primary_label.wrap = true;
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("All system settings and data will be reset to the default values. Personal data, such as music and pictures, will be uneffected."));
        secondary_label.max_width_chars = 50;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.row_spacing = 6;
        grid.margin_start = grid.margin_end = 12;
        grid.attach (image, 0, 0, 1, 2);
        grid.attach (primary_label, 1, 0, 1, 1);
        grid.attach (secondary_label, 1, 1, 1, 1);

        get_content_area ().add (grid);

        var continue_button = new Gtk.Button.with_label (_("Restore Settings"));
        continue_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        add_action_widget (cancel_button, 0);
        add_action_widget (continue_button, 1);

        var action_area = get_action_area ();
        action_area.margin_end = 6;
        action_area.margin_bottom = 6;
        action_area.margin_top = 14;
    }
}

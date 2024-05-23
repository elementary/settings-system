/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
*           2015 Ivo Nunes, Akshay Shekher
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
*/

public class About.Plug : Switchboard.Plug {
    private const string OPERATING_SYSTEM = "operating-system";
    private const string HARDWARE = "hardware";
    private const string FIRMWARE = "firmware";
    private const string DRIVERS = "drivers";

    private OperatingSystemView operating_system_view;
    private Gtk.Grid main_grid;
    private Gtk.Stack stack;

    public Plug () {
        GLib.Intl.bindtextdomain (About.GETTEXT_PACKAGE, About.LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (About.GETTEXT_PACKAGE, "UTF-8");

        var settings = new Gee.TreeMap<string, string?> (null, null);
        settings.set ("about", null);
        settings.set ("about/os", OPERATING_SYSTEM);
        settings.set ("about/hardware", HARDWARE);
        settings.set ("about/firmware", FIRMWARE);
        settings.set ("about/drivers", DRIVERS);

        Object (
            category: Category.SYSTEM,
            code_name: "io.elementary.settings.system",
            display_name: _("System"),
            description: _("View operating system and hardware information"),
            icon: "application-x-firmware",
            supported_settings: settings
        );
    }

    public override Gtk.Widget get_widget () {
        if (main_grid == null) {
            operating_system_view = new OperatingSystemView ();

            var hardware_view = new HardwareView ();
            var firmware_view = new FirmwareView ();

            stack = new Gtk.Stack () {
                vexpand = true
            };
            stack.add_titled (operating_system_view, OPERATING_SYSTEM, _("Operating System"));
            stack.add_titled (hardware_view, HARDWARE, _("Hardware"));
            stack.add_titled (firmware_view, FIRMWARE, _("Firmware"));
            stack.add_titled (new DriversView (), DRIVERS, _("Drivers"));

            var stack_switcher = new Gtk.StackSwitcher () {
                stack = stack
            };

            var size_group = new Gtk.SizeGroup (HORIZONTAL);
            var child = stack_switcher.get_first_child ();
            while (child != null) {
                size_group.add_widget (child);
                child = child.get_next_sibling ();
            }

            var headerbar = new Adw.HeaderBar () {
                title_widget = stack_switcher
            };
            headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

            main_grid = new Gtk.Grid ();
            main_grid.attach (headerbar, 0, 0);
            main_grid.attach (stack, 0, 1);
        }

        return main_grid;
    }

    public override void shown () {
        operating_system_view.load_logo.begin ();
    }

    public override void hidden () {
    }

    public override void search_callback (string location) {
        switch (location) {
            case OPERATING_SYSTEM:
            case HARDWARE:
            case FIRMWARE:
            case DRIVERS:
                stack.set_visible_child_name (location);
                break;
            default:
                stack.set_visible_child_name (OPERATING_SYSTEM);
                break;
        }
    }

    // 'search' returns results like ("Keyboard → Behavior → Duration", "keyboard<sep>behavior")
    public override async Gee.TreeMap<string, string> search (string search) {
        var search_results = new Gee.TreeMap<string, string> (
            (GLib.CompareDataFunc<string>)strcmp,
            (Gee.EqualDataFunc<string>)str_equal
        );

        search_results.set ("%s → %s".printf (display_name, _("Operating System Information")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Hardware Information")), HARDWARE);
        search_results.set ("%s → %s".printf (display_name, _("Firmware")), FIRMWARE);
        search_results.set ("%s → %s".printf (display_name, _("Restore Default Settings")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Suggest Translations")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Send Feedback")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Report a Problem")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Get Support")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Updates")), OPERATING_SYSTEM);
        search_results.set ("%s → %s".printf (display_name, _("Drivers")), DRIVERS);

        return search_results;
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating System plug");
    var plug = new About.Plug ();
    return plug;
}

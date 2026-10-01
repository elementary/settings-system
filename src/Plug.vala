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
    private Adw.ToolbarView toolbarview;
    private Gtk.Stack stack;
    private GLib.Cancellable sponsors_goal_cancellable;

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
        if (toolbarview == null) {
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

            toolbarview = new Adw.ToolbarView () {
                content = stack
            };
            toolbarview.add_top_bar (headerbar);
        }

        return toolbarview;
    }

    public override void shown () {
        operating_system_view.load_logo.begin ();

        sponsors_goal_cancellable = new GLib.Cancellable ();
        operating_system_view.load_sponsors_goal (sponsors_goal_cancellable);
    }

    public override void hidden () {
        if (sponsors_goal_cancellable != null) {
            sponsors_goal_cancellable.cancel ();
        }
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

        search_results.set ("%s → %s".printf (display_name, _("Operating System")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Automatic Updates")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Basics Guide")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Get Help")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Get Involved or Sponsor Us")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Get Support")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Our Website")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Report a Problem")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Restore Default Settings")), OPERATING_SYSTEM);
        search_results.set ("%s → %s → %s".printf (display_name, _("Operating System"), _("Send Feedback")), OPERATING_SYSTEM);

        search_results.set ("%s → %s".printf (display_name, _("Hardware")), HARDWARE);
        search_results.set ("%s → %s → %s".printf (display_name, _("Hardware"), _("Device name")), HARDWARE);
        search_results.set ("%s → %s → %s".printf (display_name, _("Hardware"), _("Host name")), HARDWARE);
        // https://github.com/elementary/switchboard-plug-about/issues/219
        search_results.set ("%s → %s".printf (display_name, _("About This Device")), HARDWARE);

        search_results.set ("%s → %s".printf (display_name, _("Firmware")), FIRMWARE);
        search_results.set ("%s → %s → %s".printf (display_name, _("Firmware"), _("Restart to Firmware Setup…")), FIRMWARE);

        search_results.set ("%s → %s".printf (display_name, _("Drivers")), DRIVERS);

        return search_results;
    }

    public static bool is_sysupdate () {
        var proc_cmdline = File.new_for_path ("/proc/cmdline");
        try {
            var @is = proc_cmdline.read ();
            var dis = new DataInputStream (@is);

            var line = dis.read_line ();
            if ("mount.usr=dissect" in line) {
                return true;
            }
        } catch (Error e) {
            critical ("Couldn't detect if running Sysupdate: %s", e.message);
        }

        return false;
    }
}

public Switchboard.Plug get_plug (Module module) {
    debug ("Activating System plug");
    var plug = new About.Plug ();
    return plug;
}

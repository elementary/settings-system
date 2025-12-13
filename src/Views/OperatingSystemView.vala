/*
* Copyright 2020–2021 elementary, Inc. (https://elementary.io)
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

public class About.OperatingSystemView : Gtk.Box {
    private static string _bug_url;
    private static string bug_url {
        get {
            if (_bug_url == null) {
                _bug_url = Environment.get_os_info (GLib.OsInfoKey.BUG_REPORT_URL);

                if (_bug_url == null) {
                    _bug_url = "https://docs.elementary.io/contributor-guide/feedback/reporting-issues";
                }
            }

            return _bug_url;
        }
    }

    private static string _documentation_url;
    private static string documentation_url {
        get {
            if (_documentation_url == null) {
                _documentation_url = Environment.get_os_info (GLib.OsInfoKey.DOCUMENTATION_URL);

                if (_documentation_url == null) {
                    _documentation_url = "https://elementary.io/docs/learning-the-basics";
                }
            }

            return _documentation_url;
        }
    }

    private static string _website_url;
    private static string website_url {
        get {
            if (_website_url == null) {
                _website_url = Environment.get_os_info (GLib.OsInfoKey.HOME_URL);

                if (_website_url == null) {
                    _website_url = "https://elementary.io";
                }
            }

            return _website_url;
        }
    }


    private static string _support_url;
    private static string support_url {
        get {
            if (_support_url == null) {
                _support_url = Environment.get_os_info (GLib.OsInfoKey.SUPPORT_URL);

                if (_support_url == null) {
                    _support_url = "https://elementary.io/support";
                }
            }

            return _support_url;
        }
    }

    private uint64 download_size_remaining = 0;
    private uint64 download_size_max = 0;

    private File? logo_file;
    private Adw.Avatar? logo;
    private Gtk.StringList packages;
    private SystemUpdate? update_proxy = null;
    private SystemUpdate.CurrentState? current_state = null;
    private Gtk.Grid software_grid;
    private Gtk.Image updates_image;
    private Gtk.Label updates_title;
    private Gtk.ProgressBar update_progress_bar;
    private Gtk.Revealer update_progress_revealer;
    private Gtk.Label updates_description;
    private Gtk.Revealer details_button_revealer;
    private Gtk.Stack button_stack;
    private SponsorUsRow sponsor_us_row;

    construct {
        add_css_class ("operating-system-view");

        var style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/settings/system/OperatingSystemView.css");

        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var uts_name = Posix.utsname ();

        var logo_icon_name = Environment.get_os_info ("LOGO");
        if (logo_icon_name == "" || logo_icon_name == null) {
            logo_icon_name = "distributor-logo";
        }

        var icon = new Gtk.Image () {
            icon_name = logo_icon_name,
        };

        var logo_overlay = new Gtk.Overlay () {
            valign = START
        };

        if (Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).has_icon (logo_icon_name + "-symbolic")) {
            foreach (unowned var path in Environment.get_system_data_dirs ()) {
                var file = File.new_for_path (
                    Path.build_path (Path.DIR_SEPARATOR_S, path, "backgrounds", "elementaryos-default")
                );

                if (file.query_exists ()) {
                    logo_file = file;
                    logo = new Adw.Avatar (128, "", false) {
                        custom_image = Gdk.Paintable.empty (128, 128)
                    };

                    logo_overlay.child = logo;
                    logo_overlay.add_overlay (icon);

                    // 128 minus 3px padding on each side
                    icon.pixel_size = 128 - 6;
                    icon.add_css_class ("logo");

                    break;
                }
            }
        }

        if (icon.parent == null) {
            icon.pixel_size = 128;
            logo_overlay.child = icon;
        }

        // Intentionally not using GLib.OsInfoKey.PRETTY_NAME here because we
        // want more granular control over text formatting
        var pretty_name = "<b>%s</b> %s".printf (
            Environment.get_os_info (GLib.OsInfoKey.NAME),
            Environment.get_os_info (GLib.OsInfoKey.VERSION) ?? ""
        );

        var title = new Gtk.Label (pretty_name) {
            ellipsize = Pango.EllipsizeMode.END,
            selectable = true,
            use_markup = true,
            xalign = 0,
            hexpand = true
        };
        title.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        var kernel_version_label = new Gtk.Label ("%s %s".printf (uts_name.sysname, uts_name.release)) {
            selectable = true,
            xalign = 0,
            hexpand = true
        };
        kernel_version_label.add_css_class (Granite.CssClass.SMALL);
        kernel_version_label.add_css_class (Granite.CssClass.DIM);

        packages = new Gtk.StringList (null);

        updates_image = new Gtk.Image () {
            icon_size = LARGE
        };

        updates_title = new Gtk.Label (null) {
            hexpand = true,
            margin_end = 6,
            xalign = 0
        };

        update_progress_bar = new Gtk.ProgressBar () {
            margin_top = 3
        };

        update_progress_revealer = new Gtk.Revealer () {
            child = update_progress_bar
        };

        updates_description = new Gtk.Label (null) {
            xalign = 0,
            use_markup = true,
            wrap = true
        };
        updates_description.add_css_class (Granite.CssClass.SMALL);
        updates_description.add_css_class (Granite.CssClass.DIM);

        var progress_description_box = new Gtk.Box (VERTICAL, 3);
        progress_description_box.append (update_progress_revealer);
        progress_description_box.append (updates_description);

        var update_button = new Gtk.Button.with_label (_("Download"));
        update_button.add_css_class (Granite.CssClass.SUGGESTED);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        var refresh_button = new Gtk.Button.with_label (_("Refresh"));

        button_stack = new Gtk.Stack () {
            hhomogeneous = false,
            transition_type = CROSSFADE,
            valign = CENTER
        };
        button_stack.add_named (new Gtk.Grid (), "blank");
        button_stack.add_named (update_button, "update");
        button_stack.add_named (cancel_button, "cancel");
        button_stack.add_named (refresh_button, "refresh");

        var details_button = new Gtk.Button.with_label (_("Learn More…")) {
            halign = START,
            has_frame = false,
            margin_top = 6
        };
        details_button.add_css_class ("link");
        details_button.add_css_class (Granite.CssClass.SMALL);

        details_button_revealer = new Gtk.Revealer () {
            child = details_button
        };

        var automatic_updates_button = new Granite.SwitchModelButton (_("Automatic Updates")) {
            description = _("Updates will be automatically downloaded. They will be installed when this device is restarted.")
        };

        var updates_grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        updates_grid.attach (updates_image, 0, 0, 1, 2);
        updates_grid.attach (updates_title, 1, 0);
        updates_grid.attach (progress_description_box, 1, 1);
        updates_grid.attach (button_stack, 2, 0, 1, 2);
        updates_grid.attach (details_button_revealer, 1, 2, 2);

        var updates_list = new Gtk.ListBox () {
            margin_bottom = 12,
            margin_top = 12,
            valign = CENTER,
            show_separators = true,
            selection_mode = NONE,
            hexpand = true
        };
        updates_list.add_css_class ("boxed-list");
        updates_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        updates_list.append (updates_grid);
        updates_list.append (automatic_updates_button);

        updates_list.get_first_child ().focusable = false;
        updates_list.get_last_child ().focusable = false;

        sponsor_us_row = new SponsorUsRow ("https://github.com/sponsors/elementary");

        var sponsor_list = new Gtk.ListBox () {
            margin_bottom = 12,
            margin_top = 12,
            valign = CENTER,
            show_separators = true,
            selection_mode = NONE,
            hexpand = true
        };
        sponsor_list.add_css_class ("boxed-list");
        sponsor_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);

        sponsor_list.append (sponsor_us_row);

        var thebasics_link = new LinkRow (
            documentation_url,
            _("Basics Guide"),
            "text-x-generic-symbolic",
            "green"
        );

        var support_link = new LinkRow (
            support_url,
            _("Get Help"),
            "help-contents-symbolic",
            "blue"
        );

        var website_link = new LinkRow (
            website_url,
            _("Our Website"),
            "view-reader-symbolic",
            "slate"
        );

        var getinvolved_link = new LinkRow (
            "https://elementary.io/get-involved",
            _("Get Involved"),
            "applications-development-symbolic",
            "purple"
        );

        var links_list = new Gtk.ListBox () {
            margin_bottom = 12,
            margin_top = 12,
            valign = CENTER,
            show_separators = true,
            selection_mode = NONE,
            hexpand = true
        };
        links_list.add_css_class ("boxed-list");
        links_list.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        links_list.append (thebasics_link);
        links_list.append (support_link);
        links_list.append (website_link);
        links_list.append (getinvolved_link);

        var settings_restore_button = new Gtk.Button.with_label (_("Restore Default Settings"));

        var bug_button = new Gtk.Button.with_label (_("Send Feedback")) {
            halign = END,
            hexpand = true
        };

        var button_grid = new Gtk.Box (HORIZONTAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12
        };
        button_grid.append (settings_restore_button);
        button_grid.append (bug_button);

        software_grid = new Gtk.Grid () {
            column_spacing = 32,
            margin_top = 12,
            valign = Gtk.Align.START,
            vexpand = true,
            hexpand = true
        };
        software_grid.attach (logo_overlay, 0, 0, 1, 4);
        software_grid.attach (title, 1, 0);

        software_grid.attach (kernel_version_label, 1, 2);
        software_grid.attach (updates_list, 1, 3);
        software_grid.attach (sponsor_list, 1, 4);
        software_grid.attach (links_list, 1, 5);

        var clamp = new Adw.Clamp () {
            child = software_grid,
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12
        };

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = clamp
        };

        orientation = Gtk.Orientation.VERTICAL;
        spacing = 12;
        append (scrolled_window);
        append (button_grid);

        var system_updates_settings = new Settings ("io.elementary.settings-daemon.system-update");
        system_updates_settings.bind ("automatic-updates", automatic_updates_button, "active", DEFAULT);

        settings_restore_button.clicked.connect (settings_restore_clicked);

        bug_button.clicked.connect (() => {
            var appinfo = new GLib.DesktopAppInfo ("io.elementary.feedback.desktop");
            if (appinfo != null) {
                try {
                    appinfo.launch (null, null);
                } catch (Error e) {
                    critical (e.message);
                    launch_uri (bug_url);
                }
            } else {
                launch_uri (bug_url);
            }
        });

        sponsor_list.row_activated.connect ((row) => {
            launch_uri (((SponsorUsRow) row).uri);
        });

        links_list.row_activated.connect ((row) => {
            launch_uri (((LinkRow) row).uri);
        });

        get_upstream_release.begin ();

        Bus.get_proxy.begin<SystemUpdate> (SESSION, "io.elementary.settings-daemon", "/io/elementary/settings_daemon", 0, null, (obj, res) => {
            try {
                update_proxy = Bus.get_proxy.end (res);

                update_proxy.state_changed.connect (update_state);
                update_state.begin ();
            } catch (Error e) {
                critical ("Failed to get updates proxy");
            }
        });

        update_button.clicked.connect (() => {
            if (update_proxy != null) {
                update_proxy.update.begin ((obj, res) => {
                    try {
                        update_proxy.update.end (res);
                    } catch (Error e) {
                        critical ("Failed to update: %s", e.message);
                    }
                });
            }
        });

        cancel_button.clicked.connect (() => {
            if (update_proxy != null) {
                update_proxy.cancel.begin ((obj, res) => {
                    try {
                        update_proxy.cancel.end (res);
                    } catch (Error e) {
                        critical ("Failed to cancel update: %s", e.message);
                    }
                });
            }
        });

        refresh_button.clicked.connect (refresh_clicked);

        details_button.clicked.connect (details_clicked);
    }

    public async void load_logo () {
        if (logo == null || logo_file == null) {
            return;
        }

        try {
            var bytes = yield logo_file.load_bytes_async (null, null);
            logo.custom_image = Gdk.Texture.from_bytes (bytes);
            logo_file = null;
        } catch (Error e) {
            warning ("Failed to load logo file: %s", e.message);
        }
    }

    public void load_sponsors_goal (GLib.Cancellable cancellable) {
        if (sponsor_us_row.was_loaded) {
            return;
        }

        sponsor_us_row.get_goal_progress (cancellable);
    }

    private async void get_upstream_release () {
        // Upstream distro version (for "Built on" text)
        // FIXME: Add distro specific field to /etc/os-release and use that instead
        // Like "ELEMENTARY_UPSTREAM_DISTRO_NAME" or something
        var file = File.new_for_path ("/usr/lib/upstream-os-release");
        string? upstream_release = null;
        try {
            var dis = new DataInputStream (yield file.read_async ());
            string line;
            // Read lines until end of file (null) is reached
            while ((line = yield dis.read_line_async ()) != null) {
                if (line.has_prefix ("PRETTY_NAME")) {
                    var distrib_component = line.split ("=", 2);
                    if (distrib_component.length == 2) {
                        upstream_release = (owned) distrib_component[1];
                        if (upstream_release.has_prefix ("\"") && upstream_release.has_suffix ("\"")) {
                            upstream_release = upstream_release.substring (1, upstream_release.length - 2);
                        }

                        break;
                    }
                }
            }
        } catch (Error e) {
            warning ("Couldn't read upstream lsb-release file, assuming none");
            debug ("Error was: %s", e.message);
        }

        if (upstream_release != null) {
            var based_off = new Gtk.Label (_("Built on %s").printf (upstream_release)) {
                selectable = true,
                xalign = 0,
                hexpand = true
            };
            based_off.add_css_class (Granite.CssClass.SMALL);
            based_off.add_css_class (Granite.CssClass.DIM);
            software_grid.attach (based_off, 1, 1, 3);
        }
    }

    private async void update_state () {
        if (update_proxy == null) {
            return;
        }

        try {
            current_state = yield update_proxy.get_current_state ();
        } catch (Error e) {
            updates_image.icon_name = "dialog-error";
            updates_title.label = _("System updates not available");
            updates_description.label = _("Couldn't connect to the backend. Try logging out to resolve the issue.");
            button_stack.visible_child_name = "blank";

            critical ("Failed to get current state from Updates Backend: %s", e.message);
            return;
        }

        update_progress_revealer.reveal_child = false;
        details_button_revealer.reveal_child = current_state.state == AVAILABLE || current_state.state == ERROR;

        switch (current_state.state) {
            case UP_TO_DATE:
                updates_image.icon_name = "process-completed";
                updates_title.label = _("Up To Date");

                try {
                    var last_refresh_time = yield update_proxy.get_last_refresh_time ();
                    updates_description.label = _("Last checked %s").printf (
                        Granite.DateTime.get_relative_datetime (
                            new DateTime.from_unix_utc (last_refresh_time)
                        )
                    );
                } catch (Error e) {
                    critical ("Failed to get last refresh time from Updates Backend: %s", e.message);
                    updates_description.label = _("Last checked unknown");
                }

                button_stack.visible_child_name = "refresh";
                break;
            case CHECKING:
                updates_image.icon_name = "emblem-synchronized";
                updates_title.label = _("Checking for Updates");
                updates_description.label = current_state.message;
                button_stack.visible_child_name = "blank";
                break;
            case AVAILABLE:
                updates_image.icon_name = "software-update-available";
                updates_title.label = _("Updates Available");
                button_stack.visible_child_name = "update";

                try {
                    var details = yield update_proxy.get_update_details ();
                    updates_description.label = dngettext (
                        GETTEXT_PACKAGE,
                        "%i update available (%s)",
                        "%i updates available (%s)",
                        details.packages.length
                    ).printf (details.packages.length, GLib.format_size (details.size));

                    if (Pk.Info.SECURITY in details.info) {
                        updates_image.icon_name = "software-update-urgent";
                    }

                    packages.splice (0, packages.get_n_items (), details.packages);
                } catch (Error e) {
                    updates_description.label = _("Unable to determine number of updates");
                    warning ("Failed to get updates list from backend: %s", e.message);
                }
                break;
            case DOWNLOADING:
                update_progress_revealer.reveal_child = current_state.percentage > 0;
                update_progress_bar.fraction = current_state.percentage / 100.0;

                download_size_remaining = current_state.download_size_remaining;
                if (download_size_remaining > download_size_max) {
                    download_size_max = download_size_remaining;
                }

                updates_image.icon_name = "browser-download";
                updates_title.label = _("Downloading Updates");
                updates_description.label = "%s <span font-features='tnum'>%s</span>".printf (
                    current_state.message,
                    to_progress_text (download_size_remaining, download_size_max)
                );
                button_stack.visible_child_name = "cancel";
                break;
            case RESTART_REQUIRED:
                updates_image.icon_name = "system-reboot";
                updates_title.label = _("Restart to install pending updates");
                updates_description.label = _("Updates have been downloaded. A restart is required to finish installing them.");
                button_stack.visible_child_name = "blank";
                break;
            case ERROR:
                updates_image.icon_name = "dialog-error";
                updates_title.label = _("Failed to download updates");
                updates_description.label = _("Manually refreshing updates may resolve the issue");
                button_stack.visible_child_name = "refresh";
                break;
        }
    }

    private string to_progress_text (uint64 remain_size, uint64 total_size) {
        if (total_size == 0) {
            return "";
        }

        uint64 current_size = total_size - remain_size;
        string current_size_str = GLib.format_size (current_size);
        string total_size_str = GLib.format_size (total_size);

        return _("%s of %s").printf (current_size_str, total_size_str);
    }

    private void details_clicked () {
        if (current_state == null) {
            return;
        }

        if (current_state.state == ERROR) {
            var message_dialog = new Granite.MessageDialog (
                _("Failed to download updates"),
                _("This may have been caused by sideloaded or manually compiled software, a third-party software source, or a package manager error. Manually refreshing updates may resolve the issue."),
                new ThemedIcon ("dialog-error")
            ) {
                transient_for = (Gtk.Window) get_root (),
                modal = true
            };

            message_dialog.show_error_details (current_state.message);

            message_dialog.response.connect (message_dialog.destroy);
            message_dialog.present ();
            return;
        }

        var details_dialog = new UpdateDetailsDialog (packages) {
            transient_for = (Gtk.Window) get_root ()
        };
        details_dialog.present ();
    }

    private async void refresh_clicked () {
        if (update_proxy == null) {
            return;
        }

        try {
            yield update_proxy.check_for_updates (true, false);
        } catch (Error e) {
            critical ("Failed to check for updates: %s", e.message);
        }
    }

    private void launch_uri (string uri) {
        var uri_launcher = new Gtk.UriLauncher (uri);
        uri_launcher.launch.begin (
            ((Gtk.Application) GLib.Application.get_default ()).active_window,
            null
        );
    }

    private void settings_restore_clicked () {
        var dialog = new Granite.MessageDialog (
            _("System Settings Will Be Restored to The Factory Defaults"),
            _("All system settings and data will be reset to the default values. Personal data, such as music and pictures, will be unaffected."),
            new ThemedIcon ("preferences-system"),
            Gtk.ButtonsType.CANCEL
        ) {
            badge_icon = new ThemedIcon ("edit-clear"),
            transient_for = (Gtk.Window) this.get_root ()
        };

        var continue_button = dialog.add_button (_("Restore Settings"), Gtk.ResponseType.ACCEPT);
        continue_button.add_css_class (Granite.CssClass.DESTRUCTIVE);

        dialog.response.connect ((response) => {
            dialog.destroy ();
            if (response == Gtk.ResponseType.ACCEPT) {
                var all_schemas = get_pantheon_schemas ();

                foreach (var schema in all_schemas) {
                    reset_recursively (schema);
                }
            }
        });
        dialog.present ();
    }

    private static void reset_all_keys (GLib.Settings settings) {
        var schema = SettingsSchemaSource.get_default ().lookup (
            settings.schema_id,
            true
        );

        foreach (var key in schema.list_keys ()) {
            settings.reset (key);
        }
    }

    private static string[] get_pantheon_schemas () {
        string[] schemas = {};
        string[] pantheon_schemas = {};
        string[] prefixes = {
            "io.elementary.desktop",
            "io.elementary.dock",
            "io.elementary.onboarding",
            "io.elementary.settings",
            "io.elementary.settings-daemon",
            "io.elementary.wingpanel",
            "org.gnome.desktop",
            "org.gnome.settings-daemon",
            "org.pantheon.desktop"
        };

        var sss = SettingsSchemaSource.get_default ();

        sss.list_schemas (true, out schemas, null);

        foreach (var schema in schemas) {
            foreach (var prefix in prefixes) {
                if (schema.has_prefix (prefix)) {
                    pantheon_schemas += schema;
                }
            }
        }
        return pantheon_schemas;
    }

    private static void reset_recursively (string schema) {
        var settings = new GLib.Settings (schema);
        // change into delay mode
        // so changes take place when apply () is called
        settings.delay ();

        reset_all_keys (settings);

        foreach (var child in settings.list_children ()) {
            var child_settings = settings.get_child (child);

            reset_all_keys (child_settings);
        }
        settings.apply ();
        GLib.Settings.sync ();
    }

    private class LinkRow : Gtk.ListBoxRow {
        public string uri { get; construct; }
        public string icon_name { get; construct; }
        public string label_string { get; construct; }
        public string color { get; construct; }

        public LinkRow (string uri, string label_string, string icon_name, string color) {
            Object (
                uri: uri,
                label_string: label_string,
                icon_name: icon_name,
                color: color
            );
        }

        class construct {
            set_accessible_role (LINK);
        }

        construct {

            var image = new Gtk.Image.from_icon_name (icon_name) {
                pixel_size = 16
            };
            image.add_css_class (Granite.CssClass.ACCENT);
            image.add_css_class (color);

            var left_label = new Gtk.Label (label_string) {
                hexpand = true,
                xalign = 0
            };

            var link_image = new Gtk.Image.from_icon_name ("adw-external-link-symbolic");

            var box = new Gtk.Box (HORIZONTAL, 0);
            box.append (image);
            box.append (left_label);
            box.append (link_image);

            child = box;
            add_css_class ("link");
        }
    }

    private class SponsorUsRow : Gtk.ListBoxRow {
        public string uri { get; construct; }

        private Gtk.Label target_label;
        private Gtk.LevelBar levelbar;
        private Gtk.Revealer details_revealer;

        public SponsorUsRow (string uri) {
            Object (
                uri: uri
            );
        }

        public bool was_loaded {
            get {
                return details_revealer.reveal_child;
            }
        }

        class construct {
            set_accessible_role (LINK);
        }

        construct {
            var image = new Gtk.Image.from_icon_name ("face-heart-symbolic");
            image.add_css_class (Granite.CssClass.ACCENT);
            image.add_css_class ("pink");

            var main_label = new Gtk.Label (_("Sponsor Us")) {
                halign = START,
                hexpand = true
            };

            target_label = new Gtk.Label (null) {
                halign = START
            };
            target_label.add_css_class (Granite.CssClass.DIM);
            target_label.add_css_class (Granite.CssClass.SMALL);

            levelbar = new Gtk.LevelBar ();
            levelbar.add_css_class (Granite.STYLE_CLASS_FLAT);
            levelbar.add_css_class ("pink");

            var details_box = new Gtk.Box (VERTICAL, 0);
            details_box.append (target_label);
            details_box.append (levelbar);

            details_revealer = new Gtk.Revealer () {
                child = details_box,
                reveal_child = false
            };

            var link_image = new Gtk.Image.from_icon_name ("adw-external-link-symbolic");

            var grid = new Gtk.Grid () {
                valign = CENTER
            };
            grid.attach (image, 0, 0, 1, 2);
            grid.attach (main_label, 1, 0);
            grid.attach (details_revealer, 1, 1);
            grid.attach (link_image, 2, 0, 2, 2);

            child = grid;
            add_css_class ("link");
        }

        public void get_goal_progress (GLib.Cancellable cancellable) {
            var message = new Soup.Message ("GET", "https://elementary.io/api/sponsors_goal");
            var session = new Soup.Session ();
            session.send_and_read_async.begin (message, GLib.Priority.DEFAULT, cancellable , (obj, res) => {
                try {
                    var bytes = session.send_and_read_async.end (res);

                    var output = (string) bytes.get_data ();
                    if (output == null) {
                        return;
                    }

                    var parser = new Json.Parser ();
                    parser.load_from_data (output);

                    var root = parser.get_root ();
                    if (root.get_node_type () != OBJECT) {
                        return;
                    }

                    int64 percent_complete = root.get_object ().get_int_member ("percent");
                    double target_value = root.get_object ().get_double_member ("target");

                    var animation_target = new Adw.CallbackAnimationTarget ((val) => {
                        ///TRANSLATORS: first value is a percentage, second value is an amount in USD
                        target_label.label = _("%.0f%% towards $%'5.0f per month goal").printf (
                            Math.round (val),
                            target_value
                        );

                        levelbar.value = val / 100.0;
                    });

                    var animation = new Adw.TimedAnimation (
                        this, 0, percent_complete, 1000,
                        animation_target
                    ) {
                        easing = EASE_IN_OUT_QUAD
                    };

                    details_revealer.reveal_child = true;
                    animation.play ();
                } catch (Error e) {
                    critical (e.message);
                }
            });
        }
    }
}

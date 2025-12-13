plug_files = files(
    'Plug.vala',
    'DBus' / 'SystemUpdate.vala',
    'DBus' / 'Drivers.vala',
    'Interfaces/FirmwareClient.vala',
    'Interfaces/LoginManager.vala',
    'Utils/ARMPartDecoder.vala',
    'Views' / 'DriversView.vala',
    'Views/FirmwareReleaseView.vala',
    'Views/FirmwareView.vala',
    'Views/HardwareView.vala',
    'Views/OperatingSystemView.vala',
    'Widgets/FirmwareUpdateRow.vala',
    'Widgets' / 'DriverRow.vala',
    'Widgets' / 'UpdateDetailsDialog.vala'
)

switchboard_dep = dependency('switchboard-3')
switchboard_plugsdir = switchboard_dep.get_variable('plugsdir', pkgconfig_define: ['libdir', libdir])

config_data = configuration_data()
config_data.set('GETTEXT_PACKAGE', gettext_name)
config_data.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_vala = configure_file(
    input: 'Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

shared_module(
    meson.project_name(),
    plug_files,
    config_vala,
    css_gresource,
    dependencies: [
        fwupd_dep,
        glib_dep,
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite-7'),
        dependency('gtk4'),
        dependency('libadwaita-1'),
        dependency('libgtop-2.0'),
        dependency('libsoup-3.0'),
        dependency('packagekit-glib2'),
        dependency('gudev-1.0'),
        dependency('udisks2'),
        dependency('polkit-gobject-1'),
        dependency('json-glib-1.0'),
        appstream_dep,
        meson.get_compiler('vala').find_library('posix'),
        switchboard_dep
    ],
    install: true,
    install_dir : join_paths(switchboard_plugsdir, 'hardware')
)

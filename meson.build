project(
    'system',
    'vala', 'c',
    version: '8.2.2'
)

gettext_name = 'io.elementary.settings.' + meson.project_name()
gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
libdir = join_paths(prefix, get_option('libdir'))

glib_dep = dependency('glib-2.0', version: '>=2.64.0')
fwupd_dep = dependency('fwupd')
appstream_dep = dependency ('appstream', version: '>=0.12.10')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    '-DG_LOG_DOMAIN="@0@"'.format(gettext_name),
    language:'c'
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

vala_flags = []

if glib_dep.version().version_compare ('>=2.73.0')
    vala_flags += ['--define', 'HAS_GLIB_2_73']
endif

if fwupd_dep.version().version_compare ('>=2.0.0')
    vala_flags += ['--define', 'HAS_FWUPD_2_0']
endif

if appstream_dep.version().version_compare('>=1.0')
    vala_flags += ['--define', 'HAS_APPSTREAM_1_0']
endif

add_project_arguments(vala_flags, language: 'vala')

subdir('data')
subdir('src')
subdir('po')

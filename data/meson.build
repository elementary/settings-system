i18n.merge_file(
    input: 'system.metainfo.xml.in',
    output: 'io.elementary.settings.system.metainfo.xml',
    po_dir: meson.source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: datadir / 'metainfo',
)

css_gresource = gnome.compile_resources(
    'gresource_css',
    'gresource.xml'
)

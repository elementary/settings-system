# Switchboard About Plug
[![Translation status](https://l10n.elementary.io/widgets/switchboard/-/switchboard-plug-about/svg-badge.svg)](https://l10n.elementary.io/engage/switchboard/?utm_source=widget)

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libswitchboard-2.0-dev
* libgranite-dev
* libgtk-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install

## OEM Configuration

The Switchboard About plug can load OEM information supplied by an `oem.conf` file placed in `/etc` with the following format:

    [OEM]
    Manufacturer=System76 Inc.
    Product=Meerkat
    Version=meer1
    Logo=/etc/oem/logo.png
    URL=https://support.system76.com

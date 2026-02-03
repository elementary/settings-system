# System Settings
[![Translation status](https://l10n.elementaryos.org/widget/settings/system/svg-badge.svg)](https://l10n.elementaryos.org/engage/settings/)

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libswitchboard-3-dev
* libfwupd-dev
* libgranite-7-dev
* libgtk-4-dev
* libgtop2-dev
* libgudev-1.0-dev
* libudisks2-dev
* libadwaita-1-dev
* libappstream-dev
* libpackagekit-glib2-dev
* libpolkit-gobject-1-dev
* libsoup-3.0-dev
* meson
* valac
* switcheroo-control (at runtime)

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install

## OEM Configuration

System Settings can load OEM information supplied by an `oem.conf` file placed in `/etc` with the following format:

```ini
[OEM]
# Human-facing OEM name
Manufacturer=Star Labs

# Device name
Product=StarBook

# Human-facing model number or version, expected to be slightly de-emphasized
Version=Mk V

# Path to a logo or hardware image, expected to be shown on a light background
Logo=/etc/oem/logo.png

# Optional version of the above image expected to be shown on a dark background
# LogoDark=/etc/oem/logo-dark.png

# OEM URL, e.g. for information and/or end user support
URL=https://support.starlabs.systems/
```

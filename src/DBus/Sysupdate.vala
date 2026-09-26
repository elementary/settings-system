/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Sysupdate {
    const string TARGET_NAME = "org.freedesktop.sysupdate1.Target";
    const string HOST_PATH = "/org/freedesktop/sysupdate1/target/host";
}

[DBus (name="org.freedesktop.sysupdate1.Target")]
public interface Sysupdate.Target : Object {
    public abstract async string check_new () throws DBusError, IOError;
    public abstract async void update (string new_version, uint64 flags) throws DBusError, IOError;
}

#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
data_root=${XDG_DATA_HOME:-"$HOME/.local/share"}
mode=${1:-all}
case "$mode" in all|--launcher-only|--effect-only) ;; *) printf '%s\n' 'Usage: sh scripts/install.sh [--launcher-only|--effect-only]' >&2; exit 2 ;; esac
backup_root=
backup_package() {
    if [ -d "$1" ]; then
        if [ -z "$backup_root" ]; then
            mkdir -p "$data_root/tahoelauncher-backups"
            backup_root=$(mktemp -d "$data_root/tahoelauncher-backups/0.2.0.XXXXXX")
        fi
        cp -a "$1" "$backup_root/$2"
    fi
}
if [ "$mode" != --effect-only ]; then
    applet="$data_root/plasma/plasmoids/TahoeLauncher"
    backup_package "$applet" launcher
    mkdir -p "$applet"
    cp -a "$source_dir/contents" "$source_dir/metadata.json" "$applet/"
    printf '%s\n' "Installed Tahoe Launcher 0.2.0: $applet"
fi
if [ "$mode" != --launcher-only ]; then
    effect_dir="$data_root/kwin/effects/tahoelauncher-motion"
    backup_package "$effect_dir" effect
    mkdir -p "$effect_dir"
    cp -a "$source_dir/kwin/tahoelauncher-motion/contents" "$source_dir/kwin/tahoelauncher-motion/metadata.json" "$effect_dir/"
    printf '%s\n' "Installed Tahoe Launcher Motion: $effect_dir"
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kwinrc --group Plugins --key tahoelauncher-motionEnabled true
    else
        printf '%s\n' 'Enable Tahoe Launcher Motion in System Settings > Desktop Effects.'
    fi
    dbus_client=
    for client in qdbus6 qdbus-qt6 qdbus; do
        if command -v "$client" >/dev/null 2>&1; then dbus_client=$client; break; fi
    done
    if [ -n "$dbus_client" ]; then
        "$dbus_client" org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect tahoelauncher-motion >/dev/null 2>&1 || true
        if "$dbus_client" org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect tahoelauncher-motion; then
            printf '%s\n' 'KWin effect load requested. The launcher checks its loaded state automatically.'
        else
            printf '%s\n' 'KWin effect was not loaded in this session; enable it in Desktop Effects. Built-in motion remains available.'
        fi
    else
        printf '%s\n' 'Install the Qt 6 qdbus tool to enable automatic KWin detection; built-in motion works without it.'
    fi
fi
if [ -n "$backup_root" ]; then printf '%s\n' "Previous packages backed up to: $backup_root"; fi
printf '%s\n' 'Reload Plasma after installation: systemctl --user restart plasma-plasmashell.service'

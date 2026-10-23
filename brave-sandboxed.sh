#!/usr/bin/bash

# PID namespace should be shared or else outside link clicks won't see the running browser instance
  # --unshare-all \
  # --share-net \

# replaced by a second dbus proxy
  # --ro-bind-try /run/dbus/system_bus_socket /run/dbus/system_bus_socket \
  # --ro-bind-try "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus" \

# the temp directory stores singleton cookies. Brave uses them to identify if it's running already, so that when you
# click a link in any app, it just opens a new tab. It can't be in tmpfs because that will be created clean every time.

# Resolve runtime directory for all sockets
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

INSTANCE_ID="$RANDOM$RANDOM"
INSTANCE_DIR="$XDG_RUNTIME_DIR/.flatpak/$INSTANCE_ID"
mkdir -p "$INSTANCE_DIR"


cleanup() {
  kill "$DBUS_PROXY_PID" "$SESSION_PROXY_PID" 2>/dev/null
  rm -rf "$INSTANCE_DIR" "$FLATPAK_INFO" "$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID" "$XDG_RUNTIME_DIR/brave-session-dbus-proxy-$INSTANCE_ID"
}

trap cleanup EXIT
trap 'exit 143' INT TERM HUP   # make signals go through the EXIT trap



APP_ID=org.local.Brave-Bwrap
FLATPAK_INFO="$XDG_RUNTIME_DIR/brave-flatpak-info"
cat > "$FLATPAK_INFO" <<EOF
[Application]
name=$APP_ID

[Instance]
instance-id=$INSTANCE_ID
EOF


wait_for_socket() {
  local path="$1"
  local tries=50
  while [ ! -S "$path" ] && [ $tries -gt 0 ]; do
    sleep 0.1
    tries=$((tries - 1))
  done
  if [ ! -S "$path" ]; then
    echo "Timed out waiting for $path" >&2
    exit 1
  fi
}

# SYSTEM BUS
setpriv --pdeathsig TERM -- xdg-dbus-proxy \
  "unix:path=/run/dbus/system_bus_socket" \
  "$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID" \
  --filter \
  --see=org.freedesktop.bluez --talk=org.freedesktop.bluez \
  --see=org.freedesktop.GeoClue2 --talk=org.freedesktop.GeoClue2 \
  --see=org.freedesktop.UPower --talk=org.freedesktop.UPower \
  --see=org.freedesktop.login1 --talk=org.freedesktop.login1 \
  --see=org.freedesktop.avahi --talk=org.freedesktop.avahi &
DBUS_PROXY_PID=$!


# SESSION BUS
setpriv --pdeathsig TERM -- bwrap \
  --unshare-all --die-with-parent \
  --ro-bind /usr /usr \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --symlink usr/bin /bin \
  --bind "$XDG_RUNTIME_DIR" "$XDG_RUNTIME_DIR" \
  --ro-bind-data 3 /.flatpak-info \
  /usr/bin/xdg-dbus-proxy \
    "unix:path=$XDG_RUNTIME_DIR/bus" \
    "$XDG_RUNTIME_DIR/brave-session-dbus-proxy-$INSTANCE_ID" \
    --filter \
    --see=org.freedesktop.Notifications --talk=org.freedesktop.Notifications \
    --see=org.freedesktop.FileManager1 --talk=org.freedesktop.FileManager1 \
    --see=org.freedesktop.ScreenSaver --talk=org.freedesktop.ScreenSaver \
    --see=org.freedesktop.portal.* --talk=org.freedesktop.portal.* \
    --call=org.freedesktop.portal.*=* \
    --broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/* \
    --see=org.kde.kwalletd5 --talk=org.kde.kwalletd5 \
    --see=org.kde.kwalletd6 --talk=org.kde.kwalletd6 \
    --own=org.mpris.MediaPlayer2.brave.* \
    --see=ca.desrt.dconf --talk=ca.desrt.dconf \
    --see=org.freedesktop.secrets --talk=org.freedesktop.secrets \
    3<"$FLATPAK_INFO" &
SESSION_PROXY_PID=$!


BRAVE_TMPDIR="$HOME/.cache/BraveSoftware/Brave-Browser/sandbox-tmp"


wait_for_socket "$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID"
wait_for_socket "$XDG_RUNTIME_DIR/brave-session-dbus-proxy-$INSTANCE_ID"



# 1. Base system mounts, display/sound sockets, and GPU access
BWRAP_ARGS=(
  --unshare-user 
  --unshare-ipc 
  --unshare-uts 
  --unshare-cgroup 
  --ro-bind /usr /usr 
  # --ro-bind /lib /lib 
  # --ro-bind-try /lib64 /lib64 
  # --ro-bind /bin /bin 
  # --ro-bind /sbin /sbin 
  --symlink usr/lib /lib 
  --symlink usr/lib64 /lib64 
  --symlink usr/bin /bin 
  --symlink usr/bin /sbin 
  --ro-bind /etc /etc 
  --ro-bind-try /run/systemd/resolve /run/systemd/resolve 
  --ro-bind-try /run/NetworkManager /run/NetworkManager 
  --ro-bind-try /var/cache/fontconfig /var/cache/fontconfig
  --ro-bind /opt/brave.com /opt/brave.com 
  --proc /proc 
  --dev /dev 
  --dev-bind-try /dev/dri /dev/dri 
  --ro-bind /sys/dev/char /sys/dev/char 
  --ro-bind /sys/devices /sys/devices 
  --tmpfs /tmp 
  --bind "$BRAVE_TMPDIR" "$BRAVE_TMPDIR" 
  --setenv TMPDIR "$BRAVE_TMPDIR" 
  --dir "$XDG_RUNTIME_DIR" 
  --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" 
  --ro-bind-try "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" 
  --ro-bind-try "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0" 
  --ro-bind-try "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse" 
  --ro-bind "$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID" "$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID" 
  --setenv DBUS_SYSTEM_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/brave-dbus-proxy-$INSTANCE_ID" 
  --ro-bind "$XDG_RUNTIME_DIR/brave-session-dbus-proxy-$INSTANCE_ID" "$XDG_RUNTIME_DIR/bus" 
  --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus" 
  --setenv GTK_USE_PORTAL 1 
  # --ro-bind "$INFO" /.flatpak-info 
  # --bind "$XDG_RUNTIME_DIR/doc/by-app/$APPID" "$XDG_RUNTIME_DIR/doc" 
  --bind "$XDG_RUNTIME_DIR/doc/by-app/$APP_ID" "$XDG_RUNTIME_DIR/doc"
  --bind-try /run/cups/cups.sock /run/cups/cups.sock 
  --setenv CUPS_SERVER /run/cups/cups.sock 
  --dev-bind-try /dev/usb /dev/usb
  --dev-bind-try /dev/bus/usb /dev/bus/usb
  --dev-bind-try /dev/nvidiactl /dev/nvidiactl
  --dev-bind-try /dev/nvidia-uvm /dev/nvidia-uvm
  --dev-bind-try /dev/nvidia-modeset /dev/nvidia-modeset
  --dev-bind-try /dev/input /dev/input
)

# 2. Mount all visible (non-hidden) files and folders in $HOME
#
#  REPLACED BY THE DESKTOP PORTAL
#
# shopt -s nullglob
# for item in "$HOME"/*; do
#   BWRAP_ARGS+=(--ro-bind "$item" "$item")
# done

# 3. Bind all cameras, nvidia-related, WebHID
for item in /dev/video* /dev/nvidia* /dev/hidraw*; do
  BWRAP_ARGS+=(--dev-bind-try "$item" "$item")
done

# 4. Brave directories
BWRAP_ARGS+=(
  --setenv MESA_SHADER_CACHE_DIR "$HOME/.cache/BraveSoftware/mesa" 
  --bind "$HOME/Downloads" "$HOME/Downloads" 
  --bind "$HOME/.config/BraveSoftware" "$HOME/.config/BraveSoftware" 
  --bind "$HOME/.cache/BraveSoftware" "$HOME/.cache/BraveSoftware" 
  --bind-try "$HOME/.pki" "$HOME/.pki" 
  --ro-bind-try "$HOME/.config/dconf" "$HOME/.config/dconf" 
  --ro-bind-try "$HOME/.config/kioslaverc" "$HOME/.config/kioslaverc" 
  --ro-bind-try "$HOME/.config/mimeapps.list" "$HOME/.config/mimeapps.list" 
#  --ro-bind-try "$HOME/.local/share" "$HOME/.local/share" 
  --bind-try "$HOME/.local/share/applications" "$HOME/.local/share/applications" 
  # --bind-try "$HOME/.local/share/applications/mimeapps.list" "$HOME/.local/share/applications/mimeapps.list" 
  # --bind-try "$HOME/.local/share/applications/mimeinfo.cache" "$HOME/.local/share/applications/mimeinfo.cache" 
  --bind-try "$HOME/.local/share/icons" "$HOME/.local/share/icons" 
  --ro-bind-try "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-3.0" 
  --ro-bind-try "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-4.0" 
  --ro-bind-try "$HOME/.config/qt5ct" "$HOME/.config/qt5ct" 
  --ro-bind-try "$HOME/.config/qt6ct" "$HOME/.config/qt6ct" 
  --ro-bind-try "$HOME/.config/kdeglobals" "$HOME/.config/kdeglobals" 
  --ro-bind-try "$HOME/.local/share/fonts" "$HOME/.local/share/fonts" 
  --ro-bind-try "$HOME/.fonts" "$HOME/.fonts" 
  --bind-try "$HOME/.cache/fontconfig" "$HOME/.cache/fontconfig" 
  --bind-try /run/.heim_org.h5l.kcm-socket /run/.heim_org.h5l.kcm-socket 
  --die-with-parent 
  --new-session 
)

mkdir -p "$HOME/Downloads" "$BRAVE_TMPDIR" "$HOME/.cache/BraveSoftware/mesa" "$HOME/.config/BraveSoftware"

busctl --user call org.freedesktop.portal.Documents /org/freedesktop/portal/documents \
  org.freedesktop.portal.Documents GetMountPoint >/dev/null

# exec removed since it makes cleanup harder
# exec bwrap "${BWRAP_ARGS[@]}" /usr/bin/brave-browser-stable --password-store=kwallet6 "$@"

bwrap --info-fd 4 "${BWRAP_ARGS[@]}" /usr/bin/brave-browser-stable "$@" \
  4>"$INSTANCE_DIR/bwrapinfo.json"

rc=$?
# cleanup()

exit "$rc"

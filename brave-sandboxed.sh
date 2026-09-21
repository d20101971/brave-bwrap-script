#!/usr/bin/env bash


# trap 'kill $DBUS_PROXY_PID && kill $SESSION_PROXY_PID' EXIT
# trap 'kill "$DBUS_PROXY_PID" "$SESSION_PROXY_PID" 2>/dev/null' EXIT

# PID namespace should be shared or else outside link clicks won't see the running browser instance
  # --unshare-all \
  # --share-net \

# replaced by a second dbus proxy
  # --ro-bind-try /run/dbus/system_bus_socket /run/dbus/system_bus_socket \
  # --ro-bind-try "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus" \

# this temp directory stores singleton cookies. Brave uses them to identify if it's running already, so that when you
# click a link in any app, it just opens a new tab. It can't be in tmpfs because that will be created clean every time.


# Resolve runtime directory for audio/display sockets
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

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


setpriv --pdeathsig TERM -- xdg-dbus-proxy \
  "unix:path=/run/dbus/system_bus_socket" \
  "$XDG_RUNTIME_DIR/brave-dbus-proxy" \
  --filter \
  --see=org.freedesktop.Notifications --talk=org.freedesktop.Notifications \
  --see=org.freedesktop.FileManager1 --talk=org.freedesktop.FileManager1 \
  --see=org.freedesktop.ScreenSaver --talk=org.freedesktop.ScreenSaver \
  --see=org.freedesktop.UPower \
  --see=org.freedesktop.portal.* --talk=org.freedesktop.portal.* &
DBUS_PROXY_PID=$!

setpriv --pdeathsig TERM -- xdg-dbus-proxy \
  "unix:path=$XDG_RUNTIME_DIR/bus" \
  "$XDG_RUNTIME_DIR/brave-session-dbus-proxy" \
  --filter \
  --see=org.freedesktop.Notifications --talk=org.freedesktop.Notifications \
  --see=org.freedesktop.FileManager1 --talk=org.freedesktop.FileManager1 \
  --see=org.freedesktop.ScreenSaver --talk=org.freedesktop.ScreenSaver \
  --see=org.freedesktop.UPower \
  --see=org.freedesktop.portal.* --talk=org.freedesktop.portal.* \
  --see=org.freedesktop.secrets --talk=org.freedesktop.secrets &
SESSION_PROXY_PID=$!

BRAVE_TMPDIR="$HOME/.cache/BraveSoftware/Brave-Browser/sandbox-tmp"


wait_for_socket "$XDG_RUNTIME_DIR/brave-dbus-proxy"
wait_for_socket "$XDG_RUNTIME_DIR/brave-session-dbus-proxy"

exec bwrap \
  --unshare-user \
  --unshare-ipc \
  --unshare-uts \
  --unshare-cgroup \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind-try /lib64 /lib64 \
  --ro-bind /bin /bin \
  --ro-bind /sbin /sbin \
  --ro-bind /etc /etc \
  --ro-bind-try /run/systemd/resolve /run/systemd/resolve \
  --ro-bind /opt/brave.com /opt/brave.com \
  --proc /proc \
  --dev /dev \
  --dev-bind-try /dev/dri /dev/dri \
  --dev-bind-try /dev/video0 /dev/video0 \
  --dev-bind-try /dev/video1 /dev/video1 \
  --ro-bind /sys/dev/char /sys/dev/char \
  --ro-bind /sys/devices /sys/devices \
  --tmpfs /tmp \
  --bind "$BRAVE_TMPDIR" "$BRAVE_TMPDIR" \
  --setenv TMPDIR "$BRAVE_TMPDIR" \
  --dir "$XDG_RUNTIME_DIR" \
  --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
  --ro-bind-try "$XDG_RUNTIME_DIR/wayland-0" "$XDG_RUNTIME_DIR/wayland-0" \
  --ro-bind-try "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0" \
  --ro-bind-try "$XDG_RUNTIME_DIR/pulse" "$XDG_RUNTIME_DIR/pulse" \
  --ro-bind "$XDG_RUNTIME_DIR/brave-dbus-proxy" "$XDG_RUNTIME_DIR/brave-dbus-proxy" \
  --setenv DBUS_SYSTEM_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/brave-dbus-proxy" \
  --ro-bind "$XDG_RUNTIME_DIR/brave-session-dbus-proxy" "$XDG_RUNTIME_DIR/bus" \
  --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus" \
  --bind "$HOME/.config/BraveSoftware" "$HOME/.config/BraveSoftware" \
  --bind "$HOME/.cache/BraveSoftware" "$HOME/.cache/BraveSoftware" \
  --bind "$HOME/Downloads" "$HOME/Downloads" \
  --ro-bind-try "$HOME/.config/dconf" "$HOME/.config/dconf" \
  --ro-bind-try "$HOME/.config/mimeapps.list" "$HOME/.config/mimeapps.list" \
  --ro-bind-try "$HOME/.local/share/applications" "$HOME/.local/share/applications" \
  --die-with-parent \
  --new-session \
  /usr/bin/brave-browser-stable "$@"
# brave-bwrap-script
A half-cooked script to launch brave in a bubblewrap sandbox.
This is configured for the .rpm version of brave from their rpm repository.

I am not an expert in these things so the script is neither exhaustively secure, nor has all features debugged properly.
Extension and theme support has not yet been tested. At least some custom extensions loaded through developer mode work fine with no issues.

Video conferencing has been tested and worked every time.

Nvidia compatibility and hardware acceleration not tested. Apparmor compatibility not tested.

Currently assumes usrmerge (bin referring to usr/bin, etc)

Currently Wayland only.


# Internal sandboxing
Creation of namespaces by unprivileged users must be enabled on your system in order for this to work.
If they are not enabled, running this may or may not compromise brave's own per-tab sandboxing. Refer to brave://sandbox for info.


# Desktop portal
To be able to select or drag-and-drop any user-selected files without giving the browser itself access to those files, the script abuses a heavily vibe-coded trick to let the desktop portal know that the browser is in fact sandboxed. Do reach out if you know a cleaner way of doing this which I'm sure exists out there.


Running requires: bubblewrap, xdg-dbus-proxy, util-linux

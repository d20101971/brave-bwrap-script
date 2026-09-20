# brave-bwrap-script
A half-cooked script to launch brave in a bubblewrap sandbox.
This is configured for the .rpm version of brave obtained from their rpm repository.

I am not an expert in these things so the script is neither exhaustively secure, nor have all features debugged properly.
Extension and theme support has not yet been tested.

# Internal sandboxing
Creation of namespaces by unprivileged users must be enabled on your system in order for this to work.
If they are not enabled, running this may or may not compromise brave's own per-tab sandboxing.

Running requires: bubblewrap, xdg-dbus-proxy, util-linux

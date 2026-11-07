"""Backend of the Quickshell OS installer.

Destructive logic lives here, not in the QML: the UI only asks for a plan,
shows its summary, and passes back the confirmation token. See
specs/003-quickshell-os-installer/contracts/backend-cli.md.
"""

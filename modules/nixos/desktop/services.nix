# Supporting desktop daemons: removable-media mounting, printing, the
# bluetooth applet, input handling, the message bus, and the polkit rule
# that lets a normal user mount things.
{ pkgs, ... }:

{
  services.printing.enable = true;

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.blueman.enable = true;
  services.libinput.enable = true;

  services.dbus = {
    enable = true;
    implementation = "broker";
    packages = with pkgs; [
      blueman
      gnome-bluetooth
    ];
  };

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    // Allow users in wheel group to mount with udisks
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.eject-media" ||
           action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}

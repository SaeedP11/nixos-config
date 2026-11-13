# Audio server. PipeWire's PulseAudio bridge is what SwayOSD's volume keys
# drive (see ./media-keys.nix).
{ pkgs, ... }:

let
  # Multi-output ALSA profile set: allows analog output (laptop speakers/headphones)
  # and HDMI audio output to be exposed as separate sinks simultaneously.
  # Without this, Intel HDA treats analog and HDMI as mutually exclusive profiles,
  # hiding HDMI from the desktop's sound output selector whenever analog is selected.
  customAlsaCardProfile = pkgs.runCommand "default.conf" { } ''
    cat ${pkgs.pipewire}/share/alsa-card-profile/mixer/profile-sets/default.conf > $out
    cat >> $out << 'EOF'

[Profile output:analog-stereo+output:hdmi-stereo+input:analog-stereo]
description = Analog Stereo + Digital Stereo (HDMI) Output
output-mappings = analog-stereo hdmi-stereo
input-mappings = analog-stereo
priority = 8000
skip-probe = yes

[Profile output:analog-stereo+output:hdmi-stereo-extra1+input:analog-stereo]
description = Analog Stereo + Digital Stereo (HDMI 2) Output
output-mappings = analog-stereo hdmi-stereo-extra1
input-mappings = analog-stereo
priority = 7900
skip-probe = yes

[Profile output:analog-stereo+output:hdmi-stereo-extra2+input:analog-stereo]
description = Analog Stereo + Digital Stereo (HDMI 3) Output
output-mappings = analog-stereo hdmi-stereo-extra2
input-mappings = analog-stereo
priority = 7800
skip-probe = yes
EOF
  '';
in
{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  environment.etc."alsa-card-profile/mixer/profile-sets/default.conf".source =
    customAlsaCardProfile;
}

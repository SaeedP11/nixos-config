# Audio configuration for PipeWire / ALSA.
#
# On Intel HDA hardware, analog audio (internal speakers/headphone jack) and
# HDMI/DisplayPort audio belong to the same sound card (HDA Intel PCH).
# Upstream ALSA Card Profile (ACP) generates profiles pairing each input with
# a SINGLE output mapping, making analog and HDMI mutually exclusive profiles.
# When analog duplex is active, HDMI audio sinks do not exist in PipeWire,
# preventing the user or desktop UI (Quickshell sound panel, pavucontrol)
# from switching output to HDMI.
#
# This custom profile set appends combined output profiles that map both
# analog-stereo and hdmi-stereo simultaneously, so both sinks appear as
# separate, switchable audio outputs in the UI.
{ pkgs, ... }:

let
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
  xdg.configFile."alsa-card-profile/mixer/profile-sets/default.conf".source =
    customAlsaCardProfile;
}

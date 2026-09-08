# Audio server. PipeWire's PulseAudio bridge is what SwayOSD's volume keys
# drive (see ./media-keys.nix).
{ ... }:

{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}

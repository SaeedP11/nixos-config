{ config, ... }:

{
  hardware.cpu.intel.updateMicrocode =
    config.hardware.enableRedistributableFirmware;

  boot.kernelModules = [ "kvm-intel" ];

  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Use the "proprietary" driver (most common)
    modesetting.enable = true;

    # Power management (important for laptops!)
    powerManagement = {
      enable = true;
      # Fine-grained power management (newer GPUs)
      finegrained = false;
    };

    # Enable NVIDIA settings app
    nvidiaSettings = true;

    # Open kernel module (if you want open source components)
    open = true; # For newer GPUs (RTX 20 series and up)
  };
  
  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };
}
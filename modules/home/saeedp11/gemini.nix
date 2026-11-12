# Google Gemini / Antigravity CLI configuration and desktop notification hooks.
#
# Antigravity CLI (`agy`) looks for global lifecycle hooks in
# ~/.gemini/config/hooks.json and executes commands at key session events
# (SessionStart, PreInvocation, Stop, PostToolUse).
#
# The notification hook dispatches desktop notifications via `notify-send`
# to report session progress and completion to the desktop environment
# (Quickshell / notify-sound).
{ pkgs, ... }:

{
  home.packages = [
    pkgs.libnotify
  ];

  home.file.".gemini/config/hooks.json".text = builtins.toJSON {
    os-notifications = {
      enabled = true;
      SessionStart = [
        {
          type = "command";
          command = "~/.gemini/config/scripts/antigravity-notify.py";
          timeout = 10;
        }
      ];
      PreInvocation = [
        {
          type = "command";
          command = "~/.gemini/config/scripts/antigravity-notify.py";
          timeout = 10;
        }
      ];
      Stop = [
        {
          type = "command";
          command = "~/.gemini/config/scripts/antigravity-notify.py";
          timeout = 10;
        }
      ];
      PostToolUse = [
        {
          matcher = "*";
          hooks = [
            {
              type = "command";
              command = "~/.gemini/config/scripts/antigravity-notify.py";
              timeout = 10;
            }
          ];
        }
      ];
    };
  };

  home.file.".gemini/config/scripts/antigravity-notify.py" = {
    source = ./gemini/antigravity-notify.py;
    executable = true;
  };
}

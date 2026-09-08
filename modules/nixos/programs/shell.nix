# Interactive shell: fish + starship + the pager/editor they lean on.
{ ... }:

{
  programs.fish.enable = true;
  # programs.starship already wires itself into fish's promptInit; setting
  # promptInit here as well would concatenate (the option is types.lines)
  # and run `starship init fish` twice in every interactive shell.
  programs.starship.enable = true;

  programs.bat.enable = true;
  programs.neovim.enable = true;
}

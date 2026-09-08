# Makes everything in ../pkgs available as a normal `pkgs.<name>` attribute.
#
# `final` (not `prev`) is passed down so packages defined here can depend on
# each other and on any other overlay applied after this one.
final: prev: import ../pkgs { pkgs = final; }

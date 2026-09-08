# Time zone and internationalisation. Split out of the networking module,
# where it only ever lived by accident.
{ ... }:

{
  time.timeZone = "Asia/Tehran";
  i18n.defaultLocale = "en_US.UTF-8";
}

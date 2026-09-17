# Font packages and default font mapping (monospace/sans/serif/emoji).

{ config, lib, pkgs, ... }:

let
  # The B series -- B Nazanin, B Titr, B Lotus and the rest -- is what Persian
  # documents written on Windows ask for by name, and it is proprietary: Borna
  # Rayaneh sells those files, nixpkgs carries no attribute for them, and there
  # is no source anyone may lawfully redistribute. What ir-standard-fonts below
  # carries is the same typefaces under the names the Supreme Council of ICT
  # standardised them as, IRNazanin/IRTitr/IRLotus and so on: identical designs,
  # different family strings in the name table (verified with fc-scan).
  #
  # Identical designs are no use to a .docx that asks for "B Nazanin", because
  # matching is by family name -- fontconfig finds nothing, falls through to the
  # default sans, and the line reflows at a different width. So every B name is
  # aliased onto its IR counterpart below, which is what makes those documents
  # lay out as they were written without the licensed files being present.
  #
  # The mapping is mechanical -- drop "IR", prepend "B " -- for all but two,
  # where the standard transliterated the Persian differently.
  irFamilies = [
    "Aban"
    "Amir"
    "Arshia"
    "Badr"
    "Compset"
    "Davat"
    "Elham"
    "Entezar"
    "Farnaz"
    "Ferdosi"
    "Homa"
    "Jadid"
    "Kamran"
    "Khorasan"
    "Koodak"
    "Lotus"
    "Maryam"
    "Mashhad"
    "Mehr"
    "Mitra"
    "Momtaz"
    "Narges"
    "Naskh"
    "Nazanin"
    "Nazli"
    "Nemad"
    "Pooya"
    "Roya"
    "Shiraz"
    "Sina"
    "Tabassom"
    "Tehran"
    "Titr"
    "Yekan"
    "Zar"
    "Zeytoon"
  ];

  bSeriesAliases =
    {
      # Traffic and Yagut are spelled as they are pronounced in the IR set.
      # "B Yaghut" is listed too: both romanisations show up in real documents.
      "B Traffic" = "IRTerafik";
      "B Yagut" = "IRYakout";
      "B Yaghut" = "IRYakout";
      "B Dast Nevis" = "IRDast Nevis";
    }
    // lib.listToAttrs (map (n: lib.nameValuePair "B ${n}" "IR${n}") irFamilies);

  # binding="same" keeps the alias from outranking a real "B Nazanin" should
  # the licensed file ever be installed into ~/.local/share/fonts by hand.
  bSeriesConf = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (b: ir: ''
      <alias binding="same">
        <family>${b}</family>
        <prefer><family>${ir}</family></prefer>
      </alias>'') bSeriesAliases
  );
in
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts
      vazir-fonts
      gandom-fonts
      # The B series, under its standardised IR names -- see the alias block
      # above for why both halves are needed.
      ir-standard-fonts
      corefonts
      dejavu_fonts
      liberation_ttf
      roboto
      open-sans
      jetbrains-mono
      cascadia-code
      font-awesome
      ubuntu_font_family
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrains Mono" ];
        sansSerif = [ "Ubuntu" "Vazirmatn" ];
        serif = [ "Ubuntu" ];
        emoji = [ "Font Awesome 6" "Noto Color Emoji" ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
        ${bSeriesConf}
        </fontconfig>
      '';
    };
  };
}

#!/usr/bin/env bash
# Reports darkman's current mode as JSON for waybar's custom/theme module.
mode=$(darkman get 2>/dev/null)

if [ "$mode" = "dark" ]; then
  icon=""   # nf-fa-moon_o
  tooltip="Dark mode — click for light"
  class="dark"
else
  icon=""   # nf-fa-sun_o
  tooltip="Light mode — click for dark"
  class="light"
fi

printf '{"text":"<span size=\x27x-large\x27>%s</span>","tooltip":"%s","class":"%s"}\n' "$icon" "$tooltip" "$class"

# Quickstart: Validating Each Step

Each step is validated on its own before the next starts. Entry points are in
[contracts/ipc.md](contracts/ipc.md); data formats in [contracts/state-files.md](contracts/state-files.md).

## Common setup (every step)

```bash
nix fmt
# Nix side evaluates and the GNOME package is gone from the closure plan:
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --dry-run

# Run the working-tree shell instead of the installed one:
systemctl --user stop quickshell
export QS_EMOJI_DATA=$(systemctl --user show quickshell -p Environment | grep -o 'QS_EMOJI_DATA=[^ ]*' | cut -d= -f2)
#   (steps 2/3: also export QS_TZ_DATA / QS_UNICODE_DATA, built with the dry-run's derivations)
qs -p modules/home/saeedp11/quickshell        # watch for QML errors; Ctrl+C to stop
# in another terminal:  qs -p modules/home/saeedp11/quickshell ipc call panel toggle <name>
systemctl --user start quickshell              # when done
```

Expected for every step: no QML warnings from the new files; the panel appears within ~0.3 s
(SC-001), uses the live palette (flip with `darkman toggle`), closes on Esc and click-outside.
After `nixos-rebuild switch` for the step: `rg -n '<gnome-app>' modules` returns nothing.

## §1 Calculator

1. Mod+D, type `Calculator` → entry listed; Enter opens the panel.
2. Type `2^10` → `= 1024` without Enter (US1-1). Enter → top of history, field cleared (US1-2).
3. Ctrl+C → clipboard holds `1024` (`wl-paste`), brief confirmation (US1-3).
4. `3+*` → quiet invalid state; Enter adds nothing (US1-4). `1/0` → `undefined`. `10^20` →
   scientific notation. `1,5*2` → `3`.
5. `sqrt(2)`, then `ans*3` → `4.24264…`; click a history row → expression back in the field (US1-5).
6. ⌨ shows the keypad; close and reopen → keypad state and history kept. Restart the shell → kept.
7. In the launcher type `=12*(3+4)/7`, Enter → panel opens prefilled showing `12`.
8. Corrupt `calculator.json` by hand, restart → panel empty, `calculator.json.bad-*` exists.

## §2 Clocks

1. Right-click the bar clock → Clocks panel under it; Mod+Shift+T toggles it.
2. Start a 1 min preset and a custom 2 min timer, close the panel → bar chip shows `⏱ 0:59…`;
   at expiry a critical notification with sound appears (US2-1). Repeat with DND on → still shown.
3. Start a 5 min timer, restart the shell → it continues from its original end time (US2-4).
4. Stopwatch: start, Lap twice → two lap rows with split and total (US2-5).
5. Add an alarm 2 minutes ahead, close the panel → fires within 2 s (SC-003); Snooze → fires again
   10 min later. Weekday-only alarm is not scheduled on a weekend (check next-fire text) (US2-2).
6. Add world clocks `Asia/Tehran`, `America/New_York` → time and offset correct (compare
   `TZ=… date`). Reboot → alarms and world clocks still present and enabled (US2-3, SC-004).
7. Late: set an alarm 1 min ahead, `systemctl suspend` for 3 min → on resume it fires once,
   marked late; a repeating alarm does not fire twice.

## §3 Characters

1. Mod+Semicolon → Emoji tab; Tab → Symbols. Mod+Shift+Semicolon opens directly on Symbols.
2. Type `degree` → `°` present; Enter copies (US3-1). Type `U+20AC` → `€` first (US3-2); `2192` → `→`.
3. Category chips filter; the detail strip shows the large glyph, `RIGHTWARDS ARROW`, `U+2192`.
4. Reopen → copied characters lead the Recent row, newest first, including an emoji picked on the
   Emoji tab (US3-3). No empty-box glyphs while scrolling Box & Shapes and Letters.
5. Find and copy a character by name in < 10 s (SC-006); paste into a text field.

## §4 Calendar events

1. Right-click the bar date → calendar (or Persian, matching the chip) with Add-event open for today.
2. Add "Dentist" tomorrow 15:00, reminder 10m → dot under tomorrow in both the Gregorian and Persian
   panels (US4-1); selecting the day lists it; no day selected → it is in Upcoming.
3. Add a yearly event on today's date → shown on the same date next year (US4-2); a yearly event on
   2028-02-29 shows on 2029-02-28.
4. Add an event from the Persian panel → appears on the matching Gregorian day in the other panel.
5. Add an event 12 minutes ahead with a 10m reminder, close the panel → notification on time (US4-3).
6. Delete it → dot gone and no reminder fires (US4-4). Reboot → remaining events intact (SC-004).
7. Final (SC-005): `rg -n 'gnome-(calculator|clocks|characters|calendar)|org\.gnome\.(Calculator|clocks|Characters|Calendar)' modules`
   is empty, and none of the four are in `nix-store -qR /run/current-system`.

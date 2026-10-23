# Contract: Todo Panel UI

`modules/popouts/TodoPanel.qml`, a `PanelSurface` with a 360 px wide content column, dropped from
the bar on the right. All colours, radii, spacing, fonts and durations come from
`config/Theme.qml`, and icons come from `config/Icons.qml` (the existing `checkOff`/`checkOn` for
the row checkbox), so the panel follows the wallust palette and dark/light (FR-017).
Controls reuse `widgets/IconButton.qml`, `StyledText.qml` and `Chip.qml`. The one-line field
follows `EventList.qml`'s `Field`.

## Layout

```text
┌──────────────────────────────────────────────┐
│ To do                        3 open  ⟳ Synced│  header: title, open count, status chip
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ + Add a task…                            │ │  add field (focused on open)
│ └──────────────────────────────────────────┘ │
│                                              │
│  ○  Renew passport before the trip to        │  open tasks, newest first
│     Tabriz in December                       │  (text wraps, never cut)
│  ○  Buy milk                             ✕   │  ✕ shown on hover / keyboard focus
│  ○  Call Ali                                 │
│                                              │
│  Done · 2                       Clear done   │  done section header
│  ●  ~Pay rent~                               │  done: struck through, textDim
│  ●  ~Back up laptop~                         │
└──────────────────────────────────────────────┘
```

- **List**: a `ListView` that grows to the content and stops at 460 px, then scrolls. It is
  delegate-recycled, so 1,000 tasks open in under 300 ms (SC-007).
- **Empty list**: a centred "Nothing to do" in `textFaint` under the field.
- **Done section**: hidden when there is nothing done.
- **Status chip**:

  | State | Chip |
  |-------|------|
  | `local` | "Local only", faint, no icon |
  | `syncing` | spinning ⟳ icon |
  | `synced` | "Synced" (tooltip "2 min ago") |
  | `pending`, `offline` | "n waiting" / "Offline · n" |
  | `error` | the error text in `Theme.critical` |

  Clicking the chip runs `Todo.sync()`, except in `local`.

## Interactions

| Input | Effect |
|-------|--------|
| Type + Enter in add field | `Todo.add(text)`. The field clears and keeps focus. Ignored if whitespace-only. The row appears at once (SC-001). |
| Click ○/● or Space on a focused row | `Todo.toggle(id)` |
| Double-click the text, or Enter/F2 on a focused row | Inline edit: the text becomes a field with the text selected. Enter saves (`Todo.edit`), Esc cancels. Saving empty or whitespace-only text cancels the edit and keeps the old text (deleting is always the explicit ✕). |
| ✕, or Delete on a focused row | `Todo.remove(id)`. No confirmation; the row fades out over `Theme.durState`. |
| Clear done | `Todo.clearDone()` |
| ↓ from the add field / ↑ from the first row | Move focus between the field and the list. ↑/↓ move between rows. |
| Esc | Cancel the inline edit if one is open, else close the panel (`Panels.close()`). |
| `Panels.arg === "add"` (on open or while open) | Focus and clear the add field. |

Row height animates on insert and remove with `Theme.durState` and `Theme.easeStandard`, and
nothing else moves. While a run is in progress, rows that arrive from a sync replace their data in
place, so the list does not jump and focus is kept by `id`.

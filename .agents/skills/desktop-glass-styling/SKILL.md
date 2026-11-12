---
name: desktop-glass-styling
description: >-
  Expert guide for modern glassmorphism, translucent layers, and window aesthetics on Linux Wayland desktops.
  Covers Niri compositor window rules, shadows, corner radii, edge-lit focus rings, dynamic wallust palette
  integration, and Quickshell (QtQuick/QML) frosted glass components.
---

# Modern Glass & Wayland Desktop Styling Guide

This skill guides the design and implementation of modern glassmorphism, frosted translucent layers, and elevated window aesthetics for Linux Wayland desktop environments, specifically optimized for **Niri** (scrollable tiling compositor) and **Quickshell** (QML desktop shell).

---

## 1. Core Principles of Wayland Glassmorphism

True glassmorphism is not merely setting opacity to 50%. Poorly designed glass creates unreadable text and visual chaos. Good glass UI adheres to these physics-inspired rules:

1. **Hierarchy & Multi-stop Opacity**:
   - Active / Focused window: `0.92` - `0.94` opacity. High enough for crisp text contrast, low enough to perceive the background depth.
   - Inactive windows: `0.82` - `0.86` opacity. Dimmed slightly to naturally guide focus to the active work area.
   - Panels / Docks / Floating dialogs: `0.75` - `0.85` opacity with backdrop blur.
2. **Exemption for Media & Dense Content**:
   - Video players (`mpv`, browser video tabs), document readers (`papers`, `okular`), and image viewers must remain `1.0` opaque. Transparent video playback or reading transparent PDFs degrades usability.
3. **Edge Lighting (Specular Highlights)**:
   - Real glass reflects light at its edges. Use a delicate 1px–2px focus ring or border featuring a subtle gradient from high-opacity accent to low-opacity background tint (`relative-to="workspace-view"` in Niri).
4. **Deep Atmospheric Shadows**:
   - Glass surfaces sit elevated in 3D space. They cast soft, wide, multi-stop diffuse shadows (`softness: 35-50px`, `spread: 4-8px`, subtle vertical offset `y: 6-10px`), rather than sharp, dark drop shadows.
5. **Harmonious Corner Radii**:
   - Modern glass thrives on continuous smooth curves. Use `14px` - `18px` for general windows, `20px` - `24px` for floating bubbles or modal sheets, and `8px` - `10px` for dense code editors.

---

## 2. Niri Compositor Window Styling Patterns

### Modern Glass Preset Pattern
```kdl
layout {
    gaps 14
    focus-ring {
        width 2
        active-gradient from="@wallust-accent@" to="@wallust-inactive@" angle=135 relative-to="workspace-view"
        inactive-color "@wallust-inactive@"
    }
    border {
        off
    }
    shadow {
        on
        softness 42
        spread 4
        offset x=0 y=6
        color "#00000066"
    }
}

window-rule {
    geometry-corner-radius 16
    clip-to-geometry true
    opacity 0.93
}

window-rule {
    match is-focused=false
    opacity 0.85
}

// Media and dense document exemptions
window-rule {
    match app-id=r#"^mpv$"#
    match app-id=r#"^org\.kde\.okular$"#
    match app-id=r#"^org\.gnome\.Papers$"#
    opacity 1.0
}
```

### Brutalist Sharp Pattern
```kdl
layout {
    gaps 6
    focus-ring {
        off
    }
    border {
        width 3
        active-color "@wallust-accent@"
        inactive-color "@wallust-inactive@"
    }
    shadow {
        on
        softness 0
        spread 2
        offset x=4 y=4
        color "#000000dd"
    }
}

window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
    opacity 1.0
}
```

---

## 3. Quickshell / QML Glassmorphism Integration

When designing Quickshell panels, notifications, or dock cards to accompany Niri glass styles:
- **Surface**: Use semi-transparent dark backgrounds derived from wallust: `Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.78)`
- **Border**: Use 1px luminous edge border: `border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)`
- **Highlight**: Hover or active state introduces the wallust accent with `0.2` alpha.
- **Corner Radius**: Match Niri's active corner radius token (e.g. 14px–16px).

---

## 4. Wallust Dynamic Palette Integration

Ensure dynamic wallpaper color extraction maps cleanly to window borders:
- `@wallust-accent@`: Primary focus indicator (typically `color4 | blend(foreground)`).
- `@wallust-accent-secondary@`: Dual-accent gradient stop (`color5 | blend(foreground)`).
- `@wallust-inactive@`: Unfocused border tint (`background | blend(foreground)`).
- Always ensure active ring contrast exceeds `3.5:1` against the desktop wallpaper.

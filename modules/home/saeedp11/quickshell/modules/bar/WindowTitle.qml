// The focused window of this output's active workspace -- per output, as
// waybar's separate-outputs did -- with the app-name suffixes stripped,
// since the workspace glyph already says which app it is.
import QtQuick
import qs.config
import qs.services
import qs.widgets

StyledText {
    id: root

    required property string output
    // Set by the bar from the room left before its centre row.
    property real maxWidth: 380

    readonly property var rewrites: [[/ [—-] Mozilla Firefox$/, ""], [/ - Visual Studio Code$/, ""], [/ - Insomnia$/, ""], [/^\[Admin\].*Nekoray.*/, "Nekoray"]]

    text: rewrites.reduce((t, [re, to]) => t.replace(re, to), Niri.titleOn(output))
    width: Math.max(0, Math.min(implicitWidth, 380, maxWidth))
    leftPadding: 10
    rightPadding: 10
    font.weight: Font.Medium
}

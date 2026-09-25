// A Nerd Font glyph, given by code point so the Private Use Area survives
// any tool that would mangle a literal character.
import QtQuick
import qs

Text {
    property int code: 0

    text: code ? Greeter.glyph(code) : ""
    color: Greeter.fg
    font.family: Greeter.iconFont
    font.pointSize: 12
}

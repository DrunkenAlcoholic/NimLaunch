import std/[unittest, options]
import ../src/[utils, state]

suite "Utils tests":
  test "parseHexRgb8 valid colors":
    let c1 = parseHexRgb8("#000000")
    check isSome(c1)
    check get(c1) == Rgb(r: 0, g: 0, b: 0)

    let c2 = parseHexRgb8("#FFFFFF")
    check isSome(c2)
    check get(c2) == Rgb(r: 255, g: 255, b: 255)

    let c3 = parseHexRgb8("#1E1E2E")
    check isSome(c3)
    check get(c3) == Rgb(r: 0x1E, g: 0x1E, b: 0x2E)

  test "parseHexRgb8 invalid colors":
    check isNone(parseHexRgb8(""))
    check isNone(parseHexRgb8("FFFFFF")) # missing #
    check isNone(parseHexRgb8("#FFFFF"))  # too short
    check isNone(parseHexRgb8("#FFFFFFF")) # too long
    check isNone(parseHexRgb8("#GGGGGG")) # invalid hex characters

  test "normalizePrefix":
    check normalizePrefix(":g") == "g"
    check normalizePrefix("g:") == "g"
    check normalizePrefix(":G:") == "g"
    check normalizePrefix("  :svc:  ") == "svc"
    check normalizePrefix("sys") == "sys"

  test "deleteLastUtf8Rune removes complete code points":
    var text = "aé"
    deleteLastUtf8Rune(text)
    check text == "a"
    deleteLastUtf8Rune(text)
    check text == ""
    deleteLastUtf8Rune(text)
    check text == ""

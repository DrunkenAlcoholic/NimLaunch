import std/[unittest, options, os]
import ../src/parser

suite "Parser tests":
  test "tokenize basic args":
    let toks = tokenize("hello world")
    check toks == @["hello", "world"]

  test "tokenize quotes":
    let toks = tokenize("cmd -arg \"hello world\" 'foo bar'")
    check toks == @["cmd", "-arg", "hello world", "foo bar"]

  test "tokenize escapes":
    let toks = tokenize("cmd \"hello \\\"world\\\"\"")
    check toks == @["cmd", "hello \"world\""]

  test "stripFieldCodes":
    check stripFieldCodes("code %F") == "code "
    check stripFieldCodes("foo %u %i %c") == "foo   "
    check stripFieldCodes("100%% sure") == "100% sure"

  test "getBaseExec":
    check getBaseExec("/usr/bin/kitty --single-instance") == "kitty"
    check getBaseExec("code %F") == "code"
    check getBaseExec("env FOO=1 VAR=2 /opt/app/bin/foo %U") == "foo"
    check getBaseExec("flatpak run com.app.Name") == "com.app.Name"
    check getBaseExec("snap run app") == "app"
    check getBaseExec("sh -c 'prog --opt'") == "prog"
    check getBaseExec("sudo nano") == "nano"
    check getBaseExec("pkexec gparted") == "gparted"

  test "parseDesktopFile valid entry with actions":
    let tmp = getTempDir() / "nimlaunch_test_valid.desktop"
    writeFile(tmp, """[Desktop Entry]
Name=SuperApp
Exec=superapp %U
Icon=superapp-icon
Categories=Network;WebBrowser;
Actions=NewTab;

[Desktop Action NewTab]
Name=New Tab
Exec=superapp --new-tab
Icon=tab-new
""")
    defer:
      if fileExists(tmp): removeFile(tmp)

    let parsed = parseDesktopFile(tmp)
    check isSome(parsed)
    let app = get(parsed)
    check app.name == "SuperApp"
    check app.exec == "superapp %U"
    check app.icon == "superapp-icon"
    check app.hasIcon == true
    check app.desktopActions.len == 1
    check app.desktopActions[0].id == "NewTab"
    check app.desktopActions[0].name == "New Tab"
    check app.desktopActions[0].exec == "superapp --new-tab"

  test "parseDesktopFile exclusions":
    let tmp = getTempDir() / "nimlaunch_test_excluded.desktop"
    defer:
      if fileExists(tmp): removeFile(tmp)

    # NoDisplay=true
    writeFile(tmp, "[Desktop Entry]\nName=HiddenApp\nExec=hiddenapp\nNoDisplay=true\n")
    check isNone(parseDesktopFile(tmp))

    # Terminal=true
    writeFile(tmp, "[Desktop Entry]\nName=TerminalApp\nExec=htop\nTerminal=true\n")
    check isNone(parseDesktopFile(tmp))

    # Settings category
    writeFile(tmp, "[Desktop Entry]\nName=SettingsApp\nExec=gnome-control-center\nCategories=GNOME;GTK;Settings;\n")
    check isNone(parseDesktopFile(tmp))


import std/[unittest, os, strutils, tables]
import ../src/[state, settings, app_core]

suite "Configuration and Shortcuts tests":
  test "load shortcuts from TOML table":
    let examplePath = currentSourcePath().parentDir.parentDir / "examples" / "nimlaunch.toml"
    check fileExists(examplePath)

    ctx.configOverridePath = examplePath
    initLauncherConfig()
    check ctx.shortcuts.len > 0

    var foundGoogle = false
    var foundSvcStatus = false
    for sc in ctx.shortcuts:
      if sc.prefix == "g":
        foundGoogle = true
        check sc.mode == smUrl
        check sc.base.contains("google.com")
      elif sc.group == "svc" and sc.label.contains("systemctl status"):
        foundSvcStatus = true
        check sc.mode == smShell
    check foundGoogle
    check foundSvcStatus

  test "parseCommand routing":
    let (cmdG, restG, idxG, _) = parseCommand(":g nim language")
    check cmdG == ckShortcut
    check restG == "nim language"
    check idxG >= 0
    check ctx.shortcuts[idxG].prefix == "g"

    let (cmdSvc, restSvc, _, groupSvc) = parseCommand(":svc ssh")
    check cmdSvc == ckGroup
    check groupSvc == "svc"
    check restSvc == "ssh"

    let (cmdSearch, restSearch, _, _) = parseCommand(":s myfile.nim")
    check cmdSearch == ckSearch
    check restSearch == "myfile.nim"

    let (cmdRun, restRun, _, _) = parseCommand("!ls -la")
    check cmdRun == ckRun
    check restRun == "ls -la"

    let (cmdNone, restNone, _, _) = parseCommand("firefox")
    check cmdNone == ckNone
    check restNone == "firefox"

  test "group query modes":
    check ctx.groupQueryModes.hasKey("sys")
    check ctx.groupQueryModes["sys"] == gqmFilter

    check ctx.groupQueryModes.hasKey("svc")
    check ctx.groupQueryModes["svc"] == gqmPass

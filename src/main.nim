import std/[os, strutils, syncio]
import sdl3
import ./[state, app_core, gui, utils, settings, search, input, apps_cache, theme_session]

const Version = "0.10.3"

proc configureStartupMode() =
  for i in 1 .. paramCount():
    let arg = paramStr(i)
    if arg == "--version" or arg == "-v":
      echo "NimLaunch v", Version
      quit 0
    elif arg == "--list-themes":
      listThemesMode = true
    elif arg == "--dry-run":
      dryRunMode = true
    elif arg == "--verbose":
      verboseMode = true
    elif arg == "--dmenu":
      dmenuMode = true

proc loadDmenuInput() =
  let raw = stdin.readAll()
  dmenuItems.setLen(0)
  for line in raw.splitLines():
    var item = line
    if item.len > 0 and item[^1] == '\r':
      item.setLen(item.len - 1)
    if item.len > 0:
      var label = item
      var iconName = ""
      let nullPos = item.find('\0')
      if nullPos != -1:
        label = item[0 ..< nullPos]
        let remainder = item[nullPos + 1 .. ^1]
        let prefix = "icon\x1f"
        if remainder.startsWith(prefix):
          iconName = remainder[prefix.len .. ^1]
      dmenuItems.add DmenuItem(label: label, iconName: iconName)

proc processSearchDebounce(): bool =
  ## Debounce wake-up: if we're in s: search, rebuild after idle.
  let (cmd, rest, _, _) = parseCommand(inputText)
  if cmd != ckSearch:
    return false
  let now = gui.nowMs()
  let sinceEdit = now - lastInputChangeMs
  if rest.len >= 2 and sinceEdit >= SearchDebounceMs and
     lastSearchBuildMs < lastInputChangeMs:
    lastSearchBuildMs = now
    buildActions()
    return true
  false

proc main*() =
  let startupTimeMs = gui.nowMs()
  configureStartupMode()

  if not dmenuMode and not ensureSingleInstance():
    echo "NimLaunch is already running."
    quit 0
  initLauncherConfig()

  if listThemesMode:
    for th in themeList:
      echo th.name
    quit 0
  if dmenuMode:
    loadDmenuInput()
  else:
    loadApplications()
    loadRecent()
    loadUsage()
  buildActions()

  resetVimState()

  gui.initGui()
  updateParsedColors(config)
  gui.updateGuiColors()
  gui.redrawWindow()

  var suppressNextTextInput = false
  var ev: Event
  var focus: FocusState
  focus.startMs = gui.nowMs()
  focus.lastGainMs = focus.startMs

  while not shouldExit:
    while pollEvent(ev):
      case ev.`type`
      of EVENT_QUIT:
        shouldExit = true
      of EVENT_WINDOW_SHOWN, EVENT_WINDOW_HIDDEN, EVENT_WINDOW_EXPOSED,
          EVENT_WINDOW_MOVED, EVENT_WINDOW_RESIZED, EVENT_WINDOW_PIXEL_SIZE_CHANGED,
          EVENT_WINDOW_MINIMIZED, EVENT_WINDOW_FOCUS_GAINED, EVENT_WINDOW_FOCUS_LOST,
          EVENT_WINDOW_DISPLAY_CHANGED, EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
        if handleWindowEvent(ev, focus):
          gui.redrawWindow()
      of EVENT_KEY_DOWN:
        if handleKeyDown(ev, focus, suppressNextTextInput):
          gui.redrawWindow()
      of EVENT_TEXT_INPUT:
        if handleTextInput(ev, focus, suppressNextTextInput):
          gui.redrawWindow()
      of EVENT_TEXT_EDITING:
        if handleTextEditing(ev):
          gui.redrawWindow()
      of EVENT_TEXT_EDITING_CANDIDATES:
        if handleTextEditingCandidates(ev):
          gui.redrawWindow()
      else:
        discard

    if shouldExit: break

    if processSearchDebounce():
      gui.redrawWindow()
      continue

    delay(config.pollIntervalMs.uint32)

  if themePreviewActive:
    endThemePreviewSession(false)

  if verboseMode:
    let uptimeMs = gui.nowMs() - startupTimeMs
    stderr.writeLine "NimLaunch shutting down."
    stderr.writeLine "  Uptime: " & $uptimeMs & " ms"
    stderr.writeLine "  Apps parsed: " & $allApps.len
    stderr.writeLine "  Icons cached: " & $getIconCacheSize()

  gui.shutdownGui()
  if dmenuMode:
    if dmenuAccepted:
      stdout.write(dmenuOutput & "\n")
      quit 0
    quit 1

when isMainModule:
  main()

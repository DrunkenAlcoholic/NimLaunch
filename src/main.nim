import sdl3
import ./[state, app_core, gui, utils, settings, search, input, apps_cache, theme_session]

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
  if not ensureSingleInstance():
    echo "NimLaunch is already running."
    quit 0
  initLauncherConfig()
  loadApplications()
  loadRecent()
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
        discard handleTextEditing(ev)
      of EVENT_TEXT_EDITING_CANDIDATES:
        discard handleTextEditingCandidates(ev)
      else:
        discard

    if shouldExit: break

    if processSearchDebounce():
      gui.redrawWindow()
      continue

    delay(10)

  if themePreviewActive:
    endThemePreviewSession(false)

  gui.shutdownGui()

when isMainModule:
  main()

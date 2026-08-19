## app_core.nim — NimLaunch application logic for search, ctx.actions, and launch flow.

import std/[os, strutils, tables, sets, uri,
            algorithm, heapqueue, exitprocs]
when defined(posix):
  import posix
import ./[state, parser, gui, utils, settings, paths, fuzzy, proc_utils, search,
    theme_session, config_actions]

when defined(posix):
  when not declared(flock):
    proc flock(fd: cint; operation: cint): cint {.importc,
        header: "<sys/file.h>".}

# ── Module-local globals ────────────────────────────────────────────────
const
  DefaultAppSearchCap = 200
  iconAliases = {
    "code": "visual-studio-code",
    "codium": "vscodium",
    "nvim": "nvim",
    "neovide": "nvim",
    "kitty": "kitty",
    "wezterm": "com.github.wez.wezterm",
    "alacritty": "Alacritty",
    "gnome-terminal": "utilities-terminal",
    "foot": "terminal",
    "firefox": "firefox",
    "chromium": "chromium",
    "google-chrome": "google-chrome",
    "brave-browser": "brave-browser",
    "opera": "opera",
    "vivaldi": "vivaldi",
    "edge": "microsoft-edge",
    "discord": "discord",
    "steam": "steam",
    "lutris": "lutris",
    "spotify": "spotify",
    "vlc": "vlc",
    "mpv": "mpv",
    "nautilus": "org.gnome.Nautilus",
    "dolphin": "dolphin",
    "thunar": "Thunar",
    "pcmanfm": "system-file-manager",
    "gimp": "gimp",
    "inkscape": "inkscape"
  }.toTable

var
  lockFilePath = ""
when defined(posix):
  var lockFd: cint = -1

proc pickIcon(app: DesktopApp): string =
  ## Choose an icon name for a DesktopApp, using explicit icon, alias, or base exec.
  if app.icon.len > 0:
    return app.icon
  let base = parser.getBaseExec(app.exec).toLowerAscii
  if iconAliases.hasKey(base):
    return iconAliases[base]
  base

proc pickDesktopActionIcon(app: DesktopApp; action: DesktopEntryAction): string =
  if action.icon.len > 0:
    return action.icon
  pickIcon(app)

proc addDesktopActionRows(rows: var seq[Action]; app: DesktopApp) =
  for desktopAction in app.desktopActions:
    let iconName = if ctx.config.showIcons: pickDesktopActionIcon(app, desktopAction) else: ""
    rows.add Action(
      kind: akAppAction,
      label: app.name & " · " & desktopAction.name,
      exec: desktopAction.exec,
      appData: app,
      iconName: iconName
    )

# ── Single-instance helpers ────────────────────────────────────────────
when defined(posix):
  const
    LOCK_EX = 2.cint
    LOCK_NB = 4.cint
    LOCK_UN = 8.cint

  proc releaseSingleInstanceLock() =
    if lockFd >= 0:
      discard flock(lockFd, LOCK_UN)
      discard close(lockFd)
      lockFd = -1
    if lockFilePath.len > 0 and fileExists(lockFilePath):
      try:
        removeFile(lockFilePath)
      except CatchableError:
        discard

  proc ensureSingleInstance*(): bool =
    ## Obtain an exclusive advisory lock; return false if another instance owns it.
    let cacheDirPath = cacheDir()
    try:
      createDir(cacheDirPath)
    except CatchableError:
      discard
    lockFilePath = cacheDirPath / "nimlaunch.lock"

    let fd = open(lockFilePath.cstring, O_RDWR or O_CREAT, 0o664)
    if fd < 0:
      echo "NimLaunch warning: unable to open lock file at ", lockFilePath
      return true

    if flock(fd, LOCK_EX or LOCK_NB) != 0:
      discard close(fd)
      return false

    discard ftruncate(fd, 0)
    discard lseek(fd, 0, 0)
    let pidStr = $getCurrentProcessId() & "\n"
    discard write(fd, pidStr.cstring, pidStr.len.cint)

    lockFd = fd
    addExitProc(releaseSingleInstanceLock)
    true
else:
  proc releaseSingleInstanceLock() =
    if lockFilePath.len > 0 and fileExists(lockFilePath):
      try:
        removeFile(lockFilePath)
      except CatchableError:
        discard

  proc ensureSingleInstance*(): bool =
    ## Basic file sentinel fallback for non-POSIX targets.
    let cacheDirPath = cacheDir()
    try:
      createDir(cacheDirPath)
    except CatchableError:
      discard
    lockFilePath = cacheDirPath / "nimlaunch.lock"

    if fileExists(lockFilePath):
      return false

    try:
      writeFile(lockFilePath, $getCurrentProcessId())
      addExitProc(releaseSingleInstanceLock)
    except CatchableError:
      discard
    true

# ── Command parsing / ctx.actions helpers ───────────────────────────────────
type CmdKind* = enum
  ## Recognised input prefixes.
  ckNone,     # no special prefix
  ckTheme,    # `t:`
  ckConfig,   # `c:`
  ckSearch,   # `s:` fast file search
  ckGroup,    # user-defined group prefix
  ckShortcut, # custom ctx.shortcuts (e.g. :g, :wiki)
  ckRun,      # raw `r:` command
  ckQuit      # `:q` or `:quit` to exit

proc takePrefix(input, pfx: string; rest: var string): bool =
  ## Consume a command prefix and return the remainder (trimmed).
  let n = pfx.len
  if input.len >= n and input[0..n-1] == pfx:
    if input.len == n:
      rest = ""; return true
    if input.len > n:
      if input[n] == ' ':
        rest = input[n+1 .. ^1].strip(); return true
      rest = input[n .. ^1].strip(); return true
  false

proc parseCommand*(inputText: string): (CmdKind, string, int, string) =
  ## Parse *ctx.inputText* and return the command kind, remainder, shortcut index, and group name.
  if ctx.inputText.len > 0 and ctx.inputText[0] == ':':
    var body = ctx.inputText[1 .. ^1]
    var rest = ""
    let sep = body.find({' ', '\t'})
    var keyword = body
    if sep >= 0:
      keyword = body[0 ..< sep]
      rest = body[sep + 1 .. ^1].strip()
    else:
      rest = ""
    let norm = normalizePrefix(keyword)
    case norm
    of "s": return (ckSearch, rest, -1, "")
    of "c": return (ckConfig, rest, -1, "")
    of "t": return (ckTheme, rest, -1, "")
    of "r": return (ckRun, rest, -1, "")
    of "q", "quit": return (ckQuit, rest, -1, "")
    else:
      for i, sc in ctx.shortcuts:
        if sc.prefix.len == 0:
          continue
        if norm == sc.prefix:
          return (ckShortcut, rest, i, "")
      if ctx.groupQueryModes.hasKey(norm):
        return (ckGroup, rest, -1, norm)
      return (ckNone, ctx.inputText, -1, "")

  var rest: string
  if takePrefix(ctx.inputText, "!", rest):
    return (ckRun, rest.strip(), -1, "")
  (ckNone, ctx.inputText, -1, "")

# ── Applications discovery (.desktop) ───────────────────────────────────
proc substituteQuery(pattern, value: string): string =
  ## Replace `{query}` placeholder or append value if absent.
  if pattern.contains("{query}"):
    result = pattern.replace("{query}", value)
  else:
    result = pattern & value

proc shortcutLabel(sc: Shortcut; query: string): string =
  ## Compose UI label for a shortcut result. Preserve user-provided spacing
  ## but inject a single space when the label doesn't already end with one.
  if sc.label.len == 0:
    return query

  if query.len == 0:
    return sc.label

  result = sc.label
  let last = sc.label[^1]
  if not last.isSpaceAscii():
    result.add ' '
  result.add query

proc shortcutExec(sc: Shortcut; query: string): string =
  ## Build the execution string for a shortcut before mode-specific handling.
  case sc.mode
  of smUrl:
    result = substituteQuery(sc.base, encodeUrl(query))
  of smShell:
    result = substituteQuery(sc.base, quoteShell(query))
  of smFile:
    result = substituteQuery(sc.base, query)

proc buildThemeActions(rest: string; defaultIndex: var int): seq[Action] =
  ## Build theme selection rows and remember the currently active index.
  defaultIndex = 0
  let ql = rest.toLowerAscii
  let currentThemeLower = ctx.config.themeName.toLowerAscii
  var idx = 0
  for th in ctx.themeList:
    if ql.len == 0 or th.name.toLowerAscii.contains(ql):
      result.add Action(kind: akTheme, label: th.name, exec: th.name, iconName: "")
      if th.name.toLowerAscii == currentThemeLower:
        defaultIndex = idx
      inc idx
  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No matching themes", exec: "")

proc buildConfigActions(rest: string): seq[Action] =
  ## Build configuration file results under ~/.config.
  ensureConfigFilesLoaded()
  let ql = rest.toLowerAscii
  for entry in ctx.configFilesCache:
    if ql.len == 0 or entry.name.toLowerAscii.contains(ql):
      result.add Action(kind: akConfig, label: entry.name, exec: entry.exec, iconName: "")
  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No matches", exec: "")

proc buildShortcutActions(rest: string; shortcutIdx: int): seq[Action] =
  ## Resolve a configured shortcut against the current query.
  if shortcutIdx < 0 or shortcutIdx >= ctx.shortcuts.len:
    return @[Action(kind: akPlaceholder, label: "Shortcut not found", exec: "")]
  let sc = ctx.shortcuts[shortcutIdx]
  @[Action(kind: akShortcut,
           label: shortcutLabel(sc, rest),
           exec: shortcutExec(sc, rest),
           iconName: "",
           shortcutMode: sc.mode,
           powerMode: sc.runMode,
           stayOpen: sc.stayOpen)]

proc groupQueryMode(name: string): GroupQueryMode =
  if ctx.groupQueryModes.hasKey(name): ctx.groupQueryModes[name] else: gqmFilter

proc buildGroupActions(groupName, rest: string): seq[Action] =
  ## Build grouped ctx.actions. Query mode controls pass-through vs filter.
  var entries: seq[Shortcut] = @[]
  for sc in ctx.shortcuts:
    if sc.group == groupName:
      entries.add sc
  if entries.len == 0:
    return @[Action(kind: akPlaceholder,
                    label: "No ctx.actions in group",
                    exec: "")]

  if groupQueryMode(groupName) == gqmPass:
    if rest.len == 0:
      return @[Action(kind: akPlaceholder, label: "Enter a query", exec: "")]
    for sc in entries:
      let label = shortcutLabel(sc, rest)
      let exec = shortcutExec(sc, rest)
      let safeLabel = if label.len > 0: label else: sc.base
      result.add Action(kind: akShortcut,
                        label: safeLabel,
                        exec: exec,
                        iconName: "",
                        shortcutMode: sc.mode,
                        powerMode: sc.runMode,
                        stayOpen: sc.stayOpen)
    if result.len == 0:
      result.add Action(kind: akPlaceholder, label: "No matches", exec: "")
    return

  let ql = rest.strip().toLowerAscii
  for sc in entries:
    let label = if sc.label.len > 0: sc.label else: sc.base
    if ql.len == 0 or label.toLowerAscii.contains(ql):
      result.add Action(kind: akShortcut,
                        label: label,
                        exec: shortcutExec(sc, ""),
                        iconName: "",
                        shortcutMode: sc.mode,
                        powerMode: sc.runMode,
                        stayOpen: sc.stayOpen)
  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No matches", exec: "")

proc buildRunActions(rest: string): seq[Action] =
  ## Return metadata for :r or ! commands.
  if rest.len == 0:
    return @[Action(kind: akPlaceholder, label: "Run: enter a command", exec: "")]
  @[Action(kind: akRun, label: "Run: " & rest, exec: rest, iconName: "")]

proc pathDepth(path: string): int =
  for ch in path:
    if ch == '/':
      inc result

proc scoreSearchCandidate(query: string; queryLower: string; fileName: string;
                          path: string; homeDir: string; homeDepth: int): int =
  let fileLower = fileName.toLowerAscii
  var score = scoreMatch(query, queryLower, fileName, fileLower, path, homeDir)
  if fileLower == queryLower:
    score += 12_000
  elif fileLower.startsWith(queryLower):
    score += 4_000

  if path.startsWith(homeDir & "/"):
    score += 800
    let directory = path[0 ..< max(0, path.len - fileName.len)]
    let relativeDepth = max(0, pathDepth(directory) - homeDepth)
    score -= min(relativeDepth, 10) * 200
    if directory == homeDir or directory == (homeDir & "/"):
      score += 5_000
      if fileName.len > 0 and fileName[0] == '.':
        score += 4_000
  else:
    score -= 2_000

  score

proc buildSearchActions(rest: string): seq[Action] =
  ## File search via :s — respects debounce and reuses cached results.
  let sinceEdit = gui.nowMs() - ctx.lastInputChangeMs
  if rest.len < 2 or sinceEdit < SearchDebounceMs:
    return @[Action(kind: akPlaceholder, label: "Searching…", exec: "")]

  gui.notifyStatus("Searching…", 1200)
  let restLower = rest.toLowerAscii

  var paths: seq[string]
  if lastSearchQuery.len > 0 and rest.len >= lastSearchQuery.len and
     rest.startsWith(lastSearchQuery) and lastSearchResults.len > 0 and
     lastSearchResults.len < SearchFdCap:
    paths = lastSearchResults
  elif getCachedSearchResults(rest, paths):
    discard
  else:
    paths = scanFilesFast(rest)
    cacheSearchResults(rest, paths)

  lastSearchQuery = rest
  lastSearchResults = paths

  let homeDir = getHomeDir()
  let homeDepth = pathDepth(homeDir)
  var topScores = initHeapQueue[(int, string)]()
  let limit = ctx.config.maxVisibleItems
  let queryLower = restLower

  for idx in 0 ..< paths.len:
    let path = paths[idx]
    let fileName = path.extractFilename
    let score = scoreSearchCandidate(rest, queryLower, fileName, path, homeDir, homeDepth)

    if score > -1_000_000:
      push(topScores, (score, path))
      if topScores.len > max(limit, 200): discard pop(topScores)

  var ranked: seq[(int, string)] = @[]
  while topScores.len > 0: ranked.add pop(topScores)
  ranked.reverse()

  let showCap = max(limit, min(40, SearchShowCap))
  for i, it in ranked:
    if i >= showCap: break
    let path = it[1]
    let fileName = path.extractFilename
    let directory = os.parentDir(path)
    let pretty = fileName & " — " & shortenPath(directory)
    result.add Action(kind: akFile, label: pretty, exec: path, iconName: "")

  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No matches", exec: "")

proc buildDmenuActions(rest: string): seq[Action] =
  ## Dmenu mode — filter stdin-provided lines and return the raw selection.
  let query = rest
  if query.len == 0:
    for item in ctx.dmenuItems:
      result.add Action(kind: akDmenu, label: item.label, exec: item.label, iconName: item.iconName)
  else:
    var top = initHeapQueue[(int, int)]()
    let limit = max(250, ctx.config.maxVisibleItems * 8)
    let queryLower = query.toLowerAscii
    for i, item in ctx.dmenuItems:
      let s = scoreMatch(query, queryLower, item.label, item.labelLower, item.label, "")
      if s > -1_000_000:
        push(top, (s, i))
        if top.len > limit:
          discard pop(top)
    var ranked: seq[(int, int)] = @[]
    while top.len > 0:
      ranked.add pop(top)
    # Using sort here instead of reverse because of the secondary key (item index)
    ranked.sort(proc(a, b: (int, int)): int =
      result = cmp(b[0], a[0])
      if result == 0:
        result = cmp(a[1], b[1])
    )
    for item in ranked:
      let dItem = ctx.dmenuItems[item[1]]
      result.add Action(kind: akDmenu, label: dItem.label, exec: dItem.label, iconName: dItem.iconName)

  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No matches", exec: "")

proc buildDefaultActions(rest: string; defaultIndex: var int): seq[Action] =
  ## Default launcher view — MRU when empty, fuzzy search otherwise.
  defaultIndex = 0
  if rest.len == 0:
    var index = initTable[string, DesktopApp](ctx.allApps.len * 2)
    for app in ctx.allApps:
      index[app.name] = app

    var seen = initHashSet[string]()
    for name in ctx.recentApps:
      if index.hasKey(name):
        let app = index[name]
        let iconName = if ctx.config.showIcons: pickIcon(app) else: ""
        result.add Action(kind: akApp, label: app.name, exec: app.exec,
            appData: app, iconName: iconName)
        seen.incl name

    var remaining: seq[DesktopApp] = @[]
    for app in ctx.allApps:
      if not seen.contains(app.name):
        remaining.add app
    remaining.sort(proc(a, b: DesktopApp): int =
      result = cmp(usageBoost(b.name), usageBoost(a.name))
      if result == 0:
        result = cmpIgnoreCase(a.name, b.name)
    )
    for app in remaining:
      let iconName = if ctx.config.showIcons: pickIcon(app) else: ""
      result.add Action(kind: akApp, label: app.name, exec: app.exec,
          appData: app, iconName: iconName)
  else:
    var top = initHeapQueue[(int, int)]()
    let limit = max(DefaultAppSearchCap, ctx.config.maxVisibleItems * 8)
    let queryLower = rest.toLowerAscii
    for i, app in ctx.allApps:
      let s = scoreMatch(rest, queryLower, app.name, app.nameLower, app.name, "")
      if s > -1_000_000:
        push(top, (s + recentBoost(app.name) + usageBoost(app.name), i))
        if top.len > limit: discard pop(top)
    var ranked: seq[(int, int)] = @[]
    while top.len > 0: ranked.add pop(top)
    ranked.sort(proc(a, b: (int, int)): int =
      result = cmp(b[0], a[0])
      if result == 0: result = cmpIgnoreCase(ctx.allApps[a[1]].name, ctx.allApps[b[1]].name)
    )
    for item in ranked:
      let app = ctx.allApps[item[1]]
      let iconName = if ctx.config.showIcons: pickIcon(app) else: ""
      result.add Action(kind: akApp, label: app.name, exec: app.exec,
          appData: app, iconName: iconName)
      let appLower = app.nameLower
      if app.desktopActions.len > 0 and (appLower == queryLower or
          appLower.startsWith(queryLower)):
        addDesktopActionRows(result, app)

  if result.len == 0:
    result.add Action(kind: akPlaceholder, label: "No applications found", exec: "")

proc updateDisplayRows(cmd: CmdKind; highlightQuery: string;
    defaultIndex: int) =
  ## Sync ctx.filteredApps/ctx.matchSpans and maintain selection/preview state.
  ctx.filteredApps.setLen(0)
  ctx.matchSpans.setLen(0)

  for act in ctx.actions:
    ctx.filteredApps.add DisplayRow(text: act.label, iconName: act.iconName)
    if highlightQuery.len == 0:
      ctx.matchSpans.add @[]
    else:
      case act.kind
      of akRun:
        const prefix = "Run: "
        let off = if act.label.len >= prefix.len: prefix.len else: 0
        let seg = if off < act.label.len: act.label[off .. ^1] else: ""
        var spansAbs: seq[(int, int)] = @[]
        for (s, l) in subseqSpans(highlightQuery, seg): spansAbs.add (off + s, l)
        ctx.matchSpans.add spansAbs
      of akPlaceholder:
        ctx.matchSpans.add @[]
      else:
        ctx.matchSpans.add subseqSpans(highlightQuery, act.label)

  if ctx.actions.len == 0:
    if cmd == ckTheme:
      endThemePreviewSession(false)
    else:
      ctx.selectedIndex = 0
      ctx.viewOffset = 0
  else:
    let maxIndex = ctx.actions.len - 1
    var clamped = min(defaultIndex, maxIndex)
    if cmd == ckTheme and defaultIndex == 0:
      clamped = min(ctx.selectedIndex, maxIndex)
    ctx.selectedIndex = clamped
    let visible = max(1, ctx.config.maxVisibleItems)
    if clamped >= visible:
      ctx.viewOffset = clamped - visible + 1
    else:
      ctx.viewOffset = 0

    if cmd == ckTheme:
      if ctx.actions.len > 0 and ctx.actions[ctx.selectedIndex].kind == akTheme:
        updateThemePreview(cmd == ckTheme, ctx.actions, ctx.selectedIndex)
      else:
        endThemePreviewSession(false)
    else:
      endThemePreviewSession(false)

# ── Build ctx.actions & mirror to ctx.filteredApps ─────────────────────────────
proc buildActions*() =
  ## Populate `ctx.actions` based on `ctx.inputText`; mirror to GUI lists/spans.
  if ctx.dmenuMode:
    ctx.actions = buildDmenuActions(ctx.inputText)
    updateDisplayRows(ckNone, ctx.inputText, 0)
    return

  let (cmd, rest, shortcutIdx, groupName) = parseCommand(ctx.inputText)
  var defaultIndex = 0
  var nextActions: seq[Action] = @[]

  case cmd
  of ckTheme:
    beginThemePreviewSession()
    nextActions = buildThemeActions(rest, defaultIndex)
  of ckConfig:
    nextActions = buildConfigActions(rest)
  of ckShortcut:
    nextActions = buildShortcutActions(rest, shortcutIdx)
  of ckGroup:
    nextActions = buildGroupActions(groupName, rest)
  of ckSearch:
    nextActions = buildSearchActions(rest)
  of ckRun:
    nextActions = buildRunActions(rest)
  of ckQuit:
    ctx.shouldExit = true
    return
  else:
    discard

  if cmd == ckNone:
    nextActions = buildDefaultActions(rest, defaultIndex)
  elif nextActions.len == 0:
    nextActions.add Action(kind: akPlaceholder, label: "No matches", exec: "")

  ctx.actions = nextActions
  updateDisplayRows(cmd, rest, defaultIndex)

# ── Perform selected action ─────────────────────────────────────────────
proc clearInput*() =
  ctx.inputText.setLen(0)
  ctx.lastInputChangeMs = gui.nowMs()
  buildActions()

proc performAction*(a: Action) =
  if ctx.dryRunMode:
    stdout.write(a.exec & "\n")
    ctx.shouldExit = true
    return

  var exitAfter = true ## default: exit after action
  case a.kind
  of akRun:
    if not runCommand(a.exec):
      gui.notifyStatus("Failed: " & a.label, 1600)
      exitAfter = false
  of akConfig:
    if not openPathWithFallback(a.exec):
      gui.notifyStatus("Failed: " & a.label, 1600)
      exitAfter = false
  of akFile:
    if not openPathWithFallback(a.exec):
      gui.notifyStatus("Failed to open: " & a.label, 1600)
      exitAfter = false
  of akApp:
    ## safer: strip .desktop field codes before launching
    let sanitized = parser.stripFieldCodes(a.exec).strip()
    let args = parser.tokenize(sanitized)
    var success = false
    if args.len > 0:
      success = spawnProcess(args[0], args[1..^1])
    if success:
      recordAppLaunch(a.label)
    else:
      gui.notifyStatus("Failed: " & a.label, 1600)
      exitAfter = false
  of akAppAction:
    ## safer: strip .desktop field codes before launching
    let sanitized = parser.stripFieldCodes(a.exec).strip()
    let args = parser.tokenize(sanitized)
    var success = false
    if args.len > 0:
      success = spawnProcess(args[0], args[1..^1])
    if success:
      recordAppLaunch(a.appData.name)
    else:
      gui.notifyStatus("Failed: " & a.label, 1600)
      exitAfter = false
  of akDmenu:
    ctx.dmenuOutput = a.exec
    ctx.dmenuAccepted = true
  of akShortcut:
    case a.shortcutMode
    of smUrl:
      if not openUrl(a.exec):
        gui.notifyStatus("Failed: " & a.label, 1600)
        exitAfter = false
    of smShell:
      var success = true
      case a.powerMode
      of pamSpawn:
        success = spawnShellCommand(a.exec)
      of pamTerminal:
        success = runCommand(a.exec)
      if not success:
        gui.notifyStatus("Failed: " & a.label, 1600)
        exitAfter = false
    of smFile:
      let expanded = a.exec.expandTilde()
      if not fileExists(expanded) and not dirExists(expanded):
        gui.notifyStatus("Not found: " & shortenPath(expanded, 50), 1600)
        exitAfter = false
      elif not openPathWithFallback(expanded):
        gui.notifyStatus("Failed to open: " & shortenPath(expanded, 50), 1600)
        exitAfter = false
    if exitAfter and a.stayOpen:
      exitAfter = false
  of akTheme:
    ## Apply and persist, but DO NOT reset selection or exit.
    applyThemeAndColors(ctx.config, a.exec, doNotify = false, doRedraw = false)
    saveLastTheme(configDir() / "nimlaunch.toml")
    endThemePreviewSession(true)
    clearInput()
    gui.redrawWindow()
    exitAfter = false
  of akPlaceholder:
    exitAfter = false
  if a.kind == akDmenu:
    ctx.shouldExit = true
  elif exitAfter:
    ctx.shouldExit = true

# ── Input/navigation helpers ───────────────────────────────────────────
proc deleteLastInputChar*() =
  if ctx.inputText.len > 0:
    ctx.inputText.setLen(ctx.inputText.len - 1)
    ctx.lastInputChangeMs = gui.nowMs()
    buildActions()

proc activateCurrentSelection*() =
  if ctx.selectedIndex in 0..<ctx.actions.len:
    performAction(ctx.actions[ctx.selectedIndex])

proc moveSelectionBy*(step: int) =
  if ctx.filteredApps.len == 0: return
  var newIndex = ctx.selectedIndex + step
  if newIndex < 0: newIndex = 0
  if newIndex > ctx.filteredApps.len - 1: newIndex = ctx.filteredApps.len - 1
  if newIndex == ctx.selectedIndex: return
  ctx.selectedIndex = newIndex
  if ctx.selectedIndex < ctx.viewOffset:
    ctx.viewOffset = ctx.selectedIndex
  elif ctx.selectedIndex >= ctx.viewOffset + ctx.config.maxVisibleItems:
    ctx.viewOffset = ctx.selectedIndex - ctx.config.maxVisibleItems + 1
    if ctx.viewOffset < 0: ctx.viewOffset = 0
  updateThemePreview(parseCommand(ctx.inputText)[0] == ckTheme, ctx.actions, ctx.selectedIndex)

proc jumpToTop*() =
  if ctx.filteredApps.len == 0: return
  ctx.selectedIndex = 0
  ctx.viewOffset = 0
  updateThemePreview(parseCommand(ctx.inputText)[0] == ckTheme, ctx.actions, ctx.selectedIndex)

proc jumpToBottom*() =
  if ctx.filteredApps.len == 0: return
  ctx.selectedIndex = ctx.filteredApps.len - 1
  let start = ctx.filteredApps.len - ctx.config.maxVisibleItems
  ctx.viewOffset = if start > 0: start else: 0
  updateThemePreview(parseCommand(ctx.inputText)[0] == ckTheme, ctx.actions, ctx.selectedIndex)

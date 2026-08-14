## icon_resolver.nim — XDG icon discovery and resolution logic

import std/[os, strutils, osproc, algorithm, streams]

const
  IconSearchSizes = [16, 20, 22, 24, 32, 48, 64, 96, 128, 192, 256, 512]
  FallbackIconThemes = ["papirus", "papirus-dark", "adwaita", "adwaita-dark",
                        "breeze", "breeze-dark", "hicolor"]

var
  iconSearchPathsReady = false
  iconThemeDirsCache: seq[string] = @[]
  iconPixmapRootsCache: seq[string] = @[]
  preferredIconThemesCache: seq[string] = @[]

# -------------------
# Icon resolution
# -------------------
proc appendUniquePath(dst: var seq[string]; path: string) =
  if path.len == 0:
    return
  let cleaned = path.strip(chars = {DirSep, AltSep}, leading = false, trailing = true)
  if cleaned.len == 0:
    return
  if cleaned notin dst:
    dst.add(cleaned)

proc appendUniqueTheme(dst: var seq[string]; themeName: string) =
  let cleaned = themeName.strip(chars = {' ', '\t', '\'', '"'}).toLowerAscii
  if cleaned.len == 0:
    return
  if cleaned notin dst:
    dst.add(cleaned)

proc detectThemeFromGSettings(): string =
  let gsettingsExe = findExe("gsettings")
  if gsettingsExe.len == 0:
    return ""
  try:
    let p = startProcess(
      gsettingsExe,
      args = @["get", "org.gnome.desktop.interface", "icon-theme"],
      options = {poUsePath, poStdErrToStdOut}
    )
    defer: close(p)
    let output = p.outputStream.readAll().strip()
    let code = p.waitForExit()
    if code != 0 or output.len == 0:
      return ""
    result = output
    if result.len >= 2 and ((result[0] == '\'' and result[^1] == '\'') or
        (result[0] == '"' and result[^1] == '"')):
      result = result[1 .. ^2]
    result = result.strip(chars = {' ', '\t', '\'', '"'})
  except CatchableError:
    return ""

proc detectThemeFromGtkSettings(): string =
  let cfgHome = getEnv("XDG_CONFIG_HOME", getHomeDir() / ".config")
  let candidates = @[
    cfgHome / "gtk-4.0/settings.ini",
    cfgHome / "gtk-3.0/settings.ini"
  ]
  for iniPath in candidates:
    if not fileExists(iniPath):
      continue
    try:
      for rawLine in lines(iniPath):
        let line = rawLine.strip()
        if line.len == 0 or line.startsWith("#") or line.startsWith(";"):
          continue
        let lower = line.toLowerAscii
        if not lower.startsWith("gtk-icon-theme-name"):
          continue
        let eq = line.find('=')
        if eq < 0:
          continue
        return line[eq + 1 .. ^1].strip(chars = {' ', '\t', '\'', '"'})
    except CatchableError:
      discard
  ""

proc initPreferredIconThemes() =
  if preferredIconThemesCache.len > 0:
    return

  for theme in [getEnv("ICON_THEME"), detectThemeFromGSettings(),
      detectThemeFromGtkSettings()]:
    if theme.len == 0:
      continue
    appendUniqueTheme(preferredIconThemesCache, theme)
    let lower = theme.toLowerAscii
    if lower.endsWith("-dark"):
      appendUniqueTheme(preferredIconThemesCache, theme[0 ..< theme.len - 5])
    else:
      appendUniqueTheme(preferredIconThemesCache, theme & "-dark")

  for theme in FallbackIconThemes:
    appendUniqueTheme(preferredIconThemesCache, theme)

proc xdgDataRoots(): seq[string] =
  let xdgDataHome = getEnv("XDG_DATA_HOME")
  if xdgDataHome.len > 0:
    appendUniquePath(result, xdgDataHome)
  else:
    appendUniquePath(result, getHomeDir() / ".local/share")

  for entry in getEnv("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(':'):
    if entry.len == 0:
      continue
    appendUniquePath(result, entry)

  appendUniquePath(result, getHomeDir() / ".local/share/flatpak/exports/share")
  appendUniquePath(result, "/var/lib/flatpak/exports/share")

proc initIconSearchPaths() =
  if iconSearchPathsReady:
    return
  initPreferredIconThemes()

  var iconRoots: seq[string] = @[]
  appendUniquePath(iconRoots, getHomeDir() / ".icons")

  for root in xdgDataRoots():
    let iconsDir = root / "icons"
    if dirExists(iconsDir):
      appendUniquePath(iconRoots, iconsDir)
    let pixmapsDir = root / "pixmaps"
    if dirExists(pixmapsDir):
      appendUniquePath(iconPixmapRootsCache, pixmapsDir)

  appendUniquePath(iconRoots, "/usr/share/icons")
  appendUniquePath(iconPixmapRootsCache, "/usr/share/pixmaps")

  for iconRoot in iconRoots:
    if not dirExists(iconRoot):
      continue
    try:
      for kind, path in walkDir(iconRoot, relative = false):
        if kind == pcDir:
          appendUniquePath(iconThemeDirsCache, path)
    except CatchableError:
      discard

  proc themeRank(path: string): int =
    let name = splitPath(path).tail.toLowerAscii
    for i, pref in preferredIconThemesCache:
      if name == pref:
        return i * 10
    for i, pref in preferredIconThemesCache:
      if name.startsWith(pref & "-"):
        return i * 10 + 3
    if name.contains("legacy"):
      return 800
    if name.contains("highcontrast"):
      return 900
    200

  iconThemeDirsCache.sort(proc(a, b: string): int =
    let ra = themeRank(a)
    let rb = themeRank(b)
    result = cmp(ra, rb)
    if result == 0:
      result = cmpIgnoreCase(a, b)
  )

  iconSearchPathsReady = true

proc searchIconInDir(base: string; size: int; iconName: string;
                     includeSymbolic: bool; includeAuxGroups: bool;
                     includeScalable: bool): string =
  ## Search a specific base dir for size/scalable icons.
  let iconLower = iconName.toLowerAscii
  let hasExt = iconLower.endsWith(".png") or iconLower.endsWith(".svg") or
      iconLower.endsWith(".xpm")
  proc pickExisting(path: string): string =
    if not fileExists(path):
      return ""
    return path

  proc checkName(name: string): string =
    let sizeDir = $size & "x" & $size
    let kdeSizeDir = $size
    let primaryGroups = ["apps", "legacy"]
    let auxGroups = ["actions", "categories", "devices", "emblems",
                     "mimetypes", "places", "preferences", "status", "panel"]
    var rels: seq[string] = @[]
    for grp in primaryGroups:
      rels.add(sizeDir / grp / name)
      rels.add(grp / kdeSizeDir / name)
    if includeAuxGroups:
      for grp in auxGroups:
        rels.add(sizeDir / grp / name)
        rels.add(grp / kdeSizeDir / name)
      rels.add(sizeDir / name)
    if includeScalable:
      for grp in primaryGroups:
        rels.add("scalable" / grp / name)
      if includeAuxGroups:
        for grp in auxGroups:
          rels.add("scalable" / grp / name)
        rels.add("scalable" / name)
    if includeSymbolic:
      for grp in primaryGroups:
        rels.add("symbolic" / grp / name)
      if includeAuxGroups:
        for grp in auxGroups:
          rels.add("symbolic" / grp / name)
        rels.add("symbolic" / name)

    for rel in rels:
      let dir = base / splitPath(rel).head
      if dirExists(dir):
        let hit = pickExisting(base / rel)
        if hit.len > 0:
          return hit
    ""

  if hasExt:
    return checkName(iconName)

  for ext in [".png", ".svg", ".xpm"]:
    let hit = checkName(iconName & ext)
    if hit.len > 0:
      return hit
  ""

proc resolveIconPath*(iconName: string; requestedSize: int): string =
  ## Resolve an icon name to an on-disk image path usable by SDL3_image.
  if iconName.len == 0:
    return ""

  initIconSearchPaths()

  var candidates: seq[string] = @[]
  proc addCandidate(name: string) =
    if name.len == 0:
      return
    if name notin candidates:
      candidates.add(name)
  addCandidate(iconName)
  let iconLower = iconName.toLowerAscii
  if iconLower != iconName:
    addCandidate(iconLower)
  if iconLower.endsWith(".png") or iconLower.endsWith(".svg") or
     iconLower.endsWith(".xpm"):
    let dot = iconName.rfind('.')
    if dot > 0:
      let stem = iconName[0 ..< dot]
      addCandidate(stem)
      addCandidate(stem.toLowerAscii)

  # If iconName is an absolute path, support direct image files and omitted extension.
  if '/' in iconName:
    let absLower = iconName.toLowerAscii()
    if fileExists(iconName) and (absLower.endsWith(".png") or absLower.endsWith(".svg") or
        absLower.endsWith(".xpm")):
      return iconName
    for ext in [".png", ".svg", ".xpm"]:
      let p = iconName & ext
      if fileExists(p):
        return p
    return ""

  # Build list of icon sizes to try:
  # 1) requested size
  # 2) nearest larger sizes (prefer downscaling for quality)
  # 3) smaller sizes as fallback
  var sizes: seq[int] = @[]
  let req = if requestedSize > 0: requestedSize else: IconSearchSizes[0]
  sizes.add(req)
  for s in IconSearchSizes:
    if s >= req and s notin sizes:
      sizes.add(s)
  for i in countdown(IconSearchSizes.high, 0):
    let s = IconSearchSizes[i]
    if s < req and s notin sizes:
      sizes.add(s)

  # Search all discovered icon themes under XDG roots.
  # Prefer non-symbolic icons unless the requested name itself is symbolic.
  for icon in candidates:
    let wantsSymbolic = icon.toLowerAscii.contains("symbolic")
    for includeAux in [false, true]:
      for includeScalable in [false, true]:
        for size in sizes:
          for themeDir in iconThemeDirsCache:
            let hit = searchIconInDir(themeDir, size, icon,
                includeSymbolic = wantsSymbolic,
                includeAuxGroups = includeAux,
                includeScalable = includeScalable)
            if hit.len > 0: return hit
        if not wantsSymbolic:
          for size in sizes:
            for themeDir in iconThemeDirsCache:
              let hit = searchIconInDir(themeDir, size, icon,
                  includeSymbolic = true,
                  includeAuxGroups = includeAux,
                  includeScalable = includeScalable)
              if hit.len > 0: return hit

  # Search discovered pixmap roots as a last resort.
  for icon in candidates:
    let lower = icon.toLowerAscii
    let hasExt = lower.endsWith(".png") or lower.endsWith(".svg") or lower.endsWith(".xpm")
    for pixRoot in iconPixmapRootsCache:
      if hasExt:
        let p = pixRoot / icon
        if fileExists(p):
          return p
      for ext in [".png", ".svg", ".xpm"]:
        let p = pixRoot / (icon & ext)
        if fileExists(p):
          return p

  result = ""

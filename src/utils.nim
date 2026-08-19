## utils.nim — shared helper routines
## Derived from NimLaunch, with X11-specific colour allocation removed.
##
## Side effects:
##   • recent-application JSON persistence
##   • app-usage JSON persistence

import std/[os, strutils, json, options, times, tables]
import ./[state, paths]



proc normalizePrefix*(prefix: string): string =
  ## Canonicalise user-configured prefixes by trimming colons/whitespace and
  ## lowercasing so parsing is resilient to variants like ":g", "g:" or ":G:".
  prefix.strip(chars = Whitespace + {':'}).toLowerAscii

# ── Colour helpers ──────────────────────────────────────────────────────
proc parseHexRgb8*(hex: string): Option[Rgb] =
  ## Parse "#RRGGBB" into Rgb; return none on bad input.
  if hex.len != 7 or hex[0] != '#':
    return none(Rgb)
  try:
    let r = parseHexInt(hex[1..2])
    let g = parseHexInt(hex[3..4])
    let b = parseHexInt(hex[5..6])
    some(Rgb(r: uint8(r), g: uint8(g), b: uint8(b)))
  except ValueError:
    none(Rgb)

# ── Recent/MRU (applications) persistence ───────────────────────────────
let recentFile* = cacheDir() / "recent.json"
let usageFile* = cacheDir() / "usage.json"

proc loadRecent*() =
  ## Populate ctx.recentApps from disk; log on error.
  if fileExists(recentFile):
    try:
      let j = parseJson(readFile(recentFile))
      ctx.recentApps = j.to(seq[string])
    except IOError, OSError, ValueError:
      let e = getCurrentException()
      echo "loadRecent warning: ", recentFile, " (", e.name, "): ", e.msg

proc saveRecent*() =
  ## Persist ctx.recentApps to disk; log on error.
  try:
    createDir(recentFile.parentDir)
    writeFile(recentFile, $ %ctx.recentApps)
  except IOError, OSError:
    let e = getCurrentException()
    echo "saveRecent warning: ", recentFile, " (", e.name, "): ", e.msg

proc loadUsage*() =
  ## Populate per-app usage stats from disk; log on error.
  ctx.appUsage = initTable[string, AppUsage]()
  if fileExists(usageFile):
    try:
      let j = parseJson(readFile(usageFile))
      ctx.appUsage = j.to(Table[string, AppUsage])
    except IOError, OSError, ValueError:
      let e = getCurrentException()
      echo "loadUsage warning: ", usageFile, " (", e.name, "): ", e.msg

proc saveUsage*() =
  ## Persist per-app usage stats to disk; log on error.
  try:
    createDir(usageFile.parentDir)
    writeFile(usageFile, $ %ctx.appUsage)
  except IOError, OSError:
    let e = getCurrentException()
    echo "saveUsage warning: ", usageFile, " (", e.name, "): ", e.msg

proc recordAppLaunch*(name: string) =
  ## Update MRU ordering and persistent launch stats for an app-like action.
  if name.len == 0:
    return
  let ri = ctx.recentApps.find(name)
  if ri >= 0:
    ctx.recentApps.delete(ri)
  ctx.recentApps.insert(name, 0)
  if ctx.recentApps.len > maxRecent:
    ctx.recentApps.setLen(maxRecent)
  var stats = ctx.appUsage.getOrDefault(name)
  inc stats.launchCount
  stats.lastLaunched = epochTime().int64
  ctx.appUsage[name] = stats
  saveRecent()
  saveUsage()

## fuzzy.nim — fuzzy matching, typo tolerance, and highlight helpers.

import std/[strutils, times, tables]
import ./state

proc recentBoost*(name: string): int =
  ## Small score bonus for recently used apps (first is strongest).
  let idx = ctx.recentApps.find(name)
  if idx >= 0: return max(0, 200 - idx * 40)
  0

proc usageBoost*(name: string): int =
  ## Small persistent score layer based on launch frequency and recency.
  let stats = ctx.appUsage.getOrDefault(name)
  if stats.launchCount <= 0 and stats.lastLaunched <= 0:
    return 0
  let frequency = min(stats.launchCount, 20) * 30
  let ageSeconds = max(0'i64, epochTime().int64 - stats.lastLaunched)
  let recency =
    if ageSeconds < 3_600: 320
    elif ageSeconds < 86_400: 220
    elif ageSeconds < 604_800: 120
    elif ageSeconds < 2_592_000: 40
    else: 0
  frequency + recency

proc subseqPositions*(q, t: string): seq[int] =
  ## Case-insensitive subsequence positions of q within t (for highlight).
  if q.len == 0: return @[]
  var qi = 0
  for i in 0 ..< t.len:
    if qi < q.len and toLowerAscii(t[i]) == toLowerAscii(q[qi]):
      result.add i
      inc qi
      if qi == q.len: return
  result.setLen(0)

proc subseqSpans*(q, t: string): seq[(int, int)] =
  ## Convert positions to 1-char spans for highlighting.
  for p in subseqPositions(q, t): result.add (p, 1)

proc isWordBoundary*(lt: string; idx: int): bool =
  ## Basic token boundary check for nicer scoring.
  if idx <= 0: return true
  let c = lt[idx-1]
  c == ' ' or c == '-' or c == '_' or c == '.' or c == '/'

proc withinOneEdit(a: string, b: openArray[char]): bool =
  let m = a.len; let n = b.len
  if abs(m - n) > 1: return false
  var i = 0; var j = 0; var edits = 0
  while i < m and j < n:
    if a[i] == b[j]: inc i; inc j
    else:
      inc edits; if edits > 1: return false
      if m == n: inc i; inc j
      elif m < n: inc j
      else: inc i
  edits += (m - i) + (n - j)
  edits <= 1

proc withinOneTransposition(a: string, b: openArray[char]): bool =
  if a.len != b.len or a.len < 2: return false
  var k = 0
  while k < a.len and a[k] == b[k]: inc k
  if k >= a.len - 1: return false
  if not (a[k] == b[k+1] and a[k+1] == b[k]): return false
  let tailStart = k + 2
  if tailStart < a.len:
    for i in tailStart ..< a.len:
      if a[i] != b[i]: return false
  return true

proc scoreMatch*(q, lq, t, lt, fullPath, home: string): int =
  ## Heuristic score for matching q against t (higher is better).
  ## Typo-friendly: 1 edit (ins/del/sub) or one adjacent transposition.
  if q.len == 0: return -1_000_000
  let pos = lt.find(lq)

  var s = -1_000_000
  if pos >= 0:
    s = 1000
    if pos == 0: s += 200
    if isWordBoundary(lt, pos): s += 80
    s += max(0, 60 - (t.len - q.len))

  if t == q: s += 9000
  elif lt == lq: s += 8600
  elif lt.startsWith(lq): s += 8200
  elif pos >= 0: s += 7800
  else:
    var typoHit = false

    ## Whole-string typo tolerance (1 edit or adjacent swap).
    if lq.len > 0 and (withinOneEdit(lq, lt) or withinOneTransposition(lq, lt)):
      typoHit = true
      s = max(s, 7600)

    ## Substring typo tolerance to catch near-start matches.
    if not typoHit and lq.len > 0:
      let sizes = [max(1, lq.len - 1), lq.len, lq.len + 1]
      for L in sizes:
        if L > lt.len: continue
        var start = 0
        let maxStart = lt.len - L
        while start <= maxStart:
          if withinOneEdit(lq, toOpenArray(lt, start, start + L - 1)) or withinOneTransposition(lq, toOpenArray(lt, start, start + L - 1)):
            typoHit = true
            var base = 7700
            if start == 0: base = 7950
            s = max(s, base - min(120, start))
            break
          inc start
        if typoHit: break

  if fullPath.startsWith(home & "/"):
    if lt == lq: s += 600
    elif lt.startsWith(lq): s += 400
  s

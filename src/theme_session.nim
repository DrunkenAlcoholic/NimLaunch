## theme_session.nim — theme preview lifecycle helpers.
## NOTE: This module could be merged later.

import ./[state, settings]

proc beginThemePreviewSession*() =
  if not ctx.themePreviewActive:
    ctx.themePreviewActive = true
    ctx.themePreviewBaseTheme = ctx.config.themeName
    ctx.themePreviewCurrent = ctx.config.themeName

proc endThemePreviewSession*(persist: bool) =
  if not ctx.themePreviewActive:
    return
  if persist:
    ctx.themePreviewBaseTheme = ctx.config.themeName
    ctx.themePreviewCurrent = ctx.config.themeName
  else:
    if ctx.themePreviewBaseTheme.len > 0 and ctx.themePreviewCurrent.len > 0 and
       ctx.themePreviewCurrent != ctx.themePreviewBaseTheme:
      applyThemeAndColors(ctx.config, ctx.themePreviewBaseTheme, doRedraw = false)
      ctx.themePreviewCurrent = ctx.themePreviewBaseTheme
  ctx.themePreviewActive = false

proc updateThemePreview*(isThemeCmd: bool; actions: seq[Action];
    selectedIndex: int) =
  if not isThemeCmd:
    return
  if ctx.actions.len == 0:
    endThemePreviewSession(false)
    return
  beginThemePreviewSession()
  if selectedIndex < 0 or selectedIndex >= ctx.actions.len:
    return
  let act = ctx.actions[selectedIndex]
  if act.kind != akTheme:
    return
  let name = act.exec
  if ctx.themePreviewCurrent == name:
    return
  applyThemeAndColors(ctx.config, name, doRedraw = false)
  ctx.themePreviewCurrent = name

## input.nim — key handling, Vim mode, and window event helpers.

import std/strutils
import sdl3
import ./[state, app_core, gui]

proc executeVimCommand*()
proc syncVimCommand*()
proc openVimCommand*(initial: string = "")
proc closeVimCommand*(restoreInput = false; preserveBuffer = false)
proc appendTextInput*(txt: string)

const
  CtrlMask = KMOD_CTRL
  ShiftMask = KMOD_SHIFT
  K_RETURN = SDLK_RETURN
  K_BACKSPACE = SDLK_BACKSPACE
  K_DELETE = SDLK_DELETE
  K_ESCAPE = SDLK_ESCAPE
  K_LEFT = SDLK_LEFT
  K_RIGHT = SDLK_RIGHT
  K_UP = SDLK_UP
  K_DOWN = SDLK_DOWN
  K_PAGEUP = SDLK_PAGEUP
  K_PAGEDOWN = SDLK_PAGEDOWN
  K_HOME = SDLK_HOME
  K_END = SDLK_END
  K_INSERT = SDLK_INSERT
  K_g = uint32(ord('g'))
  K_h = uint32(ord('h'))
  K_j = uint32(ord('j'))
  K_k = uint32(ord('k'))
  K_l = uint32(ord('l'))
  K_u = uint32(ord('u'))
  K_v = uint32(ord('v'))

type FocusState* = object
  hadFocus*: bool
  startMs*: int64
  lastGainMs*: int64

proc sanitizePastedText(text: string): string =
  ## Normalize pasted text into a single-line launcher query/command.
  result = newStringOfCap(text.len)
  var lastWasSpace = false
  for ch in text:
    case ch
    of '\0':
      discard
    of '\r', '\n', '\t':
      if not lastWasSpace:
        result.add ' '
        lastWasSpace = true
    else:
      result.add ch
      lastWasSpace = ch == ' '
  result = result.strip()

proc readClipboardText(primaryFallback = true): string =
  proc consume(raw: cstring): string =
    if raw == nil:
      return ""
    result = sanitizePastedText($raw)
    sdlFree(cast[pointer](raw))

  if hasClipboardText():
    result = consume(getClipboardText())
    if result.len > 0:
      return result

  if primaryFallback and hasPrimarySelectionText():
    result = consume(getPrimarySelectionText())

proc pasteInputText*(): bool =
  let pasted = readClipboardText(primaryFallback = true)
  if pasted.len == 0:
    return false
  appendTextInput(pasted)
  true

proc handleTextEditing*(ev: Event): bool =
  if not gui.ownsWindowID(ev.edit.windowID):
    return false
  when gui.WindowDebug:
    let preview = if ev.edit.text == nil: "" else: $ev.edit.text
    echo "[window-debug] text-editing text=\"", preview,
        "\" start=", ev.edit.start,
        " length=", ev.edit.length,
        " vimActive=", vim.active
  false

proc handleTextEditingCandidates*(ev: Event): bool =
  if not gui.ownsWindowID(ev.edit_candidates.windowID):
    return false
  when gui.WindowDebug:
    var sample: seq[string] = @[]
    let total = max(0, ev.edit_candidates.num_candidates)
    let limit = min(total, 3)
    for i in 0 ..< limit:
      let cand = ev.edit_candidates.candidates[i]
      sample.add(if cand == nil: "" else: $cand)
    echo "[window-debug] text-editing-candidates count=",
        ev.edit_candidates.num_candidates,
        " selected=", ev.edit_candidates.selected_candidate,
        " horizontal=", ev.edit_candidates.horizontal,
        " sample=", sample.join(" | ")
  false

proc shouldExitOnFocusLoss*(fs: FocusState): bool =
  ## Exit only after initial grace period and a small delay after last focus gain.
  let now = gui.nowMs()
  let armed = (now - fs.startMs) > 300
  let postGain = (now - fs.lastGainMs) > 150
  fs.hadFocus and armed and postGain

proc handleVimCommandKey*(sym: Keycode; ctrlHeld: bool;
    suppressText: var bool): bool =
  ## Handle Vim command-line keys. Return true if the key was consumed.
  case sym
  of K_RETURN:
    executeVimCommand()
    suppressText = true
    true
  of K_BACKSPACE, K_DELETE:
    if vim.buffer.len > 0:
      vim.buffer.setLen(vim.buffer.len - 1)
      syncVimCommand()
    else:
      closeVimCommand(restoreInput = true, preserveBuffer = false)
    suppressText = true
    true
  else:
    if ctrlHeld and sym == K_h:
      if vim.buffer.len > 0:
        vim.buffer.setLen(vim.buffer.len - 1)
        syncVimCommand()
      else:
        closeVimCommand(restoreInput = true, preserveBuffer = false)
      suppressText = true
      return true
    if ctrlHeld and sym == K_u:
      vim.buffer.setLen(0)
      syncVimCommand()
      suppressText = true
      return true
    if sym == K_ESCAPE:
      let restore = vim.buffer.len == 0
      closeVimCommand(restoreInput = restore, preserveBuffer = true)
      suppressText = true
      return true
    ## Printable characters are handled by TextInput; do not block.
    false

proc handleVimNormalKey*(sym: Keycode; modState: Keymod;
    suppressText: var bool): bool =
  ## Handle Vim-mode nav keys when not in command-line. Return true if consumed.
  let shiftHeld = (modState and ShiftMask) != 0

  case sym
  of K_g:
    if shiftHeld:
      vim.pendingG = false
      jumpToBottom()
    elif vim.pendingG:
      vim.pendingG = false
      jumpToTop()
    else:
      vim.pendingG = true
    suppressText = true
    true
  of K_j:
    vim.pendingG = false
    moveSelectionBy(1)
    suppressText = true
    true
  of K_k:
    vim.pendingG = false
    moveSelectionBy(-1)
    suppressText = true
    true
  of K_h:
    vim.pendingG = false
    deleteLastInputChar()
    suppressText = true
    true
  of K_l:
    vim.pendingG = false
    activateCurrentSelection()
    suppressText = true
    true
  of K_ESCAPE:
    shouldExit = true
    suppressText = true
    true
  else:
    vim.pendingG = false
    false

proc handleVimKey*(sym: Keycode; modState: Keymod;
    suppressText: var bool) =
  if vim.active:
    discard handleVimCommandKey(sym, (modState and CtrlMask) != 0, suppressText)
  else:
    discard handleVimNormalKey(sym, modState, suppressText)

proc resetVimState*() =
  vim = VimCommandState()

proc syncVimCommand*() =
  inputText = vim.prefix & vim.buffer
  lastInputChangeMs = gui.nowMs()
  buildActions()

proc openVimCommand*(initial: string = "") =
  gui.clearTextComposition()
  if not vim.active:
    vim.savedInput = inputText
    vim.savedSelectedIndex = selectedIndex
    vim.savedViewOffset = viewOffset
    vim.restorePending = true
  if initial.len > 0 and (initial[0] == ':' or initial[0] == '!'):
    vim.prefix = initial[0 .. 0]
    if initial.len > 1:
      vim.buffer = initial[1 .. ^1]
    else:
      vim.buffer.setLen(0)
  else:
    vim.prefix = ""
    if initial.len == 0 and vim.lastSearch.len > 0:
      vim.buffer = vim.lastSearch
    else:
      vim.buffer = initial
  vim.active = true
  vim.pendingG = false
  syncVimCommand()

proc closeVimCommand*(restoreInput = false; preserveBuffer = false) =
  gui.clearTextComposition()
  let savedInput = vim.savedInput
  let savedSelected = vim.savedSelectedIndex
  let savedOffset = vim.savedViewOffset
  let savedBuffer = vim.prefix & vim.buffer
  if savedBuffer.len == 0:
    vim.lastSearch = ""
  elif preserveBuffer and (savedBuffer[0] != ':' and savedBuffer[0] != '!'):
    vim.lastSearch = savedBuffer
  vim.buffer.setLen(0)
  vim.prefix = ""
  vim.active = false
  vim.pendingG = false

  if restoreInput and vim.restorePending:
    inputText = savedInput
    lastInputChangeMs = gui.nowMs()
    buildActions()

    if filteredApps.len > 0:
      let clampedSel = max(0, min(savedSelected, filteredApps.len - 1))
      let visibleRows = max(1, config.maxVisibleItems)
      let maxOffset = max(0, filteredApps.len - visibleRows)
      var newOffset = max(0, min(savedOffset, maxOffset))
      if clampedSel < newOffset:
        newOffset = clampedSel
      elif clampedSel >= newOffset + visibleRows:
        newOffset = max(0, clampedSel - visibleRows + 1)
      selectedIndex = clampedSel
      viewOffset = newOffset
    else:
      selectedIndex = 0
      viewOffset = 0

  vim.savedInput = ""
  vim.savedSelectedIndex = 0
  vim.savedViewOffset = 0
  vim.restorePending = false

proc executeVimCommand*() =
  gui.clearTextComposition()
  let trimmed = (vim.prefix & vim.buffer).strip()
  closeVimCommand(preserveBuffer = false)
  if trimmed.len == 0:
    return
  if trimmed == ":q":
    shouldExit = true
    return
  inputText = trimmed
  lastInputChangeMs = gui.nowMs()
  buildActions()
  if trimmed.len == 0 or (trimmed[0] != ':' and trimmed[0] != '!'):
    vim.lastSearch = trimmed
  if actions.len > 0:
    activateCurrentSelection()

proc appendTextInput*(txt: string) =
  if txt.len == 0: return
  if config.vimMode and vim.active:
    vim.buffer.add(txt)
    syncVimCommand()
  else:
    inputText.add(txt)
    lastInputChangeMs = gui.nowMs()
    buildActions()

proc handleWindowEvent*(ev: Event; focus: var FocusState): bool =
  ## Handle window lifecycle/resize events and report whether a redraw is needed.
  var needsRedraw = false
  case ev.window.`type`
  of EVENT_WINDOW_FOCUS_GAINED:
    focus.hadFocus = true
    focus.lastGainMs = gui.nowMs()
    needsRedraw = true
  of EVENT_WINDOW_SHOWN, EVENT_WINDOW_EXPOSED:
    discard gui.refreshMetrics()
    needsRedraw = true
  of EVENT_WINDOW_RESIZED, EVENT_WINDOW_PIXEL_SIZE_CHANGED,
      EVENT_WINDOW_DISPLAY_CHANGED, EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
    needsRedraw = gui.refreshMetrics() or needsRedraw
  of EVENT_WINDOW_FOCUS_LOST, EVENT_WINDOW_HIDDEN, EVENT_WINDOW_MINIMIZED:
    gui.clearTextComposition()
    if shouldExitOnFocusLoss(focus):
      shouldExit = true
  else:
    discard

  when gui.WindowDebug:
    let m = gui.windowMetrics()
    let l = gui.layoutMetrics()
    echo "[window-debug] event=", $ev.window.`type`,
        " data=", ev.window.data1, "x", ev.window.data2,
        " win=", m.winW, "x", m.winH,
        " drawable=", m.drawW, "x", m.drawH,
        " layout=", l.logicalW, "x", l.logicalH,
        " display=", l.displayID,
        " displayScale=", l.displayScale,
        " pixelDensity=", l.pixelDensity,
        " contentScale=", l.contentScale,
        " line=", l.lineH,
        " icon=", l.iconSlot,
        " scale=", l.scale,
        " redraw=", needsRedraw

  needsRedraw

proc handleKeyDown*(ev: Event; focus: var FocusState;
    suppressNextTextInput: var bool): bool =
  let sym = ev.key.key
  let modState = ev.key.`mod`
  let ctrlHeld = (modState and CtrlMask) != 0
  let shiftHeld = (modState and ShiftMask) != 0
  var handled = false
  focus.hadFocus = true
  if ctrlHeld and sym == K_v:
    handled = pasteInputText()
    suppressNextTextInput = handled
  elif shiftHeld and sym == K_INSERT:
    handled = pasteInputText()
    suppressNextTextInput = handled
  elif config.vimMode:
    handleVimKey(sym, modState, suppressNextTextInput)
    handled = suppressNextTextInput
  elif sym == K_u and ctrlHeld:
    clearInput()
    handled = true
  elif sym == K_h and ctrlHeld:
    deleteLastInputChar()
    handled = true
  else:
    case sym
    of K_ESCAPE:
      shouldExit = true
      handled = true
    of K_RETURN:
      activateCurrentSelection()
      handled = true
    of K_BACKSPACE:
      deleteLastInputChar()
      handled = true
    of K_LEFT:
      deleteLastInputChar()
      handled = true
    of K_RIGHT:
      discard
    of K_UP:
      moveSelectionBy(-1)
      handled = true
    of K_DOWN:
      moveSelectionBy(1)
      handled = true
    of K_PAGEUP:
      if filteredApps.len > 0:
        moveSelectionBy(-max(1, config.maxVisibleItems))
      handled = true
    of K_PAGEDOWN:
      if filteredApps.len > 0:
        moveSelectionBy(max(1, config.maxVisibleItems))
      handled = true
    of K_HOME:
      jumpToTop()
      handled = true
    of K_END:
      jumpToBottom()
      handled = true
    else:
      discard

  handled

proc handleTextInput*(ev: Event; focus: var FocusState;
    suppressNextTextInput: var bool): bool =
  if suppressNextTextInput:
    suppressNextTextInput = false
    return false
  let s = $ev.text.text
  focus.hadFocus = true
  if config.vimMode and not vim.active and s.len > 0:
    case s[0]
    of '/':
      vim.pendingG = false
      openVimCommand("")
      return true
    of ':':
      vim.pendingG = false
      openVimCommand(":")
      return true
    of '!':
      vim.pendingG = false
      openVimCommand("!")
      return true
    else:
      vim.pendingG = false
      return true
  appendTextInput(s)
  true

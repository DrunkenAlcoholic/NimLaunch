# SDL3 Migration Spec

This document defines the intended SDL2 -> SDL3 migration for NimLaunch.
The goal is not a direct API swap. The goal is to use SDL3 to clean up the
window, scaling, rendering, and text-input model while preserving current
launcher behavior.

## Goals

- Move the GUI backend from `sdl2` to `sdl3`.
- Treat config geometry and spacing as logical UI units, not physical pixels.
- Support high pixel density windows cleanly on Wayland, X11, and mixed-DPI
  multi-monitor setups.
- Rebuild fonts and icon textures when display scale changes.
- Keep app logic, search, theme handling, and launcher commands largely
  unchanged.
- Make the backend easier to reason about by separating config, layout, and
  renderer state.

## Non-Goals

- Rewriting the launcher into a new UI toolkit.
- Changing command semantics, fuzzy search behavior, or config file format
  during the first SDL3 migration pass.
- Adding GPU shaders, custom vector drawing, or animation-heavy rendering.

## Current Problems

The current SDL2 backend in `src/gui.nim` and `src/input.nim` works, but it
mixes three different concerns:

- Persistent config state such as `config.winWidth`, `config.lineHeight`, and
  `config.borderWidth`.
- Runtime compositor/window size tracking.
- Implicit DPI handling via drawable-size checks and resize bookkeeping.

Current examples:

- `windowMetrics()` in `src/gui.nim` tracks window size vs drawable size.
- `handleWindowEvent()` in `src/input.nim` writes compositor resize values back
  into `config.winWidth` and `config.winMaxHeight`.
- Font size is derived once at startup from `config.fontName`.
- Icon raster sizes are inferred from `config.lineHeight`, not display scale.

This keeps the app usable, but it prevents proper high-DPI behavior and makes
the backend harder to extend.

## Target Design

### Config Model

The existing config file remains logically the same, but these values become
logical units:

- `config.winWidth`
- `config.lineHeight`
- `config.maxVisibleItems`
- `config.positionX`
- `config.positionY`
- `config.borderWidth`

`config.winMaxHeight` should no longer be treated as the authoritative runtime
window height. It is a derived logical layout value:

`40 + config.maxVisibleItems * config.lineHeight`

That derivation should stay in config/settings code, but the GUI backend should
stop mutating config when the compositor reports a resize.

### Runtime Backend State

Add backend-only runtime state in `src/gui.nim` and keep it out of `state.nim`
unless a later refactor proves shared access is necessary.

Suggested types:

```nim
type
  UiMetrics = object
    scale: float32
    displayScale: float32
    pixelDensity: float32
    logicalWinW: int
    logicalWinH: int
    pixelWinW: int
    pixelWinH: int
    lineHeightPx: int
    borderWidthPx: int
    iconSlotPx: int
    paddingPx: int
    fontPointSize: float32
    overlayFontPointSize: float32

  BackendState = ref object
    window: Window
    renderer: Renderer
    font: Font
    fontBold: Font
    fontOverlay: Font
    metrics: UiMetrics
    lastDisplayID: DisplayID
    iconCache: Table[string, IconTexture]
    iconPathCache: Table[string, string]
    windowShown: bool
    windowRaised: bool
```

Rules:

- `logicalWinW` and `logicalWinH` come from config-derived layout values.
- `pixelWinW` and `pixelWinH` come from SDL3 window pixel size.
- `scale` is the effective UI scale used for fonts, borders, padding, and icon
  raster size.
- Texture caches remain backend-owned.

### Scale Policy

Use SDL3 to compute scale at runtime:

1. Primary source: `getWindowDisplayScale(window)`
2. Secondary source: `getDisplayContentScale(displayID)`
3. Diagnostic source: `getWindowPixelDensity(window)`

Recommended policy:

- Default to `scale = max(1.0, getWindowDisplayScale(window))`
- Clamp extremely small or pathological values.
- Round derived pixel sizes so text and borders stay crisp.
- Rebuild font and icon caches only when the effective scale changes by a
  meaningful amount, not on every expose event.

This keeps config values stable while allowing the backend to adapt to monitor
changes and compositor density.

### Layout Policy

All drawing code should be based on `st.metrics`, not directly on raw config
pixels.

Examples:

- Row height should use `metrics.lineHeightPx`
- Border width should use `metrics.borderWidthPx`
- Icon slot size should use `metrics.iconSlotPx`
- Margins and padding should be centralized instead of repeated numeric
  literals

Current hardcoded values such as `10`, `12`, `6`, and `4` in `src/gui.nim`
should be converted into named logical constants and scaled once.

### Font Policy

Font size should no longer be loaded once and frozen. Instead:

- Parse the configured base font size from `config.fontName`
- Multiply by `metrics.scale`
- Reopen `font`, `fontBold`, and `fontOverlay` when scale changes

This avoids blurry upscaled text and ensures text remains visually consistent
across monitors.

### Icon Policy

The current icon pipeline already rasterizes SVGs to PNG cache. Keep that
pipeline, but make requested raster size scale-aware.

Rules:

- Cache key should include scale-derived size, not just logical slot size
- Rebuild icon textures when `metrics.iconSlotPx` changes
- Continue preferring theme-aware icon lookup and SVG raster fallback

This is one of the best opportunities to improve quality during the SDL3 port.

### Window Policy

SDL3 window creation should use properties instead of the older SDL2-style
constructor shape.

Use:

- `createWindowWithProperties`
- `PROP_WINDOW_CREATE_TITLE_STRING`
- `PROP_WINDOW_CREATE_WIDTH_NUMBER`
- `PROP_WINDOW_CREATE_HEIGHT_NUMBER`
- `PROP_WINDOW_CREATE_X_NUMBER`
- `PROP_WINDOW_CREATE_Y_NUMBER`
- `PROP_WINDOW_CREATE_BORDERLESS_BOOLEAN`
- `PROP_WINDOW_CREATE_HIDDEN_BOOLEAN`
- `PROP_WINDOW_CREATE_UTILITY_BOOLEAN`
- `PROP_WINDOW_CREATE_HIGH_PIXEL_DENSITY_BOOLEAN`

Behavioral expectations:

- Keep borderless/utility semantics
- Keep current focus/raise behavior unless SDL3 platform behavior makes it
  unnecessary
- Keep centered positioning logic, but compute it in logical units and pass the
  resulting placement through SDL3 window properties

### Renderer Policy

Use SDL3 renderer creation intentionally rather than as a direct SDL2 port.

Preferred approach:

- Create the renderer with properties
- Enable present vsync through SDL3 renderer properties
- Set texture scale mode explicitly for icon textures

Potential SDL3 hooks worth using:

- `createRendererWithProperties`
- `PROP_RENDERER_CREATE_WINDOW_POINTER`
- `PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER`
- `setTextureScaleMode`
- `setRenderLogicalPresentation`

`setRenderLogicalPresentation` is optional in the first pass. It is useful only
if the app chooses to keep a fully logical renderer space. The simpler first
pass is:

- compute scaled pixel metrics in Nim
- draw directly in pixel coordinates
- use SDL3 scale APIs for measurement and diagnostics

### Text Input and IME Policy

SDL3 gives a better path for text input than the current always-on model.

Use:

- `startTextInput(window)`
- `stopTextInput(window)`
- `setTextInputArea(window, rect, cursor)`

Policy:

- Keep text input active while the launcher is visible
- Update the text input area to the prompt/input region
- When Vim command mode is active, move the text input area to the command bar

This improves IME candidate placement and makes the backend more correct on
non-English input methods.

## SDL2 -> SDL3 Mapping

### Imports

Replace:

- `import sdl2`
- `import sdl2/ttf`
- `import sdl2/image`

With:

- `import sdl3`
- `import sdl3_ttf`
- local `sdl3_image` wrapper, or a local image-loading helper

### Core API Shifts

- `createWindow(...)` -> `createWindowWithProperties(...)`
- `createRenderer(window, index, flags)` -> property-based renderer creation
- `startTextInput()` -> `startTextInput(window)`
- `stopTextInput()` -> `stopTextInput(window)`
- `getSize(window)` -> `getWindowSize(window, ...)`
- `getRendererOutputSize(...)` -> prefer `getWindowSizeInPixels(...)` and
  SDL3 scale queries

### Event Handling

The event loop in `src/main.nim` is already simple and should remain simple.
The important change is event interpretation:

- Stop treating resize events as permission to rewrite config
- On size/display changes, recompute metrics and redraw
- On scale changes, rebuild fonts and icon textures before redraw

## File-by-File Plan

### `src/gui.nim`

This file gets the largest change.

Required work:

- Switch imports to SDL3 modules
- Introduce runtime `UiMetrics`
- Replace SDL2 init/shutdown calls with SDL3 equivalents
- Replace direct config-pixel drawing with metrics-based drawing
- Add a single `refreshMetrics(force = false)` proc
- Add a `rebuildFonts()` proc
- Add a `invalidateIconTextures()` proc
- Update `windowMetrics()` to report logical size, pixel size, and scale
- Replace `image.loadTexture` usage with SDL3-image or local wrapper

Suggested new helper procs:

```nim
proc logicalWindowHeight(): int
proc computeUiMetrics(): UiMetrics
proc refreshMetrics(force = false): bool
proc rebuildFonts()
proc invalidateIconTextures()
proc setActiveTextInputArea()
```

### `src/input.nim`

Keep input behavior, but change window-event responsibilities.

Required work:

- Stop writing resize data into `config`
- On relevant window events, ask `gui.refreshMetrics()` whether scale/layout
  changed
- If metrics changed, redraw
- Update text-input area when command mode changes or selection bar changes

### `src/main.nim`

Keep the loop structure. Only adjust:

- imports
- event kinds/names if binding differences require it
- startup ordering so metrics/fonts are initialized after the SDL3 window and
  renderer exist

### `src/settings.nim`

Keep the config file stable, but clarify semantics internally:

- `winWidth` stays a logical width
- `lineHeight` stays a logical row height
- `winMaxHeight` is derived from logical values, not a mutable runtime window
  fact

No format break is required in the first migration.

### `NimLaunch.nimble`

Update dependencies and build notes:

- swap `sdl2` dependency to `sdl3`
- note `sdl3-ttf` and `sdl3-image` system requirements in documentation

If the local Nim package ecosystem does not expose `sdl3_image`, keep the
nimble dependency simple and ship a local wrapper module in `src/`.

## Phases

### Phase 1: Internal Cleanup Before API Port

- Introduce runtime metrics/state
- Stop mutating config from window events
- Centralize scaled layout calculations
- Keep SDL2 temporarily if needed while refactoring logic

Exit condition:

- backend logic no longer depends on config as mutable runtime window state

### Phase 2: SDL3 Backend Port

- Swap imports and backend types
- Create SDL3 window and renderer
- Switch text input, window sizing, and scale queries
- Restore current functionality without regressions

Exit condition:

- launcher builds and behaves like the SDL2 version on one monitor

### Phase 3: DPI/Scale Improvements

- enable high pixel density windows
- derive UI scale from SDL3 APIs
- rebuild fonts/icons when scale changes
- test on mixed-DPI setups and Wayland

Exit condition:

- fonts and icons remain crisp and correctly sized across monitors

### Phase 4: Optional SDL3 Enhancements

- improve IME placement with `setTextInputArea`
- refine renderer creation properties
- add better diagnostics for scale and display transitions

## Acceptance Criteria

The SDL3 migration is complete when all of the following are true:

- NimLaunch builds against SDL3 and SDL3_ttf
- icon loading works through SDL3-image or a local equivalent
- config file format remains backward compatible
- moving the launcher between displays updates font and icon scale correctly
- window redraws remain stable on Wayland and X11
- no resize event writes runtime compositor state back into persistent config
- window debug output can report logical size, pixel size, display scale, and
  pixel density

## Recommended First Implementation Slice

The best first code slice is not the import swap. It is:

1. add `UiMetrics`
2. stop mutating config on resize
3. route all layout sizes through metrics
4. add font/icon rebuild hooks

After that, the SDL3 API migration becomes much more mechanical and much less
fragile.

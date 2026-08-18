## Minimal SDL3_image wrapper used by NimLaunch.

import sdl3, std/strutils

when defined(windows):
  const ImgLibName* = "SDL3_image.dll"
elif defined(macosx):
  const ImgLibName* = "libSDL3_image.dylib"
else:
  const ImgLibName* = "libSDL3_image.so.0"

proc loadTexture*(renderer: Renderer; file: cstring): Texture {.
    importc: "IMG_LoadTexture", cdecl, dynlib: ImgLibName.}

proc loadSizedSvg*(src: IOStream; width, height: cint): ptr Surface {.
    importc: "IMG_LoadSizedSVG_IO", cdecl, dynlib: ImgLibName.}

proc load*(src: IOStream): ptr Surface {.
    importc: "IMG_Load_IO", cdecl, dynlib: ImgLibName.}

proc loadSizedSvgTexture*(renderer: Renderer; file: string; width, height: int): Texture =
  if file.len == 0 or renderer.isNil or width <= 0 or height <= 0:
    return nil

  let io = ioFromFile(file.cstring, "rb")
  if io.isNil:
    return nil
  defer:
    discard closeIO(io)

  let surface = loadSizedSvg(io, width.cint, height.cint)
  if surface.isNil:
    return nil
  defer:
    destroySurface(surface)

  createTextureFromSurface(renderer, surface)

proc loadIconSurface*(file: string; size: int): ptr Surface =
  if file.len == 0 or size <= 0:
    return nil
  let io = ioFromFile(file.cstring, "rb")
  if io.isNil:
    return nil
  defer:
    discard closeIO(io)
    
  let lower = file.toLowerAscii()
  if lower.endsWith(".svg"):
    result = loadSizedSvg(io, size.cint, size.cint)
  else:
    result = load(io)

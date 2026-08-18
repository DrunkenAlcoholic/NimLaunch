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

proc load*(file: cstring): ptr Surface {.
    importc: "IMG_Load", cdecl, dynlib: ImgLibName.}

proc loadIconSurface*(file: string; size: int): ptr Surface =
  if file.len == 0 or size <= 0:
    return nil
    
  let lower = file.toLowerAscii()
  if lower.endsWith(".svg"):
    let io = ioFromFile(file.cstring, "rb")
    if io.isNil:
      return nil
    result = loadSizedSvg(io, size.cint, size.cint)
    discard closeIO(io)
  else:
    result = load(file.cstring)

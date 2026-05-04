## Minimal SDL3_image wrapper used by NimLaunch.

import sdl3

when defined(windows):
  const ImgLibName* = "SDL3_image.dll"
elif defined(macosx):
  const ImgLibName* = "libSDL3_image.dylib"
else:
  const ImgLibName* = "libSDL3_image.so"

proc loadTexture*(renderer: Renderer; file: cstring): Texture {.
    importc: "IMG_LoadTexture", cdecl, dynlib: ImgLibName.}

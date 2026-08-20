import std/os

let root = thisDir()

# Vendored packages
switch("path", root / "packages" / "sdl3")
switch("path", root / "packages" / "parsetoml")

# Core runtime model (required for SDL3 image threads and ARC destructors)
switch("mm", "orc")
switch("threads", "on")

# Release optimizations
when defined(release):
  switch("d", "lto")
  switch("passC", "-ffunction-sections -fdata-sections")
  switch("passL", "-Wl,--gc-sections -s")

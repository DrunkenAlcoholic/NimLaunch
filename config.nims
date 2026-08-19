import std/os

let root = thisDir()

switch("path", root / "packages" / "sdl3")
switch("path", root / "packages" / "parsetoml")

when defined(release):
  switch("mm", "orc")
  switch("threads", "on")
  switch("d", "lto")
  switch("passC", "-ffunction-sections -fdata-sections")
  switch("passL", "-Wl,--gc-sections -s")

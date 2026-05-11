# Package

version       = "0.9.1"
author        = "Vyrnexis"
description   = "NimLaunch in SDL3 for native X11 and Wayland"
license       = "MIT"
srcDir        = "src"
bin           = @["nimlaunch"]

import std/[os, strutils]


# Dependencies

requires "nim >= 2.0"
requires "https://github.com/nim-lang/sdl3#3d98171f5aea71a29d639049372d4f570b2ddd5c"
requires "parsetoml"


proc firstResolvedDir(output: string): string =
  for line in output.splitLines():
    let candidate = line.strip()
    if candidate.len > 0 and dirExists(candidate):
      return candidate
  return ""

proc packageRoot(pkg: string): string =
  let res = gorgeEx("nimble path " & pkg)
  let root = firstResolvedDir(res.output)
  if root.len == 0:
    quit("NimLaunch.nimble: failed to resolve Nimble package path for '" & pkg & "'")
  root

proc compileWithResolvedPaths(flags, inputPath: string) =
  let nimExe = findExe("nim")
  if nimExe.len == 0:
    quit("NimLaunch.nimble: could not locate 'nim' in PATH")

  let sdl3Root = packageRoot("sdl3")
  let parsetomlRoot = packageRoot("parsetoml")
  let srcPath = getCurrentDir() / "src"

  let cmd = nimExe.quoteShell() & " c " &
    "--path:" & sdl3Root.quoteShell() & " " &
    "--path:" & parsetomlRoot.quoteShell() & " " &
    "--path:" & srcPath.quoteShell() & " " &
    flags & " " & inputPath.quoteShell()

  exec cmd


# Build tasks

# Native Nim builds
task nimRelease, "Release build optimized for current CPU (fastest local binary)":
  mkDir("bin")
  compileWithResolvedPaths("-d:release -d:danger --opt:speed --passC:'-march=native -mtune=native -ffunction-sections -fdata-sections' --passL:'-Wl,--gc-sections -s' -o:./bin/nimlaunch", "src/nimlaunch.nim")

task nimReleasePortable, "Release build with generic x86_64 baseline (portable)":
  mkDir("bin")
  compileWithResolvedPaths("-d:release --opt:size --passC:'-march=x86-64 -mtune=generic -ffunction-sections -fdata-sections' --passL:'-Wl,--gc-sections -s' -o:./bin/nimlaunch", "src/nimlaunch.nim")

task nimPortable, "Compatibility alias for nimReleasePortable":
  mkDir("bin")
  compileWithResolvedPaths("-d:release --opt:size --passC:'-march=x86-64 -mtune=generic -ffunction-sections -fdata-sections' --passL:'-Wl,--gc-sections -s' -o:./bin/nimlaunch", "src/nimlaunch.nim")

task nimDebug, "Debug build with native compiler":
  mkDir("bin")
  compileWithResolvedPaths("-d:debug --debuginfo --lineTrace:on --stackTrace:on --opt:none -o:./bin/nimlaunch", "src/nimlaunch.nim")

# Zig-based builds (portable)
task zigRelease, "Release build with Zig compiler optimized for current CPU":
  mkDir("bin")
  compileWithResolvedPaths("-d:release -d:danger --opt:speed --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=native -ffunction-sections -fdata-sections' --passL:'-target x86_64-linux-gnu -mcpu=native -Wl,--gc-sections -s' -o:./bin/nimlaunch", "./src/nimlaunch.nim")

task zigReleasePortable, "Release build with Zig compiler (portable)":
  mkDir("bin")
  compileWithResolvedPaths("-d:release --opt:size --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=x86_64 -ffunction-sections -fdata-sections' --passL:'-target x86_64-linux-gnu -mcpu=x86_64 -Wl,--gc-sections -s' -o:./bin/nimlaunch", "./src/nimlaunch.nim")

task zigPortable, "Compatibility alias for zigReleasePortable":
  mkDir("bin")
  compileWithResolvedPaths("-d:release --opt:size --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=x86_64 -ffunction-sections -fdata-sections' --passL:'-target x86_64-linux-gnu -mcpu=x86_64 -Wl,--gc-sections -s' -o:./bin/nimlaunch", "./src/nimlaunch.nim")

task zigDebug, "Debug build with Zig compiler":
  mkDir("bin")
  compileWithResolvedPaths("-d:debug --debuginfo --lineTrace:on --stackTrace:on --opt:none --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' -o:./bin/nimlaunch", "./src/nimlaunch.nim")

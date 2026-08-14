# Package

version       = "0.10.3"
author        = "Vyrnexis"
description   = "NimLaunch in SDL3 for native X11 and Wayland"
license       = "MIT"
srcDir        = "src"
bin           = @["nimlaunch"]


# Dependencies

requires "nim >= 2.0"

# Build tasks

const
  EntryPoint = "src/nimlaunch.nim"
  OutBin = "-o:./bin/nimlaunch"
  NativeReleaseFlags = "-d:release -d:danger --opt:speed --passC:'-march=native -mtune=native -ffunction-sections -fdata-sections' --passL:'-Wl,--gc-sections -s'"
  NativePortableFlags = "-d:release --opt:size --passC:'-march=x86-64 -mtune=generic -ffunction-sections -fdata-sections' --passL:'-Wl,--gc-sections -s'"
  NativeDebugFlags = "-d:debug --debuginfo --lineTrace:on --stackTrace:on --opt:none"
  ZigReleaseFlags = "-d:release -d:danger --opt:speed --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=native -ffunction-sections -fdata-sections' --passL:'-target x86_64-linux-gnu -mcpu=native -Wl,--gc-sections -s'"
  ZigPortableFlags = "-d:release --opt:size --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=x86_64 -ffunction-sections -fdata-sections' --passL:'-target x86_64-linux-gnu -mcpu=x86_64 -Wl,--gc-sections -s'"
  ZigDebugFlags = "-d:debug --debuginfo --lineTrace:on --stackTrace:on --opt:none --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc'"

proc runBuild(flags: string) =
  exec "nim c " & flags & " " & OutBin & " " & EntryPoint

# Native Nim builds
task nimRelease, "Release build optimized for current CPU (fastest local binary)":
  mkDir("bin")
  runBuild(NativeReleaseFlags)

task nimPortable, "Release build with generic x86_64 baseline (portable)":
  mkDir("bin")
  runBuild(NativePortableFlags)

task nimDebug, "Debug build with native compiler":
  mkDir("bin")
  runBuild(NativeDebugFlags)

# Zig-based builds (portable)
task zigRelease, "Release build with Zig compiler optimized for current CPU":
  mkDir("bin")
  runBuild(ZigReleaseFlags)

task zigPortable, "Release build with Zig compiler (portable)":
  mkDir("bin")
  runBuild(ZigPortableFlags)

task zigDebug, "Debug build with Zig compiler":
  mkDir("bin")
  runBuild(ZigDebugFlags)

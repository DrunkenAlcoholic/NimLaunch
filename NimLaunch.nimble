# Package

version       = "0.11.1"
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
  NativeReleaseFlags = "-d:release -d:danger --opt:speed --passC:'-march=native -mtune=native'"
  NativeGenericFlags = "-d:release -d:danger --opt:speed --passC:'-march=x86-64 -mtune=generic'"
  NativeDebugFlags = "-d:debug --mm:orc --threads:on --debuginfo --lineTrace:on --stackTrace:on --opt:none"
  ZigReleaseFlags = "-d:release -d:danger --opt:speed --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=native' --passL:'-target x86_64-linux-gnu'"
  ZigGenericFlags = "-d:release -d:danger --opt:speed --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc' --passC:'-target x86_64-linux-gnu -mcpu=x86_64' --passL:'-target x86_64-linux-gnu'"
  ZigDebugFlags = "-d:debug --mm:orc --threads:on --debuginfo --lineTrace:on --stackTrace:on --opt:none --cc:clang --clang.exe='./zigcc' --clang.linkerexe='./zigcc'"

proc runBuild(flags: string) =
  exec "nim c " & flags & " " & OutBin & " " & EntryPoint

task nimRelease, "Release build optimized for current CPU (fastest local binary)":
  mkDir("bin")
  runBuild(NativeReleaseFlags)

task nimGeneric, "Release build with generic x86_64 baseline (universal)":
  mkDir("bin")
  runBuild(NativeGenericFlags)

task nimDebug, "Debug build with native compiler":
  mkDir("bin")
  runBuild(NativeDebugFlags)

# Zig-based builds (generic)
task zigRelease, "Release build with Zig compiler optimized for current CPU":
  mkDir("bin")
  runBuild(ZigReleaseFlags)

task zigGeneric, "Release build with Zig compiler (universal)":
  mkDir("bin")
  runBuild(ZigGenericFlags)

task zigDebug, "Debug build with Zig compiler":
  mkDir("bin")
  runBuild(ZigDebugFlags)
task build, "Default build": nimReleaseTask()

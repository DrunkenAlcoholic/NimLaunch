import std/unittest
import ../src/parser

suite "Parser tests":
  test "tokenize basic args":
    let toks = tokenize("hello world")
    check toks == @["hello", "world"]

  test "tokenize quotes":
    let toks = tokenize("cmd -arg \"hello world\" 'foo bar'")
    check toks == @["cmd", "-arg", "hello world", "foo bar"]

  test "tokenize escapes":
    let toks = tokenize("cmd \"hello \\\"world\\\"\"")
    check toks == @["cmd", "hello \"world\""]

  test "stripFieldCodes":
    check stripFieldCodes("code %F") == "code "
    check stripFieldCodes("foo %u %i %c") == "foo   "
    check stripFieldCodes("100%% sure") == "100% sure"

  test "getBaseExec":
    check getBaseExec("/usr/bin/kitty --single-instance") == "kitty"
    check getBaseExec("code %F") == "code"
    check getBaseExec("env FOO=1 VAR=2 /opt/app/bin/foo %U") == "foo"
    check getBaseExec("flatpak run com.app.Name") == "com.app.Name"
    check getBaseExec("snap run app") == "app"
    check getBaseExec("sh -c 'prog --opt'") == "prog"
    check getBaseExec("sudo nano") == "nano"
    check getBaseExec("pkexec gparted") == "gparted"

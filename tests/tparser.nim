import std/unittest
import ../src/parser

suite "Parser and Tokenizer Tests":
  test "stripFieldCodes":
    check stripFieldCodes("code %F") == "code "
    check stripFieldCodes("foo %u %c") == "foo  "
    check stripFieldCodes("echo %%") == "echo %"
    check stripFieldCodes("app %X %Y") == "app  "
    
  test "tokenize":
    check tokenize("foo bar") == @["foo", "bar"]
    check tokenize("sh -c \"echo hello\"") == @["sh", "-c", "echo hello"]
    check tokenize("'single quote' test") == @["single quote", "test"]
    check tokenize("env FOO=1 bar") == @["env", "FOO=1", "bar"]
    check tokenize("exec \\\"escaped\\\"") == @["exec", "\"escaped\""]
    
  test "getBaseExec":
    check getBaseExec("/usr/bin/kitty --single-instance") == "kitty"
    check getBaseExec("code %F") == "code"
    check getBaseExec("env FOO=1 VAR=2 /opt/app/bin/foo %U") == "foo"
    check getBaseExec("flatpak run com.app.Name") == "com.app.Name"
    check getBaseExec("sh -c 'prog --opt'") == "prog"
    check getBaseExec("sudo nano") == "nano"
    check getBaseExec("pkexec /usr/bin/gparted") == "gparted"

import std/unittest
import ../src/fuzzy

suite "Fuzzy tests":
  test "subseqPositions":
    let t = "HelloWorld"
    check subseqPositions("hlw", t) == @[0, 2, 5]
    check subseqPositions("hld", t) == @[0, 2, 9]
    check subseqPositions("z", t) == newSeq[int]()

  test "scoreMatch exact and prefix":
    let t = "Firefox"
    let lt = "firefox"
    let q = "firefox"
    let sExact = scoreMatch(q, q, t, lt, "/usr/bin/firefox", "/home/user")
    let sPrefix = scoreMatch("fire", "fire", t, lt, "/usr/bin/firefox", "/home/user")
    check sExact > sPrefix

  test "scoreMatch typo tolerance":
    let t = "Terminal"
    let lt = "terminal"
    # One deletion: "termnal"
    let sTypo1 = scoreMatch("termnal", "termnal", t, lt, "/bin/term", "/home/user")
    # Exact match: "terminal"
    let sExact = scoreMatch("terminal", "terminal", t, lt, "/bin/term", "/home/user")
    check sTypo1 > 0
    check sExact > sTypo1

  test "scoreMatch adjacent transposition":
    let t = "Terminal"
    let lt = "terminal"
    # "terimnal" (swap i and m)
    let sTypo = scoreMatch("terimnal", "terimnal", t, lt, "/bin/term", "/home/user")
    check sTypo > 0

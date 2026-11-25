local layouts = require("punto.layouts")
local word = require("punto.word")

local ru = assert(layouts.get("ru(winkeys)"))
local en = assert(layouts.get("en(qwerty)"))
local is_word = word.predicate("word", ru, en)
local is_token = word.predicate("token", ru, en)

local function seg(line, col, predicate)
  return word.segment(line, col, predicate or is_word)
end

T.test("finds the word under the cursor", function()
  local s = seg("ghbdtn", 5)
  T.ok(s)
  T.eq(0, s.start_col)
  T.eq(6, s.end_col)
  T.eq("ghbdtn", s.text)

  s = seg("ghbdtn", 0)
  T.eq("ghbdtn", s.text)
end)

T.test("finds the last word when the cursor is after it", function()
  T.eq("ghbdtn", seg("ghbdtn ", 6).text)
  T.eq("ghbdtn", seg("ghbdtn, test", 6).text)
  T.eq("ghbdtn", seg("ghbdtn, test", 7).text)
  T.eq("test", seg("test ghbdtn", 4).text)
end)

T.test("handles multibyte cursor positions", function()
  local s = seg("привет", 0)
  T.eq("привет", s.text)

  s = seg("привет", 11)
  T.ok(s)
  T.eq("привет", s.text)
  T.eq(0, s.start_col)
  T.eq(12, s.end_col)
end)

T.test("returns nil when there is no word", function()
  T.eq(nil, seg("", 0))
  T.eq(nil, seg("123", 1))
  T.eq(nil, seg("  ghbdtn", 0))
end)

T.test("word scope ignores trailing punctuation", function()
  T.eq("ghbdtn", seg("ghbdtn?", 6).text)
end)

T.test("token scope includes trailing punctuation", function()
  local s = seg("ghbdtn?", 6, is_token)
  T.eq("ghbdtn?", s.text)
end)

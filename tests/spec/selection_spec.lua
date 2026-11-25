local selection = require("punto.selection")
local H = require("tests.helpers")

T.test("getregionpos() is available", function()
  T.eq(1, vim.fn.exists("*getregionpos"))
end)

T.test("extracts a charwise selection on one line", function()
  H.buf({ "abc привет def" })
  local segments = selection.visual_segments({
    p1 = { 0, 1, 5, 0 },
    p2 = { 0, 1, 9, 0 },
    type = "v",
  })
  T.eq(1, #segments)
  T.eq("при", segments[1].text)
  T.eq(4, segments[1].start_col)
  T.eq(10, segments[1].end_col)
end)

T.test("applies a single segment and places the cursor", function()
  H.buf({ "abc привет def" })
  local segments = selection.visual_segments({
    p1 = { 0, 1, 5, 0 },
    p2 = { 0, 1, 9, 0 },
    type = "v",
  })
  segments[1].new_text = "ПРИ"

  T.eq(true, selection.apply(0, segments))
  T.eq({ "abc ПРИвет def" }, H.lines())

  selection.place_cursor(segments)
  T.eq({ 1, 8 }, vim.api.nvim_win_get_cursor(0))
end)

T.test("extracts a linewise selection and skips empty lines", function()
  H.buf({ "abc", "", "xyz" })
  local segments = selection.visual_segments({
    p1 = { 0, 1, 1, 0 },
    p2 = { 0, 3, 3, 0 },
    type = "V",
  })
  T.eq(2, #segments)
  T.eq("abc", segments[1].text)
  T.eq("xyz", segments[2].text)
end)

T.test("extracts and applies a blockwise selection", function()
  H.buf({ "abcdef", "ghijkl" })
  local segments = selection.visual_segments({
    p1 = { 0, 1, 2, 0 },
    p2 = { 0, 2, 4, 0 },
    type = "\22",
  })
  T.eq(2, #segments)
  T.eq("bcd", segments[1].text)
  T.eq("hij", segments[2].text)

  segments[1].new_text = "BCD"
  segments[2].new_text = "HIJ"
  T.eq(true, selection.apply(0, segments))
  T.eq({ "aBCDef", "gHIJkl" }, H.lines())
end)

T.test("does not write when nothing changes", function()
  H.buf({ "abc" })
  local segments = selection.line_segments(1, 1)
  segments[1].new_text = "abc"
  T.eq(false, selection.apply(0, segments))
  T.eq({ "abc" }, H.lines())
end)

T.test("supports a numeric line range", function()
  H.buf({ "abc", "def", "ghi" })
  local segments = selection.line_segments(2, 3)
  T.eq(2, #segments)
  T.eq("def", segments[1].text)
  T.eq("ghi", segments[2].text)

  segments[1].new_text = "DEF"
  segments[2].new_text = "GHI"
  T.eq(true, selection.apply(0, segments))
  T.eq({ "abc", "DEF", "GHI" }, H.lines())
end)

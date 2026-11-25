local alphabets = require("punto.layouts.alphabets")
local layouts = require("punto.layouts")
local util = require("punto.util")

local BUILTINS = {
  "en(qwerty)",
  "ru(winkeys)",
  "ru(phonetic)",
  "ru(phonetic_winkeys)",
}

T.test("built-in layouts build and have expected shape", function()
  for _, id in ipairs(BUILTINS) do
    local layout = assert(layouts.get(id))
    T.eq(id, layout.id)
    T.eq(47, vim.tbl_count(layout.keys), id .. ": keys")
    T.eq(94, vim.tbl_count(layout.reverse), id .. ": reverse entries")
    T.eq(4, #layout.spec.rows, id .. ": rows")
    T.ok(
      type(layout.spec.alphabet) == "string" and #util.chars(layout.spec.alphabet) > 0,
      id .. ": alphabet exists"
    )
    T.eq(id:match("^en") and 52 or 66, #util.chars(layout.spec.alphabet), id .. ": alphabet size")
  end
end)

T.test("every alphabet character is mapped", function()
  for _, id in ipairs(BUILTINS) do
    local layout = assert(layouts.get(id))
    for _, ch in ipairs(util.chars(layout.spec.alphabet)) do
      T.ok(layout.alphabet_set[ch], id .. ": alphabet_set " .. ch)
      T.ok(layout.reverse[ch] ~= nil, id .. ": reverse " .. ch)
    end
  end
end)

T.test("aliases and unknown layouts", function()
  T.eq("ru(winkeys)", assert(layouts.get("ru")).id)
  T.eq("en(qwerty)", assert(layouts.get("en")).id)
  T.eq("en(qwerty)", assert(layouts.get("us")).id)

  local layout, err = layouts.get("xx(nope)")
  T.eq(nil, layout)
  T.ok(err and err:match("unknown layout"), "expected unknown layout error")
end)

T.test("phonetic and phonetic_winkeys differ on h/x/=", function()
  local phonetic = assert(layouts.get("ru(phonetic)"))
  local winkeys = assert(layouts.get("ru(phonetic_winkeys)"))

  T.eq("ч", phonetic.keys["="].plain)
  T.eq("ь", winkeys.keys["="].plain)
  T.eq("х", phonetic.keys["h"].plain)
  T.eq("ч", winkeys.keys["h"].plain)
  T.eq("ь", phonetic.keys["x"].plain)
  T.eq("х", winkeys.keys["x"].plain)
end)

T.test("phonetic_winkeys uses W for в and V for ж", function()
  local layout = assert(layouts.get("ru(phonetic_winkeys)"))
  T.eq("в", layout.keys["w"].plain)
  T.eq("ж", layout.keys["v"].plain)
  T.eq("w", layout.reverse["в"].key)
  T.eq("v", layout.reverse["ж"].key)
end)

T.test("register rejects duplicate characters", function()
  local qwerty = require("punto.layouts.qwerty")
  local rows = vim.deepcopy(qwerty.rows)
  rows[3][1] = "aasdfghjk;'" -- duplicate "a", same width

  T.raises(function()
    layouts.register({
      id = "xx(dup)",
      name = "Duplicate",
      alphabet = alphabets.latin,
      rows = rows,
    })
  end, "duplicate character")
end)

T.test("register accepts a valid custom layout", function()
  local qwerty = require("punto.layouts.qwerty")
  local rows = vim.deepcopy(qwerty.rows)
  local layout = layouts.register({
    id = "xx(test)",
    name = "Test",
    alphabet = alphabets.latin,
    rows = rows,
  })
  T.eq("xx(test)", layout.id)
  T.eq("xx(test)", assert(layouts.get("xx(test)")).id)
end)

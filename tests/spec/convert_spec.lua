local convert = require("punto.convert")
local layouts = require("punto.layouts")

local function L(id)
  return assert(layouts.get(id))
end

local function conv(text, from, to)
  return convert.convert(text, L(from), L(to))
end

T.test("converts en to ru(winkeys)", function()
  local text, changed = conv("ghbdtn", "en(qwerty)", "ru(winkeys)")
  T.eq("привет", text)
  T.eq(true, changed)
end)

T.test("converts ru(winkeys) to en", function()
  local text = conv("руддщ", "ru(winkeys)", "en(qwerty)")
  T.eq("hello", text)
end)

T.test("preserves case", function()
  T.eq("Привет", (conv("Ghbdtn", "en(qwerty)", "ru(winkeys)")))
  T.eq("Ghbdtn", (conv("Привет", "ru(winkeys)", "en(qwerty)")))
end)

T.test("converts punctuation by physical keys", function()
  T.eq("Привет,", (conv("Ghbdtn?", "en(qwerty)", "ru(winkeys)")))
  T.eq("&", (conv("?", "ru(winkeys)", "en(qwerty)")))
  T.eq(",", (conv("?", "en(qwerty)", "ru(winkeys)")))
  T.eq("?", (conv(",", "ru(winkeys)", "en(qwerty)")))
  T.eq("№", (conv("#", "en(qwerty)", "ru(winkeys)")))
  T.eq("ё", (conv("#", "en(qwerty)", "ru(phonetic_winkeys)")))
  T.eq("#", (conv("ё", "ru(phonetic_winkeys)", "en(qwerty)")))
end)

T.test("phonetic layouts use w for в and v for ж", function()
  T.eq("привет", (conv("priwet", "en(qwerty)", "ru(phonetic_winkeys)")))
  T.eq("прижет", (conv("privet", "en(qwerty)", "ru(phonetic_winkeys)")))
  T.eq("прижет", (conv("privet", "en(qwerty)", "ru(phonetic)")))
  T.eq("priwet", (conv("привет", "ru(phonetic_winkeys)", "en(qwerty)")))
end)

T.test("leaves unmapped characters alone", function()
  local text, changed = conv("123", "en(qwerty)", "ru(winkeys)")
  T.eq("123", text)
  T.eq(false, changed)

  text, changed = conv("hello мир", "en(qwerty)", "ru(winkeys)")
  T.eq("руддщ мир", text)
  T.eq(true, changed)
end)

T.test("round-trips all 94 characters of each layout", function()
  local latin = L("en(qwerty)")
  for _, id in ipairs({ "ru(winkeys)", "ru(phonetic)", "ru(phonetic_winkeys)" }) do
    local layout = L(id)
    for _, entry in pairs(layout.keys) do
      for _, ch in ipairs({ entry.plain, entry.shift }) do
        local latin_char = convert.convert(ch, layout, latin)
        local back = convert.convert(latin_char, latin, layout)
        T.eq(ch, back, id .. ": round-trip " .. ch)
      end
    end
  end
end)

T.test("detects direction from script", function()
  local ru = L("ru(winkeys)")
  local en = L("en(qwerty)")

  T.eq("to_ru", convert.detect_direction("ghbdtn", ru, en))
  T.eq("to_ru", convert.detect_direction("Ghbdtn", ru, en))
  T.eq("to_en", convert.detect_direction("привет", ru, en))
  T.eq("to_en", convert.detect_direction("ПРИВЕТ", ru, en))
  T.eq(nil, convert.detect_direction("123", ru, en))
  T.eq(nil, convert.detect_direction("ghbdtn привет", ru, en))
end)

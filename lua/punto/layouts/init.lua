local util = require("punto.util")

local M = {}

-- Canonical physical grid. Row order and widths are fixed: 13, 13, 11, 10.
local BASE_ROWS = {
  "`1234567890-=",
  "qwertyuiop[]\\",
  "asdfghjkl;'",
  "zxcvbnm,./",
}

local BUILTINS = {
  require("punto.layouts.qwerty"),
  require("punto.layouts.ru"),
  require("punto.layouts.ru_phonetic"),
  require("punto.layouts.ru_phonetic_winkeys"),
}

local ALIASES = {
  ru = "ru(winkeys)",
  en = "en(qwerty)",
  us = "en(qwerty)",
}

local specs = {}
for _, spec in ipairs(BUILTINS) do
  specs[spec.id] = spec
end

local cache = {}

local function fail(spec, msg)
  error(("punto layout %q: %s"):format(spec.id or "?", msg), 0)
end

---@param spec PuntoLayoutSpec
---@return PuntoLayout
local function build(spec)
  if type(spec) ~= "table" or type(spec.id) ~= "string" then
    error("punto: invalid layout spec", 0)
  end
  if not spec.id:match("^[%a][%w_%-]*%([%w_%-]+%)$") then
    fail(spec, "id must look like 'lang(variant)'")
  end
  if type(spec.rows) ~= "table" or #spec.rows ~= 4 then
    fail(spec, "expected 4 rows")
  end
  if type(spec.alphabet) ~= "string" or spec.alphabet == "" then
    fail(spec, "alphabet is required")
  end

  local layout = {
    id = spec.id,
    name = spec.name or spec.id,
    keys = {},
    reverse = {},
    alphabet_set = {},
    spec = spec,
  }

  for _, ch in ipairs(util.chars(spec.alphabet)) do
    layout.alphabet_set[ch] = true
  end

  for r = 1, 4 do
    local row = spec.rows[r]
    if type(row) ~= "table" or type(row[1]) ~= "string" or type(row[2]) ~= "string" then
      fail(spec, ("row %d must be { plain, shift }"):format(r))
    end
    local base = util.chars(BASE_ROWS[r])
    local plain = util.chars(row[1])
    local shift = util.chars(row[2])
    if #plain ~= #base or #shift ~= #base then
      fail(
        spec,
        ("row %d has %d plain / %d shift chars, expected %d"):format(r, #plain, #shift, #base)
      )
    end
    for i = 1, #base do
      local key = base[i]
      layout.keys[key] = { plain = plain[i], shift = shift[i] }
      for _, entry in ipairs({ { plain[i], false }, { shift[i], true } }) do
        local ch, is_shift = entry[1], entry[2]
        if layout.reverse[ch] then
          fail(spec, ("duplicate character %q"):format(ch))
        end
        layout.reverse[ch] = { key = key, shift = is_shift }
      end
    end
  end

  for ch in pairs(layout.alphabet_set) do
    if not layout.reverse[ch] then
      fail(spec, ("alphabet character %q is not mapped"):format(ch))
    end
  end

  return layout
end

---@param id string
---@return string
function M.resolve(id)
  if type(id) ~= "string" then
    return id
  end
  return ALIASES[id] or id
end

---@param id string
---@return PuntoLayout|nil, string|nil
function M.get(id)
  local resolved = M.resolve(id)
  if cache[resolved] then
    return cache[resolved]
  end
  local spec = specs[resolved]
  if not spec then
    return nil,
      ("unknown layout %q; available: %s"):format(tostring(resolved), table.concat(M.list(), ", "))
  end
  local ok, built = pcall(build, spec)
  if not ok then
    return nil, built
  end
  cache[resolved] = built
  return built
end

---Register a custom layout. Errors on invalid specs.
---@param spec PuntoLayoutSpec
---@return PuntoLayout
function M.register(spec)
  local built = build(spec)
  specs[built.id] = spec
  cache[built.id] = built
  return built
end

---@return string[]
function M.list()
  local ids = {}
  for id in pairs(specs) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  return ids
end

---Split "lang(variant)" into its parts.
---@param id string
---@return string|nil lang
---@return string|nil variant
function M.parse(id)
  if type(id) ~= "string" then
    return nil
  end
  return id:match("^([%a][%w_%-]*)%(([%w_%-]+)%)$")
end

return M

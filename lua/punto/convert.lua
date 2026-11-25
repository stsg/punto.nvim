local util = require("punto.util")

local M = {}

---Convert text character by character by physical key position.
---@param text string
---@param from PuntoLayout
---@param to PuntoLayout
---@return string text
---@return boolean changed
function M.convert(text, from, to)
  local out, changed = {}, false
  for _, ch in ipairs(util.chars(text)) do
    local replacement = ch
    local hit = from.reverse[ch]
    if hit then
      local target = to.keys[hit.key]
      if target then
        replacement = hit.shift and target.shift or target.plain
      end
    end
    if replacement ~= ch then
      changed = true
    end
    out[#out + 1] = replacement
  end
  return table.concat(out), changed
end

---Pick a conversion direction from the script of the text.
---Returns nil for text without letters and for mixed-script text.
---@param text string
---@param layout PuntoLayout configured (Cyrillic) layout
---@param latin PuntoLayout Latin layout
---@return "to_ru"|"to_en"|nil
function M.detect_direction(text, layout, latin)
  local n_layout, n_latin = 0, 0
  for _, ch in ipairs(util.chars(text)) do
    if layout.alphabet_set[ch] then
      n_layout = n_layout + 1
    elseif latin.alphabet_set[ch] then
      n_latin = n_latin + 1
    end
  end

  if n_layout > 0 and n_latin == 0 then
    return "to_en"
  end
  if n_latin > 0 and n_layout == 0 then
    return "to_ru"
  end
  return nil
end

return M

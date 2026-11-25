local util = require("punto.util")

local M = {}

---Build a word predicate for the current scope.
---@param scope "word"|"token"
---@param layout PuntoLayout
---@param latin PuntoLayout
---@return fun(ch: string): boolean
function M.predicate(scope, layout, latin)
  if scope == "token" then
    return function(ch)
      return ch:match("%s") == nil
    end
  end
  return function(ch)
    return layout.alphabet_set[ch] == true or latin.alphabet_set[ch] == true
  end
end

---Find the word at or immediately before the cursor.
---@param line string
---@param cursor_col integer 0-based byte column
---@param is_word fun(ch: string): boolean
---@return { start_col: integer, end_col: integer, text: string }|nil
function M.segment(line, cursor_col, is_word)
  local spans = util.char_spans(line)
  if #spans == 0 then
    return nil
  end

  local i = util.index_of_span(spans, cursor_col)
  if i < 1 then
    return nil
  end

  -- If the cursor is not on a word character, take the nearest word to the left.
  if not is_word(spans[i].ch) then
    i = i - 1
    while i >= 1 and not is_word(spans[i].ch) do
      i = i - 1
    end
  end
  if i < 1 then
    return nil
  end

  local left, right = i, i
  while left > 1 and is_word(spans[left - 1].ch) do
    left = left - 1
  end
  while right < #spans and is_word(spans[right + 1].ch) do
    right = right + 1
  end

  local start_col = spans[left].start
  local end_col = spans[right].stop
  return {
    start_col = start_col,
    end_col = end_col,
    text = util.sub(line, start_col, end_col),
  }
end

return M

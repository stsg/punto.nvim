local M = {}

-- Matches one UTF-8 character (including 4-byte sequences).
local UTF8_PATTERN = "[%z\1-\127\194-\244][\128-\191]*"

---Split a string into UTF-8 characters.
---@param s string
---@return string[]
function M.chars(s)
  local out = {}
  for ch in s:gmatch(UTF8_PATTERN) do
    out[#out + 1] = ch
  end
  return out
end

---@class PuntoCharSpan
---@field ch string
---@field start integer 0-based byte offset (inclusive)
---@field stop integer 0-based byte offset (exclusive)

---Split a string into characters with 0-based byte offsets.
---@param s string
---@return PuntoCharSpan[]
function M.char_spans(s)
  local spans, pos = {}, 0
  for ch in s:gmatch(UTF8_PATTERN) do
    spans[#spans + 1] = { ch = ch, start = pos, stop = pos + #ch }
    pos = pos + #ch
  end
  return spans
end

---Find the index of the character span containing a byte offset.
---@param spans PuntoCharSpan[]
---@param col integer 0-based byte offset
---@return integer index or -1
function M.index_of_span(spans, col)
  for i = 1, #spans do
    local span = spans[i]
    if col >= span.start and col < span.stop then
      return i
    end
  end
  return -1
end

---Clamp a byte column to the start of the character containing it.
---@param line string
---@param col integer 0-based byte offset
---@return integer
function M.snap_to_char_start(line, col)
  if line == "" then
    return 0
  end
  col = math.max(0, math.min(col, #line - 1))
  local char_idx = vim.fn.charidx(line, col)
  if char_idx < 0 then
    return 0
  end
  return vim.fn.byteidx(line, char_idx)
end

---Return the 0-based exclusive byte offset just after the character at col.
---@param line string
---@param col_1based integer 1-based byte offset of the last selected character
---@return integer
function M.end_exclusive(line, col_1based)
  if line == "" or col_1based < 1 then
    return 0
  end
  if col_1based > #line then
    return #line
  end
  local char_idx = vim.fn.charidx(line, col_1based - 1)
  if char_idx < 0 then
    return #line
  end
  return vim.fn.byteidx(line, char_idx + 1)
end

---Extract a byte range. `end_col` is exclusive and 0-based.
---@param line string
---@param start_col integer
---@param end_col integer
---@return string
function M.sub(line, start_col, end_col)
  return line:sub(start_col + 1, end_col)
end

---Replace a byte range. `end_col` is exclusive and 0-based.
---@param line string
---@param start_col integer
---@param end_col integer
---@param replacement string
---@return string
function M.replace(line, start_col, end_col, replacement)
  return line:sub(1, start_col) .. replacement .. line:sub(end_col + 1)
end

---Notify through vim.notify unless notifications are disabled in the config.
---@param msg string
---@param level integer|nil
function M.notify(msg, level)
  local ok, cfg = pcall(function()
    return require("punto.config").get()
  end)
  if ok and not cfg.notify then
    return
  end
  local prefix = msg:match("^punto:") and "" or "punto: "
  vim.notify(prefix .. msg, level or vim.log.levels.WARN, { title = "punto" })
end

return M

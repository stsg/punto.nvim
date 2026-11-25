local util = require("punto.util")

local M = {}

---@param line string
---@param lnum integer
---@param start_col integer
---@param end_col integer
---@return table|nil
local function make_segment(line, lnum, start_col, end_col)
  if line == "" or end_col <= start_col then
    return nil
  end
  return {
    lnum = lnum,
    start_col = start_col,
    end_col = end_col,
    text = util.sub(line, start_col, end_col),
  }
end

---Build segments for the last visual selection.
---@param opts { p1?: table, p2?: table, type?: string }|nil
---@return table[]
function M.visual_segments(opts)
  opts = opts or {}
  local p1 = opts.p1 or vim.fn.getpos("'<")
  local p2 = opts.p2 or vim.fn.getpos("'>")
  local type_ = opts.type
  if type_ == nil or type_ == "" then
    type_ = vim.fn.visualmode()
  end
  if type_ == nil or type_ == "" then
    type_ = "v"
  end

  local ranges = vim.fn.getregionpos(p1, p2, { type = type_ })
  local out = {}
  for _, range in ipairs(ranges) do
    local lnum = range[1][2]
    local line = vim.fn.getline(lnum)
    local start_1based = range[1][3]
    local end_1based = range[2][3]
    if line ~= "" and start_1based > 0 and end_1based > 0 then
      local segment = make_segment(
        line,
        lnum,
        start_1based - 1,
        util.end_exclusive(line, end_1based)
      )
      if segment then
        out[#out + 1] = segment
      end
    end
  end
  return out
end

---Build segments for a whole-line range.
---@param line1 integer
---@param line2 integer
---@return table[]
function M.line_segments(line1, line2)
  local out = {}
  for lnum = line1, line2 do
    local line = vim.fn.getline(lnum)
    local segment = make_segment(line, lnum, 0, #line)
    if segment then
      out[#out + 1] = segment
    end
  end
  return out
end

---Apply segments with `new_text` to the buffer in one write.
---@param buf integer
---@param segments table[]
---@return boolean changed
function M.apply(buf, segments)
  if #segments == 0 then
    return false
  end

  table.sort(segments, function(a, b)
    return a.lnum < b.lnum
  end)

  local first = segments[1].lnum
  local last = segments[#segments].lnum
  local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  assert(#lines == last - first + 1, "punto: inconsistent line range")

  local changed = false
  for _, segment in ipairs(segments) do
    local index = segment.lnum - first + 1
    local line = lines[index]
    local current_text = util.sub(line, segment.start_col, segment.end_col)
    if segment.new_text ~= nil and current_text ~= segment.new_text then
      lines[index] = util.replace(line, segment.start_col, segment.end_col, segment.new_text)
      changed = true
    end
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, first - 1, last, false, lines)
  end
  return changed
end

---Put the cursor at the last character of the last edited segment.
---@param segments table[]
function M.place_cursor(segments)
  if #segments == 0 then
    return
  end
  local segment = segments[#segments]
  if segment.new_text == nil then
    return
  end
  local line = vim.fn.getline(segment.lnum)
  if line == "" then
    return
  end
  local col = segment.start_col + #segment.new_text - 1
  col = util.snap_to_char_start(line, col)
  vim.api.nvim_win_set_cursor(0, { segment.lnum, col })
end

return M

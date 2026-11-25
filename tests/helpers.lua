local H = {}

---Create a scratch buffer and make it current.
---@param lines string[]
---@return integer
function H.buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "" })
  return buf
end

---@param buf integer|nil
---@return string[]
function H.lines(buf)
  return vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false)
end

---@param lnum integer
---@param col integer
function H.cursor(lnum, col)
  vim.api.nvim_win_set_cursor(0, { lnum, col })
end

---Load a fresh buffer from a temp file so that undo history starts empty.
---@param lines string[]
---@return string path
function H.edit_file(lines)
  local path = vim.fn.tempname()
  vim.fn.writefile(lines, path)
  vim.cmd("silent! enew!")
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return path
end

---@param path string
function H.rm(path)
  pcall(vim.fn.delete, path)
end

return H

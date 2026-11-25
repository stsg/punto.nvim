local config = require("punto.config")
local layouts = require("punto.layouts")
local convert = require("punto.convert")
local word = require("punto.word")
local selection = require("punto.selection")
local util = require("punto.util")

local M = {}

M.layouts = layouts

local state = { maps = {} }

local VALID_DIRECTIONS = { auto = true, to_ru = true, to_en = true }

local function notify(msg, level)
  util.notify(msg, level)
end

local function ensure_command()
  if vim.fn.exists(":PuntoSwitch") == 2 then
    return
  end

  vim.api.nvim_create_user_command("PuntoSwitch", function(cmd)
    local opts = { direction = cmd.args ~= "" and cmd.args or nil }
    if cmd.range == 0 then
      opts.mode = "normal"
    else
      local p1, p2 = vim.fn.getpos("'<"), vim.fn.getpos("'>")
      local visual_mode = vim.fn.visualmode()
      if p1[2] == cmd.line1 and p2[2] == cmd.line2 and visual_mode ~= "" then
        opts.mode = "visual"
        opts.p1, opts.p2, opts.type = p1, p2, visual_mode
      else
        opts.mode = "lines"
        opts.line1, opts.line2 = cmd.line1, cmd.line2
      end
    end
    M.switch(opts)
  end, {
    range = true,
    nargs = "?",
    complete = function()
      return { "auto", "to_ru", "to_en" }
    end,
    desc = "Punto: convert text between keyboard layouts",
  })
end

local function buffer_allowed(cfg)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].binary or not vim.bo[buf].modifiable then
    notify("buffer is not modifiable")
    return false
  end
  if vim.tbl_contains(cfg.ignore_buftypes, vim.bo[buf].buftype) then
    return false
  end
  if vim.tbl_contains(cfg.ignore_filetypes, vim.bo[buf].filetype) then
    return false
  end
  return true
end

---@param cfg table
---@param text string
---@return "to_ru"|"to_en"|nil
local function detect_direction(cfg, text)
  local layout = assert(layouts.get(cfg.layout))
  local latin = assert(layouts.get(cfg.latin_layout))
  local direction = convert.detect_direction(text, layout, latin)
  if not direction then
    notify("nothing to convert (no letters or mixed script); use :PuntoSwitch to_ru/to_en")
  end
  return direction
end

---@param cfg table
---@param opts table
---@return table[]|nil
local function build_segments(cfg, opts)
  local mode = opts.mode or "normal"

  if mode == "normal" then
    local layout = assert(layouts.get(cfg.layout))
    local latin = assert(layouts.get(cfg.latin_layout))
    local is_word = word.predicate(cfg.normal_scope, layout, latin)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local segment = word.segment(vim.api.nvim_get_current_line(), cursor[2], is_word)
    if not segment then
      notify("no word to convert")
      return nil
    end
    segment.lnum = cursor[1]
    return { segment }
  end

  if mode == "visual" then
    local segments = selection.visual_segments(opts)
    if #segments == 0 then
      notify("empty selection")
      return nil
    end
    return segments
  end

  if mode == "lines" then
    local segments = selection.line_segments(opts.line1, opts.line2)
    if #segments == 0 then
      notify("nothing to convert")
      return nil
    end
    return segments
  end

  error(("punto: invalid mode %q"):format(tostring(mode)), 0)
end

---@param opts table
---@return boolean
local function do_switch(opts)
  local cfg = config.get()
  if not buffer_allowed(cfg) then
    return false
  end

  local segments = build_segments(cfg, opts)
  if not segments then
    return false
  end

  local direction = opts.direction or cfg.direction
  if not VALID_DIRECTIONS[direction] then
    error(("punto: invalid direction %q"):format(tostring(direction)), 0)
  end

  if direction == "auto" then
    local text = {}
    for _, segment in ipairs(segments) do
      text[#text + 1] = segment.text
    end
    direction = detect_direction(cfg, table.concat(text, "\n"))
    if not direction then
      return false
    end
  end

  local layout = assert(layouts.get(cfg.layout))
  local latin = assert(layouts.get(cfg.latin_layout))
  local from, to
  if direction == "to_ru" then
    from, to = latin, layout
  else
    from, to = layout, latin
  end

  local any_changed = false
  for _, segment in ipairs(segments) do
    local converted, changed = convert.convert(segment.text, from, to)
    segment.new_text = converted
    any_changed = any_changed or changed
  end

  if not any_changed then
    notify("nothing to convert")
    return false
  end

  local changed = selection.apply(vim.api.nvim_get_current_buf(), segments)
  if changed then
    selection.place_cursor(segments)
  end
  return changed
end

---Run a conversion for the current buffer window.
---@param opts table|nil
---@return boolean changed
function M.switch(opts)
  local ok, result = pcall(do_switch, opts or {})
  if not ok then
    notify(tostring(result), vim.log.levels.ERROR)
    return false
  end
  return result
end

---Configure keymaps and the user command.
---@param opts table|nil
---@return table config
function M.setup(opts)
  local cfg = config.setup(opts)
  ensure_command()

  for _, map in ipairs(state.maps) do
    pcall(vim.keymap.del, map.mode, map.lhs)
  end
  state.maps = {}

  if cfg.keymap.normal then
    vim.keymap.set("n", cfg.keymap.normal, "<Cmd>PuntoSwitch<CR>", {
      desc = "Punto: switch layout",
    })
    state.maps[#state.maps + 1] = { mode = "n", lhs = cfg.keymap.normal }
  end
  if cfg.keymap.visual then
    vim.keymap.set("x", cfg.keymap.visual, ":<C-u>'<,'>PuntoSwitch<CR>", {
      desc = "Punto: switch layout",
    })
    state.maps[#state.maps + 1] = { mode = "x", lhs = cfg.keymap.visual }
  end

  return cfg
end

---Convert a string without touching the buffer.
---@param text string
---@param opts { direction?: string, layout?: string, latin_layout?: string }|nil
---@return string text
---@return boolean changed
function M.convert(text, opts)
  opts = opts or {}
  local cfg = config.get()

  local layout, err = layouts.get(opts.layout or cfg.layout)
  if not layout then
    error("punto: " .. err, 0)
  end
  local latin
  latin, err = layouts.get(opts.latin_layout or cfg.latin_layout)
  if not latin then
    error("punto: " .. err, 0)
  end

  local direction = opts.direction or cfg.direction
  if not VALID_DIRECTIONS[direction] then
    error(("punto: invalid direction %q"):format(tostring(direction)), 0)
  end
  if direction == "auto" then
    direction = convert.detect_direction(text, layout, latin)
    if not direction then
      return text, false
    end
  end

  local from, to
  if direction == "to_ru" then
    from, to = latin, layout
  else
    from, to = layout, latin
  end
  return convert.convert(text, from, to)
end

---Register a custom layout.
---@param spec PuntoLayoutSpec
---@return PuntoLayout
function M.register_layout(spec)
  return layouts.register(spec)
end

return M

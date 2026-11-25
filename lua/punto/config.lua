local layouts = require("punto.layouts")

local DEFAULTS = {
  layout = "ru(phonetic_winkeys)",
  latin_layout = "en(qwerty)",
  direction = "auto",
  keymap = "<Leader>sw",
  normal_scope = "word",
  notify = true,
  ignore_buftypes = { "terminal", "prompt" },
  ignore_filetypes = {},
}

local VALID_DIRECTIONS = { auto = true, to_ru = true, to_en = true }
local VALID_SCOPES = { word = true, token = true }

local M = {}

local current = nil

---@param list table
---@return table
local function copy_list(list)
  local out = {}
  for i = 1, #list do
    out[i] = list[i]
  end
  return out
end

---@param keymap string|boolean|table
---@return { normal: string|false, visual: string|false }
local function normalize_keymap(keymap)
  if keymap == nil or keymap == false then
    return { normal = false, visual = false }
  end
  if type(keymap) == "string" then
    if keymap == "" then
      error("punto: keymap must not be an empty string", 0)
    end
    return { normal = keymap, visual = keymap }
  end
  if type(keymap) == "table" then
    local out = {
      normal = keymap.normal == nil and false or keymap.normal,
      visual = keymap.visual == nil and false or keymap.visual,
    }
    for _, value in ipairs({ out.normal, out.visual }) do
      if value ~= false and (type(value) ~= "string" or value == "") then
        error("punto: keymap values must be non-empty strings or false", 0)
      end
    end
    return out
  end
  error("punto: keymap must be a string, false or table", 0)
end

---@param cfg table
---@return table
local function validate(cfg)
  local layout, err = layouts.get(cfg.layout)
  if not layout then
    error("punto: " .. err, 0)
  end
  local latin
  latin, err = layouts.get(cfg.latin_layout)
  if not latin then
    error("punto: " .. err, 0)
  end
  if layouts.resolve(cfg.layout) == layouts.resolve(cfg.latin_layout) then
    error("punto: layout and latin_layout must be different", 0)
  end
  if not VALID_DIRECTIONS[cfg.direction] then
    error(
      ("punto: invalid direction %q (expected auto, to_ru or to_en)"):format(
        tostring(cfg.direction)
      ),
      0
    )
  end
  if not VALID_SCOPES[cfg.normal_scope] then
    error(
      ("punto: invalid normal_scope %q (expected word or token)"):format(
        tostring(cfg.normal_scope)
      ),
      0
    )
  end
  if type(cfg.notify) ~= "boolean" then
    error("punto: notify must be boolean", 0)
  end
  for _, name in ipairs({ "ignore_buftypes", "ignore_filetypes" }) do
    if type(cfg[name]) ~= "table" then
      error("punto: " .. name .. " must be a list", 0)
    end
  end
  cfg.keymap = normalize_keymap(cfg.keymap)
  return cfg
end

---Apply user options and validate them.
---@param opts table|nil
---@return table
function M.setup(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    error("punto: setup() expects a table", 0)
  end

  local cfg = vim.deepcopy(DEFAULTS)
  local unknown = {}
  for key, value in pairs(opts) do
    if DEFAULTS[key] == nil then
      unknown[#unknown + 1] = key
    end
    cfg[key] = value
  end

  validate(cfg)
  cfg.ignore_buftypes = copy_list(cfg.ignore_buftypes)
  cfg.ignore_filetypes = copy_list(cfg.ignore_filetypes)
  current = cfg

  for _, key in ipairs(unknown) do
    vim.notify(("punto: unknown option %q"):format(key), vim.log.levels.WARN, { title = "punto" })
  end
  return cfg
end

---Initialize defaults lazily without creating keymaps or commands.
---@return table
function M.ensure()
  if not current then
    local cfg = vim.deepcopy(DEFAULTS)
    validate(cfg)
    current = cfg
  end
  return current
end

---@return table
function M.get()
  return M.ensure()
end

---Reset configuration (tests).
function M.reset()
  current = nil
end

---@return boolean
function M.is_setup()
  return current ~= nil
end

---@return table
function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

return M

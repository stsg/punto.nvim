local M = {}

function M.check()
  local health = vim.health
  health.start("punto")

  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim >= 0.11")
  else
    health.error("Neovim >= 0.11 is required")
  end

  if vim.fn.exists("*getregionpos") == 1 then
    health.ok("getregionpos() is available")
  else
    health.error("getregionpos() is unavailable; visual mode will not work")
  end

  local ok, cfg = pcall(function()
    return require("punto.config").get()
  end)
  if not ok then
    health.error(tostring(cfg))
    return
  end

  local layouts = require("punto.layouts")
  for _, name in ipairs({ "layout", "latin_layout" }) do
    local layout, err = layouts.get(cfg[name])
    if layout then
      health.ok(("%s = %s (%d keys)"):format(name, layout.id, vim.tbl_count(layout.keys)))
    else
      health.error(("%s: %s"):format(name, tostring(err)))
    end
  end

  health.info(("direction = %s, normal_scope = %s"):format(cfg.direction, cfg.normal_scope))

  local keymap = cfg.keymap or {}
  if keymap.normal or keymap.visual then
    health.ok(
      ("keymap: normal = %s, visual = %s"):format(
        tostring(keymap.normal or "off"),
        tostring(keymap.visual or "off")
      )
    )
  else
    health.warn("keymaps are disabled; use :PuntoSwitch")
  end

  if vim.fn.exists(":PuntoSwitch") == 2 then
    health.ok(":PuntoSwitch is registered")
  else
    health.warn(":PuntoSwitch is not registered; call setup()")
  end
end

return M

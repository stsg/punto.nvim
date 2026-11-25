local root = vim.fn.getcwd()

vim.opt.runtimepath:prepend(root)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.opt.undofile = false
vim.opt.more = false

package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

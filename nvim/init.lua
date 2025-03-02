-- Leader key configuration
vim.g.mapleader = ' '

-- Transparent background settings
vim.cmd([[
  augroup TransparentBackground
    autocmd!
    autocmd ColorScheme * highlight Normal ctermbg=none guibg=none
    autocmd ColorScheme * highlight NonText ctermbg=none guibg=none
  augroup END
]])

-- Lazy.nvim setup
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Strike-through highlighting
vim.api.nvim_set_hl(0, "@text.strike", { strikethrough = true })
require("lazy").setup("cachebag.plugins")

-- Basic editor settings
vim.opt.background = "dark"
vim.cmd([[colorscheme gruvbox-material]])
vim.opt.clipboard = 'unnamedplus'
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.smartindent = true
vim.opt.cindent = true
vim.opt.autoindent = true

-- Window navigation keybindings
vim.keymap.set('n', '<C-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<C-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<C-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { noremap = true, silent = true })
vim.keymap.set('n', '<D-Left>', ':bprevious<CR>', { noremap = true, silent = true })  -- ⌘ + Left for previous buffer
vim.keymap.set('n', '<D-Right>', ':bnext<CR>', { noremap = true, silent = true })  -- ⌘ + Right for next buffer
vim.keymap.set('n', '<D-Left>', ':tabprevious<CR>', { noremap = true, silent = true })  -- ⌘ + Left for previous tab
vim.keymap.set('n', '<D-Right>', ':tabnext<CR>', { noremap = true, silent = true })  -- ⌘ + Right for next tab


-- NvimTree keybinding
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Telescope keybindings
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

-- Encoding settings
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'

-- Python configuration
vim.g.python3_host_prog = vim.fn.expand("~/.config/nvim/env/bin/python3")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.textwidth = 88
  end,
})

-- C++ configuration
vim.api.nvim_create_autocmd("FileType", {
  pattern = "cpp",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.cindent = true
  end,
})

-- LSP configuration
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  end,
})

-- Completion settings
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- Performance settings
vim.opt.updatetime = 250

-- Diagnostic icons
local signs = {
  Error = "",
  Warn = "",
  Hint = "",
  Info = ""
}

for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.g.copilot_enabled = false


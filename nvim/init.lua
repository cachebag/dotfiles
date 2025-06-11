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
vim.keymap.set('n', '<D-Left>', ':bprevious<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<D-Right>', ':bnext<CR>', { noremap = true, silent = true })

-- NvimTree keybinding
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Telescope keybindings (wrapped in pcall to avoid errors if not installed)
pcall(function()
  local builtin = require('telescope.builtin')
  vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
  vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
  vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
  vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})
end)

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

-- Rust configuration
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.textwidth = 100
  end,
})

-- LSP configuration
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable inlay hints if available
    if vim.lsp.inlay_hint then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
    
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<leader>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
    
    -- Rust-specific keybindings
    if vim.bo[ev.buf].filetype == 'rust' then
      vim.keymap.set('n', '<leader>rr', ':!cargo run<CR>', opts)
      vim.keymap.set('n', '<leader>rt', ':!cargo test<CR>', opts)
      vim.keymap.set('n', '<leader>rb', ':!cargo build<CR>', opts)
      vim.keymap.set('n', '<leader>rc', ':!cargo check<CR>', opts)
      vim.keymap.set('n', '<leader>rC', ':!cargo clippy<CR>', opts)
    end
  end,
})

-- Completion settings
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- Performance settings
vim.opt.updatetime = 250

-- Diagnostic configuration
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Diagnostic icons
local signs = {
  Error = "",
  Warn = "",
  Hint = "",
  Info = ""
}

for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- Disable copilot by default
vim.g.copilot_enabled = false

-- Additional useful settings
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Clear search highlighting with Escape
vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>', { silent = true })

-- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

-- Move selected lines up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

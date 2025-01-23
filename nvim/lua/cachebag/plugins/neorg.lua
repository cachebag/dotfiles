-- ~/.config/nvim/lua/cachebag/plugins/neorg.lua
return {
    'nvim-neorg/neorg',
    build = ":Neorg sync-parsers",
    dependencies = { 
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "nvim-neorg/neorg-telescope",
        "hrsh7th/nvim-cmp",  -- Add nvim-cmp as dependency
    },
    config = function()
        require('neorg').setup({
            load = {
                ["core.defaults"] = {},  -- Loads default behaviour
                ["core.concealer"] = {  -- Adds pretty icons to your documents
                    config = {
                        folds = true,
                        icon_preset = "diamond",
                        icons = {
                            heading = {
                                icons = {"◆", "◈", "◇", "⋄", "▫", "∙"}  -- Six levels of headings
                            },
                            list = {
                                icons = {"•", "◦", "▪", "▫", "∙", "⋅"}  -- Six levels of lists
                            },
                            quote = {
                                icon = "❝",
                                highlight = "NeorgQuote"
                            },
                            todo = {
                                done = { icon = "✓" },
                                pending = { icon = "●" },
                                undone = { icon = " " },
                                uncertain = { icon = "?" },
                                urgent = { icon = "!" },
                                recurring = { icon = "↺" },
                                on_hold = { icon = "=" },
                                cancelled = { icon = "✗" }
                            }
                        }
                    }
                },
                ["core.dirman"] = {  -- Manages Neorg workspaces
                    config = {
                        workspaces = {
                            notes = "~/notes",
                            journal = "~/journal"
                        },
                        default_workspace = "notes"
                    }
                },
                ["core.completion"] = {
                    config = {
                        engine = "nvim-cmp"
                    }
                },  -- Enables completion support
                ["core.integrations.telescope"] = {},  -- Enable telescope integration
                ["core.keybinds"] = {  -- Configure core.keybinds
                    config = {
                        default_keybinds = true,
                        neorg_leader = "<Leader>n"
                    }
                },
                ["core.journal"] = {}, -- Enables journal support
                ["core.summary"] = {},  -- Enables summary support
                ["core.export"] = {},   -- Enable export support
                ["core.ui"] = {},       -- Enables UI support
            }
        })
    end,
    ft = "norg"
}

-- ~/.config/nvim/lua/cachebag/plugins/neorg.lua
return {
    'nvim-neorg/neorg',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
        require('neorg').setup {
            load = {
                ["core.defaults"] = {},

                ["core.dirman"] = {
                    config = {
                        workspaces = {
                            my_workspace = "~/neorg"
                        }
                    }
                },

                ["core.concealer"] = {
                    config = {
                        folds = true,               -- Enable folding for .norg files
                        icon_preset = "diamond",    -- Choose icon preset
                        icons = {
                            heading = {
                                icons = {"◆", "◇", "◈"}   -- Icons for headings
                            },
                            list = {
                                icons = {"•", "◦", "▪"}    -- Icons for lists
                            },
                            quote = {
                                icon = "❝"                -- Icon for quotes
                            },
                            todo = {
                                done = { icon = "✓" },    -- Icon for completed tasks
                                pending = { icon = "●" }, -- Icon for pending tasks
                                undone = { icon = " " }   -- Hide asterisks for undone tasks
                            }
                        }
                    }
                },

                ["core.autocommands"] = {},
                ["core.integrations.treesitter"] = {}
            }
        }
    end,
    ft = "norg"
}


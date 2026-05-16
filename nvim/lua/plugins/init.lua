local overrides = require "configs.overrides"

return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    config = function()
      require "configs.conform"
    end,
  },
  "nvm-lua/plenary.nvim",
  {
    "nvchad/ui",
    config = function()
      require "nvchad"
    end,
  },
  {
    "nvchad/base46",
    lazy = true,
    build = function()
      require("base46").load_all_highlights()
    end,
  },
  "nvchad/volt",

  -- examples
  -- {
  --   "neovim/nvim-lspconfig",
  --   config = function()
  --     require("nvchad.configs.lspconfig").defaults()
  --     require "configs.lspconfig"
  --   end,
  -- },
  --
  -- {
  -- 	"williamboman/mason.nvim",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"lua-language-server", "stylua",
  -- 			"html-lsp", "css-lsp" , "prettier"
  -- 		},
  -- 	},
  -- },
  --
  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },

  ---------------------------

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
        "nvimtools/none-ls.nvim",
        config = function()
          require "configs.null-ls"
        end,
      },
    },
    config = function()
      require "nvchad.configs.lspconfig"
      require "configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
    enabled = true,
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = overrides.telescope,
  },

  -- Install a plugin
  -- {
  --   "max397574/better-escape.nvim",
  --   event = "InsertEnter",
  --   config = function()
  --     require("better_escape").setup()
  --   end,
  -- },
  { "dhruvasagar/vim-table-mode", ft = "markdown" },

  { "francoiscabrol/ranger.vim",  cmd = "Ranger" },
  -- dependency for ranger to prevent showing proscess exited error
  -- and allows to ctrl-6 work to go to prev buffer after selecting via ranger
  { "rbgrouleff/bclose.vim",      cmd = "Bclose" },

  -- comments
  { "numToStr/Comment.nvim",      event = "InsertEnter" },
  --
  -- https://www.reddit.com/r/neovim/comments/13bd75d/copilotlua_copilotcmp_working_in_nvchad/
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    config = function()
      require("copilot").setup {
        panel = {
          enabled = true,
          auto_refresh = false,
          keymap = {
            jump_prev = "[[",
            jump_next = "]]",
            accept = "<CR>",
            refresh = "gr",
            open = "<M-CR>",
          },
          layout = {
            position = "bottom", -- | top | left | right
            ratio = 0.4,
          },
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          debounce = 75,
          keymap = {
            accept = "<C-l>",
            -- accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        filetypes = {
          yaml = false,
          markdown = false,
          help = false,
          gitcommit = false,
          gitrebase = false,
          hgcommit = false,
          svn = false,
          cvs = false,
          ["."] = false,
        },
        copilot_node_command = "node", -- Node.js version must be > 16.x
        server_opts_overrides = {},
      }
    end,
  },
  -- debugging
  {
    "mfussenegger/nvim-dap",
    event = "InsertEnter", -- TODO change
  },
  {
    "leoluz/nvim-dap-go",
    event = "InsertEnter", -- TODO change
    config = function()
      require("dap-go").setup {
        -- support remote debugging
        -- https://github.com/leoluz/nvim-dap-go#debugging-with-dlv-in-headless-mode
        dap_configurations = {
          {
            type = "go",
            name = "Attach remote",
            mode = "remote",
            request = "attach",
          },
        },
      }
    end,
  },
  {
    "sebdah/vim-delve",
    event = "InsertEnter", -- TODO change
    config = function()
      vim.g.delve_new_command = "new"
    end,
  },

  --tidal
  {
    "tidalcycles/vim-tidal",
    ft = "tidal",
    event = "InsertEnter", -- TODO change
    config = function()
      vim.g.tidal_target = "terminal"

      vim.cmd [[
            autocmd FileType tidal call s:tidal_abbr()
            autocmd FileType tidal setlocal commentstring=--\\ %s
        ]]
      vim.api.nvim_exec(
        [[
        function s:tidal_abbr()
            inoreabbr billybd "[t ~ ~ ~] [~ ~ ~ ~] [t ~ ~ ~] [~ ~ ~ ~]"
            inoreabbr billysn "[~ ~ ~ ~] [t ~ ~ ~] [~ ~ ~ ~] [t ~ ~ ~]"
            inoreabbr billych "[t ~ t ~] [t ~ t ~] [t ~ t ~] [t ~ t ~]"
            inoreabbr bluemondaybd "[t ~ ~ ~] [~ ~ ~ ~] [t ~ ~ ~] [~ ~ ~ ~]"
            inoreabbr bluemondaysn "[~ ~ ~ ~] [t ~ ~ ~] [~ ~ ~ ~] [t ~ ~ ~]"
            inoreabbr bluemondaycp "[~ ~ ~ ~] [t ~ ~ ~] [~ ~ ~ ~] [t ~ ~ ~]"
            inoreabbr bluemondayoh "[~ ~ t ~] [~ ~ t ~] [~ ~ t ~] [~ ~ t ~]"
        endfunction
        ]],
        false
      )
    end,
  },

  -- obsidian
  {
    "epwalsh/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    lazy = true,
    enabled = true,
    -- ft = "markdown",
    event = "InsertEnter",
    -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
    -- event = {
    --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
    --   "BufReadPre path/to/my-vault/**.md",
    --   "BufNewFile path/to/my-vault/**.md",
    -- },
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",
      "hrsh7th/nvim-cmp",
    },
    opts = {
      workspaces = {
        {
          name = "garden",
          path = "~/garden"
        },
        -- {
        --   name = "work",
        --   path = "~/vaults/work",
        -- },
      },
      -- dir = "~/garden/content",

      use_advanced_uri = true,

      -- Optional, for templates (see below).
      templates = {
        folder = "templates",
        -- date_format = "%Y-%m-%d",
        -- time_format = "%H:%M",
        -- -- A map for custom variables, the key should be the variable and the value a function
        -- substitutions = {},
      },
      daily_notes = {
        folder = "journal",
        date_format = "%Y-%m-%d",
        template = "templates/daily_note_simple",
      },
      follow_url_func = function(url)
        -- Open the URL in the default web browser.
        vim.fn.jobstart({ "open", url }) -- Mac OS
        -- vim.fn.jobstart({"xdg-open", url})  -- linux
        -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
        -- vim.ui.open(url) -- need Neovim 0.10.0+
      end,
      completion = {
        nvim_cmp = true,
        min_chars = 2,
      },
      mappings = {
        -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
        ["gf"] = {
          action = function()
            return require("obsidian").util.gf_passthrough()
          end,
          opts = { noremap = false, expr = true, buffer = true },
        },
        -- Toggle check-boxes.
        ["<leader>cc"] = {
          action = function()
            return require("obsidian").util.toggle_checkbox()
          end,
          opts = { buffer = true },
        },
        -- Smart action depending on context, either follow link or toggle checkbox.
        ["<cr>"] = {
          action = function()
            return require("obsidian").util.smart_action()
          end,
          opts = { buffer = true, expr = true },
        },
      },
      new_notes_location = "notes_subdir",

      -- see below for full list of options 👇
    },
  },
  {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    -- optional for floating window border decoration
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- setting the keybinding for LazyGit with 'keys' is recommended in
    -- order to load the plugin when the command is run for the first time
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },
  {
    "hedyhli/outline.nvim",
    cmd = "Outline",
    config = function()
      -- Example mapping to toggle outline
      vim.keymap.set("n", "<leader>q", "<cmd>Outline<CR>",
        { desc = "Toggle Outline" })

      require("outline").setup {
        -- Your setup opts here (leave empty to use defaults)
      }
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    cmd = "TSContextToggle",
    config = function()
      -- Example mapping to toggle outline
      vim.keymap.set("n", "<leader>cc", "<cmd>TSContext toggle<CR>",
        { desc = "Toggle TSContext" })

      require("outline").setup {
        -- Your setup opts here (leave empty to use defaults)
      }
    end,
  },
  { "francoiscabrol/ranger.vim",  cmd = "Ranger" },

  -- {
  --   "kelly-lin/ranger.nvim",
  --   enabled = false,
  --   config = function()
  --     require("ranger-nvim").setup {
  --       replace_netrw = true,
  --       enable_cmds = true,
  --     }
  --     vim.api.nvim_set_keymap("n", "<leader>rr", "", {
  --       noremap = true,
  --       callback = function()
  --         require("ranger-nvim").open(true)
  --       end,
  --     })
  --   end,
  -- },

  -- To make a plugin not be loaded
  -- {
  --   "NvChad/nvim-colorizer.lua",
  --   enabled = false
  -- },

  -- All NvChad plugins are lazy-loaded by default
  -- For a plugin to be loaded, you will need to set either `ft`, `cmd`, `keys`, `event`, or set `lazy = false`
  -- If you want a plugin to load on startup, add `lazy = false` to a plugin spec, for example
  -- {
  --   "mg979/vim-visual-multi",
  --   lazy = false,
  -- }
}

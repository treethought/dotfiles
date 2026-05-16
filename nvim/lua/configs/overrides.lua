local M = {}

M.treesitter = {
  ensure_installed = {
    "vim",
    "lua",
    "html",
    "css",
    "javascript",
    "typescript",
    "tsx",
    "c",
    "markdown",
    "markdown_inline",
    "go",
		"templ",
  },
  indent = {
    enable = true,
    -- disable = {
    --   "python"
    -- },
  },
}
M.telescope = {
  defaults = {
    vimgrep_arguments = {
      "ag",
      "-f",
      "--nocolor",
      "--noheading",
      "--numbers",
      "--column",
      "--smart-case",
    },
    -- vimgrep_arguments = {
    --   "rg",
    --   "-L",
    --   "--color=never",
    --   "--no-heading",
    --   "--with-filename",
    --   "--line-number",
    --   "--column",
    --   "--smart-case",
    -- },
    sorting_strategy = "descending",
    pickers = {
      find_files = {
        theme = "ivy",
      },
    },
    layout_config = {
      horizontal = {
        prompt_position = "bottom",
      },
    },
  },
}

M.mason = {
  ensure_installed = {
    -- lua stuff
    "lua-language-server",
    "stylua",

    -- web dev stuff
    "css-lsp",
    "html-lsp",
    "typescript-language-server",
    "deno",
    "prettier",
    "gopls",
    "goimports",
    "goimports-reviser",

    -- c/cpp stuff
    "clangd",
    "clang-format",
  },
}

-- git support in nvimtree
M.nvimtree = {
  git = {
    enable = true,
  },

  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
}

return M

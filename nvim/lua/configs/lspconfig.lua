-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()


local servers = {
  "html",
  "buf",
  "cssls",
  "ts_ls",
  "clangd",
  "gopls",
  "pyright",
  "templ",
  "tailwindcss",
  "yamlls",
  "lua_ls",
  "solidity_ls",
  "vscode-json-language-server",
  "helm-ls",
  -- "solidity_ls_nomicfoundation",
}

vim.lsp.enable(servers)

vim.lsp.config("templ", {
  filetypes = {
    "templ",
  },
  init_options = {
    userLanguages = {
      templ = "html"
    }
  }
})

vim.lsp.config("helm-ls", {
  settings = {
    ['helm-ls'] = {
      yamlls = {
        path = "yaml-language-server",
      }
    }
  }
})

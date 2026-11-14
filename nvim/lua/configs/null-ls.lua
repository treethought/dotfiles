local present, null_ls = pcall(require, "none-ls")

if not present then
  return
end

local b = null_ls.builtins

local sources = {

  -- webdev stuff
  b.formatting.deno_fmt,                                                     -- deno for ts/js files
  b.formatting.prettier.with { filetypes = { "html", "markdown", "css" } },  -- prettier works only on these filetypes
  b.formatting.jq.with { filetypes = { "json" } },

  -- golang
  b.formatting.goimports,
  b.formatting.goimports_reviser,
  b.formatting.mdformat,
  b.code_actions.gomodifytags,
  b.code_actions.impl,

  -- Lua
  b.formatting.stylua,

  -- cpp
  b.formatting.clang_format,
}

null_ls.setup {
  debug = true,
  sources = sources,
}

require "nvchad.mappings"

local map = vim.keymap.set

-- remove default leader+b for new buffer mapping
vim.keymap.del("n", "<leader>b")

map("n", ";", ":", { desc = "CMD enter command mode" })
-- map("i", "jk", "<ESC>")

-- bs for save
map("n", "<leader>bs", "<cmd> w <CR>", { desc = "Save file" })

-- ranger
map("n", "<leader>rr", "<cmd> Ranger<CR>", { desc = "Open Ranger" })

-- comment (normal and visual mode)
--map("n", "gcc", "<cmd> lua require('Comment.api').toggle.linewise.current()<CR>", { desc = "Toggle comment" })
map("n", "gcc", function()
  require("Comment.api").toggle.linewise.current()
end, { desc = "Toggle comment" })

map("v", "gcc", function()
  require("Comment.api").toggle.linewise.current()
end, { desc = "Toggle comment" })

-- format
map("n", "<leader>fm", function()
  require("conform").format { lsp_fallback = true }
end, { desc = "Format Files" })

-- lsp
-- See `<cmd> :help vim.lsp.*` for documentation on any of the below functions
map("n", "<leader>bf", function()
  vim.lsp.buf.format { async = true }
end, { desc = "LSP formatting" })

map("n", "[e", function()
  vim.diagnostic.goto_prev { float = { border = "rounded" } }
end, { desc = "Goto prev diagnostic" })

map("n", "]e", function()
  vim.diagnostic.goto_next { float = { border = "rounded" } }
end, { desc = "Goto next diagnostic" })

-- snacks picker
map("n", "<leader>ll", function() Snacks.picker() end, { desc = "Find files" })
map("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Find files" })
map("n", "<leader>sp", function() Snacks.picker.grep() end, { desc = "Live grep" })
map("n", "<leader><C-p>", function() Snacks.picker.commands() end, { desc = "Commands" })

--- obsidian

map("n", "<leader>ww", "<cmd> ObsidianToday<CR>", { desc = "Obsidian Open daily note" })
map("n", "<leader>oa", "<cmd> ObsidianOpen<CR>", { desc = "Obsidian open in app" })

map("n", "<leader><C-o>", function()
  Snacks.picker.files { cwd = vim.fn.expand "~/garden", ft = "md" }
end, { desc = "Obsidian quick switch" })

map("n", "<leader>of", function()
  Snacks.picker.grep { cwd = vim.fn.expand "~/garden" }
end, { desc = "Obsidian search" })

-- map("n", "<leader>ww", function()
--   require("functions").open_daily_note_float()
-- end, { desc = "Open daily note" })

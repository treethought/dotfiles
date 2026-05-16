
-----------------------------------------
-- local autocmd = vim.api.nvim_create_autocmd

-- disable swap
vim.opt.swapfile = false

-- close quickfix menu after selecting choice
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "qf" },
	command = [[nnoremap <buffer> <CR> <CR>:cclose<CR>]],
})

-- set commentstring for tidal
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "tidal" },
	callback = function()
		vim.bo.commentstring = "-- %s"
	end,
})

vim.filetype.add({
 extension = {
  templ = "templ",
 },
})

-- Auto resize panes when resizing nvim window
-- autocmd("VimResized", {
--   pattern = "*",
--   command = "tabdo wincmd =",
-- })

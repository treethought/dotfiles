
-----------------------------------------
-- local autocmd = vim.api.nvim_create_autocmd

-- disable swap
vim.opt.swapfile = false

-- Over ssh there is no clipboard provider (no wl-copy, no display) and nvim's
-- OSC52 auto-detection does not fire, so yanks go nowhere and "+y errors. The
-- terminal carries OSC52 instead, which reaches the clipboard of the machine
-- running the terminal. Copy works this way; pasting still uses the terminal's
-- own paste key, since reading the clipboard needs the terminal to answer a
-- query that a multiplexer may swallow.
if vim.env.SSH_CONNECTION then
	vim.g.clipboard = "osc52"
	vim.o.clipboard = "unnamedplus"
end

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

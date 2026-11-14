
local M = {}

local daily_note = os.date "~/quartz/content/journal/%Y-%m-%d.md"
function M.open_daily_note()
  vim.cmd(string.format("edit %s", daily_note))
end

function M.open_daily_note_float()
  local file_path = os.date "~/garden/content/journal/%Y-%m-%d.md"

  -- Create a new empty buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set up the window dimensions and open a new floating window
  local width = vim.api.nvim_get_option "columns"
  local height = vim.api.nvim_get_option "lines"

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)

  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
  }

  -- Create the floating window with the buffer attached
  local win = vim.api.nvim_open_win(buf, true, border_opts)

  -- Switch to the new buffer and open the file
  vim.api.nvim_win_set_buf(win, buf)
  -- vim.api.nvim_buf_set_name(buf, file_path)
  vim.cmd("edit " .. file_path)

  -- Define keys that will close the window
  local closing_keys = { "<esc><esc><esc>", "qq" }

  -- Map these keys to close the window in the new buffer
  for _, key in ipairs(closing_keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true, nowait = true })
  end
end

return M

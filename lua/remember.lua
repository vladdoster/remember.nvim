--
-- Author: vladdoster <mvdoster@gmail.com>
-- Version: 1.0.0
--
-- Based on https://github.com/farmergreg/vim-lastplace/
--
-- This work is licensed under the terms of the MIT license.
-- For a copy, see <https://opensource.org/licenses/MIT>.
--

local g = vim.g
local bo = vim.bo
local fn = vim.fn
local api = vim.api

local M = {}

local config = {
  ignore_filetype = { "gitcommit", "gitrebase", "svn", "hgcommit" },
  ignore_buftype = { "quickfix", "nofile", "help" },
  open_folds = true,
}

function M.setup(options)
  if options["ignore_filetype"] then
    config["ignore_filetype"] = options["ignore_filetype"]
  end

  if options["ignore_buftype"] then
    config["ignore_buftype"] = options["ignore_buftype"]
  end

  if options["open_folds"] then
    config["open_folds"] = options["open_folds"]
  end
end

function set_cursor_position()
  -- Return if we have a buffer or filetype we want to ignore
  for _, k in pairs(config["ignore_buftype"]) do
    if bo.buftype == k then
      return
    end
  end

  for _, k in pairs(config["ignore_filetype"]) do
    if bo.filetype == k then
      return
    end
  end

  -- Return if the file doesn't exist, like a new and unsaved file
  if fn.empty(fn.glob(fn.expand("%"))) ~= 0 then
    return
  end

  local cursor_position = api.nvim_buf_get_mark(0, '"')
  local row = cursor_position[1]
  local col = cursor_position[2]

  -- If the saved row is less than the number of rows in the buffer,
  -- then continue
  if row > 0 and row <= api.nvim_buf_line_count(0) then
    -- If the last row is visible within this window, like in a very short
    -- file, just set the cursor position to the saved position
    if api.nvim_buf_line_count(0) == fn.line("w$") then
      api.nvim_win_set_cursor(0, cursor_position)

      -- If we're in the middle of the file, set the cursor position and center
      -- the screen
    elseif api.nvim_buf_line_count(0) - row > ((fn.line("w$") - fn.line("w0")) / 2) - 1 then
      api.nvim_win_set_cursor(0, cursor_position)
      api.nvim_input("zz")

      -- If we're at the end of the screen, set the cursor position and move
      -- the window up by one with C-e. This is to show that we are at the end
      -- of the file. If we did "zz" half the screen would be blank.
    else
      api.nvim_win_set_cursor(0, cursor_position)
      api.nvim_input("<c-e>")
    end
  end

  -- If the row is within a fold, make the row visible and recenter the screen
  if api.nvim_eval("foldclosed('.')") ~= -1 and config["open_folds"] then
    api.nvim_input("zvzz")
  end
end

local api = vim.api
api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    set_cursor_position()
  end,
})

return M

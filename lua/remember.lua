--
-- Author: vladdoster <mvdoster@gmail.com>
-- Version: 1.5.2
--
-- Based on https://github.com/farmergreg/vim-lastplace/
--
-- This work is licensed under the terms of the MIT license.
-- For a copy, see <https://opensource.org/licenses/MIT>.
--

local bo = vim.bo
local fn = vim.fn
local api = vim.api
local cmd = vim.cmd

local M = {}

local config = {
  ignore_filetype = { "gitcommit", "gitrebase", "svn", "hgcommit", "dap-repl" },
  ignore_buftype = { "quickfix", "nofile", "help" },
  open_folds = true,
  dont_center = false,
}

local ctrl_e = api.nvim_replace_termcodes("<c-e>", true, false, true)

-- Errors reported so far, so a persistent failure is shown once, not on every buffer
local reported = {}

local function contains(list, value)
  for _, item in pairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

function M.setup(options)
  if options["ignore_filetype"] then
    config["ignore_filetype"] = options["ignore_filetype"]
  end

  if options["ignore_buftype"] then
    config["ignore_buftype"] = options["ignore_buftype"]
  end

  if options["open_folds"] ~= nil then
    config["open_folds"] = options["open_folds"]
  end

  if options["dont_center"] ~= nil then
    config["dont_center"] = options["dont_center"]
  end
end

local function restore_cursor()
  -- Return if we have a buffer or filetype we want to ignore
  if contains(config["ignore_buftype"], bo.buftype) or contains(config["ignore_filetype"], bo.filetype) then
    return
  end

  -- Return if the file doesn't exist, like a new and unsaved file. The name is
  -- tested literally because glob() would parse characters like "[" as a pattern
  if fn.filereadable(api.nvim_buf_get_name(0)) == 0 then
    return
  end

  local cursor_position = api.nvim_buf_get_mark(0, '"')
  local row = cursor_position[1]
  local line_count = api.nvim_buf_line_count(0)

  -- If the saved row is less than the number of rows in the buffer,
  -- then continue
  if row > 0 and row <= line_count then
    local last_visible_row = fn.line("w$")

    -- If the last row is visible within this window, like in a very short
    -- file, or user requested us not centering the screen, just set the cursor
    -- position to the saved position
    if line_count == last_visible_row or config["dont_center"] then
      api.nvim_win_set_cursor(0, cursor_position)

      -- If we're in the middle of the file, set the cursor position and center
      -- the screen
    elseif line_count - row > ((last_visible_row - fn.line("w0")) / 2) - 1 then
      api.nvim_win_set_cursor(0, cursor_position)
      cmd("norm! zz")

      -- If we're at the end of the screen, set the cursor position and move
      -- the window up by one with C-e. This is to show that we are at the end
      -- of the file. If we did "zz" half the screen would be blank.
    else
      api.nvim_win_set_cursor(0, cursor_position)
      cmd("norm! " .. ctrl_e)
    end
  end

  -- If the row is within a fold, make the row visible and recenter the screen
  if config["open_folds"] and fn.foldclosed(".") ~= -1 then
    cmd("norm! zvzz")
  end
end

function M.set_cursor_position()
  local success, err = pcall(restore_cursor)
  if success then
    return
  end

  -- A Ctrl-C must still abort the command that triggered BufWinEnter
  local reason = tostring(err)
  if reason:find("Keyboard interrupt", 1, true) then
    error(err, 0)
  end

  if reported[reason] then
    return
  end
  reported[reason] = true

  local name = api.nvim_buf_get_name(0)
  if name == "" then
    name = "[No Name]"
  end
  local message = "remember.nvim: error setting cursor position in " .. name .. ": " .. reason
  -- Deferred because an error echoed inside the autocmd is rethrown into the
  -- command that triggered BufWinEnter, which breaks other plugins
  vim.schedule(function()
    vim.notify(message, vim.log.levels.ERROR)
  end)
end

api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    M.set_cursor_position()
  end,
})

return M

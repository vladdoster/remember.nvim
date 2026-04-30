--
-- Author: vladdoster <mvdoster@gmail.com>
-- Version: 1.5.1
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
local cmd = vim.cmd
local M = {}
local config = {
  ignore_buftype = { "quickfix", "nofile", "help" },
  ignore_filetype = { "gitcommit", "gitrebase", "svn", "hgcommit", "dap-repl" },
  open_folds = true,
  dont_center = false,
}
function M.setup(options)
  if options["ignore_buftype"] then
    config["ignore_buftype"] = options["ignore_buftype"]
  end

  if options["ignore_filetype"] then
    config["ignore_filetype"] = options["ignore_filetype"]
  end

  if options["open_folds"] then
    config["open_folds"] = options["open_folds"]
  end

  if options["dont_center"] then
    config["dont_center"] = options["dont_center"]
  end
end
function set_cursor_position()
  local success, err = pcall(function()
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

    if fn.empty(fn.glob(fn.expand("%"))) ~= 0 then
      return
    end

    local cursor_position = api.nvim_buf_get_mark(0, '"')
    local row = cursor_position[1]
    local col = cursor_position[2]

    if row > 0 and row <= api.nvim_buf_line_count(0) then
      if api.nvim_buf_line_count(0) == fn.line("w$") or config["dont_center"] then
        api.nvim_win_set_cursor(0, cursor_position)
      elseif api.nvim_buf_line_count(0) - row > ((fn.line("w$") - fn.line("w0")) / 2) - 1 then
        api.nvim_win_set_cursor(0, cursor_position)
        cmd("norm! zz")
      else
        api.nvim_win_set_cursor(0, cursor_position)
        api.nvim_feedkeys(api.nvim_replace_termcodes("<c-e>", true, false, true), "n", false)
      end
    end

    if api.nvim_eval("foldclosed('.')") ~= -1 and config["open_folds"] then
      cmd("norm! zvzz")
    end
  end)

  if not success then
    vim.notify("Error setting cursor position: " .. tostring(err), vim.log.levels.ERROR)
  end
end
api.nvim_create_autocmd({ "BufWinEnter" }, {
  callback = function()
    set_cursor_position()
  end,
})
return M
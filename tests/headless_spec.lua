--
-- Integration tests that drive a real headless Neovim.
-- Marked pending when nvim is not on PATH; CI installs nvim so they always run there.
--

local function capture(command)
  local handle = assert(io.popen(command))
  local output = handle:read("*a")
  handle:close()
  return output
end

-- Shared by every script: loads the plugin from the repo root, which busted
-- already requires as the working directory, and adds two helpers.
-- drain() runs every callback queued so far, including a deferred error
-- report; try() runs a command and prints whether it survived.
local prelude = [[
package.path = "./lua/?.lua;" .. package.path
require("remember")

local function drain()
  local drained = false
  vim.schedule(function() drained = true end)
  vim.wait(1000, function() return drained end)
end

local function temp_file(lines)
  local path = vim.fn.tempname()
  vim.fn.writefile(lines, path)
  return path
end

local function try(cmdline)
  local ok, err = pcall(vim.cmd, cmdline)
  drain()
  print(("ok=%s err=%s"):format(tostring(ok), tostring(err)))
end
]]

local postlude = [[
print("messages=" .. vim.fn.execute("messages"))
]]

-- Runs the script in a fresh nvim with the plugin loaded and returns what it printed
local function run_headless(lua_script)
  local script_path = os.tmpname()
  local file = assert(io.open(script_path, "w"))
  file:write(prelude, lua_script, postlude)
  file:close()

  local output = capture(("nvim --headless --clean -c 'luafile %s' -c 'qa!' 2>&1"):format(script_path))
  os.remove(script_path)
  return output
end

local has_nvim = capture("nvim --version 2>/dev/null"):find("NVIM", 1, true) ~= nil
local it_with_nvim = has_nvim and it or pending

describe("remember.nvim in headless nvim", function()
  it_with_nvim("restores the last cursor position of a file", function()
    local output = run_headless([[
      local lines = {}
      for i = 1, 200 do
        lines[i] = "line " .. i
      end
      local path = temp_file(lines)

      -- Leave the file at line 120, keep the " mark through shada and drop the
      -- buffer, which is what happens between two Neovim sessions
      vim.o.shadafile = vim.fn.tempname()
      vim.o.shada = "'100"
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      vim.api.nvim_win_set_cursor(0, { 120, 0 })
      vim.cmd("enew")
      vim.cmd("wshada")
      vim.cmd("bwipeout! " .. vim.fn.bufnr(path))
      vim.cmd("rshada")

      vim.cmd("edit " .. vim.fn.fnameescape(path))
      print("cursor=" .. vim.api.nvim_win_get_cursor(0)[1])
    ]])

    assert.matches("cursor=120", output, 1, true)
  end)

  it_with_nvim("does not break a plugin opening a window named [Scratch-1] (issue #10)", function()
    local output = run_headless([[
      try("silent keepalt topleft vertical 30 new [Scratch-1]")
      print("windows=" .. vim.fn.winnr("$"))
    ]])

    assert.matches("ok=true", output, 1, true)
    assert.matches("windows=2", output, 1, true)
    assert.not_matches("E944", output, 1, true)
  end)

  it_with_nvim("reports an unexpected error without aborting the triggering command", function()
    local output = run_headless([[
      local path = temp_file({ "line 1", "line 2" })
      vim.api.nvim_buf_get_mark = function()
        error("injected failure")
      end

      try("edit " .. vim.fn.fnameescape(path))
    ]])

    assert.matches("ok=true", output, 1, true)
    assert.matches("injected failure", output, 1, true)
  end)
end)

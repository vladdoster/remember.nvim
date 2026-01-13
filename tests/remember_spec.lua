--
-- Unit tests for remember.nvim
-- Tests cover the setup function and cursor position restoration logic
--

describe("remember.nvim", function()
  local remember

  -- Mock vim API
  local mock_vim
  local mock_api
  local mock_fn
  local mock_cmd
  local mock_bo
  local mock_g

  before_each(function()
    -- Reset mocks before each test
    mock_api = {
      nvim_buf_get_mark = spy.new(function() return {10, 5} end),
      nvim_buf_line_count = spy.new(function() return 100 end),
      nvim_win_set_cursor = spy.new(function() end),
      nvim_feedkeys = spy.new(function() end),
      nvim_replace_termcodes = spy.new(function(str) return str end),
      nvim_eval = spy.new(function() return -1 end),
      nvim_create_autocmd = spy.new(function() end),
    }

    mock_fn = {
      empty = spy.new(function() return 0 end),
      glob = spy.new(function() return "file.txt" end),
      expand = spy.new(function(arg) return arg end),
      line = spy.new(function(arg)
        if arg == "w$" then return 30 end
        if arg == "w0" then return 1 end
        return 1
      end),
    }

    mock_cmd = spy.new(function() end)

    mock_bo = {
      buftype = "",
      filetype = ""
    }

    mock_g = {}

    mock_vim = {
      api = mock_api,
      fn = mock_fn,
      cmd = mock_cmd,
      bo = mock_bo,
      g = mock_g,
    }

    -- Mock the global vim object
    _G.vim = mock_vim

    -- Reload the module to get a fresh instance
    package.loaded['remember'] = nil
    remember = require('remember')
  end)

  after_each(function()
    -- Clean up
    package.loaded['remember'] = nil
  end)

  describe("setup", function()
    it("should accept empty options", function()
      assert.has_no.errors(function()
        remember.setup({})
      end)
    end)

    it("should configure ignore_filetype", function()
      local custom_filetypes = {"markdown", "text"}
      remember.setup({
        ignore_filetype = custom_filetypes
      })

      -- We can't directly access the config, but we can test the behavior
      -- by checking if the set_cursor_position function respects it
      mock_bo.filetype = "markdown"
      _G.set_cursor_position()

      -- Cursor should not be set for ignored filetype
      assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
    end)

    it("should configure ignore_buftype", function()
      local custom_buftypes = {"terminal", "prompt"}
      remember.setup({
        ignore_buftype = custom_buftypes
      })

      mock_bo.buftype = "terminal"
      _G.set_cursor_position()

      -- Cursor should not be set for ignored buftype
      assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
    end)

    it("should configure open_folds", function()
      remember.setup({
        open_folds = false
      })

      -- This affects fold behavior in set_cursor_position
      -- We test this indirectly through the function behavior
      assert.has_no.errors(function()
        _G.set_cursor_position()
      end)
    end)

    it("should configure dont_center", function()
      remember.setup({
        dont_center = true
      })

      -- This affects centering behavior in set_cursor_position
      assert.has_no.errors(function()
        _G.set_cursor_position()
      end)
    end)

    it("should handle multiple options at once", function()
      remember.setup({
        ignore_filetype = {"custom"},
        ignore_buftype = {"custom_buf"},
        open_folds = false,
        dont_center = true
      })

      assert.has_no.errors(function()
        _G.set_cursor_position()
      end)
    end)
  end)

  describe("set_cursor_position", function()
    it("should skip ignored buffer types", function()
      local ignored_buftypes = {"quickfix", "nofile", "help"}

      for _, buftype in ipairs(ignored_buftypes) do
        -- Reset spy
        mock_api.nvim_win_set_cursor:clear()

        mock_bo.buftype = buftype
        _G.set_cursor_position()

        assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
      end
    end)

    it("should skip ignored file types", function()
      local ignored_filetypes = {"gitcommit", "gitrebase", "svn", "hgcommit", "dap-repl"}

      for _, filetype in ipairs(ignored_filetypes) do
        -- Reset spy
        mock_api.nvim_win_set_cursor:clear()

        mock_bo.filetype = filetype
        mock_bo.buftype = ""
        _G.set_cursor_position()

        assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
      end
    end)

    it("should skip non-existent files", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 1 end) -- File doesn't exist
      mock_vim.fn = mock_fn

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
    end)

    it("should restore cursor position for valid files", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end) -- File exists
      mock_api.nvim_buf_get_mark = spy.new(function() return {10, 5} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      assert.spy(mock_api.nvim_win_set_cursor).was_called_with(0, {10, 5})
    end)

    it("should not restore cursor if saved row is 0", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {0, 0} end) -- Row is 0
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
    end)

    it("should not restore cursor if saved row exceeds buffer line count", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {150, 0} end) -- Row > line count
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_not_called()
    end)

    it("should center screen when in middle of file", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {50, 5} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_fn.line = spy.new(function(arg)
        if arg == "w$" then return 30 end
        if arg == "w0" then return 1 end
        return 1
      end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      assert.spy(mock_cmd).was_called_with("norm! zz")
    end)

    it("should not center screen when dont_center is true", function()
      remember.setup({ dont_center = true })

      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {50, 5} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_fn.line = spy.new(function(arg)
        if arg == "w$" then return 30 end
        if arg == "w0" then return 1 end
        return 1
      end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      assert.spy(mock_cmd).was_not_called_with("norm! zz")
    end)

    it("should handle cursor position at end of file", function()
      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {95, 0} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_fn.line = spy.new(function(arg)
        if arg == "w$" then return 30 end
        if arg == "w0" then return 1 end
        return 1
      end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      assert.spy(mock_api.nvim_feedkeys).was_called()
    end)

    it("should open folds when cursor is in folded area", function()
      remember.setup({ open_folds = true })

      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {10, 5} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_api.nvim_eval = spy.new(function() return 5 end) -- Folded
      mock_fn.line = spy.new(function(arg)
        if arg == "w$" then return 100 end
        if arg == "w0" then return 1 end
        return 1
      end)
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      assert.spy(mock_cmd).was_called_with("norm! zvzz")
    end)

    it("should not open folds when open_folds is false", function()
      remember.setup({ open_folds = false })

      mock_bo.buftype = ""
      mock_bo.filetype = ""
      mock_fn.empty = spy.new(function() return 0 end)
      mock_api.nvim_buf_get_mark = spy.new(function() return {10, 5} end)
      mock_api.nvim_buf_line_count = spy.new(function() return 100 end)
      mock_api.nvim_eval = spy.new(function() return 5 end) -- Folded
      mock_fn.line = spy.new(function(arg)
        if arg == "w$" then return 100 end
        if arg == "w0" then return 1 end
        return 1
      end)

      -- Create a fresh cmd spy to track only calls in this test
      local fresh_cmd_spy = spy.new(function() end)
      mock_vim.cmd = fresh_cmd_spy
      mock_vim.fn = mock_fn
      mock_vim.api = mock_api

      _G.set_cursor_position()

      assert.spy(mock_api.nvim_win_set_cursor).was_called()
      -- Should not call the fold open command in this test
      assert.spy(fresh_cmd_spy).was_not_called()
    end)
  end)

  describe("autocmd registration", function()
    it("should register BufWinEnter autocmd", function()
      -- The module registers autocmd on load
      assert.spy(mock_api.nvim_create_autocmd).was_called()

      -- Check that it was called with BufWinEnter
      local calls = mock_api.nvim_create_autocmd.calls
      local found = false
      for i = 1, #calls do
        local args = calls[i].vals
        if args[1] and type(args[1]) == "table" then
          for _, event in ipairs(args[1]) do
            if event == "BufWinEnter" then
              found = true
              break
            end
          end
        end
      end
      assert.is_true(found, "BufWinEnter autocmd should be registered")
    end)
  end)
end)

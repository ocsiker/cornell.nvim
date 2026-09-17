local api = vim.api

local state = require("cornell.state")
local sync = require("cornell.sync")
local layout = require("cornell.layout")
local render = require("cornell.render")
local config = require("cornell.config")

local M = {}

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function is_cornell_buffer(buf)
  return buf == state.cues_buf
    or buf == state.notes_buf
    or buf == state.summary_buf
    or buf == state.review_buf
end

local function map_toggle(buf)
  if not valid_buf(buf) then
    return
  end

  local lhs = config.options.keymaps.toggle
  if not lhs or lhs == "" then
    return
  end

  vim.keymap.set("n", lhs, require("cornell").toggle, {
    buffer = buf,
    silent = true,
    noremap = true,
    nowait = true,
    desc = "Cornell: Toggle",
  })
end

function M.clear_session()
  if state.augroup then
    pcall(api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
end

function M.setup_session()
  M.clear_session()

  state.augroup = api.nvim_create_augroup(
    "CornellActive",
    { clear = true }
  )

  local function on_change(buf, callback)
    if not valid_buf(buf) then
      return
    end

    api.nvim_create_autocmd(
      { "TextChanged", "TextChangedI" },
      {
        group = state.augroup,
        buffer = buf,
        callback = function()
          if state.active
            and not state.syncing
            and not state.closing
          then
            callback()
          end
        end,
      }
    )
  end

  on_change(state.cues_buf, function()
    sync.refresh()
  end)

  on_change(state.notes_buf, function()
    sync.rebuild_index()
    render.refresh()
    sync.write_back()
  end)

  on_change(state.summary_buf, function()
    sync.write_back()
  end)

  api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.cues_buf,
    callback = function()
      sync.sync_cursor_from_cues()
    end,
  })

  api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.notes_buf,
    callback = function()
      sync.sync_cursor_from_notes()
    end,
  })

  api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if state.active then
        layout.resize()
        render.render_cue_alignment()
      end
    end,
  })

  ---------------------------------------------------------------------------
  -- If the user enters a buffer outside Cornell, close Cornell.
  ---------------------------------------------------------------------------

  api.nvim_create_autocmd("BufLeave", {
    group = state.augroup,
    callback = function()
      if not state.active or state.closing then
        return
      end

      vim.schedule(function()
        if not state.active or state.closing then
          return
        end

        local current_buf = api.nvim_get_current_buf()

        if not is_cornell_buffer(current_buf) then
          require("cornell").close()
        end
      end)
    end,
  })

  api.nvim_create_autocmd("BufEnter", {
    group = state.augroup,
    callback = function()
      if not state.active or state.closing then
        return
      end

      local current_buf = api.nvim_get_current_buf()

      if not is_cornell_buffer(current_buf) then
        vim.schedule(function()
          if state.active and not state.closing then
            if not is_cornell_buffer(api.nvim_get_current_buf()) then
              require("cornell").close()
            end
          end
        end)
      end
    end,
  })
end

function M.setup_launcher()
  if state.launcher_augroup then
    pcall(
      api.nvim_del_augroup_by_id,
      state.launcher_augroup
    )
  end

  state.launcher_augroup = api.nvim_create_augroup(
    "CornellLauncher",
    { clear = true }
  )

  api.nvim_create_autocmd("FileType", {
    group = state.launcher_augroup,
    pattern = "markdown",
    callback = function(args)
      map_toggle(args.buf)
    end,
  })

  -- Important for lazy-loaded plugins: FileType may already have fired
  -- before setup_launcher() is called.
  local current_buf = api.nvim_get_current_buf()

  if vim.bo[current_buf].filetype == "markdown" then
    map_toggle(current_buf)
  end
end

return M

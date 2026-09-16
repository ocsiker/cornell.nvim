local state = require("cornell.state")
local sync = require("cornell.sync")
local layout = require("cornell.layout")

local M = {}

local function valid_buf(buf) return buf and vim.api.nvim_buf_is_valid(buf) end
local function is_cornell_buffer(buf)
  return buf == state.cues_buf or buf == state.notes_buf or buf == state.summary_buf or buf == state.review_buf
end

function M.setup()
  if state.augroup then pcall(vim.api.nvim_del_augroup_by_id, state.augroup) end
  state.augroup = vim.api.nvim_create_augroup("CornellActive", { clear = true })

  local function on_change(buf, callback)
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      group = state.augroup,
      buffer = buf,
      callback = function()
        if state.active and not state.syncing and not state.closing then callback() end
      end,
    })
  end

  on_change(state.cues_buf, sync.refresh)
  on_change(state.notes_buf, function()
    sync.rebuild_index()
    require("cornell.render").setup_highlights(state.notes_buf)
    require("cornell.render").render_cue_alignment()
    require("cornell").write_back()
  end)
  on_change(state.summary_buf, function() require("cornell").write_back() end)

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.cues_buf,
    callback = sync.sync_cursor_from_cues,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.notes_buf,
    callback = sync.sync_cursor_from_notes,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      if state.active then layout.resize(); require("cornell.render").render_cue_alignment() end
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = state.augroup,
    callback = function()
      if not state.active or state.closing then return end
      vim.schedule(function()
        if state.active and not is_cornell_buffer(vim.api.nvim_get_current_buf()) then
          require("cornell").close()
        end
      end)
    end,
  })
end

function M.setup_launcher()
  if state.launcher_augroup then pcall(vim.api.nvim_del_augroup_by_id, state.launcher_augroup) end
  state.launcher_augroup = vim.api.nvim_create_augroup("CornellLauncher", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = state.launcher_augroup,
    pattern = "markdown",
    callback = function(args)
      vim.keymap.set("n", "<leader>cv", require("cornell").toggle, {
        buffer = args.buf,
        silent = true,
        desc = "Cornell: Toggle",
      })
    end,
  })
end

return M

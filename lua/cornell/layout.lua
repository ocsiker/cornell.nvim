local config = require("cornell.config")
local state = require("cornell.state")

local M = {}

local api = vim.api
local configure_cues_window
local configure_notes_window
local configure_summary_window

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function clamp(value, min_value, max_value)
  if max_value < min_value then
    return min_value
  end
  return math.max(min_value, math.min(value, max_value))
end

function M.setup_buffer(buf, win, filetype)
  if not valid_buf(buf) then
    return
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = filetype or "markdown"
  vim.bo[buf].buflisted = false
  vim.bo[buf].undolevels = -1

  if valid_win(win) then
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].cursorline = true
    vim.wo[win].list = false
    vim.wo[win].spell = false

    -- setup_buffer() is called after the corresponding Cornell window is
    -- assigned in init.lua.  Apply role-specific window settings here so
    -- the layout is consistent even when the caller does not explicitly
    -- call configure_*_window().
    if win == state.cues_win then
      configure_cues_window(win)
    elseif win == state.notes_win then
      configure_notes_window(win)
    elseif win == state.summary_win then
      configure_summary_window(win)
    end
  end
end

function M.setup_content_padding(win)
  if not valid_win(win) then
    return
  end

  local padding = math.max(0, tonumber(config.options.content_padding) or 0)

  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = "shift:" .. tostring(padding)

  -- Keep the text visually inset without adding spaces to the actual buffer.
  -- statuscolumn is window-local, so it does not affect Markdown contents.
  vim.wo[win].statuscolumn = string.format("%%{repeat(' ', %d)}", padding)
end

function M.setup_title(win, title)
  if valid_win(win) then
    vim.wo[win].winbar = " " .. title .. " "
  end
end

function M.mark_cornell_window(win)
  if valid_win(win) then
    vim.w[win].cornell = true
  end
end

function M.close_window(win)
  if not valid_win(win) then
    return false
  end

  -- Never leave Neovim without a window.
  if #api.nvim_list_wins() <= 1 then
    return false
  end

  local ok = pcall(api.nvim_win_close, win, true)
  return ok
end

function M.focus_cues()
  if valid_win(state.cues_win) then
    api.nvim_set_current_win(state.cues_win)
    return true
  end
  return false
end

function M.focus_notes()
  if valid_win(state.notes_win) then
    api.nvim_set_current_win(state.notes_win)
    return true
  end
  return false
end

function M.focus_summary()
  if valid_win(state.summary_win) then
    api.nvim_set_current_win(state.summary_win)
    return true
  end
  return false
end

function M.resize()
  if not state.active then
    return
  end

  if valid_win(state.cues_win) then
    local width = tonumber(config.options.cues_width) or 32
    width = math.max(1, math.floor(width))

    local ok = pcall(api.nvim_win_set_width, state.cues_win, width)
    if not ok then
      -- The editor may be too narrow for the requested width.  Try to use
      -- the largest practical width instead of throwing an error.
      local current = api.nvim_win_get_width(state.cues_win)
      local fallback = clamp(width, 1, math.max(1, current))
      pcall(api.nvim_win_set_width, state.cues_win, fallback)
    end
  end

  if valid_win(state.summary_win) then
    local height = tonumber(config.options.summary_height) or 8
    height = math.max(1, math.floor(height))

    local ok = pcall(api.nvim_win_set_height, state.summary_win, height)
    if not ok then
      local current = api.nvim_win_get_height(state.summary_win)
      local fallback = clamp(height, 1, math.max(1, current))
      pcall(api.nvim_win_set_height, state.summary_win, fallback)
    end
  end
end

configure_cues_window = function(win)
  if not valid_win(win) then
    return
  end

  vim.wo[win].wrap = false
  vim.wo[win].linebreak = false
  vim.wo[win].breakindent = false
  vim.wo[win].breakindentopt = ""
  vim.wo[win].statuscolumn = ""
  vim.wo[win].winfixwidth = true
  M.setup_title(win, "CUES / QUESTIONS")
end

configure_notes_window = function(win)
  if not valid_win(win) then
    return
  end

  vim.wo[win].winfixwidth = false
  M.setup_content_padding(win)
  M.setup_title(win, "NOTES / ANSWERS")
end

configure_summary_window = function(win)
  if not valid_win(win) then
    return
  end

  vim.wo[win].winfixheight = true
  M.setup_content_padding(win)
  M.setup_title(win, "SUMMARY")
end

M.configure_cues_window = configure_cues_window
M.configure_notes_window = configure_notes_window
M.configure_summary_window = configure_summary_window

function M.toggle_summary()
  if not state.active or not valid_buf(state.summary_buf) then
    return
  end

  if valid_win(state.summary_win) then
    local was_current = api.nvim_get_current_win() == state.summary_win

    M.close_window(state.summary_win)
    state.summary_win = nil

    if was_current then
      M.focus_notes()
    end

    return
  end

  if not valid_win(state.notes_win) then
    return
  end

  local previous_win = api.nvim_get_current_win()

  -- Always create Summary underneath the Notes column.  This makes the
  -- layout deterministic and keeps Cues as the left column.
  M.focus_notes()
  vim.cmd("belowright split")

  state.summary_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(state.summary_win, state.summary_buf)

  M.setup_buffer(state.summary_buf, state.summary_win, "markdown")
  M.configure_summary_window(state.summary_win)

  -- If the user opened Summary while focused on Cues, return focus there.
  if valid_win(previous_win) and previous_win == state.cues_win then
    M.focus_cues()
  else
    M.focus_notes()
  end

  M.resize()
end

return M

local api = vim.api

local config = require("cornell.config")
local state = require("cornell.state")

local M = {}

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function mark_window(win, role)
  if not valid_win(win) then
    return
  end

  vim.w[win].cornell = true
  vim.w[win].cornell_role = role
end

local function create_scratch_buffer()
  local buf = api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "markdown"

  return buf
end

local function base_window_options(win)
  if not valid_win(win) then
    return
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].cursorline = true
  vim.wo[win].list = false
  vim.wo[win].spell = false
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
end

function M.setup_content_padding(win)
  if not valid_win(win) then
    return
  end

  local padding = tonumber(config.options.content_padding) or 0
  padding = math.max(0, math.floor(padding))

  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = "shift:" .. tostring(padding)

  if padding > 0 then
    vim.wo[win].statuscolumn = string.format(
      "%%{repeat(' ', %d)}",
      padding
    )
  else
    vim.wo[win].statuscolumn = ""
  end
end

function M.setup_title(win, title)
  if valid_win(win) then
    vim.wo[win].winbar = " " .. title .. " "
  end
end

function M.setup_cues_window(win)
  if not valid_win(win) then
    return
  end

  base_window_options(win)

  vim.wo[win].wrap = false
  vim.wo[win].linebreak = false
  vim.wo[win].breakindent = false
  vim.wo[win].breakindentopt = ""
  vim.wo[win].statuscolumn = ""
  vim.wo[win].winfixwidth = true

  M.setup_title(win, "CUES / QUESTIONS")
  mark_window(win, "cues")
end

function M.setup_notes_window(win)
  if not valid_win(win) then
    return
  end

  base_window_options(win)

  vim.wo[win].winfixwidth = false

  M.setup_content_padding(win)
  M.setup_title(win, "NOTES / ANSWERS")
  mark_window(win, "notes")
end

function M.setup_summary_window(win)
  if not valid_win(win) then
    return
  end

  base_window_options(win)
  vim.wo[win].winfixheight = true

  M.setup_content_padding(win)
  M.setup_title(win, "SUMMARY")
  mark_window(win, "summary")
end

function M.setup_buffer(buf, win, filetype)
  if not valid_buf(buf) then
    return
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = filetype or "markdown"

  if win == state.cues_win then
    M.setup_cues_window(win)
  elseif win == state.notes_win then
    M.setup_notes_window(win)
  elseif win == state.summary_win then
    M.setup_summary_window(win)
  end
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
    pcall(api.nvim_win_set_width, state.cues_win, width)
  end

  if valid_win(state.summary_win) then
    local height = tonumber(config.options.summary_height) or 8
    height = math.max(1, math.floor(height))
    pcall(api.nvim_win_set_height, state.summary_win, height)
  end
end

function M.open(parsed)
  if state.active then
    return false
  end

  if not valid_buf(state.source_buf)
    or not valid_win(state.source_win)
  then
    return false
  end

  state.cues_buf = create_scratch_buffer()
  state.notes_buf = create_scratch_buffer()
  state.summary_buf = create_scratch_buffer()

  api.nvim_buf_set_lines(
    state.cues_buf,
    0,
    -1,
    false,
    parsed.cues or {}
  )

  api.nvim_buf_set_lines(
    state.notes_buf,
    0,
    -1,
    false,
    parsed.notes or {}
  )

  api.nvim_buf_set_lines(
    state.summary_buf,
    0,
    -1,
    false,
    parsed.summary or {}
  )

  ---------------------------------------------------------------------------
  -- The original source window becomes the Notes window.
  ---------------------------------------------------------------------------

  state.notes_win = state.source_win

  api.nvim_win_set_buf(
    state.notes_win,
    state.notes_buf
  )

  M.setup_buffer(
    state.notes_buf,
    state.notes_win,
    "markdown"
  )

  ---------------------------------------------------------------------------
  -- Create Cues on the left.
  ---------------------------------------------------------------------------

  api.nvim_set_current_win(state.notes_win)
  vim.cmd("leftabove vsplit")

  state.cues_win = api.nvim_get_current_win()

  api.nvim_win_set_buf(
    state.cues_win,
    state.cues_buf
  )

  M.setup_buffer(
    state.cues_buf,
    state.cues_win,
    "markdown"
  )

  state.active = true
  M.resize()

  M.focus_cues()

  return true
end

function M.toggle_summary()
  if not state.active or not valid_buf(state.summary_buf) then
    return false
  end

  ---------------------------------------------------------------------------
  -- Close Summary.
  ---------------------------------------------------------------------------

  if valid_win(state.summary_win) then
    local old_win = state.summary_win
    local was_current = api.nvim_get_current_win() == old_win

    if #api.nvim_list_wins() > 1 then
      pcall(api.nvim_win_close, old_win, true)
    end

    state.summary_win = nil

    if was_current then
      M.focus_notes()
    end

    return true
  end

  ---------------------------------------------------------------------------
  -- Open Summary below Notes.
  ---------------------------------------------------------------------------

  if not valid_win(state.notes_win) then
    return false
  end

  local previous_win = api.nvim_get_current_win()

  M.focus_notes()
  vim.cmd("belowright split")

  state.summary_win = api.nvim_get_current_win()

  api.nvim_win_set_buf(
    state.summary_win,
    state.summary_buf
  )

  M.setup_buffer(
    state.summary_buf,
    state.summary_win,
    "markdown"
  )

  M.resize()

  if previous_win == state.cues_win then
    M.focus_cues()
  else
    M.focus_notes()
  end

  return true
end

function M.close_window(win)
  if not valid_win(win) then
    return false
  end

  if #api.nvim_list_wins() <= 1 then
    return false
  end

  return pcall(api.nvim_win_close, win, true)
end

function M.restore_source()
  if not valid_win(state.notes_win)
    or not valid_buf(state.source_buf)
  then
    return false
  end

  api.nvim_win_set_buf(
    state.notes_win,
    state.source_buf
  )

  return true
end

return M

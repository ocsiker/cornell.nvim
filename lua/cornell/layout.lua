local config = require("cornell.config")
local state = require("cornell.state")

local M = {}

local function valid_buf(buf) return buf and vim.api.nvim_buf_is_valid(buf) end
local function valid_win(win) return win and vim.api.nvim_win_is_valid(win) end

function M.setup_buffer(buf, win, filetype)
  if not valid_buf(buf) then return end
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
  end
end

function M.setup_content_padding(win)
  if not valid_win(win) then return end
  local pad = string.rep(" ", config.options.content_padding)
  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = "shift:" .. tostring(config.options.content_padding)
  vim.wo[win].statuscolumn = pad
end

function M.setup_title(win, title)
  if valid_win(win) then vim.wo[win].winbar = " " .. title .. " " end
end

function M.close_window(win)
  if valid_win(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
end

function M.resize()
  if valid_win(state.cues_win) then
    vim.api.nvim_win_set_width(state.cues_win, config.options.cues_width)
  end
  if valid_win(state.summary_win) then
    vim.api.nvim_win_set_height(state.summary_win, config.options.summary_height)
  end
end

function M.toggle_summary()
  if not state.active or not valid_buf(state.summary_buf) then return end

  if valid_win(state.summary_win) then
    local was_current = vim.api.nvim_get_current_win() == state.summary_win
    M.close_window(state.summary_win)
    state.summary_win = nil
    if was_current and valid_win(state.notes_win) then
      vim.api.nvim_set_current_win(state.notes_win)
    end
    return
  end

  if not valid_win(state.notes_win) then return end
  vim.api.nvim_set_current_win(state.notes_win)
  vim.cmd("belowright split")
  state.summary_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.summary_win, state.summary_buf)
  M.setup_buffer(state.summary_buf, state.summary_win, "markdown")
  M.setup_content_padding(state.summary_win)
  M.setup_title(state.summary_win, "SUMMARY")
  M.resize()
end

return M

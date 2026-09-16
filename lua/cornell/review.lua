local config = require("cornell.config")
local parser = require("cornell.parser")
local state = require("cornell.state")
local layout = require("cornell.layout")

local M = {}

local function valid_buf(buf) return buf and vim.api.nvim_buf_is_valid(buf) end
local function valid_win(win) return win and vim.api.nvim_win_is_valid(win) end

function M.build()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then return {} end
  local cues = parser.parse_cues(vim.api.nvim_buf_get_lines(state.cues_buf, 0, -1, false))
  local out = {
    "# Cornell Review",
    "",
  }
  for _, cue in ipairs(cues) do
    out[#out + 1] = "## [" .. cue.qid .. "] " .. cue.text
    out[#out + 1] = ""
    out[#out + 1] = ""
    out[#out + 1] = "---"
    out[#out + 1] = ""
  end
  return out
end

function M.enter()
  if not state.active or not valid_win(state.notes_win) then return end
  if state.review_mode then return end

  state.review_mode = true
  state.review_buf = state.review_buf or vim.api.nvim_create_buf(false, true)
  vim.bo[state.review_buf].buftype = "nofile"
  vim.bo[state.review_buf].bufhidden = "wipe"
  vim.bo[state.review_buf].swapfile = false
  vim.bo[state.review_buf].filetype = "markdown"

  vim.api.nvim_buf_set_lines(state.review_buf, 0, -1, false, M.build())

  vim.api.nvim_set_current_win(state.notes_win)
  vim.api.nvim_win_set_buf(state.notes_win, state.review_buf)
  state.review_win = state.notes_win
  layout.setup_title(state.review_win, "REVIEW")
  vim.wo[state.review_win].wrap = true
  vim.wo[state.review_win].linebreak = true
end

function M.leave()
  if not state.review_mode then return end
  state.review_mode = false
  if valid_win(state.review_win) and valid_buf(state.notes_buf) then
    vim.api.nvim_win_set_buf(state.review_win, state.notes_buf)
    layout.setup_title(state.review_win, "NOTES / ANSWERS")
    layout.setup_content_padding(state.review_win)
  end
  if valid_buf(state.review_buf) then pcall(vim.api.nvim_buf_delete, state.review_buf, { force = true }) end
  state.review_buf = nil
  state.review_win = nil
end

function M.toggle()
  if state.review_mode then M.leave() else M.enter() end
end

return M

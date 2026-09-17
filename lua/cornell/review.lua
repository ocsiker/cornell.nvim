local api = vim.api

local parser = require("cornell.parser")
local state = require("cornell.state")
local layout = require("cornell.layout")
local render = require("cornell.render")

local M = {}

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

function M.build()
  if not valid_buf(state.cues_buf) then
    return {}
  end

  local cues = parser.parse_cues(
    api.nvim_buf_get_lines(
      state.cues_buf,
      0,
      -1,
      false
    )
  )

  local out = {
    "# Cornell Review",
    "",
  }

  for _, cue in ipairs(cues) do
    out[#out + 1] =
      "## [" .. cue.qid .. "] " .. cue.text
    out[#out + 1] = ""
    out[#out + 1] = "Answer:"
    out[#out + 1] = ""
    out[#out + 1] = ""
    out[#out + 1] = "---"
    out[#out + 1] = ""
  end

  return out
end

function M.enter()
  if not state.active
    or not valid_win(state.notes_win)
    or state.review_mode
  then
    return false
  end

  state.review_buf = api.nvim_create_buf(false, true)

  vim.bo[state.review_buf].buftype = "nofile"
  vim.bo[state.review_buf].bufhidden = "wipe"
  vim.bo[state.review_buf].swapfile = false
  vim.bo[state.review_buf].modifiable = true
  vim.bo[state.review_buf].buflisted = false
  vim.bo[state.review_buf].filetype = "markdown"

  local previous = state.syncing
  state.syncing = true

  api.nvim_buf_set_lines(
    state.review_buf,
    0,
    -1,
    false,
    M.build()
  )

  state.syncing = previous
  state.review_mode = true
  state.review_win = state.notes_win

  api.nvim_win_set_buf(
    state.review_win,
    state.review_buf
  )

  layout.setup_content_padding(state.review_win)
  layout.setup_title(state.review_win, "REVIEW")

  render.setup_review_highlights(state.review_buf)

  -- Install navigation mappings after the review buffer exists.
  require("cornell.mappings").setup()

  return true
end

function M.leave()
  if not state.review_mode then
    return false
  end

  local review_win = state.review_win

  state.review_mode = false

  if valid_win(review_win) and valid_buf(state.notes_buf) then
    api.nvim_win_set_buf(
      review_win,
      state.notes_buf
    )

    layout.setup_notes_window(review_win)
  end

  if valid_buf(state.review_buf) then
    pcall(
      api.nvim_buf_delete,
      state.review_buf,
      { force = true }
    )
  end

  state.review_buf = nil
  state.review_win = nil

  render.refresh()
  require("cornell.mappings").setup()

  return true
end

function M.toggle()
  if state.review_mode then
    return M.leave()
  end

  return M.enter()
end

return M

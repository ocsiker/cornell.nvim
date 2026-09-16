local state = require("cornell.state")
local parser = require("cornell.parser")
local render = require("cornell.render")

local M = {}

local function valid_buf(buf) return buf and vim.api.nvim_buf_is_valid(buf) end
local function valid_win(win) return win and vim.api.nvim_win_is_valid(win) end

local function get_lines(buf)
  if not valid_buf(buf) then return {} end
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function set_lines(buf, lines)
  if not valid_buf(buf) then return end
  state.syncing = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  state.syncing = false
end

function M.rebuild_index()
  parser.rebuild_index(state, get_lines(state.cues_buf), get_lines(state.notes_buf))
end

function M.ensure_notes_for_cues()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then return end

  local cues = parser.parse_cues(get_lines(state.cues_buf))
  local notes = get_lines(state.notes_buf)
  local existing = {}
  for _, block in ipairs(parser.parse_note_blocks(notes)) do existing[block.qid] = true end

  local changed = false
  for _, cue in ipairs(cues) do
    if not existing[cue.qid] then
      if #notes > 0 and notes[#notes] ~= "" then notes[#notes + 1] = "" end
      notes[#notes + 1] = "### [" .. cue.qid .. "] " .. cue.text
      notes[#notes + 1] = ""
      notes[#notes + 1] = ""
      existing[cue.qid] = true
      changed = true
    end
  end

  if changed then set_lines(state.notes_buf, notes) end
end

function M.sync_note_titles()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then return end

  local cues = {}
  for _, cue in ipairs(parser.parse_cues(get_lines(state.cues_buf))) do cues[cue.qid] = cue.text end

  local lines = get_lines(state.notes_buf)
  local changed = false
  for i, line in ipairs(lines) do
    local qid = parser.extract_qid(line)
    if qid and line:match("^%s*###") and cues[qid] then
      local new_line = "### [" .. qid .. "] " .. cues[qid]
      if line ~= new_line then
        lines[i] = new_line
        changed = true
      end
    end
  end

  if changed then set_lines(state.notes_buf, lines) end
end

function M.current_qid(buf, line)
  if not valid_buf(buf) then return nil end
  local lines = get_lines(buf)
  line = line or (vim.api.nvim_win_get_cursor(0)[1])
  if buf == state.cues_buf then
    return parser.extract_qid(lines[line])
  end
  for i = line, 1, -1 do
    local qid = parser.extract_qid(lines[i])
    if qid and lines[i]:match("^%s*###") then return qid end
  end
  return nil
end

function M.jump_to_cue(qid)
  local line = state.cue_index[qid]
  if line and valid_win(state.cues_win) then
    vim.api.nvim_set_current_win(state.cues_win)
    vim.api.nvim_win_set_cursor(state.cues_win, { line, 0 })
    vim.cmd("normal! zz")
  end
end

function M.jump_to_note(qid)
  local line = state.note_index[qid]
  if line and valid_win(state.notes_win) then
    vim.api.nvim_set_current_win(state.notes_win)
    vim.api.nvim_win_set_cursor(state.notes_win, { line, 0 })
    vim.cmd("normal! zz")
  end
end

function M.sync_cursor_from_cues()
  if state.syncing or state.closing or state.review_mode then return end
  if vim.api.nvim_get_current_buf() ~= state.cues_buf then return end
  local qid = M.current_qid(state.cues_buf)
  if qid then M.jump_to_note(qid) end
end

function M.sync_cursor_from_notes()
  if state.syncing or state.closing or state.review_mode then return end
  if vim.api.nvim_get_current_buf() ~= state.notes_buf then return end
  local qid = M.current_qid(state.notes_buf)
  if qid then M.jump_to_cue(qid) end
end

function M.refresh()
  if not state.active or state.syncing or state.closing then return end
  M.ensure_notes_for_cues()
  M.sync_note_titles()
  M.rebuild_index()
  render.setup_highlights(state.cues_buf)
  render.setup_highlights(state.notes_buf)
  render.render_cue_alignment()
end

return M

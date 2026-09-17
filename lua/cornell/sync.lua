local api = vim.api

local state = require("cornell.state")
local parser = require("cornell.parser")
local render = require("cornell.render")

local M = {}

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function get_lines(buf)
  if not valid_buf(buf) then
    return {}
  end

  return api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function set_lines(buf, lines)
  if not valid_buf(buf) then
    return false
  end

  local previous = state.syncing
  state.syncing = true

  local ok = pcall(
    api.nvim_buf_set_lines,
    buf,
    0,
    -1,
    false,
    lines
  )

  state.syncing = previous

  return ok
end

function M.rebuild_index()
  parser.rebuild_index(
    state,
    get_lines(state.cues_buf),
    get_lines(state.notes_buf)
  )
end

function M.ensure_notes_for_cues()
  if not valid_buf(state.cues_buf)
    or not valid_buf(state.notes_buf)
  then
    return false
  end

  local cues = parser.parse_cues(
    get_lines(state.cues_buf)
  )

  local notes = get_lines(state.notes_buf)
  local existing = {}

  for _, block in ipairs(parser.parse_note_blocks(notes)) do
    existing[block.qid] = true
  end

  local changed = false

  for _, cue in ipairs(cues) do
    if not existing[cue.qid] then
      while #notes > 0 and vim.trim(notes[#notes]) == "" do
        table.remove(notes)
      end

      if #notes > 0 then
        notes[#notes + 1] = ""
      end

      notes[#notes + 1] =
        "### [" .. cue.qid .. "] " .. cue.text
      notes[#notes + 1] = ""
      notes[#notes + 1] = ""

      existing[cue.qid] = true
      changed = true
    end
  end

  if changed then
    set_lines(state.notes_buf, notes)
  end

  return changed
end

function M.sync_note_titles()
  if not valid_buf(state.cues_buf)
    or not valid_buf(state.notes_buf)
  then
    return false
  end

  local cue_text = {}

  for _, cue in ipairs(parser.parse_cues(get_lines(state.cues_buf))) do
    cue_text[cue.qid] = cue.text
  end

  local lines = get_lines(state.notes_buf)
  local changed = false

  for i, line in ipairs(lines) do
    if line:match("^%s*###%s*%[") then
      local qid = parser.extract_qid(line)

      if qid and cue_text[qid] ~= nil then
        local new_line =
          "### [" .. qid .. "] " .. cue_text[qid]

        if line ~= new_line then
          lines[i] = new_line
          changed = true
        end
      end
    end
  end

  if changed then
    set_lines(state.notes_buf, lines)
  end

  return changed
end

function M.current_qid(buf, line)
  if not valid_buf(buf) then
    return nil
  end

  local lines = get_lines(buf)

  if not line then
    local current_win = api.nvim_get_current_win()
    if valid_win(current_win) then
      line = api.nvim_win_get_cursor(current_win)[1]
    else
      line = 1
    end
  end

  line = math.max(1, math.min(line, #lines))

  if buf == state.cues_buf then
    return parser.extract_qid(lines[line])
  end

  if buf == state.notes_buf then
    for i = line, 1, -1 do
      if lines[i]:match("^%s*###%s*%[") then
        return parser.extract_qid(lines[i])
      end
    end
  end

  return nil
end

local function set_opposite_cursor(win, line)
  if not valid_win(win) then
    return
  end

  local buf = api.nvim_win_get_buf(win)
  if not valid_buf(buf) then
    return
  end

  local count = api.nvim_buf_line_count(buf)
  line = math.max(1, math.min(line, count))

  local current_col = api.nvim_win_get_cursor(win)[2]
  local line_text = api.nvim_buf_get_lines(
    buf,
    line - 1,
    line,
    false
  )[1] or ""

  current_col = math.min(current_col, #line_text)

  api.nvim_win_set_cursor(win, { line, current_col })
end

-- IMPORTANT:
-- Cursor synchronization NEVER changes the current window.
-- This is what allows <C-h>/<C-l> to move between Cues and Notes without
-- immediately being pulled back by CursorMoved.
function M.sync_cursor_from_cues()
  if state.syncing
    or state.cursor_syncing
    or state.closing
    or state.review_mode
  then
    return
  end

  if api.nvim_get_current_buf() ~= state.cues_buf then
    return
  end

  local qid = M.current_qid(state.cues_buf)
  if not qid then
    return
  end

  local note_line = state.note_index[qid]
  if not note_line or not valid_win(state.notes_win) then
    return
  end

  state.cursor_syncing = true
  set_opposite_cursor(state.notes_win, note_line)
  state.cursor_syncing = false
end

function M.sync_cursor_from_notes()
  if state.syncing
    or state.cursor_syncing
    or state.closing
    or state.review_mode
  then
    return
  end

  if api.nvim_get_current_buf() ~= state.notes_buf then
    return
  end

  local qid = M.current_qid(state.notes_buf)
  if not qid then
    return
  end

  local cue_line = state.cue_index[qid]
  if not cue_line or not valid_win(state.cues_win) then
    return
  end

  state.cursor_syncing = true
  set_opposite_cursor(state.cues_win, cue_line)
  state.cursor_syncing = false
end

function M.jump_to_cue(qid)
  local line = state.cue_index[qid]

  if not line or not valid_win(state.cues_win) then
    return false
  end

  api.nvim_set_current_win(state.cues_win)
  api.nvim_win_set_cursor(state.cues_win, { line, 0 })
  vim.cmd("normal! zz")

  return true
end

function M.jump_to_note(qid)
  local line = state.note_index[qid]

  if not line or not valid_win(state.notes_win) then
    return false
  end

  api.nvim_set_current_win(state.notes_win)
  api.nvim_win_set_cursor(state.notes_win, { line, 0 })
  vim.cmd("normal! zz")

  return true
end

function M.add_question(qid, text, line)
  if not valid_buf(state.cues_buf)
    or not valid_buf(state.notes_buf)
  then
    return false
  end

  local cues = get_lines(state.cues_buf)
  local notes = get_lines(state.notes_buf)

  line = math.max(0, math.min(line or #cues, #cues))

  table.insert(
    cues,
    line + 1,
    "- [" .. qid .. "] " .. text
  )

  set_lines(state.cues_buf, cues)

  while #notes > 0 and vim.trim(notes[#notes]) == "" do
    table.remove(notes)
  end

  if #notes > 0 then
    notes[#notes + 1] = ""
  end

  notes[#notes + 1] =
    "### [" .. qid .. "] " .. text
  notes[#notes + 1] = ""
  notes[#notes + 1] = ""

  set_lines(state.notes_buf, notes)

  M.rebuild_index()
  render.refresh()

  return true
end

function M.write_back()
  if not state.active
    or not valid_buf(state.source_buf)
    or not valid_buf(state.cues_buf)
    or not valid_buf(state.notes_buf)
    or not valid_buf(state.summary_buf)
  then
    return false
  end

  local markdown = parser.build_markdown(
    state,
    get_lines
  )

  local previous = state.syncing
  state.syncing = true

  local ok = pcall(
    api.nvim_buf_set_lines,
    state.source_buf,
    0,
    -1,
    false,
    markdown
  )

  state.syncing = previous

  return ok
end

function M.save(notify)
  if not state.active then
    return false
  end

  M.write_back()

  if not valid_buf(state.source_buf) then
    return false
  end

  local ok = pcall(function()
    api.nvim_buf_call(state.source_buf, function()
      vim.cmd("silent update")
    end)
  end)

  if notify then
    if ok then
      notify("Đã lưu Cornell.")
    else
      notify(
        "Không thể ghi Cornell về Markdown.",
        vim.log.levels.ERROR
      )
    end
  end

  return ok
end

function M.refresh()
  if not state.active
    or state.syncing
    or state.closing
  then
    return
  end

  M.ensure_notes_for_cues()
  M.sync_note_titles()
  M.rebuild_index()
  render.refresh()
end

return M

local M = {}

local api = vim.api
local config = require("cornell.config")
local state = require("cornell.state")
local parser = require("cornell.parser")
local sync = require("cornell.sync")
local render = require("cornell.render")
local layout = require("cornell.layout")
local review = require("cornell.review")

local setup_done = false

local function valid_buf(buf) return buf and api.nvim_buf_is_valid(buf) end
local function valid_win(win) return win and api.nvim_win_is_valid(win) end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Cornell" })
end

local function get_lines(buf)
  if not valid_buf(buf) then return {} end
  return api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function set_lines(buf, lines)
  if not valid_buf(buf) then return end
  state.syncing = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  state.syncing = false
end

local function is_cornell_buffer(buf)
  return buf == state.cues_buf or buf == state.notes_buf or buf == state.summary_buf or buf == state.review_buf
end

function M.setup(opts)
  config.setup(opts)
  require("cornell.commands").setup()
  require("cornell.autocmds").setup_launcher()
  setup_done = true
  return M
end

function M.write_back()
  if not state.active or not valid_buf(state.source_buf) then return end
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) or not valid_buf(state.summary_buf) then return end

  local markdown = parser.build_markdown(state, get_lines)
  state.syncing = true
  api.nvim_buf_set_lines(state.source_buf, 0, -1, false, markdown)
  state.syncing = false
end

function M.save()
  if not state.active then return end
  M.write_back()
  if valid_buf(state.source_buf) then
    local ok = pcall(function()
      api.nvim_buf_call(state.source_buf, function() vim.cmd("silent update") end)
    end)
    if ok then notify("Đã lưu Cornell.") else notify("Không thể ghi Cornell về Markdown.", vim.log.levels.ERROR) end
  end
end

function M.add_question()
  if not state.active or not valid_buf(state.cues_buf) then return end
  local qid = parser.next_qid(state)
  local line = api.nvim_win_get_cursor(state.cues_win)[1]
  local lines = get_lines(state.cues_buf)
  table.insert(lines, line + 1, "- [" .. qid .. "] ")
  set_lines(state.cues_buf, lines)
  sync.refresh()
  api.nvim_set_current_win(state.cues_win)
  api.nvim_win_set_cursor(state.cues_win, { line + 1, 6 + #qid })
  vim.cmd("startinsert!")
end

function M.open_answer()
  if not state.active then return end
  local qid = sync.current_qid(state.cues_buf)
  if qid then sync.jump_to_note(qid) end
end

function M.check()
  if not state.active then return end
  sync.rebuild_index()
  local missing, duplicate = {}, {}
  local seen = {}
  for _, qid in ipairs(state.qids) do
    if seen[qid] then duplicate[#duplicate + 1] = qid end
    seen[qid] = true
    if not state.note_index[qid] then missing[#missing + 1] = qid end
  end
  local notes = parser.parse_note_blocks(get_lines(state.notes_buf))
  local cue_set = {}
  for _, qid in ipairs(state.qids) do cue_set[qid] = true end
  local orphan = {}
  for _, block in ipairs(notes) do
    if not cue_set[block.qid] then orphan[#orphan + 1] = block.qid end
  end

  if #missing == 0 and #duplicate == 0 and #orphan == 0 then
    notify("Cornell OK: Cues và Notes khớp nhau.")
    return
  end

  local parts = {}
  if #missing > 0 then parts[#parts + 1] = "missing: " .. table.concat(missing, ", ") end
  if #duplicate > 0 then parts[#parts + 1] = "duplicate: " .. table.concat(duplicate, ", ") end
  if #orphan > 0 then parts[#parts + 1] = "orphan notes: " .. table.concat(orphan, ", ") end
  notify(table.concat(parts, " | "), vim.log.levels.WARN)
end

function M.review()
  if not state.active then return end
  review.toggle()
end

function M.summary()
  if not state.active then return end
  layout.toggle_summary()
end

function M.close()
  if not state.active or state.closing then return end
  state.closing = true

  M.write_back()

  local current_win = api.nvim_get_current_win()
  local current_buf = api.nvim_get_current_buf()
  local external = not is_cornell_buffer(current_buf)

  if valid_win(state.review_win) and state.review_mode then review.leave() end

  local wins = {
    state.cues_win,
    state.summary_win,
  }
  for _, win in ipairs(wins) do
    if valid_win(win) then pcall(api.nvim_win_close, win, true) end
  end

  if valid_win(state.notes_win) and valid_buf(state.source_buf) then
    if external then
      -- Do not disturb an external buffer the user has already entered.
    else
      pcall(api.nvim_win_set_buf, state.notes_win, state.source_buf)
    end
  end

  if valid_buf(state.cues_buf) then pcall(api.nvim_buf_delete, state.cues_buf, { force = true }) end
  if valid_buf(state.notes_buf) and state.notes_buf ~= state.source_buf then
    pcall(api.nvim_buf_delete, state.notes_buf, { force = true })
  end
  if valid_buf(state.summary_buf) then pcall(api.nvim_buf_delete, state.summary_buf, { force = true }) end
  if valid_buf(state.review_buf) then pcall(api.nvim_buf_delete, state.review_buf, { force = true }) end

  if state.augroup then pcall(api.nvim_del_augroup_by_id, state.augroup) end
  state.reset()
end

function M.open()
  if state.active then return end
  local source_buf = api.nvim_get_current_buf()
  local source_win = api.nvim_get_current_win()

  if vim.bo[source_buf].filetype ~= "markdown" or vim.bo[source_buf].buftype ~= "" then
    notify("Cornell chỉ mở trên Markdown buffer thông thường.", vim.log.levels.WARN)
    return
  end

  local parsed = parser.parse_source(get_lines(source_buf))
  state.preamble = parsed.preamble
  state.source_buf = source_buf
  state.source_win = source_win

  state.cues_buf = api.nvim_create_buf(false, true)
  state.notes_buf = api.nvim_create_buf(false, true)
  state.summary_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_lines(state.cues_buf, 0, -1, false, parsed.cues)
  api.nvim_buf_set_lines(state.notes_buf, 0, -1, false, parsed.notes)
  api.nvim_buf_set_lines(state.summary_buf, 0, -1, false, parsed.summary)

  state.active = true

  -- Original source window becomes Notes.
  state.notes_win = source_win
  api.nvim_win_set_buf(state.notes_win, state.notes_buf)
  layout.setup_buffer(state.notes_buf, state.notes_win, "markdown")
  layout.setup_content_padding(state.notes_win)
  layout.setup_title(state.notes_win, "NOTES / ANSWERS")

  -- Cues on the left.
  vim.cmd("leftabove vsplit")
  state.cues_win = api.nvim_get_current_win()
  api.nvim_win_set_width(state.cues_win, config.options.cues_width)
  api.nvim_win_set_buf(state.cues_win, state.cues_buf)
  layout.setup_buffer(state.cues_buf, state.cues_win, "markdown")
  layout.setup_title(state.cues_win, "CUES / QUESTIONS")

  -- Return to notes.
  api.nvim_set_current_win(state.notes_win)

  sync.ensure_notes_for_cues()
  sync.sync_note_titles()
  sync.rebuild_index()
  render.setup_highlights(state.cues_buf)
  render.setup_highlights(state.notes_buf)
  render.render_cue_alignment()

  require("cornell.mappings").setup()
  require("cornell.autocmds").setup()

  api.nvim_set_current_win(state.cues_win)
  api.nvim_win_set_cursor(state.cues_win, { 1, 0 })
  notify("Cornell opened.")
end

function M.toggle()
  if state.active then M.close() else M.open() end
end

return M

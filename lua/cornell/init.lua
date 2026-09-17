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

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function notify(message, level)
  vim.notify(
    message,
    level or vim.log.levels.INFO,
    { title = "Cornell" }
  )
end

local function get_lines(buf)
  if not valid_buf(buf) then
    return {}
  end

  return api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function is_cornell_buffer(buf)
  return buf == state.cues_buf
    or buf == state.notes_buf
    or buf == state.summary_buf
    or buf == state.review_buf
end

function M.setup(opts)
  config.setup(opts)

  require("cornell.commands").setup()
  require("cornell.autocmds").setup_launcher()

  setup_done = true

  return M
end

local function ensure_setup()
  if not setup_done then
    M.setup()
  end
end

function M.open()
  ensure_setup()

  if state.active then
    return false
  end

  local source_buf = api.nvim_get_current_buf()
  local source_win = api.nvim_get_current_win()

  if vim.bo[source_buf].filetype ~= "markdown"
    or vim.bo[source_buf].buftype ~= ""
  then
    notify(
      "Cornell chỉ mở trên Markdown buffer thông thường.",
      vim.log.levels.WARN
    )
    return false
  end

  local parsed = parser.parse_source(
    get_lines(source_buf)
  )

  state.source_buf = source_buf
  state.source_win = source_win
  state.preamble = parsed.preamble

  if not layout.open(parsed) then
    state.reset()
    notify(
      "Không thể tạo Cornell layout.",
      vim.log.levels.ERROR
    )
    return false
  end

  ---------------------------------------------------------------------------
  -- Synchronize the initial data.
  ---------------------------------------------------------------------------

  sync.ensure_notes_for_cues()
  sync.sync_note_titles()
  sync.rebuild_index()

  render.refresh()

  ---------------------------------------------------------------------------
  -- Install all Cornell-local mappings AFTER every buffer/window exists.
  ---------------------------------------------------------------------------

  require("cornell.mappings").setup()
  require("cornell.autocmds").setup_session()

  layout.focus_cues()

  if valid_win(state.cues_win)
    and api.nvim_buf_line_count(state.cues_buf) > 0
  then
    pcall(
      api.nvim_win_set_cursor,
      state.cues_win,
      { 1, 0 }
    )
  end

  notify("Cornell opened.")

  return true
end

function M.close()
  if not state.active or state.closing then
    return false
  end

  state.closing = true

  local current_win = api.nvim_get_current_win()
  local current_buf = api.nvim_get_current_buf()
  local current_is_cornell = is_cornell_buffer(current_buf)

  ---------------------------------------------------------------------------
  -- Write the current Cornell state back before destroying scratch buffers.
  ---------------------------------------------------------------------------

  sync.write_back()

  ---------------------------------------------------------------------------
  -- Leave Review first. This restores Notes into notes_win.
  ---------------------------------------------------------------------------

  if state.review_mode then
    review.leave()
  end

  ---------------------------------------------------------------------------
  -- If the user has already entered an external buffer, do not replace it.
  -- Otherwise restore the original Markdown source into source_win.
  ---------------------------------------------------------------------------

  if current_is_cornell then
    if valid_win(state.notes_win)
      and valid_buf(state.source_buf)
    then
      pcall(
        api.nvim_win_set_buf,
        state.notes_win,
        state.source_buf
      )
    end
  end

  ---------------------------------------------------------------------------
  -- Close auxiliary Cornell windows.
  ---------------------------------------------------------------------------

  local windows = {
    state.cues_win,
    state.summary_win,
  }

  for _, win in ipairs(windows) do
    if valid_win(win) and win ~= current_win then
      pcall(api.nvim_win_close, win, true)
    end
  end

  -- If the current window is Cornell Cues/Summary, it can be closed now too;
  -- the source window must remain available to restore the Markdown buffer.
  if current_is_cornell
    and current_win ~= state.notes_win
    and valid_win(current_win)
    and #api.nvim_list_wins() > 1
  then
    pcall(api.nvim_win_close, current_win, true)
  end

  ---------------------------------------------------------------------------
  -- If Notes/source window survived, restore source there.
  ---------------------------------------------------------------------------

  if current_is_cornell
    and valid_win(state.notes_win)
    and valid_buf(state.source_buf)
  then
    pcall(
      api.nvim_win_set_buf,
      state.notes_win,
      state.source_buf
    )

    pcall(
      api.nvim_set_current_win,
      state.notes_win
    )
  end

  ---------------------------------------------------------------------------
  -- Delete scratch buffers.
  ---------------------------------------------------------------------------

  local scratch_buffers = {
    state.cues_buf,
    state.notes_buf,
    state.summary_buf,
    state.review_buf,
  }

  for _, buf in ipairs(scratch_buffers) do
    if valid_buf(buf) then
      pcall(
        api.nvim_buf_delete,
        buf,
        { force = true }
      )
    end
  end

  ---------------------------------------------------------------------------
  -- Remove session autocmds and reset state.
  ---------------------------------------------------------------------------

  require("cornell.autocmds").clear_session()

  state.reset()

  return true
end

function M.toggle()
  ensure_setup()

  if state.active then
    return M.close()
  end

  return M.open()
end

function M.save()
  ensure_setup()

  return sync.save(function(message, level)
    notify(message, level)
  end)
end

function M.write_back()
  return sync.write_back()
end

function M.review()
  if not state.active then
    return false
  end

  local result = review.toggle()

  if result then
    require("cornell.mappings").setup()
  end

  return result
end

function M.summary()
  if not state.active then
    return false
  end

  local result = layout.toggle_summary()

  if result then
    require("cornell.mappings").setup()
  end

  return result
end

function M.add_question()
  if not state.active
    or not valid_buf(state.cues_buf)
    or not valid_win(state.cues_win)
  then
    return false
  end

  sync.rebuild_index()

  local qid = parser.next_qid(state)
  local cursor = api.nvim_win_get_cursor(state.cues_win)
  local line = cursor[1]

  vim.ui.input(
    {
      prompt = qid .. " question: ",
    },
    function(text)
      if not text or vim.trim(text) == "" then
        return
      end

      text = vim.trim(text)

      if sync.add_question(qid, text, line) then
        layout.focus_cues()

        local target_line = math.min(
          line + 1,
          api.nvim_buf_line_count(state.cues_buf)
        )

        pcall(
          api.nvim_win_set_cursor,
          state.cues_win,
          { target_line, #("- [" .. qid .. "] ") }
        )

        vim.cmd("startinsert!")
      end
    end
  )

  return true
end

function M.open_answer()
  if not state.active then
    return false
  end

  local qid = sync.current_qid(state.cues_buf)

  if not qid then
    return false
  end

  return sync.jump_to_note(qid)
end

function M.jump_to_note()
  if not state.active then
    return false
  end

  local qid = sync.current_qid(state.cues_buf)

  if not qid then
    return false
  end

  return sync.jump_to_note(qid)
end

function M.jump_to_cue()
  if not state.active then
    return false
  end

  local qid = sync.current_qid(state.notes_buf)

  if not qid then
    return false
  end

  return sync.jump_to_cue(qid)
end

function M.check()
  if not state.active then
    return false
  end

  sync.rebuild_index()

  local missing = {}
  local duplicate = {}
  local seen = {}

  for _, qid in ipairs(state.qids) do
    if seen[qid] then
      duplicate[#duplicate + 1] = qid
    end

    seen[qid] = true

    if not state.note_index[qid] then
      missing[#missing + 1] = qid
    end
  end

  local cue_set = {}
  for _, qid in ipairs(state.qids) do
    cue_set[qid] = true
  end

  local orphan = {}

  for _, block in ipairs(
    parser.parse_note_blocks(get_lines(state.notes_buf))
  ) do
    if not cue_set[block.qid] then
      orphan[#orphan + 1] = block.qid
    end
  end

  if #missing == 0
    and #duplicate == 0
    and #orphan == 0
  then
    notify("Cornell OK: Cues và Notes khớp nhau.")
    return true
  end

  local parts = {}

  if #missing > 0 then
    parts[#parts + 1] =
      "missing: " .. table.concat(missing, ", ")
  end

  if #duplicate > 0 then
    parts[#parts + 1] =
      "duplicate: " .. table.concat(duplicate, ", ")
  end

  if #orphan > 0 then
    parts[#parts + 1] =
      "orphan notes: " .. table.concat(orphan, ", ")
  end

  notify(
    table.concat(parts, " | "),
    vim.log.levels.WARN
  )

  return false
end

return M

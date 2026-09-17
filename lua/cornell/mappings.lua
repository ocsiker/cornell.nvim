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

local function map(buf, lhs, rhs, desc)
  if not valid_buf(buf) then
    return
  end

  if not lhs or lhs == "" then
    return
  end

  -- Do not use a "safe_map" check here.
  -- Cornell View must own <C-h>/<C-l> while it is active.
  vim.keymap.set("n", lhs, rhs, {
    buffer = buf,
    silent = true,
    noremap = true,
    nowait = true,
    desc = desc,
  })
end

local function focus(win)
  if not valid_win(win) then
    return false
  end

  api.nvim_set_current_win(win)
  return true
end

local function focus_cues()
  return focus(state.cues_win)
end

local function focus_notes()
  return focus(state.notes_win)
end

local function focus_summary()
  return focus(state.summary_win)
end

local function common(buf, cornell)
  local km = config.options.keymaps

  map(buf, km.toggle, cornell.toggle, "Cornell: Toggle")
  map(buf, km.review, cornell.review, "Cornell: Review")
  map(buf, km.summary, cornell.summary, "Cornell: Summary")
  map(buf, km.save, cornell.save, "Cornell: Save")
  map(buf, km.close, cornell.close, "Cornell: Close")
end

function M.setup()
  local cornell = require("cornell")
  local km = config.options.keymaps

  ---------------------------------------------------------------------------
  -- CUES
  ---------------------------------------------------------------------------

  if valid_buf(state.cues_buf) then
    common(state.cues_buf, cornell)

    -- The two navigation keys are intentionally explicit.
    map(
      state.cues_buf,
      "<C-l>",
      focus_notes,
      "Cornell: Cues -> Notes"
    )

    map(
      state.cues_buf,
      km.jump,
      cornell.jump_to_note,
      "Cornell: Jump to Note"
    )

    map(
      state.cues_buf,
      km.answer,
      cornell.open_answer,
      "Cornell: Open Answer"
    )

    map(
      state.cues_buf,
      km.add_question,
      cornell.add_question,
      "Cornell: Add Question"
    )

    map(
      state.cues_buf,
      km.cues,
      focus_cues,
      "Cornell: Cues"
    )

    map(
      state.cues_buf,
      km.notes,
      focus_notes,
      "Cornell: Notes"
    )
  end

  ---------------------------------------------------------------------------
  -- NOTES
  ---------------------------------------------------------------------------

  if valid_buf(state.notes_buf) then
    common(state.notes_buf, cornell)

    map(
      state.notes_buf,
      "<C-h>",
      focus_cues,
      "Cornell: Notes -> Cues"
    )

    map(
      state.notes_buf,
      km.jump,
      cornell.jump_to_cue,
      "Cornell: Jump to Cue"
    )

    map(
      state.notes_buf,
      km.cues,
      focus_cues,
      "Cornell: Cues"
    )

    map(
      state.notes_buf,
      km.notes,
      focus_notes,
      "Cornell: Notes"
    )
  end

  ---------------------------------------------------------------------------
  -- SUMMARY
  ---------------------------------------------------------------------------

  if valid_buf(state.summary_buf) then
    common(state.summary_buf, cornell)

    map(
      state.summary_buf,
      "<C-h>",
      focus_cues,
      "Cornell: Summary -> Cues"
    )

    map(
      state.summary_buf,
      "<C-l>",
      focus_notes,
      "Cornell: Summary -> Notes"
    )

    map(
      state.summary_buf,
      km.cues,
      focus_cues,
      "Cornell: Cues"
    )

    map(
      state.summary_buf,
      km.notes,
      focus_notes,
      "Cornell: Notes"
    )
  end

  ---------------------------------------------------------------------------
  -- REVIEW
  ---------------------------------------------------------------------------

  if valid_buf(state.review_buf) then
    common(state.review_buf, cornell)

    map(
      state.review_buf,
      "<C-h>",
      focus_cues,
      "Cornell: Review -> Cues"
    )

    map(
      state.review_buf,
      "<C-l>",
      focus_notes,
      "Cornell: Review -> Notes"
    )

    map(
      state.review_buf,
      km.cues,
      focus_cues,
      "Cornell: Cues"
    )

    map(
      state.review_buf,
      km.notes,
      focus_notes,
      "Cornell: Notes"
    )
  end
end

return M

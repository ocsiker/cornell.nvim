local state = require("cornell.state")

local M = {}

local api = vim.api

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

local function safe_map(buf, mode, lhs, rhs, desc)
  if not valid_buf(buf) or not lhs or lhs == "" then
    return
  end

  for _, map in ipairs(api.nvim_buf_get_keymap(buf, mode)) do
    if map.lhs == lhs then
      return
    end
  end

  vim.keymap.set(mode, lhs, rhs, {
    buffer = buf,
    silent = true,
    desc = desc,
  })
end

local function focus_window(win)
  if valid_win(win) then
    api.nvim_set_current_win(win)
  end
end

local function jump_to_note()
  local qid = require("cornell.sync").current_qid(state.cues_buf)
  if qid then
    require("cornell.sync").jump_to_note(qid)
  end
end

local function jump_to_cue()
  local qid = require("cornell.sync").current_qid(state.notes_buf)
  if qid then
    require("cornell.sync").jump_to_cue(qid)
  end
end

local function common(buf, cornell)
  safe_map(buf, "n", "<leader>cv", cornell.toggle, "Cornell: Toggle")
  safe_map(buf, "n", "<leader>cr", cornell.review, "Cornell: Review")
  safe_map(buf, "n", "<leader>cs", cornell.summary, "Cornell: Summary")
  safe_map(buf, "n", "<C-s>", cornell.save, "Cornell: Save")
  safe_map(buf, "n", "q", cornell.close, "Cornell: Close")
end

function M.setup()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then
    return
  end

  local cornell = require("cornell")

  common(state.cues_buf, cornell)
  common(state.notes_buf, cornell)

  if valid_buf(state.summary_buf) then
    common(state.summary_buf, cornell)
  end

  if valid_buf(state.review_buf) then
    common(state.review_buf, cornell)
  end

  --------------------------------------------------------------------------
  -- Cues <-> Notes window navigation
  --
  -- Do not use <C-w>h / <C-w>l here.  The Cornell layout may contain other
  -- windows, and we want these keys to mean exactly "Cues" and "Notes".
  --
  -- <C-l> from Cues -> Notes
  -- <C-h> from Notes -> Cues
  --
  -- Review lives in the Notes window, so the same Notes -> Cues mapping is
  -- installed on the review buffer as well.
  --------------------------------------------------------------------------
  safe_map(
    state.cues_buf,
    "n",
    "<C-l>",
    function()
      focus_window(state.notes_win)
    end,
    "Cornell: Go to Notes"
  )

  safe_map(
    state.notes_buf,
    "n",
    "<C-h>",
    function()
      focus_window(state.cues_win)
    end,
    "Cornell: Go to Cues"
  )

  if valid_buf(state.review_buf) then
    safe_map(
      state.review_buf,
      "n",
      "<C-h>",
      function()
        focus_window(state.cues_win)
      end,
      "Cornell: Go to Cues"
    )
  end

  --------------------------------------------------------------------------
  -- Jump between the corresponding Cue and Note.
  --------------------------------------------------------------------------
  safe_map(
    state.cues_buf,
    "n",
    "<CR>",
    jump_to_note,
    "Cornell: Jump to note"
  )

  safe_map(
    state.notes_buf,
    "n",
    "<CR>",
    jump_to_cue,
    "Cornell: Jump to cue"
  )

  --------------------------------------------------------------------------
  -- Cornell actions.
  --------------------------------------------------------------------------
  safe_map(
    state.cues_buf,
    "n",
    "<leader>ca",
    cornell.open_answer,
    "Cornell: Open answer"
  )

  safe_map(
    state.cues_buf,
    "n",
    "<leader>cq",
    cornell.add_question,
    "Cornell: Add question"
  )

  safe_map(
    state.cues_buf,
    "n",
    "<leader>cc",
    function()
      focus_window(state.cues_win)
    end,
    "Cornell: Cues"
  )

  safe_map(
    state.cues_buf,
    "n",
    "<leader>cn",
    function()
      focus_window(state.notes_win)
    end,
    "Cornell: Notes"
  )

  safe_map(
    state.notes_buf,
    "n",
    "<leader>cc",
    function()
      focus_window(state.cues_win)
    end,
    "Cornell: Cues"
  )

  safe_map(
    state.notes_buf,
    "n",
    "<leader>cn",
    function()
      focus_window(state.notes_win)
    end,
    "Cornell: Notes"
  )

  if valid_buf(state.summary_buf) then
    safe_map(
      state.summary_buf,
      "n",
      "<leader>cc",
      function()
        focus_window(state.cues_win)
      end,
      "Cornell: Cues"
    )

    safe_map(
      state.summary_buf,
      "n",
      "<leader>cn",
      function()
        focus_window(state.notes_win)
      end,
      "Cornell: Notes"
    )
  end
end

return M

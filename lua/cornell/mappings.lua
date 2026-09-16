local state = require("cornell.state")

local M = {}

local function valid_buf(buf) return buf and vim.api.nvim_buf_is_valid(buf) end

local function safe_map(buf, mode, lhs, rhs, desc)
  if not valid_buf(buf) then return end
  local existing = vim.api.nvim_buf_get_keymap(buf, mode)
  for _, map in ipairs(existing) do
    if map.lhs == lhs then return end
  end
  vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
end

function M.setup()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then return end

  local cornell = require("cornell")

  local function common(buf)
    safe_map(buf, "n", "<leader>cv", cornell.toggle, "Cornell: Toggle")
    safe_map(buf, "n", "<leader>cr", cornell.review, "Cornell: Review")
    safe_map(buf, "n", "<leader>cs", cornell.summary, "Cornell: Summary")
    safe_map(buf, "n", "<C-s>", cornell.save, "Cornell: Save")
    safe_map(buf, "n", "q", cornell.close, "Cornell: Close")
  end

  common(state.cues_buf)
  common(state.notes_buf)
  if valid_buf(state.summary_buf) then common(state.summary_buf) end

  safe_map(state.cues_buf, "n", "<CR>", function()
    local qid = require("cornell.sync").current_qid(state.cues_buf)
    if qid then require("cornell.sync").jump_to_note(qid) end
  end, "Cornell: Jump to note")

  safe_map(state.notes_buf, "n", "<CR>", function()
    local qid = require("cornell.sync").current_qid(state.notes_buf)
    if qid then require("cornell.sync").jump_to_cue(qid) end
  end, "Cornell: Jump to cue")

  safe_map(state.cues_buf, "n", "<leader>ca", cornell.open_answer, "Cornell: Open answer")
  safe_map(state.cues_buf, "n", "<leader>cq", cornell.add_question, "Cornell: Add question")
  safe_map(state.cues_buf, "n", "<leader>cc", function() vim.api.nvim_set_current_win(state.cues_win) end, "Cornell: Cues")
  safe_map(state.cues_buf, "n", "<leader>cn", function() vim.api.nvim_set_current_win(state.notes_win) end, "Cornell: Notes")
  safe_map(state.notes_buf, "n", "<leader>cc", function() vim.api.nvim_set_current_win(state.cues_win) end, "Cornell: Cues")
  safe_map(state.notes_buf, "n", "<leader>cn", function() vim.api.nvim_set_current_win(state.notes_win) end, "Cornell: Notes")
end

return M

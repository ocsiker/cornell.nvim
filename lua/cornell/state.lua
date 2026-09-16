local M = {}

M.augroup = nil
M.launcher_augroup = nil
M.layout_ns = vim.api.nvim_create_namespace("cornell_layout")
M.hl_ns = vim.api.nvim_create_namespace("cornell_highlights")

M.active = false
M.closing = false
M.review_mode = false
M.syncing = false

M.source_buf = nil
M.source_win = nil
M.cues_buf = nil
M.notes_buf = nil
M.summary_buf = nil
M.review_buf = nil

M.cues_win = nil
M.notes_win = nil
M.summary_win = nil
M.review_win = nil

M.preamble = {}
M.qids = {}
M.cue_index = {}
M.note_index = {}

function M.reset()
  M.active = false
  M.closing = false
  M.review_mode = false
  M.syncing = false
  M.source_buf = nil
  M.source_win = nil
  M.cues_buf = nil
  M.notes_buf = nil
  M.summary_buf = nil
  M.review_buf = nil
  M.cues_win = nil
  M.notes_win = nil
  M.summary_win = nil
  M.review_win = nil
  M.preamble = {}
  M.qids = {}
  M.cue_index = {}
  M.note_index = {}
end

return M

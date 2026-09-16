local M = {}

M.defaults = {
  cues_width = 32,
  summary_height = 8,
  content_padding = 4,
  qid_prefix = "Q",
  highlights = {
    cue = "Identifier",
    note = "Title",
    summary = "String",
    qid = "Special",
    heading = "Title",
    separator = "WinSeparator",
    review = "WarningMsg",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.options.qid_prefix = tostring(M.options.qid_prefix or "Q"):upper()
  return M.options
end

return M

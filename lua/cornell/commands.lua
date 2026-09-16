local M = {}

function M.setup()
  local cornell = require("cornell")

  vim.api.nvim_create_user_command("Cornell", cornell.toggle, { desc = "Toggle Cornell Notes" })
  vim.api.nvim_create_user_command("CornellOpen", cornell.open, { desc = "Open Cornell Notes" })
  vim.api.nvim_create_user_command("CornellClose", cornell.close, { desc = "Close Cornell Notes" })
  vim.api.nvim_create_user_command("CornellReview", cornell.review, { desc = "Toggle Cornell Review" })
  vim.api.nvim_create_user_command("CornellCheck", cornell.check, { desc = "Check Cornell document" })
  vim.api.nvim_create_user_command("CornellSummary", cornell.summary, { desc = "Toggle Cornell Summary" })
end

return M

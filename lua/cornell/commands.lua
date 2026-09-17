local M = {}
local created = false

function M.setup()
  if created then
    return
  end

  created = true

  vim.api.nvim_create_user_command(
    "Cornell",
    function()
      require("cornell").toggle()
    end,
    { desc = "Toggle Cornell Notes" }
  )

  vim.api.nvim_create_user_command(
    "CornellOpen",
    function()
      require("cornell").open()
    end,
    { desc = "Open Cornell Notes" }
  )

  vim.api.nvim_create_user_command(
    "CornellClose",
    function()
      require("cornell").close()
    end,
    { desc = "Close Cornell Notes" }
  )

  vim.api.nvim_create_user_command(
    "CornellReview",
    function()
      require("cornell").review()
    end,
    { desc = "Toggle Cornell Review" }
  )

  vim.api.nvim_create_user_command(
    "CornellCheck",
    function()
      require("cornell").check()
    end,
    { desc = "Check Cornell document" }
  )

  vim.api.nvim_create_user_command(
    "CornellSummary",
    function()
      require("cornell").summary()
    end,
    { desc = "Toggle Cornell Summary" }
  )
end

return M

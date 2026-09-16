if vim.g.loaded_cornell then
  return
end

vim.g.loaded_cornell = 1

require("cornell").setup()

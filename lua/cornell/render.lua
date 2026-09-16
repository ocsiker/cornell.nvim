local config = require("cornell.config")
local parser = require("cornell.parser")
local state = require("cornell.state")

local M = {}

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

function M.setup_highlights(buf)
  if not valid_buf(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, state.hl_ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    local s, e = line:find("%[" .. vim.pesc(config.options.qid_prefix) .. "%d+%]")
    if s then
      vim.api.nvim_buf_add_highlight(buf, state.hl_ns, config.options.highlights.qid, i - 1, s - 1, e)
    end
  end
end

function M.note_visual_height(win, start_line, finish_line)
  if not valid_win(win) then return math.max(1, finish_line - start_line + 1) end
  if vim.api.nvim_win_text_height then
    local ok, result = pcall(vim.api.nvim_win_text_height, win, {
      start_row = start_line - 1,
      end_row = finish_line,
    })
    if ok and result and result.all then
      return math.max(1, result.all)
    end
  end
  return math.max(1, finish_line - start_line + 1)
end

function M.render_cue_alignment()
  if not valid_buf(state.cues_buf) or not valid_buf(state.notes_buf) then return end
  vim.api.nvim_buf_clear_namespace(state.cues_buf, state.layout_ns, 0, -1)

  local note_lines = vim.api.nvim_buf_get_lines(state.notes_buf, 0, -1, false)
  local blocks = parser.parse_note_blocks(note_lines)
  local cues = vim.api.nvim_buf_get_lines(state.cues_buf, 0, -1, false)
  local cue_count = #cues

  for i, block in ipairs(blocks) do
    if i <= cue_count then
      local extra = M.note_visual_height(state.notes_win, block.start, block.finish) - 1
      if extra > 0 then
        local virt = {}
        for _ = 1, extra do virt[#virt + 1] = { { "", "Normal" } } end
        vim.api.nvim_buf_set_extmark(state.cues_buf, state.layout_ns, i - 1, 0, {
          virt_lines = virt,
          virt_lines_above = false,
          hl_mode = "combine",
        })
      end
    end
  end
end

return M

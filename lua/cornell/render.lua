local api = vim.api

local config = require("cornell.config")
local parser = require("cornell.parser")
local state = require("cornell.state")

local M = {}

local function valid_buf(buf)
  return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
  return win and api.nvim_win_is_valid(win)
end

function M.setup_highlights(buf)
  if not valid_buf(buf) then
    return
  end

  api.nvim_buf_clear_namespace(buf, state.hl_ns, 0, -1)

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local prefix = vim.pesc(config.options.qid_prefix)

  for row, line in ipairs(lines) do
    local qid_start, qid_end = line:find(
      "%[" .. prefix .. "%d+%]"
    )

    if qid_start then
      api.nvim_buf_add_highlight(
        buf,
        state.hl_ns,
        config.options.highlights.qid,
        row - 1,
        qid_start - 1,
        qid_end
      )
    end

    if buf == state.cues_buf then
      local close_bracket = line:find("]")
      if close_bracket then
        api.nvim_buf_add_highlight(
          buf,
          state.hl_ns,
          config.options.highlights.cue,
          row - 1,
          close_bracket,
          -1
        )
      end
    elseif buf == state.notes_buf then
      if line:match("^%s*###%s*%[") then
        api.nvim_buf_add_highlight(
          buf,
          state.hl_ns,
          config.options.highlights.note,
          row - 1,
          0,
          -1
        )

        if qid_start then
          api.nvim_buf_add_highlight(
            buf,
            state.hl_ns,
            config.options.highlights.qid,
            row - 1,
            qid_start - 1,
            qid_end
          )
        end
      end
    end
  end
end

function M.setup_review_highlights(buf)
  if not valid_buf(buf) then
    return
  end

  api.nvim_buf_clear_namespace(buf, state.hl_ns, 0, -1)

  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)

  for row, line in ipairs(lines) do
    if line == "Answer:" or line == "---" then
      api.nvim_buf_add_highlight(
        buf,
        state.hl_ns,
        config.options.highlights.review,
        row - 1,
        0,
        -1
      )
    end
  end
end

function M.note_visual_height(win, start_line, finish_line)
  if not valid_win(win) then
    return math.max(1, finish_line - start_line + 1)
  end

  if api.nvim_win_text_height then
    local ok, result = pcall(
      api.nvim_win_text_height,
      win,
      {
        start_row = start_line - 1,
        end_row = finish_line,
      }
    )

    if ok and result and result.all then
      return math.max(1, result.all)
    end
  end

  return math.max(1, finish_line - start_line + 1)
end

function M.render_cue_alignment()
  if not valid_buf(state.cues_buf)
    or not valid_buf(state.notes_buf)
  then
    return
  end

  api.nvim_buf_clear_namespace(
    state.cues_buf,
    state.layout_ns,
    0,
    -1
  )

  local note_lines = api.nvim_buf_get_lines(
    state.notes_buf,
    0,
    -1,
    false
  )

  local blocks = parser.parse_note_blocks(note_lines)
  local cues = api.nvim_buf_get_lines(
    state.cues_buf,
    0,
    -1,
    false
  )

  for index, block in ipairs(blocks) do
    if index <= #cues then
      local visual_height = M.note_visual_height(
        state.notes_win,
        block.start,
        block.finish
      )

      local extra = visual_height - 1

      if extra > 0 then
        local virt_lines = {}

        for _ = 1, extra do
          virt_lines[#virt_lines + 1] = {
            { "", "Normal" },
          }
        end

        api.nvim_buf_set_extmark(
          state.cues_buf,
          state.layout_ns,
          index - 1,
          0,
          {
            virt_lines = virt_lines,
            virt_lines_above = false,
            hl_mode = "combine",
          }
        )
      end
    end
  end
end

function M.refresh()
  if not state.active then
    return
  end

  M.setup_highlights(state.cues_buf)

  if not state.review_mode then
    M.setup_highlights(state.notes_buf)
    M.render_cue_alignment()
  else
    M.setup_review_highlights(state.review_buf)
  end
end

return M

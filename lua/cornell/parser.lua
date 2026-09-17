local config = require("cornell.config")

local M = {}

local function prefix()
  return vim.pesc(config.options.qid_prefix or "Q")
end

function M.normalize_qid(qid)
  if not qid then
    return nil
  end

  qid = vim.trim(qid):upper()

  if qid:match("^" .. prefix() .. "%d+$") then
    return qid
  end

  return nil
end

function M.extract_qid(line)
  if type(line) ~= "string" then
    return nil
  end

  local qid = line:match("%[(" .. prefix() .. "%d+)%]")
  return M.normalize_qid(qid)
end

function M.is_cue(line)
  if type(line) ~= "string" then
    return false
  end

  local qid = line:match("^%s*%-%s*%[(" .. prefix() .. "%d+)%]%s*(.*)$")
  return M.normalize_qid(qid) ~= nil
end

function M.parse_source(lines)
  local preamble = {}
  local cues = {}
  local notes = {}
  local summary = {}

  local section = "preamble"

  for _, line in ipairs(lines or {}) do
    local heading = line:match("^##%s+(.+)%s*$")

    if heading then
      local h = vim.trim(heading):lower()

      if h == "cues" or h == "questions" then
        section = "cues"
      elseif h == "notes" then
        section = "notes"
      elseif h == "summary" then
        section = "summary"
      else
        section = "other"
      end
    elseif section == "preamble" then
      preamble[#preamble + 1] = line
    elseif section == "cues" then
      cues[#cues + 1] = line
    elseif section == "notes" then
      notes[#notes + 1] = line
    elseif section == "summary" then
      summary[#summary + 1] = line
    end
  end

  return {
    preamble = preamble,
    cues = cues,
    notes = notes,
    summary = summary,
  }
end

function M.parse_cues(lines)
  local cues = {}

  for line_no, line in ipairs(lines or {}) do
    local qid, text = line:match(
      "^%s*%-%s*%[(" .. prefix() .. "%d+)%]%s*(.*)$"
    )

    qid = M.normalize_qid(qid)

    if qid then
      cues[#cues + 1] = {
        qid = qid,
        text = text or "",
        line = line_no,
      }
    end
  end

  return cues
end

function M.parse_note_blocks(lines)
  local blocks = {}
  local current = nil

  local function finish(last_line)
    if not current then
      return
    end

    current.finish = math.max(current.start, last_line)
    current.height = math.max(
      1,
      current.finish - current.start + 1
    )

    blocks[#blocks + 1] = current
    current = nil
  end

  for line_no, line in ipairs(lines or {}) do
    local qid, title = line:match(
      "^%s*###%s*%[(" .. prefix() .. "%d+)%]%s*(.*)$"
    )

    qid = M.normalize_qid(qid)

    if qid then
      finish(line_no - 1)

      current = {
        qid = qid,
        title = title or "",
        start = line_no,
        finish = line_no,
        height = 1,
      }
    end
  end

  finish(#(lines or {}))

  return blocks
end

function M.rebuild_index(state, cues_lines, notes_lines)
  state.qids = {}
  state.cue_index = {}
  state.note_index = {}

  local cues = M.parse_cues(cues_lines)
  for _, cue in ipairs(cues) do
    state.qids[#state.qids + 1] = cue.qid
    if not state.cue_index[cue.qid] then
      state.cue_index[cue.qid] = cue.line
    end
  end

  local notes = M.parse_note_blocks(notes_lines)
  for _, block in ipairs(notes) do
    if not state.note_index[block.qid] then
      state.note_index[block.qid] = block.start
    end
  end
end

function M.next_qid(state)
  local max_number = 0

  for _, qid in ipairs(state.qids or {}) do
    local n = tonumber(qid:match("(%d+)$"))
    if n and n > max_number then
      max_number = n
    end
  end

  return config.options.qid_prefix .. tostring(max_number + 1)
end

function M.build_markdown(state, get_lines)
  local cues = get_lines(state.cues_buf)
  local notes = get_lines(state.notes_buf)
  local summary = get_lines(state.summary_buf)

  local out = vim.deepcopy(state.preamble or {})

  while #out > 0 and vim.trim(out[#out]) == "" do
    table.remove(out)
  end

  local function append_section(name, lines)
    if #out > 0 then
      out[#out + 1] = ""
    end

    out[#out + 1] = "## " .. name

    for _, line in ipairs(lines or {}) do
      out[#out + 1] = line
    end
  end

  append_section("Cues", cues)
  append_section("Notes", notes)
  append_section("Summary", summary)

  return out
end

return M

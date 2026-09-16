local config = require("cornell.config")

local M = {}

local function prefix()
  return vim.pesc(config.options.qid_prefix)
end

function M.normalize_qid(qid)
  if not qid then return nil end
  qid = vim.trim(qid):upper()
  if qid:match("^" .. prefix() .. "%d+$") then
    return qid
  end
  return nil
end

function M.extract_qid(line)
  local qid = line:match("%[(" .. prefix() .. "%d+)%]")
  return M.normalize_qid(qid)
end

function M.parse_source(lines)
  local preamble, cues, notes, summary = {}, {}, {}, {}
  local section = "preamble"

  for _, line in ipairs(lines) do
    local heading = line:match("^##%s+(.+)%s*$")
    if heading then
      local h = heading:lower()
      if h == "cues" or h == "questions" then
        section = "cues"
      elseif h == "notes" then
        section = "notes"
      elseif h == "summary" then
        section = "summary"
      else
        if section == "preamble" then
          table.insert(preamble, line)
        elseif section == "cues" then
          table.insert(cues, line)
        elseif section == "notes" then
          table.insert(notes, line)
        elseif section == "summary" then
          table.insert(summary, line)
        end
        section = "other"
      end
    else
      if section == "preamble" then
        table.insert(preamble, line)
      elseif section == "cues" then
        table.insert(cues, line)
      elseif section == "notes" then
        table.insert(notes, line)
      elseif section == "summary" then
        table.insert(summary, line)
      end
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
  for _, line in ipairs(lines) do
    local qid, text = line:match("^%s*%-%s*%[(" .. prefix() .. "%d+)%]%s*(.*)$")
    qid = M.normalize_qid(qid)
    if qid then
      table.insert(cues, { qid = qid, text = text or "" })
    end
  end
  return cues
end

function M.parse_note_blocks(lines)
  local blocks = {}
  local current

  local function finish(last)
    if not current then return end
    current.finish = last
    current.height = math.max(1, current.finish - current.start + 1)
    table.insert(blocks, current)
    current = nil
  end

  for i, line in ipairs(lines) do
    local qid, title = line:match("^%s*###%s*%[(" .. prefix() .. "%d+)%]%s*(.*)$")
    qid = M.normalize_qid(qid)
    if qid then
      finish(i - 1)
      current = {
        qid = qid,
        title = title or "",
        start = i,
        finish = i,
        height = 1,
      }
    end
  end

  finish(#lines)
  return blocks
end

function M.rebuild_index(state, cues_lines, notes_lines)
  state.qids = {}
  state.cue_index = {}
  state.note_index = {}

  for i, cue in ipairs(M.parse_cues(cues_lines)) do
    state.qids[#state.qids + 1] = cue.qid
    for line_no, line in ipairs(cues_lines) do
      if M.extract_qid(line) == cue.qid then
        state.cue_index[cue.qid] = line_no
        break
      end
    end
  end

  for i, block in ipairs(M.parse_note_blocks(notes_lines)) do
    state.note_index[block.qid] = block.start
  end
end

function M.next_qid(state)
  local max = 0
  for _, qid in ipairs(state.qids) do
    local n = tonumber(qid:match("%d+$"))
    if n and n > max then max = n end
  end
  return config.options.qid_prefix .. tostring(max + 1)
end

function M.build_markdown(state, get_lines)
  local cues = get_lines(state.cues_buf)
  local notes = get_lines(state.notes_buf)
  local summary = get_lines(state.summary_buf)

  local out = vim.deepcopy(state.preamble)
  while #out > 0 and out[#out] == "" do table.remove(out) end

  local function append_section(name, lines)
    if #out > 0 then out[#out + 1] = "" end
    out[#out + 1] = "## " .. name
    for _, line in ipairs(lines) do out[#out + 1] = line end
  end

  append_section("Cues", cues)
  append_section("Notes", notes)
  append_section("Summary", summary)

  return out
end

return M

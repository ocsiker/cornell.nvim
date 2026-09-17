local api = vim.api

local config = require("cornell.config")
local state = require("cornell.state")

local M = {}

local function valid_buf(buf)
	return buf and api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
	return win and api.nvim_win_is_valid(win)
end

local function map(buf, mode, lhs, rhs, desc, opts)
	if not valid_buf(buf) or not lhs or lhs == "" then
		return
	end

	opts = vim.tbl_extend("force", {
		buffer = buf,
		silent = true,
		noremap = true,
		desc = desc,
	}, opts or {})

	vim.keymap.set(mode, lhs, rhs, opts)
end

local function focus(win)
	if valid_win(win) then
		api.nvim_set_current_win(win)
		return true
	end

	return false
end

local function focus_cues()
	return focus(state.cues_win)
end

local function focus_notes()
	return focus(state.notes_win)
end

local function focus_summary()
	return focus(state.summary_win)
end

local function jump_to_note()
	if not valid_buf(state.cues_buf) then
		return
	end

	local sync = require("cornell.sync")
	local qid = sync.current_qid(state.cues_buf)

	if qid then
		sync.jump_to_note(qid)
	end
end

local function jump_to_cue()
	if not valid_buf(state.notes_buf) then
		return
	end

	local sync = require("cornell.sync")
	local qid = sync.current_qid(state.notes_buf)

	if qid then
		sync.jump_to_cue(qid)
	end
end

local function common(buf, cornell)
	if not valid_buf(buf) then
		return
	end

	map(buf, "n", config.options.keymaps.toggle, cornell.toggle, "Cornell: Toggle")

	map(buf, "n", config.options.keymaps.review, cornell.review, "Cornell: Review")

	map(buf, "n", config.options.keymaps.summary, cornell.summary, "Cornell: Summary")

	map(buf, "n", config.options.keymaps.save, cornell.save, "Cornell: Save")

	map(buf, "n", config.options.keymaps.close, cornell.close, "Cornell: Close")
end

function M.setup()
	local cornell = require("cornell")

	---------------------------------------------------------------------------
	-- CUES
	---------------------------------------------------------------------------

	if valid_buf(state.cues_buf) then
		common(state.cues_buf, cornell)

		-- IMPORTANT:
		-- These are intentionally buffer-local and intentionally override
		-- existing mappings while Cornell View is active.
		map(state.cues_buf, "n", "<C-l>", focus_notes, "Cornell: Cues -> Notes", { nowait = true })

		map(state.cues_buf, "n", "<CR>", jump_to_note, "Cornell: Jump to note")

		map(state.cues_buf, "n", config.options.keymaps.answer, cornell.open_answer, "Cornell: Open answer")

		map(state.cues_buf, "n", config.options.keymaps.add_question, cornell.add_question, "Cornell: Add question")

		map(state.cues_buf, "n", config.options.keymaps.cues, focus_cues, "Cornell: Cues")

		map(state.cues_buf, "n", config.options.keymaps.notes, focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- NOTES
	---------------------------------------------------------------------------

	if valid_buf(state.notes_buf) then
		common(state.notes_buf, cornell)

		-- IMPORTANT:
		-- Notes -> Cues must always work inside Cornell View.
		map(state.notes_buf, "n", "<C-h>", focus_cues, "Cornell: Notes -> Cues", { nowait = true })

		map(state.notes_buf, "n", "<CR>", jump_to_cue, "Cornell: Jump to cue")

		map(state.notes_buf, "n", config.options.keymaps.cues, focus_cues, "Cornell: Cues")

		map(state.notes_buf, "n", config.options.keymaps.notes, focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- SUMMARY
	---------------------------------------------------------------------------

	if valid_buf(state.summary_buf) then
		common(state.summary_buf, cornell)

		map(state.summary_buf, "n", "<C-h>", focus_cues, "Cornell: Summary -> Cues", { nowait = true })

		map(state.summary_buf, "n", "<C-l>", focus_notes, "Cornell: Summary -> Notes", { nowait = true })

		map(state.summary_buf, "n", config.options.keymaps.cues, focus_cues, "Cornell: Cues")

		map(state.summary_buf, "n", config.options.keymaps.notes, focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- REVIEW
	--
	-- Review buffer replaces Notes buffer inside notes_win.
	-- Therefore <C-h> must also be installed here.
	---------------------------------------------------------------------------

	if valid_buf(state.review_buf) then
		common(state.review_buf, cornell)

		map(state.review_buf, "n", "<C-h>", focus_cues, "Cornell: Review -> Cues", { nowait = true })

		map(state.review_buf, "n", "<C-l>", focus_notes, "Cornell: Review -> Notes", { nowait = true })

		map(state.review_buf, "n", config.options.keymaps.cues, focus_cues, "Cornell: Cues")

		map(state.review_buf, "n", config.options.keymaps.notes, focus_notes, "Cornell: Notes")
	end
end

return M

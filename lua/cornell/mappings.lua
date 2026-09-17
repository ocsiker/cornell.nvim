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

local function keymaps()
	return config.options.keymaps or {}
end

local function map(buf, mode, lhs, rhs, desc)
	if not valid_buf(buf) then
		return
	end

	if not lhs or lhs == "" then
		return
	end

	vim.keymap.set(mode, lhs, rhs, {
		buffer = buf,
		silent = true,
		noremap = true,
		nowait = true,
		desc = desc,
	})
end

local function focus(win)
	if not valid_win(win) then
		return false
	end

	api.nvim_set_current_win(win)

	return true
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
	local cornell = require("cornell")

	if cornell.jump_to_note then
		cornell.jump_to_note()
	end
end

local function jump_to_cue()
	local cornell = require("cornell")

	if cornell.jump_to_cue then
		cornell.jump_to_cue()
	end
end

local function common(buf, cornell)
	if not valid_buf(buf) then
		return
	end

	local km = keymaps()

	---------------------------------------------------------------------------
	-- Cornell toggle
	---------------------------------------------------------------------------

	map(buf, "n", km.toggle or "<leader>cv", cornell.toggle, "Cornell: Toggle")

	---------------------------------------------------------------------------
	-- Review
	---------------------------------------------------------------------------

	map(buf, "n", km.review or "<leader>cr", cornell.review, "Cornell: Review")

	---------------------------------------------------------------------------
	-- Summary
	---------------------------------------------------------------------------

	map(buf, "n", km.summary or "<leader>cs", cornell.summary, "Cornell: Summary")

	---------------------------------------------------------------------------
	-- Save
	---------------------------------------------------------------------------

	map(buf, "n", km.save or "<C-s>", cornell.save, "Cornell: Save")

	---------------------------------------------------------------------------
	-- Close
	---------------------------------------------------------------------------

	map(buf, "n", km.close or "q", cornell.close, "Cornell: Close")
end

function M.setup()
	local cornell = require("cornell")
	local km = keymaps()

	---------------------------------------------------------------------------
	-- CUES
	---------------------------------------------------------------------------

	if valid_buf(state.cues_buf) then
		common(state.cues_buf, cornell)

		-------------------------------------------------------------------------
		-- Cues -> Notes
		--
		-- This is deliberately NOT implemented using <C-w>l.
		-- We know exactly which window is Cornell Notes.
		-------------------------------------------------------------------------

		map(state.cues_buf, "n", "<C-l>", focus_notes, "Cornell: Cues -> Notes")

		-------------------------------------------------------------------------
		-- Jump from cue to corresponding note.
		-------------------------------------------------------------------------

		map(state.cues_buf, "n", km.jump or "<CR>", jump_to_note, "Cornell: Jump to note")

		-------------------------------------------------------------------------
		-- Open answer.
		-------------------------------------------------------------------------

		map(state.cues_buf, "n", km.answer or "<leader>ca", cornell.open_answer, "Cornell: Open answer")

		-------------------------------------------------------------------------
		-- Add question.
		-------------------------------------------------------------------------

		map(state.cues_buf, "n", km.add_question or "<leader>cq", cornell.add_question, "Cornell: Add question")

		-------------------------------------------------------------------------
		-- Explicit focus mappings.
		-------------------------------------------------------------------------

		map(state.cues_buf, "n", km.cues or "<leader>cc", focus_cues, "Cornell: Cues")

		map(state.cues_buf, "n", km.notes or "<leader>cn", focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- NOTES
	---------------------------------------------------------------------------

	if valid_buf(state.notes_buf) then
		common(state.notes_buf, cornell)

		-------------------------------------------------------------------------
		-- Notes -> Cues
		-------------------------------------------------------------------------

		map(state.notes_buf, "n", "<C-h>", focus_cues, "Cornell: Notes -> Cues")

		-------------------------------------------------------------------------
		-- Jump from note to corresponding cue.
		-------------------------------------------------------------------------

		map(state.notes_buf, "n", km.jump or "<CR>", jump_to_cue, "Cornell: Jump to cue")

		-------------------------------------------------------------------------
		-- Explicit focus mappings.
		-------------------------------------------------------------------------

		map(state.notes_buf, "n", km.cues or "<leader>cc", focus_cues, "Cornell: Cues")

		map(state.notes_buf, "n", km.notes or "<leader>cn", focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- SUMMARY
	---------------------------------------------------------------------------

	if valid_buf(state.summary_buf) then
		common(state.summary_buf, cornell)

		map(state.summary_buf, "n", "<C-h>", focus_cues, "Cornell: Summary -> Cues")

		map(state.summary_buf, "n", "<C-l>", focus_notes, "Cornell: Summary -> Notes")

		map(state.summary_buf, "n", km.cues or "<leader>cc", focus_cues, "Cornell: Cues")

		map(state.summary_buf, "n", km.notes or "<leader>cn", focus_notes, "Cornell: Notes")
	end

	---------------------------------------------------------------------------
	-- REVIEW
	--
	-- Review replaces the Notes buffer inside notes_win.
	-- Therefore navigation must also exist here.
	---------------------------------------------------------------------------

	if valid_buf(state.review_buf) then
		common(state.review_buf, cornell)

		map(state.review_buf, "n", "<C-h>", focus_cues, "Cornell: Review -> Cues")

		map(state.review_buf, "n", "<C-l>", focus_notes, "Cornell: Review -> Notes")

		map(state.review_buf, "n", km.cues or "<leader>cc", focus_cues, "Cornell: Cues")

		map(state.review_buf, "n", km.notes or "<leader>cn", focus_notes, "Cornell: Notes")
	end
end

return M

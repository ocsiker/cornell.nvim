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

local function create_scratch_buffer()
	local buf = api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].buflisted = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].filetype = "markdown"

	return buf
end

local function mark_window(win, role)
	if not valid_win(win) then
		return
	end

	vim.w[win].cornell = true
	vim.w[win].cornell_role = role
end

local function base_window_options(win)
	if not valid_win(win) then
		return
	end

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].cursorline = true
	vim.wo[win].list = false
	vim.wo[win].spell = false
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
end

local function setup_content_padding(win)
	if not valid_win(win) then
		return
	end

	local padding = tonumber(config.options.content_padding) or 0
	padding = math.max(0, math.floor(padding))

	vim.wo[win].breakindent = true
	vim.wo[win].breakindentopt = "shift:" .. tostring(padding) .. ",min:" .. tostring(padding)

	if padding > 0 then
		vim.wo[win].statuscolumn = string.format("%%{repeat(' ', %d)}", padding)
	else
		vim.wo[win].statuscolumn = ""
	end
end

local function setup_cues_window(win)
	if not valid_win(win) then
		return
	end

	base_window_options(win)

	vim.wo[win].wrap = false
	vim.wo[win].linebreak = false
	vim.wo[win].breakindent = false
	vim.wo[win].breakindentopt = ""
	vim.wo[win].statuscolumn = ""

	-- Cues is the fixed left column.
	vim.wo[win].winfixwidth = true

	vim.wo[win].winbar = " CUES / QUESTIONS "
end

local function setup_notes_window(win)
	if not valid_win(win) then
		return
	end

	base_window_options(win)

	vim.wo[win].winfixwidth = false

	setup_content_padding(win)

	vim.wo[win].winbar = " NOTES / ANSWERS "
end

local function setup_summary_window(win)
	if not valid_win(win) then
		return
	end

	base_window_options(win)

	vim.wo[win].winfixheight = true

	setup_content_padding(win)

	vim.wo[win].winbar = " SUMMARY "
end

function M.setup_buffer(buf, win, filetype)
	if not valid_buf(buf) then
		return
	end

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].buflisted = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].filetype = filetype or "markdown"

	if win == state.cues_win then
		setup_cues_window(win)
	elseif win == state.notes_win then
		setup_notes_window(win)
	elseif win == state.summary_win then
		setup_summary_window(win)
	end
end

function M.setup_content_padding(win)
	setup_content_padding(win)
end

function M.setup_title(win, title)
	if valid_win(win) then
		vim.wo[win].winbar = " " .. title .. " "
	end
end

function M.mark_cornell_window(win, role)
	mark_window(win, role)
end

function M.focus_cues()
	if not valid_win(state.cues_win) then
		return false
	end

	api.nvim_set_current_win(state.cues_win)
	return true
end

function M.focus_notes()
	if not valid_win(state.notes_win) then
		return false
	end

	api.nvim_set_current_win(state.notes_win)
	return true
end

function M.focus_summary()
	if not valid_win(state.summary_win) then
		return false
	end

	api.nvim_set_current_win(state.summary_win)
	return true
end

function M.resize()
	if not state.active then
		return
	end

	---------------------------------------------------------------------------
	-- Cues width
	---------------------------------------------------------------------------

	if valid_win(state.cues_win) then
		local width = tonumber(config.options.cues_width) or 32
		width = math.max(1, math.floor(width))

		pcall(api.nvim_win_set_width, state.cues_win, width)
	end

	---------------------------------------------------------------------------
	-- Summary height
	---------------------------------------------------------------------------

	if valid_win(state.summary_win) then
		local height = tonumber(config.options.summary_height) or 8
		height = math.max(1, math.floor(height))

		pcall(api.nvim_win_set_height, state.summary_win, height)
	end
end

function M.open(parsed)
	if state.active then
		return false
	end

	local source_buf = state.source_buf
	local source_win = state.source_win

	if not valid_buf(source_buf) or not valid_win(source_win) then
		return false
	end

	---------------------------------------------------------------------------
	-- Create Cornell buffers
	---------------------------------------------------------------------------

	state.cues_buf = create_scratch_buffer()
	state.notes_buf = create_scratch_buffer()
	state.summary_buf = create_scratch_buffer()

	api.nvim_buf_set_lines(state.cues_buf, 0, -1, false, parsed.cues or {})

	api.nvim_buf_set_lines(state.notes_buf, 0, -1, false, parsed.notes or {})

	api.nvim_buf_set_lines(state.summary_buf, 0, -1, false, parsed.summary or {})

	---------------------------------------------------------------------------
	-- Source window becomes Notes
	---------------------------------------------------------------------------

	state.notes_win = source_win

	api.nvim_win_set_buf(state.notes_win, state.notes_buf)

	mark_window(state.notes_win, "notes")

	M.setup_buffer(state.notes_buf, state.notes_win, "markdown")

	---------------------------------------------------------------------------
	-- Create Cues column on the left
	---------------------------------------------------------------------------

	api.nvim_set_current_win(state.notes_win)

	vim.cmd("leftabove vsplit")

	state.cues_win = api.nvim_get_current_win()

	api.nvim_win_set_buf(state.cues_win, state.cues_buf)

	mark_window(state.cues_win, "cues")

	M.setup_buffer(state.cues_buf, state.cues_win, "markdown")

	---------------------------------------------------------------------------
	-- Return to Notes
	---------------------------------------------------------------------------

	M.focus_notes()

	state.active = true

	M.resize()

	return true
end

function M.toggle_summary()
	if not state.active then
		return false
	end

	if not valid_buf(state.summary_buf) then
		return false
	end

	---------------------------------------------------------------------------
	-- Close Summary
	---------------------------------------------------------------------------

	if valid_win(state.summary_win) then
		local was_current = api.nvim_get_current_win() == state.summary_win

		local win = state.summary_win

		state.summary_win = nil

		if valid_win(win) and #api.nvim_list_wins() > 1 then
			pcall(api.nvim_win_close, win, true)
		end

		if was_current then
			M.focus_notes()
		end

		return true
	end

	---------------------------------------------------------------------------
	-- Open Summary
	---------------------------------------------------------------------------

	if not valid_win(state.notes_win) then
		return false
	end

	local previous_win = api.nvim_get_current_win()

	M.focus_notes()

	vim.cmd("belowright split")

	state.summary_win = api.nvim_get_current_win()

	api.nvim_win_set_buf(state.summary_win, state.summary_buf)

	mark_window(state.summary_win, "summary")

	M.setup_buffer(state.summary_buf, state.summary_win, "markdown")

	M.resize()

	---------------------------------------------------------------------------
	-- Restore the user's focus.
	---------------------------------------------------------------------------

	if previous_win == state.cues_win then
		M.focus_cues()
	elseif previous_win == state.summary_win then
		M.focus_summary()
	else
		M.focus_notes()
	end

	return true
end

function M.close_aux_window(win)
	if not valid_win(win) then
		return false
	end

	if #api.nvim_list_wins() <= 1 then
		return false
	end

	return pcall(api.nvim_win_close, win, true)
end

function M.restore_source()
	if not valid_win(state.notes_win) then
		return false
	end

	if not valid_buf(state.source_buf) then
		return false
	end

	api.nvim_win_set_buf(state.notes_win, state.source_buf)

	return true
end

return M

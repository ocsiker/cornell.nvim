local M = {}

M.defaults = {
	cues_width = 32,
	summary_height = 8,
	content_padding = 4,
	qid_prefix = "Q",

	highlights = {
		cue = "Identifier",
		note = "Title",
		summary = "String",
		qid = "Special",
		heading = "Title",
		separator = "WinSeparator",
		review = "WarningMsg",
	},

	keymaps = {
		toggle = "<leader>cv",
		jump = "<CR>",
		answer = "<leader>ca",
		add_question = "<leader>cq",
		review = "<leader>cr",
		notes = "<leader>cn",
		summary = "<leader>cs",
		cues = "<leader>cc",
		save = "<C-s>",
		close = "q",
	},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
	opts = opts or {}

	M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.options), opts)

	local prefix = tostring(M.options.qid_prefix or "Q"):upper()

	if not prefix:match("^[A-Z][A-Z0-9_-]*$") then
		prefix = "Q"
	end

	M.options.qid_prefix = prefix

	return M.options
end

function M.get()
	return M.options
end

return M

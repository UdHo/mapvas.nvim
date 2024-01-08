local M = {}

local function send_mapcat(content)
	local cmd = ("echo '$content' | mapcat"):gsub("$content", content)
	os.execute(cmd)
end

local function send_line(line_number)
	vim.print(line_number)
	if line_number == nil then
		line_number = select(1, unpack(vim.api.nvim_win_get_cursor(0)))
	end
	vim.print(line_number)
	local line_content = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)
	send_mapcat(line_content)
end

M.draw = send_mapcat
M.send_line = send_line
return M

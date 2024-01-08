local M = {}
local function send_mapcat(body)
	local cmd = string.format("echo '%s' | mapcat", body)
	os.execute(cmd)
end

local function send_line(line_number)
	if line_number == nil then
		line_number = select(1, unpack(vim.api.nvim_win_get_cursor(0)))
	end
	local line_content = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]
	send_mapcat(line_content)
end

local function send_buffer()
	local buffer_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	send_mapcat(table.concat(buffer_content, "\n"))
end

M.send = send_mapcat
M.send_line = send_line
M.send_buffer = send_buffer
return M

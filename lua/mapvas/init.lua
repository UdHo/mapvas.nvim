local M = {}

local ns = vim.api.nvim_create_namespace('mapvas')
local augroup = vim.api.nvim_create_augroup('mapvas', { clear = true })

-- Vim regex matching the grep parser's coordinate pattern: (-?\d*\.\d*), ?(-?\d*\.\d*)
local coord_re = vim.regex([[-\?\d*\.\d*,\s*-\?\d*\.\d*]])

local state = {
  auto = false,
  highlight = true,
}

-- Highlight all coordinate pairs in buf using extmarks.
local function highlight_buf(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if not state.highlight then return end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for lnum, line in ipairs(lines) do
    local col = 0
    while col <= #line do
      local s, e = coord_re:match_str(line:sub(col + 1))
      if not s then break end
      vim.api.nvim_buf_add_highlight(bufnr, ns, 'MapvasCoord', lnum - 1, col + s, col + e)
      col = col + e
      if e == s then col = col + 1 end -- guard against zero-width match
    end
  end
end

local function clear()
  local out = vim.fn.system({
    'curl', '-s', '-X', 'POST', 'http://localhost:12345/',
    '-H', 'Content-Type: application/json',
    '-d', '"Clear"',
  })
  if vim.v.shell_error ~= 0 then
    vim.notify('mapvas: clear failed: ' .. out, vim.log.levels.ERROR)
  end
end

local function send_lines(lines)
  local stdin = table.concat(lines, '\n')
  local out = vim.fn.system({ 'mapcat', '--focus' }, stdin)
  if vim.v.shell_error ~= 0 then
    vim.notify('mapvas: ' .. out, vim.log.levels.ERROR)
  end
end

local function send_buf(bufnr)
  send_lines(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

-- Register auto-send and auto-highlight autocmds.
local function enable_auto()
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    callback = function(ev)
      send_buf(ev.buf)
      highlight_buf(ev.buf)
    end,
    desc = 'mapvas: send buffer to mapvas on save',
  })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = augroup,
    callback = function(ev)
      highlight_buf(ev.buf)
    end,
    desc = 'mapvas: refresh coordinate highlights on change',
  })
end

local function disable_auto()
  vim.api.nvim_clear_autocmds({ group = augroup })
end

-- Public API ------------------------------------------------------------------

--- Send the current buffer (or a range) to mapvas.
--- @param opts? { line1: integer, line2: integer }
function M.send(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  if opts and opts.line1 then
    send_lines(vim.api.nvim_buf_get_lines(bufnr, opts.line1 - 1, opts.line2, false))
  else
    send_buf(bufnr)
  end
end

--- Clear the map.
function M.clear()
  clear()
end

--- Highlight coordinate pairs in the current buffer.
function M.highlight()
  highlight_buf(vim.api.nvim_get_current_buf())
end

--- Toggle automatic send-on-save + highlight-on-change.
function M.toggle_auto()
  state.auto = not state.auto
  if state.auto then
    enable_auto()
    local bufnr = vim.api.nvim_get_current_buf()
    send_buf(bufnr)
    highlight_buf(bufnr)
    vim.notify('mapvas: auto on')
  else
    disable_auto()
    vim.notify('mapvas: auto off')
  end
end

--- Toggle coordinate highlighting.
function M.toggle_highlight()
  state.highlight = not state.highlight
  local bufnr = vim.api.nvim_get_current_buf()
  if state.highlight then
    highlight_buf(bufnr)
    vim.notify('mapvas: highlight on')
  else
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.notify('mapvas: highlight off')
  end
end

--- Toggle the layer explorer sidebar.
function M.sidebar_toggle()
  require('mapvas.sidebar').toggle()
end

--- @param opts? { highlight_group?: string, keys?: { send?: string, toggle?: string, highlight?: string, sidebar?: string } }
function M.setup(opts)
  opts = opts or {}
  local hl = opts.highlight_group or 'Search'
  vim.api.nvim_set_hl(0, 'MapvasCoord', { link = hl, default = true })

  local keys = vim.tbl_extend('force', {
    send      = '<leader>ms',
    clear     = '<leader>mc',
    toggle    = '<leader>mt',
    highlight = '<leader>mh',
    sidebar   = '<leader>ml',
  }, opts.keys or {})

  vim.keymap.set('n', keys.send,      '<cmd>Mapvas<cr>',          { desc = 'mapvas: send buffer' })
  vim.keymap.set('v', keys.send,      ':Mapvas<cr>',              { desc = 'mapvas: send selection' })
  vim.keymap.set('n', keys.clear,     '<cmd>MapvasClear<cr>',     { desc = 'mapvas: clear map' })
  vim.keymap.set('n', keys.toggle,    '<cmd>MapvasToggle<cr>',    { desc = 'mapvas: toggle auto' })
  vim.keymap.set('n', keys.highlight, '<cmd>MapvasHighlight<cr>', { desc = 'mapvas: toggle highlight' })
  vim.keymap.set('n', keys.sidebar,   '<cmd>MapvasSidebar<cr>',   { desc = 'mapvas: toggle layer sidebar' })
end

return M

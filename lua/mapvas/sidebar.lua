local M = {}

local state = {
  buf = nil,
  win = nil,
  layers = {},     -- [{id, visible, shape_count}]
  shapes = nil,    -- nil = layer view; {layer_id, items=[{index,label,shape_type,visible}]} = shape view
  timer = nil,
  width = 42,
}

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- helpers ---------------------------------------------------------------------

local function layer_line(layer)
  local check = layer.visible and '[x]' or '[ ]'
  local count = string.format('(%d)', layer.shape_count)
  local id_w = state.width - 2 - 4 - 1 - #count - 2
  local id = layer.id
  if #id > id_w then id = id:sub(1, id_w - 1) .. '…' end
  local pad = id_w - #id
  return string.format(' %s %s%s %s ›', check, id, string.rep(' ', pad), count)
end

local function shape_line(shape)
  local check = shape.visible and '[x]' or '[ ]'
  local typ = string.format('[%s]', shape.shape_type:sub(1, 4))
  local label = shape.label or string.format('#%d', shape.index)
  local label_w = state.width - 2 - 4 - 1 - #typ - 1
  if #label > label_w then label = label:sub(1, label_w - 1) .. '…' end
  return string.format(' %s %s %s', check, typ, label)
end

-- render ----------------------------------------------------------------------

local function render()
  if not is_open() then return end
  if not vim.api.nvim_buf_is_valid(state.buf) then return end

  local lines
  if state.shapes then
    local title = '‹ ' .. state.shapes.layer_id
    lines = {
      string.format(' %-' .. (state.width - 12) .. 's [r]efresh', title),
      ' ' .. string.rep('─', state.width - 2),
    }
    if #state.shapes.items == 0 then
      lines[#lines + 1] = '  (no shapes)'
    else
      for _, shape in ipairs(state.shapes.items) do
        lines[#lines + 1] = shape_line(shape)
      end
    end
  else
    lines = {
      string.format(' %-' .. (state.width - 12) .. 's [r]efresh', 'Layers'),
      ' ' .. string.rep('─', state.width - 2),
    }
    if #state.layers == 0 then
      lines[#lines + 1] = '  (no layers)'
    else
      for _, layer in ipairs(state.layers) do
        lines[#lines + 1] = layer_line(layer)
      end
    end
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

-- fetch -----------------------------------------------------------------------

local function url_encode(str)
  return (str:gsub('[^%w%-_%.~]', function(c)
    return string.format('%%%02X', string.byte(c))
  end))
end

local function fetch_shapes(layer_id, cb)
  vim.system(
    { 'curl', '-s', '--max-time', '2',
      string.format('http://localhost:12345/layer/%s/shapes', url_encode(layer_id)) },
    { text = true },
    function(result)
      if result.code ~= 0 or result.stdout == '' then
        cb({})
        return
      end
      local ok, data = pcall(vim.json.decode, result.stdout)
      cb(ok and data or {})
    end
  )
end

local function fetch()
  vim.system(
    { 'curl', '-s', '--max-time', '2', 'http://localhost:12345/state' },
    { text = true },
    function(result)
      if result.code ~= 0 or result.stdout == '' then return end
      local ok, data = pcall(vim.json.decode, result.stdout)
      if not ok or type(data) ~= 'table' then return end
      state.layers = data.layers or {}
      -- If we are in shape view, refresh shapes too
      if state.shapes then
        local lid = state.shapes.layer_id
        fetch_shapes(lid, function(items)
          state.shapes = { layer_id = lid, items = items }
          vim.schedule(render)
        end)
      else
        vim.schedule(render)
      end
    end
  )
end

-- cursor helpers --------------------------------------------------------------

local function cursor_row()
  if not is_open() then return nil end
  return vim.api.nvim_win_get_cursor(state.win)[1]
end

local function layer_at_cursor()
  local row = cursor_row()
  if not row then return nil end
  local idx = row - 2
  if idx < 1 or idx > #state.layers then return nil end
  return state.layers[idx]
end

local function shape_at_cursor()
  if not state.shapes then return nil end
  local row = cursor_row()
  if not row then return nil end
  local idx = row - 2
  if idx < 1 or idx > #state.shapes.items then return nil end
  return state.shapes.items[idx]
end

-- actions ---------------------------------------------------------------------

local function enter_layer(layer)
  fetch_shapes(layer.id, function(items)
    state.shapes = { layer_id = layer.id, items = items }
    vim.schedule(render)
  end)
end

local function exit_layer()
  state.shapes = nil
  vim.schedule(render)
end

local function handle_enter()
  if state.shapes then
    -- shape view: focus the shape
    local shape = shape_at_cursor()
    if not shape then return end
    vim.system(
      {
        'curl', '-s', '-X', 'POST', 'http://localhost:12345/',
        '-H', 'Content-Type: application/json',
        '-d', vim.json.encode({
          FocusShape = { layer_id = state.shapes.layer_id, shape_idx = shape.index },
        }),
      },
      { text = true }, function() end
    )
  else
    -- layer view: drill in
    local layer = layer_at_cursor()
    if layer then enter_layer(layer) end
  end
end

local function toggle_visibility()
  if state.shapes then
    local shape = shape_at_cursor()
    if not shape then return end
    local new_visible = not shape.visible
    vim.system(
      {
        'curl', '-s', '-X', 'POST',
        string.format('http://localhost:12345/layer/%s/shape/%d',
          url_encode(state.shapes.layer_id), shape.index),
        '-H', 'Content-Type: application/json',
        '-d', vim.json.encode({ visible = new_visible }),
      },
      { text = true },
      function(_)
        shape.visible = new_visible
        vim.schedule(render)
      end
    )
  else
    local layer = layer_at_cursor()
    if not layer then return end
    local new_visible = not layer.visible
    vim.system(
      {
        'curl', '-s', '-X', 'POST', 'http://localhost:12345/layer',
        '-H', 'Content-Type: application/json',
        '-d', vim.json.encode({ id = layer.id, visible = new_visible }),
      },
      { text = true },
      function(_)
        layer.visible = new_visible
        vim.schedule(render)
      end
    )
  end
end

local function focus_layer()
  if state.shapes then return end
  local layer = layer_at_cursor()
  if not layer then return end
  vim.system(
    {
      'curl', '-s', '-X', 'POST', 'http://localhost:12345/',
      '-H', 'Content-Type: application/json',
      '-d', vim.json.encode({ FocusLayer = { id = layer.id } }),
    },
    { text = true }, function() end
  )
end

-- timer -----------------------------------------------------------------------

local function stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function start_timer()
  stop_timer()
  state.timer = vim.uv.new_timer()
  state.timer:start(0, 2000, vim.schedule_wrap(fetch))
end

-- open / close / toggle -------------------------------------------------------

function M.open()
  if is_open() then return end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].buftype = 'nofile'
  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].buflisted = false
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].filetype = 'mapvas-sidebar'

  local current_win = vim.api.nvim_get_current_win()
  vim.cmd('topleft ' .. state.width .. 'vsplit')
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.api.nvim_set_current_win(current_win)

  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = 'no'
  vim.wo[state.win].wrap = false
  vim.wo[state.win].winfixwidth = true
  vim.wo[state.win].cursorline = true

  local buf = state.buf
  local opts = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set('n', 'q',      function() M.close() end,    opts)
  vim.keymap.set('n', '<Esc>',  function() M.close() end,    opts)
  vim.keymap.set('n', 'r',      function() fetch() end,      opts)
  vim.keymap.set('n', '<CR>',   handle_enter,                opts)
  vim.keymap.set('n', '<BS>',   exit_layer,                  opts)
  vim.keymap.set('n', 'v',      toggle_visibility,           opts)
  vim.keymap.set('n', '<Space>', toggle_visibility,           opts)
  vim.keymap.set('n', 'f',      focus_layer,                 opts)

  vim.api.nvim_create_autocmd('WinClosed', {
    buffer = buf,
    once = true,
    callback = function()
      stop_timer()
      state.win = nil
      state.buf = nil
      state.shapes = nil
    end,
  })

  start_timer()
  render()
end

function M.close()
  stop_timer()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.shapes = nil
end

function M.toggle()
  if is_open() then M.close() else M.open() end
end

return M
